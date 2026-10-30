# Scripts de compilação, execução e validação

[English](README.md)

## Portal Wiki

Os READMEs principais apresentam o projeto e a primeira execução. Os guias
técnicos permanecem em `docs/`, versionados com a implementação. Os dois
índices da documentação são a fonte mantida da navegação Wiki; não manter
cópias independentes dos guias ali.

```powershell
pwsh ./scripts/prepare-wiki.ps1
```

O gerador local determinístico escreve `Home.md`, `Home.pt-BR.md`, `_Sidebar.md`
e `_Footer.md` em `out/wiki` descartável. Links relativos dos guias viram links
do repositório, preservando fragmentos; os de idioma escolhem a página inicial
Wiki correspondente. `-OutputDirectory out/wiki-preview` escolhe outro local
de prévia sob `out/`. Não clona, commita nem publica repositórios.

Antes de publicar, commitar/publicar os guias referenciados em `main` e passar
por `scripts/check-doc-links.ps1` e pelos três crivos de
`scripts/commit-check.ps1`. A Wiki tem repositório Git próprio. Habilitá-la nas
configurações do repositório e, na primeira publicação, criar a página inicial
pela interface GitHub, conforme as
[instruções oficiais](https://docs.github.com/en/communities/documenting-your-project-with-wikis/adding-or-editing-wiki-pages).
Após inicializar, usar checkout novo da Wiki e copiar somente as quatro páginas
geradas para ele:

```powershell
git clone https://github.com/naldodj/hb.bridge.wiki.git out/wiki-repository
Copy-Item -LiteralPath out/wiki/Home.md,out/wiki/Home.pt-BR.md,out/wiki/_Sidebar.md,out/wiki/_Footer.md -Destination out/wiki-repository
git -C out/wiki-repository diff --check
git -C out/wiki-repository add -- Home.md Home.pt-BR.md _Sidebar.md _Footer.md
git -C out/wiki-repository commit -m "Refresh hbBridge documentation navigation"
git -C out/wiki-repository push origin HEAD
```

Usar caminho de checkout ainda não utilizado em cada reprodução. Preservar
páginas Wiki existentes não relacionadas. Nas atualizações, editar índices/
guias versionados e gerar novamente; o gerador não exige token pessoal nem
segredo adicional de CI.

## Apresentação nativa Protheus isolada

`test-protheus-presentation.ps1` recebe pré-requisitos explícitos por
`-AppServerDirectory`, `-IniFile`, `-RpoDirectory` e `-IncludeDirectory`.
Passe includes como array PowerShell, por exemplo `@('<totvs>', '<projeto>/includes')`.
Copia SDK/RPOs licenciados para área descartável nova, compila todos os fontes
TLPP atuais e executa conversão e regressões dos datasets tipado/comum.
`-NativeTables` também executa observações SDK, armazenamento/liberação reais
FWTemporaryTable e callbacks de navegação/colunas do exemplo sem abrir a janela,
no DBAccess configurado. Não ativa o browse, substitui arquivos
da instalação nem interrompe serviços existentes. Fontes/RPOs recebem hashes;
`result.json` local registra resultados exatos sem conteúdo INI. Veja o
[guia e exemplo visual manual](../docs/native-presentation.pt-BR.md).

`-MeasureConversion` compara adicionalmente a conversão estrita por linha com
a conversão por página em 100 colunas × 100 linhas, em três rodadas alternadas.
A fase local medida exclui criação da fixture, SQL, transporte, armazenamento
nativo, interface e comparação dos valores. Os checks de corretude não exigem
ganho de tempo. As suítes padrão incluem conversão por página e planejamento
dos metadados SRA.

`-NativeRows 10000` define a carga sintética principal (padrão 1025), por
`U_HBBridgePresentationTableCLI --native-rows=10000`. Os casos pequenos de
paginação mantêm duas linhas seguidas de uma. O exemplo interativo é separado:
`U_HBBridgeNativeBrowse(10000,100)` define quantidade e tamanho da página;
os padrões são 1000/13. As duas origens são fixtures geradas, sem consulta a
tabelas do ERP.

Para acrescentar integração SQL efetiva pelo hbBridge, mantenha uma nova fixture
SQL tipada própria servindo em um terminal:

```powershell
./scripts/test-hbbridge-typed-sql.ps1 -Config '<ini-privado>' `
    -Profile '<alias-mssql>' -Serve -ServeSeconds 1200
```

Aguarde o novo caminho de `endpoints.json` impresso; em outro terminal execute:

```powershell
./scripts/test-protheus-presentation.ps1 -AppServerDirectory '<sdk>' `
    -IniFile '<ini-sdk>' -RpoDirectory '<rpos-fornecedor>' `
    -IncludeDirectory @('<includes-totvs>', '<projeto>/includes') `
    -NativeTables -HBBridgeEndpointsFile '<endpoints-novo.json>'
```

`-HBBridgeEndpointsFile` exige `-NativeTables` e acrescenta
`U_HBBridgePresentationSQLTest`: SELECT MSSQL real sobre cinco linhas
constantes de `VALUES`, TCP e HTTP gzip, dataset tipado e temporária nativa
própria. Não lê/grava tabelas ERP. O runner copia a nova configuração de
endpoints somente para seu novo INI próprio; INIs da instalação não são
alterados. O JSON contém token HTTP temporário privado: mantenha-o local,
fora do Git e de evidências publicáveis. A fixture servidora encerra ao atingir
o prazo limitado ou por `stop.request` naquela nova pasta da execução.
Reproduza com uma nova execução, sem preservar endpoints em tmp.

Já `U_HBBridgeNativeBrowseSX5('<perfil>','TCP',100)` ou a variante HTTP lê SX5
real interativamente em contexto Protheus de empresa/filial já preparado.
Sua definição de origem resolve dicionário/tabela/filial no Protheus. Essa
etapa visual manual é separada do aceite automático de constantes SQL; veja
o [guia nativo](../docs/native-presentation.pt-BR.md#ler-dados-reais-da-sx5-no-browse-nativo).

## Probes de resposta HTTP

Manutenção de respostas HTTP: `test-harbour-http-send.ps1` reproduz envios
parciais/prazo/parada nativos, sem credenciais do banco.
`test-protheus-http-gzip.ps1` recebe SDK/INI/includes externos explícitos e cria
SDK/RPO privados novos para verificar FWRest/cliente TLPP; `-CompileAll`
compila todo o TLPP do projeto. Python 3 é necessário apenas na fixture própria
em loopback. Veja o [guia do probe](../src/tlpp/tests/protheus/hbbridge.http.test/README.pt-BR.md).

`profile-protheus-http.ps1` usa o mesmo SDK isolado e `-EndpointsFile`
explícito de uma fixture MSSQL M08 nova para medir FWRest, expansão gzip,
parsing JSON e validação direta das linhas. Identity é diagnóstico; o
benchmark HTTP exige gzip. `benchmark-harbour-json.ps1` compara a busca de
codepage por escalar com uma por documento: por padrão, oito lotes alternados
de 50 codificações e três aquecimentos. Verifica bytes idênticos em quatro
configurações SET; esses tempos de serialização não comprovam ganho HTTP.

Os checks Windows de 2026-10-24 passaram envio nativo 18/0 e FWRest/cliente
14/0; a rodada isolada `-CompileAll` compilou 55 fontes com zero erros. Veja
[escopo e identidades](../docs/validation/http.response.windows.json).

São necessários PowerShell 7 e Git. O bootstrap gerenciado resolve cópias
fixadas de hb_compile, Harbour e Zig; veja [dependências](../docs/dependencies.pt-BR.md).
Não depende de um checkout pessoal nem de Zig instalado globalmente.

`./scripts/test-harbour-memio.ps1` compila/executa o probe MEMIO independente
com toolchain gerenciado e diretório descartável novo. A rodada Windows de
2026-10-23 passou em 22 verificações mais uma em processo novo; não homologa
serviço SQL/cache do produto nem Linux. Veja [vida útil, escopo e trabalho futuro](../docs/evolution.pt-BR.md#resultados-em-memoria-entre-requisicoes).

```powershell
./scripts/bootstrap.ps1
./scripts/build-hbbridge.ps1
./scripts/test-hbbridge.ps1
```

O bootstrap verifica o checksum do arquivo Zig e as revisões Git de
[dependencies.json](../config/dependencies.json). Uma instalação completa
registrada evita recompilações desnecessárias. `-ForceBuild` recompila o
Harbour; `-SkipHarbourBuild` resolve somente fontes e Zig. Windows compila
pelo hb_compile; Linux usa seu preparador de compatibilidade e make/GCC
nativos. Linux requer PowerShell 7, Git, make/GCC/binutils e headers de
desenvolvimento unixODBC. Drivers ODBC SQL Server e recursos licenciados
TOTVS são instalados separadamente. A execução Linux exige homologação própria.

O bootstrap também prepara hbhttpd/hbtcpio e o patch do projeto com checksum
verificado através de `prepare-http.ps1`. HTTPS direto exige build opcional
hbssl/OpenSSL e seu SDK/runtime. Veja [HTTP](../docs/http.pt-BR.md);
`-hblib` identifica o modo de biblioteca do hbmk2.

`build-hbbridge.ps1` gera `out/hbbridge.exe` no Windows ou `out/hbbridge`
no Linux. Não encerra servidores ativos. Para compilar junto de uma
instalação em execução, use uma saída isolada:

```powershell
./scripts/build-hbbridge.ps1 -OutputDirectory tmp/candidate
```

`-HbCompileRoot` e `-ZigPath` são substituições explícitas para casos
avançados. O padrão usa dependências do projeto. `toolchain.ps1` resolve
hbrun/hbmk2/Zig/compilador e verifica a versão Zig; mudanças temporárias
de ambiente são restauradas após a execução.

`test-hbbridge.ps1` prepara fixtures e o alvo MT isolados, compartilhando os
componentes do produto. Registra `tmp/tests-<id>/results.log` e propaga o
código de saída. A cobertura inclui configuração/INI, registro, relógio
monotônico, NETIO/admin/VF IO, gzip/enquadramento, SQLite/paginação e MT.
A rodada anterior Windows teve 412 verificações, zero falhas e nenhum skip.
A validação gerenciada posterior de 2026-10-04 teve **416 verificações,
zero falhas e nenhum skip**; o log é
`tmp/tests-d1b829ff332c414f816a6e70748152d1/results.log`.
Esses resultados históricos não homologam alterações posteriores.
Veja [homologação](../docs/acceptance.pt-BR.md).

## Limpeza de artefatos

`tmp/` pode ser descartado por inteiro. Fontes e runners reutilizáveis ficam
versionados em `scripts/` e `tests/`; veja [validação](../docs/validation/README.pt-BR.md).
Logs, manifests, referências em documentos e `*-current.txt` não preservam
arquivos temporários silenciosamente.

```powershell
# Simular; idade padrão: sete dias.
$report = ./scripts/clean-artifacts.ps1
$report.Candidates | Format-Table Path, Status, Bytes, Reason -AutoSize

# Simular tmp inteiro, incluindo entradas recentes.
./scripts/clean-artifacts.ps1 -Target tmp -MinAgeDays 0

# Aplicar essa mesma limpeza explícitamente.
./scripts/clean-artifacts.ps1 -Target tmp -MinAgeDays 0 -Apply

# Limpar builds de out, preservando o produto/addons gerados.
./scripts/clean-artifacts.ps1 -Target out -MinAgeDays 0 -Apply
```

Exige PowerShell 7 e Git acessível, sem compilador. `-Target` aceita `all`
(padrão), `tmp` ou `out`. A idade mínima de sete dias considera descendentes;
0 permite limpeza imediata. Todas as entradas de primeiro nível de tmp são
candidatas, incluindo RPOs copiados, scripts avulsos e diretórios desconhecidos.
Em out, o script remove caches de build/objetos, preservando demais entregaveis.

Permanecem as proteções de arquivos Git, links/junctions, processos visíveis e
`-KeepPath` explícito. A exclusão manual de um caminho é uma escolha operacional
temporária, nunca requisito permanente do projeto. Links não são percorridos.
O crivo de commit rejeita fontes/artefatos versionados em tmp/out.

`-Apply -WhatIf` simula sem excluir nem criar relatório. `-ReportPath` opcional
deve indicar arquivo novo em tmp/out; o relatório também é descartavel.
Bloqueio ou alteração concorrente pode deixar candidato parcialmente limpo,
com estado `Failed`; examine `$report.FailedCount`. O script não encerra
processos. A detecção de processos é parcial: executar entre builds/testes.
Caminhos são verificados; somente arquivos e diretórios vazios são removidos.
Contagens de bytes representam tamanhos lógicos.

```powershell
./tests/unit/scripts/clean.artifacts.test.ps1
./scripts/check-doc-links.ps1
```

As fixtures validam ausência de tmp/out, descarte completo de tmp, ausência de
retenção por documentos/ponteiros, idade, Git, links, preservação explícita,
arquivos bloqueados, relatórios e simulação/WhatIf.

Helpers de validação mantidos: `check-doc-links.ps1`,
`test-harbour-thread-state.ps1` e `run-protheus-cli.ps1`. O último exige
SDK/INI/programa explícitos e informa resultados do processo, sem deduzir
aprovação das asserções. Veja os [roteiros por fontes](../docs/validation/README.pt-BR.md).
O INI fornecido precisa ficar junto ao executável do SDK isolado fornecido;
o AppServer testado rejeita diretório em `-ini`. O executor omite essa opção
para `appserver.ini` padrão, ou passa outro INI pelo nome base como argumento
separado. Não copia INI para instalação ativa nem a modifica. Veja a
[referência TOTVS de linha de comando](https://tdn.totvs.com/display/tec/Application%2BServer%2B-%2BCommand%2BLine).

## Validação de commits

Antes de cada commit:

```powershell
./scripts/commit-check.ps1
```

Por padrão, verifica arquivos modificados/adicionados da árvore de trabalho e
do índice, além dos novos não ignorados. Use `-Staged` para validar somente os
arquivos alterados preparados para commit, com seu conteúdo indexado; `-All`
faz a revisão completa (`-Staged -All` revisa o índice completo). Documentos
excluídos/renomeados incluem o par de idioma sobrevivente. Alterações nas
regras, ferramentas de validação ou políticas de dependências/configuração
exigem automaticamente revisão completa. A validação de terceiros permanece
global; os três validadores Harbour são executados mesmo com seleção vazia.
A seleção não atualiza nem modifica o índice. A regressão isolada está em
`./scripts/test-commit-check-selection.ps1`.

A validação do índice remove sua cópia dos fontes em `finally`, inclusive em
falhas de checkout/validação. A regressão de seleção também remove as fixtures
geradas. Cópias TLPP não devem permanecer em `tmp/`: confundem a resolução de
fontes da extensão TOTVS. Listas/logs preservados não contêm fontes duplicados;
a compilação Protheus usa os caminhos dos fontes mantidos.

O `hbrun` gerenciado executa `.hbcommit/check.hb`, `.hbcommit/commit.hb` e
`.hbcommit/3rdpatch.hb` em validação somente de leitura. Não há outro
runtime Harbour distribuído em `bin/harbour`. Preserve os avisos originais
e corrija falhas antes do commit; a validação não prepara o índice.
`-InstallHook` instala o hook após os checks passarem, preservando um hook
diferente já existente. `-Staged` verifica o conteúdo do índice em cópia
isolada. Os [padrões](../docs/standards.pt-BR.md) definem arquivos em
minúsculas, identificadores em inglês e funções, procedures, métodos,
namespaces e classes em PascalCase, além dos pares de documentação.

## Compilação TOTVS

O SDK proprietário é externo. Configure explicitamente seus diretórios:

```powershell
$env:HBBRIDGE_TOTVS_APPSERVER_DIR = '<your-appserver-directory>'
$env:HBBRIDGE_TOTVS_INCLUDES = '<your-totvs-includes>'
$env:HBBRIDGE_TOTVS_ENV = 'PROTHEUS'
./scripts/build-totvs.cmd
```

Os argumentos são diretório AppServer, diretórios de include separados por
ponto e vírgula e ambiente, cujo padrão é PROTHEUS. Includes do projeto são
acrescentados automaticamente. `HBBRIDGE_TOTVS_STOP_SCRIPT` e
`HBBRIDGE_TOTVS_START_SCRIPT` opcionais indicam scripts da instalação; não
se presume instalação fixa nem parada de processos elevados. Falha de
parada configurada interrompe a compilação. O reinício é tentado após o
compilador, preservando seu resultado. O log fica em `tmp/totvs-compile.log`.
`prepare-totvs-sources.ps1` gera lista recursiva dos arquivos `.tlpp` regulares.
TOTVS exige uma linha separada e terminada por ponto e vírgula. Diretórios
pontuados tratados como fontes causaram sete erros e omitiram seus filhos na
análise de 2026-10-12; a lista corrigida incluiu os 24 fontes. Na instalação
local documentada, usar terminal administrativo e `C:\totvs\stop-totvs.bat`
/ `C:\totvs\start-totvs.bat`, reiniciando também após falhas. Colocar argumentos
de includes com ponto e vírgula entre aspas no PowerShell.
Compile toda a árvore `src/tlpp/`, incluindo testes. Classes renomeadas
exigem nova compilação; o aceite anterior não cobre os novos nomes.

## Iniciar o produto e os exemplos

[run-hbbridge.ps1](run-hbbridge.ps1) resolve `-Config` a partir da raiz e
define o diretório de trabalho dos addons. Somente argumentos `-Port` e
`-MaxWorkers` explícitos sobrepõem valores INI/JSON:

```powershell
./scripts/run-hbbridge.ps1 -Config config/examples/hbbridge.ini
./examples/mvp/run.ps1
./examples/sql/run.ps1 -Config config/examples/sqlite.ini
./examples/sql/run.ps1 -Config config/examples/mssql.ini -Profile mssql_demo
./examples/sql/run.ps1 -Config config/examples/databases.ini -Profile MSSQL/pData
```

Encerre a instância anterior com Ctrl+Q antes de reutilizar suas portas.
Sem `-Config`, o executável procura `hbbridge.ini` ao seu lado e usa os
padrões quando ausente. Configuração inválida existente impede o início.
Query não é registrado com perfis SQL vazios. O launcher SQL valida o
perfil e mostra a chamada Protheus; os testes são executados separadamente
no AppServer. O launcher não altera a configuração cliente.

`--config-info` retorna somente metadados de host/porta/workers/perfis,
sem segredos, caminhos, listeners ou acesso ao banco:

```powershell
./out/hbbridge.exe --config-info "-config=config/examples/sqlite.ini"
```

Coloque argumentos nativos PowerShell `-config=...ini` entre aspas como no
exemplo. Veja [configuração](../docs/configuration.pt-BR.md) para precedência
e caminhos. Alinhe separadamente o
[template AppServer](../config/examples/protheus-appserver.ini), ou informe
argumentos explícitos. **SQLProfile é opcional e vazio por padrão**.
`sqlite_demo` é exclusivo do exemplo; cada consulta/dataset escolhe seu
alias, como `MSSQL/pData`. Sem alias, o teste informa PROFILE_REQUIRED.

| Configuração | CLI | Padrão / significado |
| --- | --- | --- |
| protheusMaxPayloadBytes | -maxpayloadbytes= | 0, sem teto adicional de aplicação |
| protheusMaxWireBytes | -maxwirebytes= | 0, sem teto adicional de aplicação |
| protheusReadChunkBytes | -readchunkbytes= | 65536, buffer, não teto de mensagem |
| protheusTimeoutMs | -iotimeout= | 30000 ms; 0 desativa prazo no servidor |
| netioTimeout | -netiotimeout= | 0 corresponde ao -1 nativo |
| maxWorkers | -maxworkers= | 64 por listener, configurável |

As capacidades técnicas de `HBBridgeRuntimeLimits()` são validadas
separadamente. TLPP mantém timeout positivo padrão e limites AppServer,
incluindo MAXSTRINGSIZE; blocos lógicos e negociação permanecem pendentes.
O Protheus resolve tenant/empresa/filial/xFilial/tabelas e envia parâmetros
explícitos; o hbBridge permanece executor genérico.

O relato manual AppServer registrado em 2026-10-04 confirmou os 13 checks INI,
relógio Windows, RPC normal e os 29 checks SQLite. Tentativas anteriores de
parada TOTVS permanecem históricas; não houve log posterior de compilação
informado. Novos nomes e os 16 checks revisados precisam de novo aceite.
Falhas/envios parciais forçados, destinos não padrão, MSSQL e Linux continuam
pendentes. A [proposta de credenciais](../docs/credentials.pt-BR.md) descreve
armazenamento portátil; gerenciamento de credenciais cifradas ainda não foi
implementado.

## Teste SQL concorrente opt-in

`test-hbbridge-mssql.ps1 -Config C:/tmp/hbBridge.ini -Profile MSSQL/pData -Concurrency`
compila e executa a suíte M07 isolada de oito workers. `-Concurrency`, `-Failures`
e `-Pooling` são mutuamente exclusivos; `-Serve` funciona em concorrência
ou falhas. No modo concorrência,
imprime endpoints/perfis de teste, hospeda por até 600 segundos e encerra com
`m07.stop` no diretório da rodada ou Esc/Ctrl+Q. Checks finais de recursos
sucedem o shutdown. Veja o [guia](../tests/README.pt-BR.md#concorrência-mssql-e-liberação-de-recursos-m07)
e [consumidor Protheus](../src/tlpp/tests/protheus/hbbridge.concurrency.test/README.pt-BR.md).

`-Pooling -ODBCPooling off` e `-Pooling -ODBCPooling driver` executam o teste
de reuso físico/isolamento em processos separados; `-Pooling` assume `driver`.
`-OtherProfile` opcional deve indicar outro banco MSSQL configurado.
`-Concurrency -ODBCPooling driver` exercita todas as rotas nativas com pooling.
`-HTTPListenBacklog <inteiro positivo>` seleciona a fila solicitada no host
isolado de concorrência. Não altera INIs privados. Veja a
[homologação do pool](../docs/acceptance.pt-BR.md#odbc-physical-reuse-on-2026-10-15).

## Provas nativas de binding SQL (T02)

```powershell
./scripts/test-harbour-sqlite-bind.ps1
./scripts/test-harbour-mssql-bind.ps1 -Config '<ini-privado>' -Profile '<alias>'
```

Os runners usam dependências Harbour gerenciadas e criam pastas descartáveis
com logs de compilação, resultados sanitizados e recibos de fontes/binários.
SQLite usa banco em memória. A prova MSSQL inicial é exclusiva do Windows,
exige driver ODBC SQL Server configurado e usa tabela `#temp` da própria
sessão, descartada antes de desconectar; não altera tabelas da aplicação.
A linha de comando recebe somente o caminho do INI privado e o alias explícito.
Credenciais e texto nativo dos diagnósticos não são registrados.

São provas nativas de prepare/bind/fetch/metadados/liberação. Não expõem
QueryTyped, não validam integração SQLMIX nem homologam AppServer.
DECIMAL fixo exato no SQLite permanece não suportado. Veja o
[contrato](../docs/typed-sql.pt-BR.md), [decisão dos conectores](../docs/typed-sql-connectors.pt-BR.md)
e [evidência sanitizada](../docs/validation/sql.bind.windows.json).

## Integração SQL tipada gerenciada (T03)

```powershell
# Hook nativo SQLite, serviço compartilhado e TCP/HTTP/REST com gzip.
./scripts/test-hbbridge-typed-sql.ps1

# Adicionar o perfil MSSQL privado escolhido explicitamente.
./scripts/test-hbbridge-typed-sql.ps1 -Config '<ini-privado>' -Profile '<alias>'
```

O executor prepara as bibliotecas gerenciadas ODBC, SQLite e HTTP, compila a
fixture versionada e executa processo filho próprio com orçamento padrão de
120 segundos (`-TimeoutSeconds` aceita 10..600). `-Config` e `-Profile` são
opcionais juntos; selecionam INI/perfil privado existente sem copiar credenciais
para o relatório. SQLite usa arquivo descartável de fixture; consultas MSSQL usam entradas
explícitas sem alterar tabelas da aplicação.

`-Serve` executa os checks de integração e então mantém novos listeners TCP/HTTP
loopback próprios para consumidor externo. `-ServeSeconds` aceita 1..1800,
com padrão 120, limitando a fase servidora separadamente do orçamento inicial
de testes `-TimeoutSeconds`. Informe INI/perfil MSSQL privado explícito para
o teste de apresentação AppServer. Quando pronto, o runner imprime o caminho
local de `endpoints.json`, contendo perfil, portas e token HTTP privado.
Não exporte esse arquivo como evidência de aceite. Encerre criando
`stop.request` naquela nova pasta ou aguarde o prazo servidor expirar.
A fixture registra `serve.result.json` e verifica liberação de listeners e
leases SQL próprios. Veja os [comandos do consumidor AppServer](#apresentação-nativa-protheus-isolada).

A rodada Windows de 2026-10-25 passou em **133 verificações, sem falhas**:
111 nativas SDD/serviço compartilhado e 22 TCP/HTTP/REST com gzip entre SQLite e
MSSQL. Verifica saída compartilhada em hash por `RDDI_EXECUTE`, compatibilidade
de strings/Query, bindings nativos, NULL distinto de vazio/ausente, int64/decimal
exatos, UTF-8/NUL, metadados fixos, paginação/contagem, rejeições explícitas e
recuperação. Os checks reais de transporte usam consumidores Harbour, sem
AppServer. Apresentação nativa Protheus, Linux e outras combinações de driver
exigem homologação separada.

A saída nova `tmp/typed-sql-<id>/` contém `build.log`, `console.log`,
`result.json` e `receipt.json` com identidades de fontes/binário/dependências.
Todos são descartáveis; a reprodução usa fontes/scripts mantidos e dependências
gerenciadas. O executor rejeita totais de checks inconsistentes, checks não
booleanos/com falha, ausência de execução SQLite ou perfil MSSQL solicitado
que não tenha sido exercitado.

`prepare-odbc.ps1` também chama `prepare-sqlite.ps1` antes de reaproveitar o
cache. Os recibos dos dois conectores gerenciados identificam helpers nativos,
patch e biblioteca; alterar helpers provoca recompilação. Veja
[dependências](../docs/dependencies.pt-BR.md) e
[escopo dos conectores](../docs/typed-sql-connectors.pt-BR.md). As provas T02
acima continuam evidências isoladas e não substituem estes checks de integração.

## Referência MSSQL de tempo e memória

`benchmark-hbbridge-mssql.ps1 -Config C:/tmp/hbBridge.ini -Profile MSSQL/pData`
compila a fixture M08 somente de leitura e executa processos filhos separados,
em sequência, para Harbour local, TCP e HTTP. O padrão é 1000 linhas, páginas
de 100, dois aquecimentos e cinco varreduras completas medidas; concorrência um.
`-ODBCPooling off|driver` seleciona a política do processo nativo; padrão `off`.
O executor grava `benchmark.json`, `result.json` por rota, logs sanitizados
e amostras de memória do SO com tempos em `tmp/mssql-benchmark-*` isolado.
Consultar [a metodologia](../docs/benchmarking.pt-BR.md) para o escopo das medidas
e o host opcional `-Route http -ServeSeconds 600` destinado ao
[consumidor AppServer](../src/tlpp/tests/protheus/hbbridge.benchmark.test/README.pt-BR.md).

## Comparação Protheus e addon de benchmark opcionais

O [benchmark visual](../src/tlpp/tests/protheus/hbbridge.benchmark.test/README.pt-BR.md)
compara hbBridge TCP/HTTP com Protheus StartJob/REST e escopos separados de
addon Harbour/Protheus em um job único. Todos usam a fixture paginada fixa.
StartJob por página inclui preparação do worker/ambiente
por página; não simula tráfego TCP pela rede. O addon executa varreduras completas
dentro do hbBridge e retorna apenas estatísticas. Suas medidas internas excluem
transporte e carga do HRB; a chamada `ADDON.Execute` única possui tempo decorrido
informado separadamente.

Compilar e testar o addon com a toolchain gerenciada:

```powershell
./scripts/build-hbbridge-benchmark-addon.ps1
./scripts/test-hbbridge-benchmark-addon.ps1
```

O build grava `addons/examples/hbbridgebenchmarkaddon.hrb`; `-Output` seleciona
outro destino. O teste compila HRBs e fixture nativa isolados, compara o SQL dos
fontes TLPP/addon/teste e exercita despacho simulado, erros, recarga e limpeza.
O log fica em `tmp/benchmark-addon-tests-<id>/results.log`. Exige dependências
gerenciadas de build ODBC/Zig, mas não credenciais MSSQL reais. Esses checks
não homologam AppServer nem MSSQL real.

Para manter fixture isolada do addon recém-compilada disponível ao cliente
TLPP real, executar em outro terminal:

```powershell
./scripts/test-hbbridge-benchmark-addon.ps1 -Serve -ServeSeconds 1800 `
    -Config C:/tmp/hbbridge.ini -Profile MSSQL/pData
```

`-Config` e `-Profile` são opcionais juntos e exigem `-Serve`. Com eles, o host
carrega somente o perfil MSSQL explicitamente escolhido no registro nativo.
Imprime porta TCP dinâmica de loopback, perfil/backend e módulo
`hbbridgebenchmarkaddon.hrb`; não altera INI privado nem serviço existente.
Sem o par, serve mode usa SQL simulado. O servidor próprio termina em
`-ServeSeconds` (1..3600) ou ao encontrar `stop.request` na pasta da execução
impressa. Preparação/compilação ficam fora do tempo servido e das amostras.

Com perfil privado, a fixture configura `[SQL] ODBCPooling` privado antes
das conexões e imprime o campo ready `odbcPooling` efetivo. Sem esse perfil,
o mock mantém política off. Demais opções runtime não são reproduzidas
implicitamente. A fixture anterior de 255 iterações usou pooling off; registrar
o ready atual sem presumir equivalência com a rodada anterior/implantação.
É host de correção/reprodução, sem constituir implantação de desempenho equivalente. Veja o
[roteiro do cliente/módulo e rodadas 255/500](../src/tlpp/tests/protheus/hbbridge.benchmark.test/README.pt-BR.md#reproduzir-o-host-do-addon-com-perfil-mssql-explícito).

Mesclar o [fragmento REST](../config/hbbridge.benchmark.rest.pt-BR.md) à instalação
existente: reutilizar um listener REST 2.0 com `Security=1`, sua configuração TLS
e preparação de empresa/filial definida na implantação. `BenchmarkProtheusURL`
inclui `/rest`; `BenchmarkProtheusCredentialSection` seleciona seção existente
no servidor com `UserName`/`Password`. Protheus valida as credenciais HTTP Basic
antes do endpoint. Não exige listener adicional nem bearer próprio do benchmark.
A entrada do navegador não fornece SQL, contexto ERP ou credenciais; o contexto
e a configuração confiáveis do AppServer fornecem esses dados.
`BenchmarkAddonModule` seleciona o HRB instalado e `BenchmarkAddonTimeoutSeconds`
define o prazo de chamadas antigas. A nova política explícita fornece o prazo
efetivo da chamada completa em seu lugar. Checks automáticos atuais e aceite
manual pendente estão no [WIP](../WIP.pt-BR.md), separadamente da referência
M08 histórica homologada.
