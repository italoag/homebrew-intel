# Inventário, atualização da esteira e migração do Mac

Os comandos abaixo são executados **no Mac Intel com macOS 26**, dentro do
checkout Git do seu `homebrew-intel`. O template atualizado precisa estar
publicado nesse repositório antes de executar o inventário.

## 1. Gerar lista e atualizar packages.txt

```bash
brew update
/usr/bin/python3 scripts/sync-installed.py scan --write-packages
cat .work/missing-tahoe-bottles.txt
cat .work/review.txt
git diff -- packages.txt
```

O scanner consulta **a definição stable atual de homebrew/core** para cada
fórmula instalada, mesmo se você já estiver usando sua cópia no tap. Usa Python
da Apple para não depender de jq nem de um Python gerenciado que será migrado.

Critério: **ausência de bottle `tahoe` (Intel macOS 26) e de bottle universal
`all`**. É uma escolha conservadora de gerar builds específicos para sua máquina;
não equivale a afirmar que o software perdeu suporte Intel. Um bottle `sequoia`
ou `sonoma` ainda pode funcionar em Tahoe. Esses tags ficam registrados no
relatório completo `.work/intel-scan.json`.

Fórmulas de outros taps, desabilitadas, sem stable ou renomeadas entram em
`.work/review.txt`, sem importação automática. Ausência de bottle também não
garante que uma fórmula conseguirá compilar em Intel: o workflow verificará.

`packages.txt` recebe as candidatas novas e preserva entradas anteriores. Não
remove automaticamente pacotes que já eram mantidos pelo tap. Os relatórios
locais ficam em `.work`, ignorada pelo Git; não publique seu inventário completo.

## 2. Publicar a lista e aguardar os builds

```bash
git add packages.txt
git commit -m "Update Intel bottle build catalog from local inventory"
git push origin main
```

Se não houver alterações, não crie um commit vazio. A lista já está configurada.
O push da lista aciona o workflow; o horário diário também verifica mudanças
upstream. A rotina só publica fórmulas novas após build, testes, download e
instalação reais de todo o snapshot no runner.

Confira Actions no GitHub e aguarde **sucesso**, não apenas a existência de um
release. Releases de runs que falharam na validação podem permanecer disponíveis
sem serem promovidos para main.

## 3. Atualizar os metadados locais e revisar a migração

Substitua `SEU_USUARIO` pelo proprietário do repositório:

```bash
git pull --ff-only
brew tap SEU_USUARIO/intel
brew update
/usr/bin/python3 scripts/sync-installed.py migrate
```

A rotina lê o inventário local e o snapshot publicado, resolve dependências de
execução e salva `.work/migration-plan.json`. Sem `--apply`, não reinstala nada.
Pode migrar dependências que já têm bottle oficial porque o snapshot do tap foi
compilado e testado usando as cópias dessas dependências no mesmo tap.

Se aparecer serviço iniciado/agendado, a rotina para. Faça backup dos dados e
configurações e interrompa esse serviço durante sua janela de manutenção, por
exemplo `brew services stop postgresql@17`. Depois repita o plano. A rotina
também para em pacotes pinned, HEAD, opções personalizadas e conflitos de outros
taps; revise cada caso, em vez de removê-los automaticamente.

## 4. Executar a migração

```bash
/usr/bin/python3 scripts/sync-installed.py migrate --apply
```

A rotina:

1. Registra inventário anterior e plano em `.work/migration-<data>`.
2. Baixa e verifica SHA-256 de **todos** os bottles antes de qualquer reinstalação.
3. Instala/reinstala em ordem de dependência, com nome completo do tap e
   `--force-bottle`; não faz desinstalação em massa.
4. Verifica a receipt da versão ativa: origem do tap e `poured_from_bottle`.
5. Testa linkage e registra cada pacote concluído.

O Homebrew mantém um backup temporário do keg durante cada reinstalação e tenta
restaurá-lo se a operação falhar. Isso **não é rollback transacional** do conjunto,
nem backup de bancos de dados/configurações. Se uma etapa falhar, pacotes
anteriores já concluídos permanecem migrados. Investigue o log antes de repetir.

Atualização/reinstalação automática de dependentes e limpeza ficam desativadas
somente nos subprocessos deste fluxo, para evitar builds inesperados de pacotes
fora do catálogo. Isso exige avaliar linkage nos outros aplicativos que usam
as bibliotecas migradas. Não habilite indiscriminadamente um upgrade global
para tentar reparar dependentes sem bottle.

## 5. Próximas atualizações

O horário diário acompanha versões upstream dos pacotes configurados. No Mac,
use nomes completos e o preflight fornecido para instalar as versões publicadas:

```bash
brew update
tap_checkout="$(brew --repository SEU_USUARIO/intel)"
/usr/bin/python3 "$tap_checkout/scripts/install-binary.py" upgrade jq
```

Troque `jq` pelos nomes que você migrou. Você pode informar vários nomes na
mesma chamada. Ao instalar pacotes adicionais no Mac, repita o scanner para
acrescentar candidatas a `packages.txt` e faça push.

Adicionar o tap não muda sozinho a origem dos kegs existentes. O fluxo usa
reinstalação qualificada para efetivar a troca e confere `source.tap` na receipt.
`brew migrate` é voltado à migração de pacotes renomeados; não deve ser tratado
como um seletor genérico de tap. O antigo `brew tap-pin` foi removido.

## Verificação manual

Para um pacote, substitua `jq` pelo nome desejado:

```bash
/usr/bin/python3 - <<'PY'
import json
from pathlib import Path
import subprocess
name = 'jq'
prefix = Path(subprocess.check_output(['brew', '--prefix', name], text=True).strip())
receipt = json.loads((prefix / 'INSTALL_RECEIPT.json').read_text())
print('Tap:', receipt.get('source', {}).get('tap'))
print('Instalado por bottle:', receipt.get('poured_from_bottle'))
PY
```

## Referências

- https://docs.brew.sh/Manpage
- https://docs.brew.sh/Bottles
- https://docs.brew.sh/Taps
- https://docs.brew.sh/Querying-Brew
- https://github.com/Homebrew/brew/blob/main/Library/Homebrew/reinstall/reinstall.rb
- https://brew.sh/2020/05/29/homebrew-2.3.0/

O fluxo foi validado com fixtures e testes em Linux. Inventário real,
reinstalação entre taps e compatibilidade dos seus aplicativos precisam ser
verificados no Mac e no primeiro run do GitHub Actions.
