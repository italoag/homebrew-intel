#!/usr/bin/env python3
"""Esteira paralela de bottles Intel para macOS Tahoe em GitHub Actions.

Subcomandos:
  plan     — inventário do fechamento, fingerprints por fórmula, particiona
             em shards e garante o release rolante tahoe-bottles.
  build N  — processa os membros do shard N: baixa bottles reutilizados,
             compila o que falta e publica cada bottle/metadado ao concluir.
  publish  — mescla os manifestos dos shards, monta Formula/, limpa assets
             órfãos e promove o snapshot para main.

Bottles e manifestos moram no release tahoe-bottles; qualquer trabalho já
publicado sobrevive a timeout/falha, e a run seguinte refaz só o que falta.
"""
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / '.work'
TAG = 'tahoe-bottles'  # release rolante: assets persistem entre runs (retomada)
SHARDS = 4
HEAVY = (('llvm', 40), ('lld', 40), ('rust', 45), ('openjdk', 35), ('gcc', 30),
         ('qt', 30), ('node', 30), ('ffmpeg', 25), ('go', 25), ('gtk', 20),
         ('boost', 20), ('emacs', 20), ('python@', 15), ('postgresql', 15),
         ('mysql', 15), ('ruby', 15))


class ApiError(RuntimeError):
    def __init__(self, code, path, body):
        super().__init__(f'GitHub API {code} em {path}: {body[:500]}')
        self.code = code


def run(*args, cwd=None, capture=False):
    print('+', ' '.join(map(str, args)), flush=True)
    if capture:
        return subprocess.run(list(map(str, args)), cwd=cwd or ROOT, check=True,
                              text=True, stdout=subprocess.PIPE).stdout
    subprocess.run(list(map(str, args)), cwd=cwd or ROOT, check=True)


def deps(name):
    # Dependências de teste fazem parte do fechamento para permitir brew test.
    # --formula evita carregar cask homônimo (ex.: reviewdog/tap).
    return run('brew', 'deps', '--formula', '--direct', '--full-name',
               '--include-build', '--include-test', name, capture=True).split()


def formula_info(name):
    # --formula evita carregar cask homônimo (ex.: reviewdog/tap tem ambos; o
    # cask usa DSL deprecado que aborta a carga em modo desenvolvedor).
    return json.loads(run('brew', 'info', '--json=v2', '--formula', name,
                          capture=True))['formulae'][0]


def canonical(name, external_taps=()):
    name = name.removeprefix('homebrew/core/')
    if '/' in name:
        if name.count('/') == 2 and name.rsplit('/', 1)[0] in external_taps:
            return name
        raise RuntimeError('Dependência externa ou nome inválido: ' + name)
    if not re.fullmatch(r'[a-z0-9][a-z0-9+_.@-]*', name):
        raise RuntimeError('Dependência externa ou nome inválido: ' + name)
    return name


def short_name(key):
    return key.split('/')[-1]


def topo(roots, graph):
    order, active, done = [], set(), set()
    def visit(name):
        if name in done:
            return
        if name in active:
            raise RuntimeError('Ciclo de dependências incluindo ' + name)
        active.add(name)
        for dep in graph[name]:
            visit(dep)
        active.remove(name)
        done.add(name)
        order.append(name)
    for root in roots:
        visit(root)
    return order


def transform(source, tap, names, keep_bottle=False):
    # O bloco bottle canônico é delimitado por end com a mesma indentação. Quando a
    # versão atual já tem bottle Intel do mantenedor, o bloco oficial é preservado.
    if not keep_bottle:
        source = re.sub(r'(?ms)^  bottle do\n.*?^  end\n', '', source)
        if re.search(r'^\s*bottle\b', source, re.M):
            raise RuntimeError('Formato de bottle não suportado; revisar importação.')
    # no_autobump! só é permitido em taps oficiais; metadado de manutenção upstream.
    source = re.sub(r'(?m)^\s*no_autobump![^\n]*\n', '', source)
    pattern = r'((?:depends_on|uses_from_macos)\s+|Formula\[)([\"\x27])([^\"\x27]+)\2'
    def replace(match):
        raw = match[3]
        member = raw if raw in names else raw.removeprefix('homebrew/core/')
        target = tap + '/' + short_name(member) if member in names else raw
        return match[1] + match[2] + target + match[2]
    return re.sub(pattern, replace, source)


