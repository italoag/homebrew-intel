#!/usr/bin/env bash
# Prepara uma instalação limpa de macOS 26 Intel para construir os bottles do
# tap. Idempotente: instala só o que falta e valida os pré-requisitos que o
# pipeline exige (x86_64, macOS 26, Homebrew em /usr/local, token do GitHub).
# Não compila nada — a build começa pelo comando impresso no final.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

die() { echo "erro: $*" >&2; exit 1; }
step() { echo; echo "== $*"; }

step "Arquitetura e sistema"
# Bottle gravado com outro prefixo/tag quebra em quem instala: o pipeline
# recusa, e aqui a falha é antes de baixar qualquer coisa.
[ "$(uname -m)" = x86_64 ] || die "arquitetura $(uname -m); o tap publica só x86_64"
version=$(sw_vers -productVersion)
[ "${version%%.*}" = 26 ] || die "macOS $version; os bottles são tahoe (26)"

step "Command Line Tools"
if ! xcode-select -p >/dev/null 2>&1; then
    echo "instalando (uma janela do sistema pode abrir)..."
    xcode-select --install >/dev/null 2>&1 || true
    for _ in $(seq 60); do
        xcode-select -p >/dev/null 2>&1 && break
        sleep 10
    done
    xcode-select -p >/dev/null 2>&1 \
        || die "CLT não instalado; rode 'xcode-select --install' e repita"
fi
/usr/bin/python3 -c 'import sys; raise SystemExit(sys.version_info < (3, 9))' \
    || die "python3 >= 3.9 é necessário (vem com o CLT)"

step "Homebrew em /usr/local"
if ! command -v brew >/dev/null 2>&1; then
    NONINTERACTIVE=1 /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
prefix=$(brew --prefix)
[ "$prefix" = /usr/local ] || die "Homebrew em $prefix; os bottles exigem /usr/local"

step "Token do GitHub"
if [ -z "${GITHUB_TOKEN:-}" ]; then
    command -v gh >/dev/null 2>&1 \
        || die "exporte GITHUB_TOKEN (PAT com Contents: read/write neste repositório)"
    GITHUB_TOKEN=$(gh auth token)
fi

step "Pré-requisitos do pipeline"
# checks()/repo_tap() são exatamente o que o build valida; falhar aqui evita
# descobrir o problema depois de horas compilando.
GITHUB_TOKEN=$GITHUB_TOKEN PIPELINE_ALLOW_LOCAL=1 python3 - <<'PY'
import importlib.util
import pathlib

spec = importlib.util.spec_from_file_location(
    'pipeline', pathlib.Path('scripts/pipeline.py'))
pipeline = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pipeline)
pipeline.checks()
owner, repository, tap = pipeline.repo_tap()
print(f'tap ok: {owner}/{repository} -> {tap}')
PY

cat <<'EOF'

Pronto. Para construir e publicar no release rolante:

  PIPELINE_ALLOW_LOCAL=1 GITHUB_TOKEN="$GITHUB_TOKEN" \
    python3 scripts/pipeline.py local

EOF
