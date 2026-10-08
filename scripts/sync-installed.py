#!/usr/bin/env python3
"""Inventário local e migração para bottles Intel; sem dependência de jq."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / '.work'
ENV = dict(os.environ, HOMEBREW_NO_AUTO_UPDATE='1',
           HOMEBREW_NO_INSTALL_CLEANUP='1', HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK='1')


def brew(*args, capture=True):
    return subprocess.run(['brew', *args], check=True, text=True, env=ENV,
                          stdout=subprocess.PIPE if capture else None).stdout


def info(name):
    return json.loads(brew('info', '--json=v2', name))['formulae'][0]


def platform_check():
    if platform.system() != 'Darwin' or platform.machine() != 'x86_64':
        raise SystemExit('Execute em um Mac Intel nativo, fora de Rosetta.')
    version = subprocess.check_output(['sw_vers', '-productVersion'], text=True).strip()
    if version.split('.')[0] != '26' or brew('--prefix').strip() != '/usr/local':
        raise SystemExit('O tap fornecido exige macOS 26 e prefixo /usr/local.')


def classify(installed, upstream, own_tap=None):
    origin = installed.get('tap') or 'homebrew/core'
    files = ((upstream.get('bottle') or {}).get('stable') or {}).get('files') or {}
    exact = bool(files.get('tahoe') or files.get('all'))
    # Um Intel bottle antigo não implica que o brew irá rejeitá-lo em Tahoe.
    older = sorted(tag for tag in files if tag not in ('tahoe', 'all')
                   and not tag.startswith(('arm64_', 'x86_64_linux', 'aarch64_linux'))
                   and 'linux' not in tag)
    eligible_origin = origin == 'homebrew/core' or origin == own_tap
    reason = None
    if not eligible_origin:
        reason = 'Fórmula de outro tap; preserve sua origem e revise separadamente.'
    elif upstream.get('disabled'):
        reason = 'Fórmula desabilitada upstream: ' + str(upstream.get('disable_reason') or '')
    elif not (upstream.get('urls') or {}).get('stable'):
        reason = 'Sem versão stable upstream.'
    elif upstream.get('name') != installed['name']:
        reason = 'Fórmula renomeada/alias; revisar nome canônico.'
    return {'name': installed['name'], 'origin': origin,
            'installed_versions': [v.get('version') for v in installed.get('installed', [])],
            'upstream_version': upstream.get('versions', {}).get('stable'),
            'has_tahoe_or_all': exact, 'older_intel_bottle_tags': older,
            'candidate': not exact and reason is None,
            'review': reason}


def scan(write_packages):
    platform_check()
    WORK.mkdir(exist_ok=True)
    installed = json.loads(brew('info', '--json=v2', '--installed'))['formulae']
    own_tap = None
    if (ROOT / 'snapshot.json').exists():
        own_tap = json.loads((ROOT / 'snapshot.json').read_text())['tap']
    rows = []
    for item in installed:
        print('Consultando versão atual de', item['full_name'], flush=True)
        # Consulta core mesmo se o keg instalado já veio do nosso tap.
        if item.get('tap') not in (None, 'homebrew/core', own_tap):
            rows.append({'name': item['name'], 'origin': item.get('tap'),
                         'candidate': False, 'review': 'Outro tap: não importado automaticamente.'})
            continue
        try:
            upstream = info('homebrew/core/' + item['name'])
        except subprocess.CalledProcessError:
            rows.append({'name': item['name'], 'origin': item.get('tap'),
                         'candidate': False, 'review': 'Não resolvido em homebrew/core.'})
            continue
        rows.append(classify(item, upstream, own_tap))
    candidates = sorted(row['name'] for row in rows if row['candidate'])
    report = {'created_at': datetime.now(timezone.utc).isoformat(),
              'criterion': 'Sem bottle tahoe ou all na definição stable atual de core',
              'installed': installed, 'results': rows, 'candidates': candidates}
    (WORK / 'intel-scan.json').write_text(json.dumps(report, indent=2) + '\n')
    (WORK / 'missing-tahoe-bottles.txt').write_text(''.join(n + '\n' for n in candidates))
    (WORK / 'review.txt').write_text(''.join(row['name'] + ': ' + row['review'] + '\n'
                                              for row in rows if row.get('review')))
    if write_packages:
        path = ROOT / 'packages.txt'
        previous = path.read_text() if path.exists() else ''
        configured = {line.split('#', 1)[0].strip() for line in previous.splitlines()}
        additions = [name for name in candidates if name not in configured]
        if additions:
            path.write_text(previous.rstrip() + '\n\n# Detectadas no inventário local\n' +
                            ''.join(name + '\n' for name in additions))
        print('packages.txt atualizado; entradas anteriores preservadas.')
    print(f'{len(installed)} instaladas; {len(candidates)} candidatas.')
    print('Lista: .work/missing-tahoe-bottles.txt; relatório: .work/intel-scan.json')
    print('Revisão: .work/review.txt. Nenhum pacote instalado foi alterado.')


def migration_plan():
    platform_check()
    if not (ROOT / 'snapshot.json').exists() or not (WORK / 'intel-scan.json').exists():
        raise SystemExit('Execute scan e aguarde a publicação do snapshot antes de migrar.')
    snapshot = json.loads((ROOT / 'snapshot.json').read_text())
    scan_report = json.loads((WORK / 'intel-scan.json').read_text())
    tap = snapshot['tap']
    roots = scan_report['candidates']
    if not roots:
        raise SystemExit('Nenhuma candidata no inventário.')
    missing = set(roots) - set(snapshot['order'])
    if missing:
        raise SystemExit('A esteira ainda não publicou: ' + ', '.join(sorted(missing)))
    order_set = set(snapshot['order'])
    closure = {tap + '/' + name for name in roots}
    for name in roots:
        for dep in brew('deps', '--full-name', tap + '/' + name).split():
            short = dep.removeprefix('homebrew/core/')
            if dep.startswith(tap + '/'):
                closure.add(dep)
            elif short in order_set:
                # Dep implícita (ex.: extrator .7z -> p7zip) resolve pelo nome
                # curto; o keg do tap a satisfaz na ordem do snapshot.
                closure.add(tap + '/' + short)
            else:
                raise SystemExit('Dependência fora do tap: ' + dep + '; migração bloqueada.')
    if any(full.removeprefix(tap + '/') not in order_set for full in closure):
        raise SystemExit('Dependência fora do snapshot: migração bloqueada.')
    names = [name for name in snapshot['order'] if tap + '/' + name in closure]
    installed = json.loads(brew('info', '--json=v2', '--installed'))['formulae']
    installed_by_name = {item['name']: item for item in installed}
    pinned = set(brew('list', '--pinned').split())
    services = json.loads(brew('services', 'list', '--json'))
    active = [item['name'] for item in services
              if item.get('status') in ('started', 'scheduled') and item['name'] in names]
    if active:
        raise SystemExit('Pare os serviços antes da migração e faça backup dos dados: ' + ', '.join(active))
    base_url = 'https://github.com/' + tap.split('/')[0] + '/homebrew-' + tap.split('/')[1] + '/releases/download/' + snapshot['tag'] + '/'
    plan = []
    for name in names:
        current = installed_by_name.get(name)
        if name in pinned:
            raise SystemExit('Pacote fixado (pinned); revisar antes de migrar: ' + name)
        if current and current.get('tap') not in (None, 'homebrew/core', tap):
            raise SystemExit('Mesmo nome instalado por outro tap: ' + name)
        if current and any(item.get('used_options') or str(item.get('version', '')).startswith('HEAD')
                           for item in current.get('installed', [])):
            raise SystemExit('Instalação HEAD/com opções exige revisão: ' + name)
        full = tap + '/' + name
        desired = info(full)
        files = ((desired.get('bottle') or {}).get('stable') or {}).get('files') or {}
        bottle = files.get('tahoe') or files.get('all')
        if not bottle or not bottle['url'].startswith(base_url):
            raise SystemExit('Bottle do snapshot ausente: ' + full)
        plan.append({'name': name, 'full_name': full,
                     'action': 'reinstall' if current else 'install',
                     'previous_origin': current.get('tap') if current else None,
                     'previous_versions': [i.get('version') for i in current.get('installed', [])] if current else [],
                     'url': bottle['url'], 'sha256': bottle['sha256']})
    return snapshot, installed, plan


def migrate(apply):
    snapshot, installed, plan = migration_plan()
    WORK.mkdir(exist_ok=True)
    (WORK / 'migration-plan.json').write_text(json.dumps(plan, indent=2) + '\n')
    for item in plan:
        print(f"{item['action']:9} {item['full_name']} (origem anterior: {item['previous_origin']})")
    if not apply:
        print('Plano salvo; nenhum pacote alterado. Para executar: migrate --apply')
        return
    backup = WORK / ('migration-' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ'))
    backup.mkdir()
    (backup / 'installed-before.json').write_text(json.dumps(installed, indent=2) + '\n')
    (backup / 'plan.json').write_text(json.dumps(plan, indent=2) + '\n')
    # Preserva a situação atual enquanto faz download e verifica TODOS os assets.
    for item in plan:
        brew('fetch', '--force-bottle', item['full_name'], capture=False)
        cache = Path(brew('--cache', '--force-bottle', item['full_name']).strip())
        with cache.open('rb') as stream:
            digest = hashlib.sha256()
            for chunk in iter(lambda: stream.read(1024 * 1024), b''):
                digest.update(chunk)
        if digest.hexdigest() != item['sha256']:
            raise SystemExit('Download/checksum inválido; nenhuma reinstalação iniciada.')
    log = []
    for item in plan:
        # Reinstall mantém backup temporário do keg; evita desinstalação em massa.
        args = [item['action'], '--force-bottle']
        if item['action'] == 'reinstall':
            args.extend(['--force', '--no-ask'])
        args.append(item['full_name'])
        brew(*args, capture=False)
        actual = info(item['full_name'])
        receipts = actual.get('installed') or []
        if not receipts:
            raise SystemExit('Verificação de instalação por bottle falhou: ' + item['full_name'])
        # Confira a origem real nas receipts; a definição consultada sozinha não prova migração.
        active_prefix = Path(brew('--prefix', item['full_name']).strip())
        receipt = json.loads((active_prefix / 'INSTALL_RECEIPT.json').read_text())
        if not receipt.get('poured_from_bottle'):
            raise SystemExit('Receipt não indica instalação por bottle: ' + item['full_name'])
        if receipt.get('source', {}).get('tap') != snapshot['tap']:
            raise SystemExit('Receipt não indica o tap esperado: ' + item['full_name'])
        brew('linkage', '--test', item['full_name'], capture=False)
        log.append(item['full_name'])
        (backup / 'completed.json').write_text(json.dumps(log, indent=2) + '\n')
    print('Migração concluída. Registros em', backup)
    print('Checks automáticos de dependentes ficaram desativados neste processo.')
    print('Avalie brew linkage --test nos demais aplicativos que usam estas bibliotecas.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    scanner = sub.add_parser('scan')
    scanner.add_argument('--write-packages', action='store_true')
    migration = sub.add_parser('migrate')
    migration.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    if args.command == 'scan':
        scan(args.write_packages)
    else:
        migrate(args.apply)


if __name__ == '__main__':
    main()
