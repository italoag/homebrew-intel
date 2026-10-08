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
    closure = set(targets)
    for target in targets:
        closure.update(brew('deps', '--full-name', target).split())
    for full in sorted(closure):
        if not full.startswith(tap + '/'):
            raise SystemExit('Dependência fora do tap: ' + full)
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
    subprocess.run(['brew', sys.argv[1], '--force-bottle', *targets], env=env, check=True)


if __name__ == '__main__':
    main()