def api(path, data=None, binary=False, method=None):
    base = 'https://uploads.github.com' if binary else 'https://api.github.com'
    body = data if binary else (json.dumps(data).encode() if data is not None else None)
    req = urllib.request.Request(base + path, data=body,
                                 method=method or ('POST' if body is not None else 'GET'))
    req.add_header('Authorization', 'Bearer ' + os.environ['GITHUB_TOKEN'])
    req.add_header('Accept', 'application/vnd.github+json')
    if binary:
        req.add_header('Content-Type', 'application/octet-stream')
    elif body is not None:
        req.add_header('Content-Type', 'application/json')
    try:
        with urllib.request.urlopen(req) as res:
            return json.loads(res.read() or b'null')
    except urllib.error.HTTPError as err:
        raise ApiError(err.code, path, err.read().decode(errors='replace'))


def repo():
    return os.environ['GITHUB_REPOSITORY'].lower()


def release_for_tag(create=False):
    try:
        return api('/repos/' + repo() + '/releases/tags/' + TAG)
    except ApiError as err:
        if err.code != 404 or not create:
            raise
    return api('/repos/' + repo() + '/releases', {
        'tag_name': TAG, 'target_commitish': 'main',
        'name': 'Intel Tahoe bottles', 'prerelease': True,
        'body': 'Bottles Intel macOS 26. Assets acumulam entre runs; '
                'manifest.json registra o fingerprint publicado por fórmula.'})


def release_assets(release_id):
    assets, page = [], 1
    while True:
        batch = api(f'/repos/{repo()}/releases/{release_id}/assets'
                    f'?per_page=100&page={page}')
        if not batch:
            return assets
        assets.extend(batch)
        page += 1


def download(url):
    req = urllib.request.Request(url)
    req.add_header('Authorization', 'Bearer ' + os.environ['GITHUB_TOKEN'])
    with urllib.request.urlopen(req) as res:
        return res.read()


def upload_asset(release_id, path, name=None):
    path = Path(path)
    name = name or path.name
    endpoint = (f'/repos/{repo()}/releases/{release_id}/assets?name=' +
                urllib.parse.quote(name))
    try:
        return api(endpoint, path.read_bytes(), binary=True)
    except ApiError as err:
        if err.code != 422:
            raise
    # Substitui asset de mesmo nome (versão anterior já substituída no manifesto).
    for asset in release_assets(release_id):
        if asset['name'] == name:
            api(f"/repos/{repo()}/releases/assets/{asset['id']}", method='DELETE')
            break
    return api(endpoint, path.read_bytes(), binary=True)


def load_manifest(release):
    for asset in release_assets(release['id']):
        if asset['name'] == 'manifest.json':
            return json.loads(download(asset['browser_download_url']))
    return {}


def checks():
    if os.environ.get('GITHUB_ACTIONS') != 'true':
        raise RuntimeError('Este programa remove pacotes do runner; execução local bloqueada.')
    if run('uname', '-m', capture=True).strip() != 'x86_64':
        raise RuntimeError('Arquitetura diferente de x86_64.')
    if run('sw_vers', '-productVersion', capture=True).split('.')[0] != '26':
        raise RuntimeError('Sistema diferente de macOS 26.')
    if run('brew', '--prefix', capture=True).strip() != '/usr/local':
        raise RuntimeError('Prefixo diferente de /usr/local.')


def repo_tap():
    owner, repository = repo().split('/')
    if not repository.startswith('homebrew-'):
        raise RuntimeError('O repositório precisa chamar-se homebrew-intel (ou homebrew-<tap>).')
    return owner, repository, owner + '/' + repository.removeprefix('homebrew-')


def read_roots():
    roots = []
    for line in (ROOT / 'packages.txt').read_text().splitlines():
        name = line.split('#', 1)[0].strip()
        if not name:
            continue
        # Fórmulas de taps de terceiros entram como owner/tap/nome; nome curto é core.
        if '/' in name and (name.count('/') != 2 or
                            not all(re.fullmatch(r'[a-z0-9][a-z0-9+_.@-]*', seg)
                                    for seg in name.split('/'))):
            raise RuntimeError('Nome inválido: ' + name)
        roots.append(canonical(name) if '/' not in name else name)
    if not roots:
        raise RuntimeError('packages.txt vazio.')
    return roots


