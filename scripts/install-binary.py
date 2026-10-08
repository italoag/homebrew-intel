#!/usr/bin/env python3
"""Preflight de instalação/upgrade: somente snapshot Intel validado, sem opções livres."""
import json
import os
from pathlib import Path
import platform
import subprocess
import sys


def brew(*args):
    return subprocess.check_output(['brew', *args], text=True)


def main():
    if len(sys.argv) < 3 or sys.argv[1] not in ('install', 'upgrade'):
        raise SystemExit('Uso: python3 scripts/install-binary.py install|upgrade jq [outros]')
    if platform.system() != 'Darwin' or platform.machine() != 'x86_64':
        raise SystemExit('Este snapshot exige Mac Intel nativo.')
    version = subprocess.check_output(['sw_vers', '-productVersion'], text=True).strip()
    if version.split('.')[0] != '26' or brew('--prefix').strip() != '/usr/local':
        raise SystemExit('Exige macOS 26 e Homebrew em /usr/local. Não force bottles em outro OS.')
    state_file = Path(__file__).resolve().parents[1] / 'snapshot.json'
    if not state_file.exists():
        raise SystemExit('Execute o primeiro workflow com sucesso antes de instalar.')
    state = json.loads(state_file.read_text())
    tap = state['tap']
    names = sys.argv[2:]
    if any(name not in state['order'] for name in names):
        raise SystemExit('Pacote fora do snapshot. Acrescente a packages.txt e aguarde o workflow.')
    targets = [tap + '/' + name for name in names]
    order_set = set(state['order'])
    closure = set(targets)
    for target in targets:
        for dep in brew('deps', '--full-name', target).split():
            short = dep.removeprefix('homebrew/core/')
            if dep.startswith(tap + '/'):
                closure.add(dep)
            elif short in order_set:
                # Dep implícita (ex.: extrator .7z -> p7zip) resolve pelo nome
                # curto; o keg do tap a satisfaz desde que instalado antes.
                closure.add(tap + '/' + short)
            else:
                raise SystemExit('Dependência fora do tap: ' + dep)
    for full in sorted(closure):
        info = json.loads(brew('info', '--json=v2', full))['formulae'][0]
        bottles = (info.get('bottle') or {}).get('stable', {}).get('files', {})
        bottle = bottles.get('tahoe') or bottles.get('all')
        if not bottle or not bottle['url'].startswith(
                'https://github.com/' + tap.split('/')[0] + '/homebrew-' +
                tap.split('/')[1] + '/releases/download/' + state['tag'] + '/'):
            raise SystemExit('Bottle do snapshot ausente: ' + full)
    # Não cria fallback. Preflight valida a presença; o brew valida SHA-256 ao baixar.
    # --force-bottle sozinho NÃO constitui garantia geral de ausência de build.
    env = dict(os.environ, HOMEBREW_NO_AUTO_UPDATE='1',
               HOMEBREW_NO_INSTALL_CLEANUP='1', HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK='1')
    # Instala o fechamento em ordem de dependência para que deps implícitas de
    # nome curto (ex.: p7zip de um .7z) sejam satisfeitas pelo keg do tap.
    planned = [tap + '/' + n for n in state['order'] if tap + '/' + n in closure]
    if sys.argv[1] == 'upgrade':
        installed = {item.get('full_name') for item in
                     json.loads(brew('info', '--json=v2', '--installed'))['formulae']}
        planned = [item for item in planned if item in installed or item in targets]
    for item in planned:
        subprocess.run(['brew', sys.argv[1], '--force-bottle', item], env=env, check=True)


if __name__ == '__main__':
    main()
