# Homebrew Intel Tahoe — bottles via GitHub Actions

Template de tap público para Mac Intel com **macOS 26**, Homebrew em **/usr/local**
e Command Line Tools instaladas. Runner fixo: **macos-26-intel**.

O projeto ainda precisa ser publicado no seu GitHub e validado no runner macOS.
A verificação local do template não substitui um build/instalação real no macOS.

Para gerar o catálogo a partir das suas fórmulas instaladas e migrar os kegs
para o tap, siga **MIGRACAO.md**. O script `scripts/sync-installed.py` gera o
inventário, atualiza `packages.txt` e prepara/executa a migração após o build.

## Ativar

1. Crie um repositório **público** chamado `homebrew-intel`, com branch padrão `main`.
   Pode usar seu usuário ou uma organização. Não há proprietário fixo no código.
2. Copie o conteúdo desta pasta, incluindo `.github`, para o repositório.
3. Comece com o `jq` de exemplo em `packages.txt`. Depois do primeiro sucesso,
   acrescente seus pacotes reais, um nome canônico de `homebrew/core` por linha.
   Fórmulas de taps de terceiros entram como `owner/tap/nome`; para taps com
   remote fora do padrão `github.com/owner/homebrew-<tap>`, registre o remote
   em `taps.txt` (`owner/tap URL`) — `sync-installed.py scan` gera o arquivo.
4. Em Settings → Actions → General, permita a execução do workflow e permissões
   de escrita em contents para `GITHUB_TOKEN`. Uma política da organização pode
   exigir ajuste pelo administrador. Nenhum PAT precisa ser criado.
5. Execute Actions → Intel Tahoe bottles → Run workflow. Pushes que alterem a
   lista/esteira também iniciam o build. O agendamento diário verifica mudanças
   aproximadamente às **04:23 de São Paulo** (07:23 UTC), sujeito a atrasos do GitHub.
6. Espere o workflow concluir e aparecerem `Formula/*.rb` e `snapshot.json` em main.
   Só então configure o Mac.

Se usar Git local, execute dentro de um checkout vazio do novo repositório:

```bash
# Copie os arquivos do template primeiro, incluindo a pasta .github.
git add .
git commit -m "Add Intel Tahoe bottle pipeline"
git push origin main
```

## Usar no Mac

Substitua `SEU_USUARIO` pelo proprietário real do repositório:

```bash
brew tap SEU_USUARIO/intel
brew trust SEU_USUARIO/intel
brew update
brew install SEU_USUARIO/intel/jq
```

Homebrew lê o `bottle do` da fórmula do tap e baixa o `.bottle.tar.gz` do GitHub
Release indicado por `root_url`. SHA-256 é verificado pelo próprio Homebrew.
`brew tap` não confia no tap automaticamente: sem `brew trust`, o brew recusa
carregar fórmulas de taps de terceiros ao resolver dependências.
Não use `HOMEBREW_BOTTLE_DOMAIN`: este projeto é um tap com metadados próprios,
não um espelho completo dos bottles de homebrew/core.

Para usar o preflight incluído, localize o checkout criado pelo próprio tap:

```bash
tap_checkout="$(brew --repository SEU_USUARIO/intel)"
python3 "$tap_checkout/scripts/install-binary.py" install jq

# Depois que a esteira publicar uma atualização:
brew update
python3 "$tap_checkout/scripts/install-binary.py" upgrade jq
```

O preflight valida plataforma, prefixo, conjunto de dependências e presença dos
bottles do snapshot antes de chamar brew. Não aceita HEAD, opções de build ou
pacotes fora do snapshot. O Homebrew continua responsável por requisitos,
restrições `pour_bottle?`, integridade e erros de instalação. `--force-bottle`
isoladamente não é uma política global de proibição de compilação; não o use
para contornar incompatibilidade entre sistemas operacionais.

**Use nomes qualificados** (`SEU_USUARIO/intel/jq`). `brew install jq` pode
resolver homebrew/core. `brew update` atualiza os metadados; `brew upgrade`
instala as novas versões. A esteira não instala atualizações no Mac sozinha.

Pacotes já instalados de homebrew/core não mudam de origem apenas com `brew tap`.
Faça inventário e backup de configurações/dados antes de uma migração. Homebrew
pode recusar instalar uma fórmula de mesmo nome de outro tap; nesse caso a
migração requer desinstalação/reinstalação planejada. O template não remove
automaticamente pacotes ou dados do seu Mac.

## Como funciona

O workflow tem três jobs: **plan** → **build** (matrix de 4 shards) → **publish**.