def tap_source_taps(external_taps):
    taps_map = {}
    taps_path = ROOT / 'taps.txt'
    if taps_path.exists():
        for line in taps_path.read_text().splitlines():
            entry = line.split('#', 1)[0].strip()
            if entry:
                tap_name, _, remote = entry.partition(' ')
                taps_map[tap_name] = remote.strip()
    for external in sorted(external_taps):
        run('brew', 'tap', external,
            *([taps_map[external]] if taps_map.get(external) else []))
        # Sem confiança o brew recusa carregar as fórmulas do tap de origem.
        run('brew', 'trust', external)


def link_own_tap(owner, repository, tap):
    # Disponibiliza o checkout como tap local sem clonar uma versão antiga.
    tap_path = Path(run('brew', '--repository', capture=True).strip()) / 'Library/Taps' / owner / repository
    tap_path.parent.mkdir(parents=True, exist_ok=True)
    if tap_path.is_symlink() or tap_path.exists():
        if tap_path.is_symlink():
            tap_path.unlink()
        else:
            shutil.rmtree(tap_path)
    tap_path.symlink_to(ROOT, target_is_directory=True)
    # Brew recusa carregar fórmulas de taps não confiáveis ao resolver dependências.
    run('brew', 'trust', tap)


def build_graph(roots, external_taps):
    graph, sources, reusable = {}, {}, {}
    pending = list(roots)
    while pending:
        name = pending.pop()
        if name in graph:
            continue
        full_ref = name if '/' in name else 'homebrew/core/' + name
        info = formula_info(full_ref)
        if info['full_name'].removeprefix('homebrew/core/') != name:
            raise RuntimeError('Use nome canônico em vez de alias: ' + name)
        graph[name] = [canonical(dep, external_taps) for dep in deps(full_ref)]
        sources[name] = run('brew', 'cat', '--formula', full_ref, capture=True)
        files = ((info.get('bottle') or {}).get('stable') or {}).get('files') or {}
        # Bottle Intel reutilizável: qualquer tag macOS x86_64 que o brew despeja.
        reusable[name] = any('arm64' not in tag and 'aarch64' not in tag
                             and 'linux' not in tag for tag in files)
        pending.extend(graph[name])
    return graph, sources, reusable


def owners(order):
    file_owner = {}
    for name in order:
        owner = file_owner.get(short_name(name))
        if owner is None or ('/' in owner and '/' not in name):
            file_owner[short_name(name)] = name
    # Mesma fórmula oferecida por core e por tap externa: o core vence, pois deps
    # de nome curto sempre resolvem para homebrew/core. Duas taps externas com o
    # mesmo nome curto continuam ambíguas e abortam.
    ambiguous = [name for name in order
                 if file_owner[short_name(name)] != name
                 and '/' in file_owner[short_name(name)]]
    if ambiguous:
        raise RuntimeError('Colisão de nomes entre taps externas: ' + ', '.join(ambiguous))
    dropped = {name for name in order
               if '/' in name and file_owner[short_name(name)] != name}
    for name in sorted(dropped):
        print(f'Colisão resolvida por homebrew/core: {name} usa '
              f'{file_owner[short_name(name)]}', flush=True)
    return file_owner, dropped


def member_fps(order, graph, normalized, file_owner):
    # Fingerprint por fórmula: fonte transformada + fingerprint das deps, para
    # que mudança em uma dependência invalide os dependentes em cascata. O
    # subgrafo de donos tem ordem própria: uma dep descartada resolve para o
    # dono core, que pode aparecer depois do dependente em order.
    owner_names = [name for name in order if file_owner[short_name(name)] == name]
    ograph = {name: {file_owner[short_name(dep)] for dep in graph[name]
                     if file_owner[short_name(dep)] != name}
              for name in owner_names}
    fps = {}
    for name in topo(owner_names, ograph):
        dep_fps = sorted(fps[dep] for dep in ograph[name])
        fps[name] = hashlib.sha256(
            (normalized[name] + json.dumps(dep_fps)).encode()).hexdigest()
    for name in order:
        if file_owner[short_name(name)] != name:
            fps[name] = fps[file_owner[short_name(name)]]
    return fps


