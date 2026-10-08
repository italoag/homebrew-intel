#!/usr/bin/env python3
"""Executar somente no runner descartável do GitHub Actions, nunca no Mac pessoal."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / '.work'


def run(*args, cwd=None, capture=False):
    print('+', ' '.join(map(str, args)), flush=True)
    return subprocess.run(list(map(str, args)), cwd=cwd or ROOT, check=True,
                          text=True, stdout=subprocess.PIPE if capture else None).stdout


def deps(name):
    return run('brew', 'deps', '--direct', '--full-name', '--include-build',
               '--include-test', name, capture=True).split()


def canonical(name):
    name = name.removeprefix('homebrew/core/')
    if not re.fullmatch(r'[a-z0-9][a-z0-9+_.@-]*', name):
        raise RuntimeError('Dependência externa ou nome inválido: ' + name)
    return name


def topo(roots, graph):
    order, active, done = [], set(), set()
    def visit(name):
        if name in active:
            raise RuntimeError('Ciclo de bootstrap/teste em ' + name +
                               ': exige tratamento específico; snapshot não publicado.')
        if name in done:
            return
        active.add(name)
        for dep in graph[name]:
            visit(dep)
        active.remove(name)
        done.add(name)
        order.append(name)
    for root in roots:
        visit(root)
    return order


def transform(source, tap, names):
    # O bloco bottle canônico é delimitado por end com a mesma indentação.
    source = re.sub(r'(?ms)^  bottle do\n.*?^  end\n', '', source)
    if re.search(r'^\s*bottle\b', source, re.M):
        raise RuntimeError('Formato de bottle não suportado; revisar importação.')
    # no_autobump! só é permitido em taps oficiais; metadado de manutenção upstream.
    source = re.sub(r'(?m)^\s*no_autobump![^\n]*\n', '', source)
    pattern = r'((?:depends_on|uses_from_macos)\s+|Formula\[)([\"\x27])([^\"\x27]+)\2'
    def replace(match):
        name = match[3].removeprefix('homebrew/core/')
        target = tap + '/' + name if name in names else match[3]
        return match[1] + match[2] + target + match[2]
    return re.sub(pattern, replace, source)


def api(path, data=None, binary=False):
    base = 'https://uploads.github.com' if binary else 'https://api.github.com'
    headers = {'Authorization': 'Bearer ' + os.environ['GH_TOKEN'],
               'Accept': 'application/vnd.github+json',
               'X-GitHub-Api-Version': '2022-11-28',
               'Content-Type': 'application/octet-stream' if binary else 'application/json'}
    body = data if binary else (json.dumps(data).encode() if data is not None else None)
    req = urllib.request.Request(base + path, data=body, headers=headers)
    with urllib.request.urlopen(req, timeout=300) as response:
        return json.load(response)


def formula_info(name):
    return json.loads(run('brew', 'info', '--json=v2', name, capture=True))['formulae'][0]


def main():
    if os.environ.get('GITHUB_ACTIONS') != 'true':
        raise RuntimeError('Este programa remove pacotes do runner; execução local bloqueada.')
    repo = os.environ['GITHUB_REPOSITORY'].lower()
    owner, repository = repo.split('/')
    if not repository.startswith('homebrew-'):
        raise RuntimeError('O repositório precisa chamar-se homebrew-intel (ou homebrew-<tap>).')
    tap = owner + '/' + repository.removeprefix('homebrew-')
    if run('uname', '-m', capture=True).strip() != 'x86_64':
        raise RuntimeError('Arquitetura diferente de x86_64.')
    if run('sw_vers', '-productVersion', capture=True).split('.')[0] != '26':
        raise RuntimeError('Sistema diferente de macOS 26.')
    if run('brew', '--prefix', capture=True).strip() != '/usr/local':
        raise RuntimeError('Prefixo diferente de /usr/local.')
    WORK.mkdir(exist_ok=True)
    # Atualiza explicitamente; nas etapas seguintes as versões ficam congeladas.
    run('brew', 'update')
    run('brew', 'tap', '--force', 'homebrew/core')
    core = Path(run('brew', '--repository', 'homebrew/core', capture=True).strip())
    core_commit = run('git', 'rev-parse', 'HEAD', cwd=core, capture=True).strip()
    licenses = [p for p in (core / 'LICENSE.txt', core / 'LICENSE') if p.is_file()]
    if not licenses:
        raise RuntimeError('Licença de homebrew/core não encontrada; importação interrompida.')
    roots = [canonical(line.split('#', 1)[0].strip())
             for line in (ROOT / 'packages.txt').read_text().splitlines()
             if line.split('#', 1)[0].strip()]
    if not roots:
        raise RuntimeError('packages.txt vazio.')
    graph, sources = {}, {}
    pending = list(roots)
    while pending:
        name = pending.pop()
        if name in graph:
            continue
        info = formula_info('homebrew/core/' + name)
        if info['name'] != name:
            raise RuntimeError('Use nome canônico em vez de alias: ' + name)
        graph[name] = [canonical(dep) for dep in deps('homebrew/core/' + name)]
        sources[name] = run('brew', 'cat', 'homebrew/core/' + name, capture=True)
        pending.extend(graph[name])
    order = topo(roots, graph)
    # Ignora alterações exclusivamente nos bottles upstream.
    normalized = {name: transform(src, tap, set(graph)) for name, src in sources.items()}
    fingerprint = hashlib.sha256(json.dumps({
        'roots': roots, 'sources': normalized, 'graph': graph,
        'pipeline': (ROOT / 'scripts/pipeline.py').read_text(),
        'workflow': (ROOT / '.github/workflows/bottles.yml').read_text(),
        'brew_version': run('brew', '--version', capture=True).splitlines()[0],
    }, sort_keys=True).encode()).hexdigest()
    state_path = ROOT / 'snapshot.json'
    if state_path.exists() and json.loads(state_path.read_text())['fingerprint'] == fingerprint:
        print('Sem alterações de fontes/dependências/esteira; build dispensado.')
        return
    print(f'Snapshot completo: {len(order)} fórmulas: ' + ', '.join(order), flush=True)
    formula_dir = ROOT / 'Formula'
    if formula_dir.exists():
        shutil.rmtree(formula_dir)
    formula_dir.mkdir()
    shutil.copyfile(licenses[0], ROOT / 'LICENSE.homebrew-core.txt')
    for name in order:
        (formula_dir / (name + '.rb')).write_text(normalized[name])
    # Disponibiliza o checkout como tap local sem clonar uma versão antiga.
    tap_path = Path(run('brew', '--repository', capture=True).strip()) / 'Library/Taps' / owner.lower() / repository.lower()
    tap_path.parent.mkdir(parents=True, exist_ok=True)
    if tap_path.exists() or tap_path.is_symlink():
        raise RuntimeError('Tap já existente no runner; não sobrescrito.')
    tap_path.symlink_to(ROOT, target_is_directory=True)
    # Brew recusa carregar fórmulas de taps não confiáveis ao resolver dependências.
    run('brew', 'trust', tap)
    for name in order:
        full = tap + '/' + name
        outside = [dep for dep in deps(full) if not dep.startswith(tap + '/')]
        if outside:
            raise RuntimeError(f'Dependências sem redirecionamento em {full}: {outside}')
    # Apenas VM descartável: evita satisfazer dependências com kegs de outro tap.
    installed = run('brew', 'list', '--formula', capture=True).split()
    if installed:
        run('brew', 'uninstall', '--force', '--ignore-dependencies', *installed)
    tag = 'tahoe-' + os.environ['GITHUB_RUN_ID'] + '-' + os.environ['GITHUB_RUN_ATTEMPT']
    root_url = 'https://github.com/' + repo + '/releases/download/' + tag
    bottles = []
    for name in order:
        full = tap + '/' + name
        run('brew', 'install', '--build-bottle', '--include-test', full)
        run('brew', 'test', full)
        run('brew', 'linkage', '--test', full)
        out = WORK / name
        out.mkdir()
        run('brew', 'bottle', '--json', '--no-rebuild', '--root-url=' + root_url, full, cwd=out)
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
        # O nome do arquivo local pode conter --; a URL é a autoridade.
        filename = Path(urllib.parse.urlparse(bottle['url']).path).name
        target = archive.with_name(filename)
        if target != archive:
            archive.rename(target)
        bottles.append(target)
    release = api('/repos/' + repo + '/releases', {
        'tag_name': tag, 'target_commitish': os.environ['GITHUB_SHA'],
        'name': tag, 'body': 'Intel macOS 26; core commit: ' + core_commit,
        'make_latest': 'false'})
    for bottle_path in bottles:
        endpoint = '/repos/' + repo + '/releases/' + str(release['id']) + '/assets?name=' + urllib.parse.quote(bottle_path.name)
        api(endpoint, bottle_path.read_bytes(), binary=True)
    # Reinstala TUDO a partir do download publicado e testa o conjunto final.
    run('brew', 'uninstall', '--force', '--ignore-dependencies', *[tap + '/' + n for n in order])
    for name in order:
        full = tap + '/' + name
        run('brew', 'install', '--force-bottle', full)
        tab = formula_info(full)['installed']
        if not tab or not all(item.get('poured_from_bottle') for item in tab):
            raise RuntimeError('Instalação recompilou em vez de usar bottle: ' + name)
        run('brew', 'test', full)
        run('brew', 'linkage', '--test', full)
    state_path.write_text(json.dumps({'fingerprint': fingerprint, 'tap': tap,
                                    'tag': tag, 'core_commit': core_commit,
                                    'roots': roots, 'order': order}, indent=2) + '\n')
    # Só promove depois que os binários públicos foram baixados e validados.
    run('git', 'config', 'user.name', 'github-actions[bot]')
    run('git', 'config', 'user.email', '41898282+github-actions[bot]@users.noreply.github.com')
    run('git', 'add', 'Formula', 'snapshot.json', 'LICENSE.homebrew-core.txt')
    run('git', 'commit', '-m', 'Publish Intel Tahoe snapshot ' + tag)
    run('git', 'push', 'origin', 'HEAD:main')


if __name__ == '__main__':
    main()