1. `plan` resolve recursivamente dependências diretas de runtime, build e testes
   em homebrew/core e nas taps de `taps.txt`. Detecta ciclos, remove
   `no_autobump!`, reescreve deps para o tap e verifica com brew que a árvore
   não escapou para outro tap.
2. Quando a versão atual já publica bottle Intel pelo mantenedor, o bloco
   `bottle` oficial é preservado e o binário é apenas baixado. Sem bottle
   Intel, a fórmula é compilada.
3. Cada membro recebe um fingerprint (fonte transformada + fingerprint das
   deps). Mudança em uma dep invalida os dependentes em cascata — só o que
   mudou entra no build_set, particionado em 4 shards com afinidade de deps.
4. Cada shard `build` instala deps despejando bottles já publicados (do release
   ou adotados de shards irmãos) e compila o que falta localmente. Ao concluir
   cada membro, publica na hora o `.bottle.tar.gz`, o `Formula-<nome>.rb` e seu
   fragmento de manifesto no release rolante `tahoe-bottles` — o checkpoint
   faz qualquer trabalho concluído sobreviver a timeout ou falha do shard.
5. Reexecutar um job falho ou disparar nova run continua de onde parou:
   manifesto e fragmentos dizem o que já existe e só o restante é refeito.
6. `publish` mescla manifestos, monta `Formula/` (asset novo, arquivo promovido
   ou fonte reutilizada), remove assets órfãos e grava `snapshot.json` com
   `pending` para o que ainda falta. Só então commita em main; shard falho
   promove apenas o que ficou pronto e a run seguinte retoma o restante.

## Escopo e limites

- **Não é um espelho universal.** A lista explícita é o catálogo desejado.
  Para obter candidatos no Mac: `brew leaves`. Revise a lista antes de adicionar.
- Somente fórmulas canônicas de homebrew/core ou dos taps declarados em
  `packages.txt`/`taps.txt`, versões stable e opções padrão. Nomes de fórmulas
  que colidirem entre taps abortam o run. Casks não entram: em geral já
  distribuem binários e possuem outro ciclo.
- Fórmulas com ciclos de bootstrap/teste, dependências geradas dinamicamente,
  helpers externos, requisitos exclusivos de ARM ou APIs específicas de
  homebrew/core podem exigir adaptação manual. Não há promessa de que toda
  fórmula continuará compilando em Intel. Falha não promove o snapshot.
- O primeiro build ainda é grande: shards dividem o trabalho em 4 runners e
  deps compartilhadas podem ser compiladas em mais de um shard (duplicação
  segura; só o dono publica). Uma fórmula que sozinha exceda 360 minutos
  (ex.: LLVM em hardware lento) continua sendo o limite duro do job.
- O release `tahoe-bottles` é rolante e acumula assets entre runs — é o
  mecanismo de retomada. Não apague o release nem assets referenciados no
  manifesto; o publish remove sozinho o que ficou órfão.
- Limite de job configurado: 360 minutos por shard. Repositórios privados podem
  gerar cobrança por minutos macOS e exigem estratégia de autenticação para
  downloads. Esta configuração pressupõe distribuição **pública** de binários.
- Agendamentos do GitHub podem atrasar e ser desativados por inatividade em
  repositórios públicos. Confira a execução periódica. Proteção de main que
  proíba push do bot impede promoção; nesse cenário use PR automatizada/App
  apropriada, sem enfraquecer a política existente.
- Binários Tahoe x86_64 não são garantia de compatibilidade com macOS 15/14.
  Prefixo padrão e ferramentas de desenvolvimento continuam necessários.
- Publicar bottles não resolve a remoção futura do suporte Intel do próprio
  brew: prevista em ou após setembro de 2027. Continuidade exigirá um fork/versão
  mantida do Homebrew e disponibilidade de runner Intel, avaliados à época.
- Homebrew-core tem licença BSD-2-Clause; preserve sua licença (o workflow abaixo
  copia a licença no snapshot). Cada software e suas dependências possuem suas
  próprias licenças e obrigações de redistribuição; revise o catálogo escolhido.

## Referências oficiais

- https://docs.github.com/en/actions/reference/runners/github-hosted-runners
- https://github.com/actions/runner-images
- https://docs.brew.sh/Bottles
- https://docs.brew.sh/Manpage
- https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap
- https://docs.brew.sh/Support-Tiers
- https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#schedule

## Validação realizada antes da entrega

Sintaxe Python e YAML, execução local bloqueada da rotina destrutiva,
tratamento de grafo/ciclos, transformação de metadados/dependências e preflight
com fixtures: **10 testes passaram**, incluindo filtragem de bottles e bloqueio
da migração antes da publicação/download completos. Build macOS, download dos releases e instalação real precisam
ser validados pelo primeiro workflow; não foram executados no ambiente Linux.