def partition(order, graph, build_set, nshards):
    # Afinidade leve por dependências compartilhadas sem desequilibrar pesos.
    def weight(name):
        if name not in build_set:
            return 1  # só despeja um bottle existente
        for pat, w in HEAVY:
            if pat in name:
                return w
        return 2 + len(graph[name])
    owner_shard = {}
    shards = [[] for _ in range(nshards)]
    cost = [0] * nshards
    for name in order:
        best = min(range(nshards), key=lambda i: cost[i] - 2 * sum(
            1 for dep in graph[name] if owner_shard.get(dep) == i))
        owner_shard[name] = best
        shards[best].append(name)
        cost[best] += weight(name)
    return shards


def verify_poured(full, name):
    tab = formula_info(full)['installed']
    if not tab or not all(item.get('poured_from_bottle') for item in tab):
        raise RuntimeError('Instalação recompilou em vez de usar bottle: ' + name)


def verify_closure(order, file_owner, dropped, graph, tap):
    for name in order:
        if name in dropped or file_owner[short_name(name)] != name:
            continue
        full = tap + '/' + short_name(name)
        # Deps implícitas por extensão/VCS (ex.: url .7z -> p7zip) não têm texto
        # para reescrever: o brew as resolve pelo nome curto, e o keg do tap
        # instalado antes na ordem do grafo satisfaz a exigência.
        outside = [dep for dep in deps(full)
                   if not dep.startswith(tap + '/')
                   and dep.removeprefix('homebrew/core/') not in graph]
        if outside:
            raise RuntimeError(f'Dependências sem redirecionamento em {full}: {outside}')


def plan():
    checks()
    owner, repository, tap = repo_tap()
    WORK.mkdir(exist_ok=True)
    # Atualiza explicitamente; nas etapas seguintes as versões ficam congeladas.
    run('brew', 'update')
    run('brew', 'tap', '--force', 'homebrew/core')
    core = Path(run('brew', '--repository', 'homebrew/core', capture=True).strip())
    core_commit = run('git', 'rev-parse', 'HEAD', cwd=core, capture=True).strip()
    licenses = [p for p in (core / 'LICENSE.txt', core / 'LICENSE') if p.is_file()]
    if not licenses:
        raise RuntimeError('Licença de homebrew/core não encontrada; importação interrompida.')
    roots = read_roots()
    external_taps = {name.rsplit('/', 1)[0] for name in roots if '/' in name}
    tap_source_taps(external_taps)
    graph, sources, reusable = build_graph(roots, external_taps)
    order = topo(roots, graph)
    # Ignora alterações exclusivamente nos bottles upstream.
    normalized = {name: transform(src, tap, set(graph), reusable[name])
                  for name, src in sources.items()}
    file_owner, dropped = owners(order)
    fps = member_fps(order, graph, normalized, file_owner)
    release = release_for_tag(create=True)
    manifest = load_manifest(release)
    assets = {asset['name'] for asset in release_assets(release['id'])}
    build_set = set()
    for name in order:
        if file_owner[short_name(name)] != name:
            continue  # membro descartado por colisão acompanha o dono do arquivo.
        entry = manifest.get(short_name(name)) or {}
        if entry.get('fp') != fps[name]:
            build_set.add(name)
        elif not reusable[name] and entry.get('asset') not in assets:
            build_set.add(name)  # fingerprint ok mas asset sumiu do release.
    shards = partition(order, graph, build_set, SHARDS)
    # A verificação de escape roda no plan: falha antes de gastar minutos de shard.
    formula_dir = ROOT / 'Formula'
    if formula_dir.exists():
        shutil.rmtree(formula_dir)
    formula_dir.mkdir()
    for name in order:
        if file_owner[short_name(name)] == name:
            (formula_dir / (short_name(name) + '.rb')).write_text(normalized[name])
    link_own_tap(owner, repository, tap)
    verify_closure(order, file_owner, dropped, graph, tap)
    plan_data = {'tap': tap, 'order': order, 'graph': graph, 'roots': roots,
                 'normalized': normalized, 'reusable': reusable, 'fps': fps,
                 'build_set': sorted(build_set), 'shards': shards,
                 'file_owner': file_owner, 'dropped': sorted(dropped),
                 'core_commit': core_commit}
    plan_path = WORK / 'plan.json'
    plan_path.write_text(json.dumps(plan_data))
    upload_asset(release['id'], plan_path, 'plan.json')
    total = len(order)
    print(f'Snapshot: {total} fórmulas; {len(build_set)} precisam de build; '
          f'{sum(1 for n in order if reusable.get(n))} reutilizadas; '
          f'{len(dropped)} colisões resolvidas por core.', flush=True)
    for i, members in enumerate(shards):
        todo = [n for n in members if n in build_set]
        print(f'Shard {i}: {len(members)} membros ({len(todo)} builds): '
              + ', '.join(todo)[:200], flush=True)
    if not build_set:
        print('Nada a construir; shards desnecessários.', flush=True)
        output_lines = ['has_work=false', 'shard_ids=[]']
    else:
        output_lines = ['has_work=true',
                        'shard_ids=' + json.dumps([i for i, s in enumerate(shards) if s])]
    output_file = os.environ.get('GITHUB_OUTPUT')
    if output_file:
        with open(output_file, 'a') as stream:
            stream.write('\n'.join(output_lines) + '\n')


def load_plan():
    release = release_for_tag()
    for asset in release_assets(release['id']):
        if asset['name'] == 'plan.json':
            return release, json.loads(download(asset['browser_download_url']))
    raise RuntimeError('plan.json ausente no release; execute o job plan primeiro.')


def write_formula_dir(plan_data):
    formula_dir = ROOT / 'Formula'
    formula_dir.mkdir(exist_ok=True)
    keep = {short_name(name) for name in plan_data['order']
            if plan_data['file_owner'][short_name(name)] == name}
    for stale in formula_dir.glob('*.rb'):
        if stale.stem not in keep:
            stale.unlink()
    normalized = plan_data['normalized']
    build_set = set(plan_data['build_set'])
    for name in plan_data['order']:
        if plan_data['file_owner'][short_name(name)] != name:
            continue
        target = formula_dir / (short_name(name) + '.rb')
        # Membros fora do build_set mantêm o arquivo promovido com o bottle
        # publicado; membros do build_set recebem a fonte normalizada (sem bottle
        # ou com o bloco upstream preservado quando reutilizado).
        if name in build_set or not target.exists():
            target.write_text(normalized[name])


def adopt_bottles(release, full, formula_dir):
    # Dependência de outro shard: se o dono já publicou, adota o arquivo com o
    # bloco bottle e o brew despeja em vez de compilar a dep duplicada.
    asset_map = {asset['name']: asset['browser_download_url']
                 for asset in release_assets(release['id'])}
    for dep in run('brew', 'deps', '--formula', '--full-name', '--include-build',
                   '--include-test', full, capture=True).split():
        dep_short = dep.split('/')[-1]
        asset_name = f'Formula-{dep_short}.rb'
        if asset_name not in asset_map:
            continue
        target = formula_dir / (dep_short + '.rb')
        fetched = download(asset_map[asset_name])
        if not target.exists() or target.read_bytes() != fetched:
            print('Adotando bottle publicado por outro shard:', dep_short, flush=True)
            target.write_bytes(fetched)


def install_missing_deps(full, tap):
    # --build-bottle exige bottle em toda dep instalável e --force-bottle se
    # aplica à operação inteira: pré-instala as ausentes com install comum
    # (despeja bottle adotado/publicado ou compila como fallback local — só o
    # shard dono publica), deixando o install final tratar só do alvo.
    installed = set(run('brew', 'list', '--formula', capture=True).split())
    for dep in deps(full):
        dep_short = dep.split('/')[-1]
        if dep_short not in installed:
            run('brew', 'install', tap + '/' + dep_short)
            installed.add(dep_short)


def build_shard(idx):
    checks()
    owner, repository, tap = repo_tap()
    WORK.mkdir(exist_ok=True)
    run('brew', 'update')
    run('brew', 'tap', '--force', 'homebrew/core')
    release, plan_data = load_plan()
    reusable = plan_data['reusable']
    fps = plan_data['fps']
    file_owner = plan_data['file_owner']
    build_set = set(plan_data['build_set'])
    members = plan_data['shards'][idx]
    # Retomada dentro do mesmo run: fragmentos e manifesto anteriores dizem o
    # que já foi publicado por qualquer shard e não precisa repetir.
    done = dict(load_manifest(release))
    for asset in release_assets(release['id']):
        if re.fullmatch(r'manifest-\d+\.json', asset['name']):
            done.update(json.loads(download(asset['browser_download_url'])))
    write_formula_dir(plan_data)
    link_own_tap(owner, repository, tap)
    # Apenas VM descartável: evita satisfazer dependências com kegs de outro tap.
    installed = run('brew', 'list', '--formula', capture=True).split()
    if installed:
        run('brew', 'uninstall', '--force', '--ignore-dependencies', *installed)
    fragment = {}
    out_dir = WORK / f'out-{idx}'
    out_dir.mkdir(exist_ok=True)
    frag_path = out_dir / f'manifest-{idx}.json'
    root_url = f'https://github.com/{repo()}/releases/download/{TAG}'
    for name in members:
        if file_owner[short_name(name)] != name:
            continue
        short = short_name(name)
        full = tap + '/' + short
        if (done.get(short) or {}).get('fp') == fps[name]:
            print(f'[{idx}] {short}: já publicado; pulando', flush=True)
            continue
        if name in build_set and not reusable[name]:
            # Deps resolvem pelo tap: members com bottle publicado despejam; os
            # que outro shard ainda compila são construídos localmente (fallback
            # duplicado e seguro — só o shard dono publica).
            adopt_bottles(release, full, ROOT / 'Formula')
            install_missing_deps(full, tap)
            tab = formula_info(full).get('installed') or []
            if tab and not all(item.get('poured_from_bottle') for item in tab):
                # Já foi compilado como dep de outro membro: refaz com test deps.
                run('brew', 'reinstall', '--build-bottle', '--include-test', full)
            else:
                run('brew', 'install', '--build-bottle', '--include-test', full)
            run('brew', 'test', full)
            run('brew', 'linkage', '--test', full)
            out = WORK / f'pkg-{idx}' / short
            out.mkdir(parents=True, exist_ok=True)
            run('brew', 'bottle', '--json', '--no-rebuild',
                '--root-url=' + root_url, full, cwd=out)
            metadata = list(out.glob('*.bottle.json'))
            if len(metadata) != 1:
                raise RuntimeError('Metadados de bottle inesperados: ' + name)
            run('brew', 'bottle', '--merge', '--write', '--no-commit', metadata[0])
            files = formula_info(full)['bottle']['stable']['files']
            bottle = files.get('tahoe') or files.get('all')
            if bottle is None:
                raise RuntimeError('Bottle Intel Tahoe ausente: ' + name)
            archives = list(out.glob('*.bottle.tar.gz'))
            if len(archives) != 1:
                raise RuntimeError('Arquivo de bottle inesperado: ' + name)
            archive = archives[0]
            if hashlib.sha256(archive.read_bytes()).hexdigest() != bottle['sha256']:
                raise RuntimeError('Checksum inválido: ' + name)
            filename = Path(urllib.parse.urlparse(bottle['url']).path).name
            target = archive.with_name(filename)
            if target != archive:
                archive.rename(target)
            # Checkpoint imediato: bottle, metadado da fórmula e manifesto do shard.
            upload_asset(release['id'], target, filename)
            upload_asset(release['id'], ROOT / 'Formula' / (short + '.rb'),
                         f'Formula-{short}.rb')
            fragment[short] = {'fp': fps[name], 'asset': filename}
        else:
            # Reutilizado ou inalterado: despeja o bottle oficial/publicado e
            # valida que funciona dentro do grafo do tap.
            adopt_bottles(release, full, ROOT / 'Formula')
            install_missing_deps(full, tap)
            # --include-test traz as test deps que brew test exige instaladas.
            run('brew', 'install', '--force-bottle', '--include-test', full)
            verify_poured(full, name)
            run('brew', 'test', full)
            run('brew', 'linkage', '--test', full)
            if reusable[name]:
                upload_asset(release['id'], ROOT / 'Formula' / (short + '.rb'),
                             f'Formula-{short}.rb')
                fragment[short] = {'fp': fps[name], 'reused': True}
        frag_path.write_text(json.dumps(fragment, indent=2))
        upload_asset(release['id'], frag_path, f'manifest-{idx}.json')
        print(f'[{idx}] {short}: ok', flush=True)


def publish():
    checks()
    owner, repository, tap = repo_tap()
    run('brew', 'tap', '--force', 'homebrew/core')
    core = Path(run('brew', '--repository', 'homebrew/core', capture=True).strip())
    licenses = [p for p in (core / 'LICENSE.txt', core / 'LICENSE') if p.is_file()]
    if licenses:
        shutil.copyfile(licenses[0], ROOT / 'LICENSE.homebrew-core.txt')
    release = release_for_tag()
    assets = {asset['name']: asset for asset in release_assets(release['id'])}
    if 'plan.json' not in assets:
        raise RuntimeError('plan.json ausente no release; execute plan primeiro.')
    plan_data = json.loads(download(assets['plan.json']['browser_download_url']))
    order = plan_data['order']
    reusable = plan_data['reusable']
    fps = plan_data['fps']
    file_owner = plan_data['file_owner']
    manifest = dict(load_manifest(release))
    for name, asset in assets.items():
        if re.fullmatch(r'manifest-\d+\.json', name):
            manifest.update(json.loads(download(asset['browser_download_url'])))
    # short -> chave do membro dono do arquivo Formula/<short>.rb.
    member_shorts = {short_name(name): name for name in order
                     if file_owner[short_name(name)] == name}
    # Membros removidos do catálogo perdem entrada no manifesto e os assets.
    manifest = {k: v for k, v in manifest.items() if k in member_shorts}
    formula_dir = ROOT / 'Formula'
    formula_dir.mkdir(exist_ok=True)
    for stale_file in formula_dir.glob('*.rb'):
        if stale_file.stem not in member_shorts:
            stale_file.unlink()
    pending = []
    for short, key in member_shorts.items():
        entry = manifest.get(short) or {}
        stale = entry.get('fp') != fps[key]
        if not reusable[key] and entry.get('asset') not in assets:
            stale = True
        asset_name = f'Formula-{short}.rb'
        target = formula_dir / (short + '.rb')
        if asset_name in assets:
            target.write_bytes(download(assets[asset_name]['browser_download_url']))
        elif not target.exists() and reusable[key]:
            # Arquivo de membro reutilizado é autossuficiente (bottle upstream);
            # membro novo sem bottle construído fica ausente até o build.
            target.write_text(plan_data['normalized'][key])
        if stale:
            pending.append(short)
    keep = {'plan.json', 'manifest.json'}
    keep.update(f'manifest-{i}.json' for i in range(SHARDS))
    keep.update(f'Formula-{s}.rb' for s in member_shorts)
    keep.update(entry['asset'] for entry in manifest.values() if entry.get('asset'))
    for asset in assets.values():
        if asset['name'] not in keep:
            print('Removendo asset órfão:', asset['name'], flush=True)
            api(f"/repos/{repo()}/releases/assets/{asset['id']}", method='DELETE')
    manifest_path = WORK / 'manifest.json'
    manifest_path.parent.mkdir(exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True))
    upload_asset(release['id'], manifest_path, 'manifest.json')
    snapshot = {'tap': tap,
                'fingerprint': hashlib.sha256(json.dumps(
                    {'roots': plan_data['roots'], 'fps': fps},
                    sort_keys=True).encode()).hexdigest(),
                'tag': TAG, 'core_commit': plan_data['core_commit'],
                'roots': plan_data['roots'], 'order': order,
                'reused': sorted(key for key in member_shorts.values() if reusable.get(key)),
                'pending': sorted(pending)}
    (ROOT / 'snapshot.json').write_text(json.dumps(snapshot, indent=2) + '\n')
    run('git', 'config', 'user.name', 'github-actions[bot]')
    run('git', 'config', 'user.email', '41898282+github-actions[bot]@users.noreply.github.com')
    run('git', 'add', 'Formula', 'snapshot.json', 'LICENSE.homebrew-core.txt')
    if subprocess.run(['git', 'diff', '--cached', '--quiet']).returncode == 0:
        print('Nenhuma alteração para promover.', flush=True)
        return
    run('git', 'commit', '-m', 'Update Intel Tahoe bottle snapshot')
    run('git', 'push')
    print('Snapshot promovido. Pendentes: ' +
          (', '.join(snapshot['pending']) or 'nenhum'), flush=True)


def main():
    command = sys.argv[1] if len(sys.argv) > 1 else 'plan'
    if command == 'plan':
        plan()
    elif command == 'build':
        build_shard(int(sys.argv[2]))
    elif command == 'publish':
        publish()
    else:
        raise RuntimeError('Subcomando inválido: ' + command)


if __name__ == '__main__':
    main()
