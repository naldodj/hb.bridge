# Testes

[English](README.md)

Os fontes Protheus permanecem sob `src/tlpp`; agora os testes estão agrupados
em subpastas de [tests/protheus](../src/tlpp/tests/protheus):

| Pasta | Entradas ou suporte |
| --- | --- |
| `hbbridge.connection.test/` | `U_HBBridgeConnectionTest`. |
| `hbbridge.config.test/` | `U_HBBridgeConfigTest`. |
| `hbbridge.dataset.test/` | `U_HBBridgeDataSetTest` e seu cliente simulado. |
| `hbbridge.failure.test/` | Testes de falha/recuperação SQL real TCP/HTTP e `U_HBBridgeFailureCLI`; [guia](../src/tlpp/tests/protheus/hbbridge.failure.test/README.pt-BR.md). |
| `hbbridge.http.test/` | Teste HTTP comum e wrappers explícitos MSSQL/SQLite. |
| `hbbridge.http.table.test/` | Exemplos FWWebEx fixture/SX5 e mock `U_HBBridgeHTTPTableTest`: validação manual confirmada, 71 checks/zero falhas em 2026-10-13; [evidências](../src/tlpp/tests/protheus/hbbridge.http.table.test/README.pt-BR.md). |
| `hbbridge.query.test/` | Teste Query comum, wrapper SQLite e wrapper `FWGetTopInfo()` no chamador. |
| `hbbridge.browse.data.test/` | Exemplo de browse genérico e exemplos SX5/SRA preparados pelo chamador. |

Compile os fontes aninhados com suas classes de produto e includes. Mover um
fonte não altera sua entrada `U_` publicada nem homologa os novos exemplos.

[hbbridge.connection.test.tlpp](../src/tlpp/tests/protheus/hbbridge.connection.test/hbbridge.connection.test.tlpp) é o teste de integração Protheus do produto. Com o
servidor escutando em `0.0.0.0:1512`, configure o cliente local para
`127.0.0.1:1512`. Na nova revisão, argumentos omitidos vêm de `[hbBridge]`
no INI selecionado pelo AppServer, com esses valores como fallback; o
[template cliente](../config/examples/protheus-appserver.ini) deve acompanhar
o destino do servidor. Compile toda a arvore `src/tlpp/` no Protheus e execute
`U_HBBridgeConnectionTest()` ou informe host/porta/timeout como argumentos.
Essa entrada mantém a declaração `procedure U_HBBridgeConnectionTest`.
O pré-processador também gera o símbolo `U_` a partir de `User Function`;
não é necessário converter a declaração existente.

O teste chama `Health`, `Echo` e `ADDON.Execute` com
`module = "examples/hbbridgesampleaddon.hb"` e os parâmetros do módulo (macro
`__IS_THE_ADDONS_EXECUTION_ENABLED__` habilitada) pelo cliente `HBBridgeClient`.
As chamadas usam JSON no frame `HBBRIDGE/1`, com compressao e descompressao de strings nos
dois sentidos: `GzStrComp`/`GzStrDecomp` no Protheus e
compressor/decoder gzip incrementais pela API C no Harbour. O frame completo e comprimido;
o tamanho declarado no cabecalho corresponde aos bytes do JSON
descomprimido. O contrato ativo é único: `HBBRIDGE/1`, JSON e gzip, com
constantes compartilhadas em [includes/hbbridge.h](../includes/hbbridge.h).

Antes do RPC, verifica os métodos estáticos de `HBBridge.Client.HBBridgeTime`
em [hbbridge.time.tlpp](../src/tlpp/hbbridge.time.tlpp): diferença
de `TimeCounter()` após `Sleep(1000)`, unidade normalizada, leituras sem regressão
e aritmética do prazo. O fator Unix × 1000 trata a diferença reproduzida na
[issue #12](https://github.com/naldodj/totvs-protheus-open-issues/issues/12).
Uma escala incompatível interrompe o teste e registra os valores brutos,
inclusive se novos builds alterarem a unidade do contador.

O teste verifica `success` e compara integralmente a mensagem e os 200.000
caracteres `X` de `largePayload`. O Marco 2 acrescenta um segundo Echo com
ASCII variado e exige previamente gzip maior que 65.535 bytes. O conteúdo
retornado também é comparado integralmente. Os logs resumem resultado e
tamanho. A execução manual foi confirmada em 2026-10-03: Health,
ADDON.Execute e os dois Echo passaram, com 200.000 bytes idênticos e gzip
de requisição de 152.964 bytes no caso variado. Timeout/falhas e a medição
detalhada do relógio ficaram pendentes naquela rodada. No novo relato manual
registrado na sessão de 2026-10-04, foram reconfirmados Health,
ADDON.Execute e os dois Echo, com os mesmos tamanhos e conteúdo idêntico.
O teste do relógio também passou: `Unix=false`, delta bruto `1097.692700`,
tempo normalizado `1097.773500 ms` após `Sleep(1000)` e `result=OK`.
Isso aceita a medição normalizada no Windows alvo; outras plataformas e
timeout/falhas provocados continuam na matriz de homologação.
Em 2026-10-07 às 16:14:31, thread 27084, foram reconfirmados Health,
ADDON e os dois Echo exatos de 200.000 bytes, com gzip de 152.964 bytes.
Relógio `OK`: `Unix=false`, delta bruto `1089.987500`, normalizado
`1090.088100 ms` após `Sleep(1000)`.

O resultado aparece no console do Protheus. `Health` ainda depende da
biblioteca Zig demonstrativa do build atual. A execução do teste TLPP
no AppServer alvo foi confirmada pelos relatos manuais; essa
execução não integra o runner Harbour.

## SQL e páginas

O [teste HTTP TLPP](../src/tlpp/tests/protheus/hbbridge.http.test/hbbridge.http.test.tlpp),
`U_HBBridgeHTTPTest`, usa `HBBridgeHTTPClient` para GET Health/descoberta,
POST Health/Echo/addon, serviços inexistentes/proibidos, bearer inválido e
recuperação. Reaproveita o dataset para páginas SQL opcionais.
Veja [configuração e chamadas](../examples/http/README.pt-BR.md).
Foram homologados manualmente **13 checks** em 2026-10-07, thread 25672. As rodadas
posteriores passaram nos 13: thread 27296 (programa às 16:10:40, teste
16:10:44–16:10:45) e thread 25456 (programa às 16:15:02, teste
16:15:03–16:15:04), cada uma em um segundo. Horários locais de São Paulo.
Essa prova AppServer é separada do runner Harbour. Os relatos HTTP de
2026-10-07 não identificam perfil/backend SQL nem comprovam HTTPS/Unicode
mais amplo; as rodadas identificadas de 2026-10-08 estão registradas abaixo.

[hbbridge.query.test.tlpp](../src/tlpp/tests/protheus/hbbridge.query.test/hbbridge.query.test.tlpp)
acrescenta `U_HBBridgeQueryTest`: campos por nome, decimal, EOF, fechamento,
consulta vazia/inválida e recuperação, além de primeira/próxima/última página,
IDs com lacunas e parâmetros de paginação inválidos. Compile toda a árvore
`src/tlpp/` quando houver fontes novos. Encerre o servidor anterior com Ctrl+Q
e execute da raiz `.\examples\sql\run.ps1` para usar `sqlite_demo`, padrão
da entrada. O [launcher SQL](../examples/sql/README.pt-BR.md) valida o perfil e
informa a chamada de teste; a execução ocorre separadamente no AppServer.
SQLite foi homologado manualmente no AppServer em 04/10/2026 às 00:40:06,
thread `41228`, perfil `sqlite_demo`, com todos os 29 checks verdadeiros.
Na nova rodada manual registrada na sessão de 2026-10-04, foram reconfirmados
os 29 checks verdadeiros no perfil `sqlite_demo`, junto do novo teste de
configuração cliente. Em 2026-10-07 às 16:13:33, thread 27136, o log
reconfirmou todos os 29 checks verdadeiros com `profile=sqlite_demo`.
Naquela rodada MSSQL real ainda estava pendente; o aceite nativo e TCP
posterior, de 2026-10-08, está registrado abaixo.

Com a seção `[hbBridge]` do AppServer alinhada ao servidor, abra
[U_HBBridgeQueryTest no WebApp](https://localhost:4321/webapp/?p=U_HBBridgeQueryTest&e=PROTHEUS).
Para MSSQL, configure um DSN ODBC e use
`.\examples\sql\run.ps1 -Config config/examples/mssql.ini -Profile mssql_demo`,
seguido de `U_HBBridgeQueryTest("mssql_demo", "127.0.0.1", 1512, 30000)` no
Protheus. O link sem argumentos usa `SQLProfile`, `Host` e `Port` dessa seção
cliente, com destino padrão `127.0.0.1:1512`. `SQLProfile` é opcional e vazio
por padrão; configure-o ou informe o alias explicitamente. Sem alias, o
teste retorna `PROFILE_REQUIRED` antes do acesso à rede. `sqlite_demo` é
somente o perfil do exemplo. Alinhe a seção para
outros perfis/portas ou use a chamada explícita mostrada pelo launcher.
Alterar apenas o perfil no host não exige recompilar o TLPP já atualizado.
Cada consulta/dataset escolhe um alias opaco, como `MSSQL/pData`, sem inferir
tenant, empresa, filial/xFilial ou tabelas; essas regras pertencem ao Protheus.
Um nome `oracle/alias` não habilita um conector Oracle, ainda futuro.
Chamadas com os quatro argumentos existentes executam as consultas de
constantes. O quinto argumento opcional `lRunERPExamples` tem padrão falso;
informe verdadeiro para habilitar explicitamente os exemplos locais SX5/SRA/SX3
no perfil `MSSQL/pData`, depois da fixture:

```advpl
U_HBBridgeQueryTest("MSSQL/pData", "127.0.0.1", 1512, 30000, .T.)
```

Esses exemplos usam nomes físicos da instalação e imprimem valores dos campos.
Protheus prepara SQL e formatação do dicionário; a ponte não passa a resolver
dicionário ou regras de negócio do Protheus. Os exemplos exigem homologação
manual separada e entradas preparadas para a instalação.
INI e JSON são aceitos; para INI, recompile o produto que fornece
`--config-info`, usado pelo launcher para validar metadados sem iniciar o host.

`SERVICE_NOT_FOUND` indica que o processo conectado não registrou o serviço;
sem perfis no arquivo selecionado ou no `hbbridge.ini` junto ao binário,
`sqlProfiles` permanece vazio. Inicie o exemplo SQL
e confira a porta antes de repetir o teste. Um serviço já registrado com
perfil desconhecido retorna `PROFILE_NOT_FOUND`.

[hbbridge.query.test.hb](integration/harbour/hbbridge.query.test.hb) usa um SQLite
real em arquivo isolado, com perfis, valores, metadados, conexão/área restauradas,
erros sanitizados e 16 chamadas concorrentes. Verifica páginas no SGBD,
ordenação composta/descendente, lacunas, linha extra, página cheia/parcial/vazia,
ordinais representáveis, aliases duplicados/reservados e o mesmo resultado por
NETIO e TCP/JSON. O contrato está em [Marco 3](../docs/milestone3-sql.pt-BR.md).

Runner completo anterior em 2026-10-04: **412 verificações, zero falhas, sem skips**,
SQLite **3.53.4**, Harbour/Zig Windows x64. Resultado em
`tmp/tests-236f1241c1174cf4b193c22f6eedb6e0/results.log`.
Inclui 26 verificações INI e três rejeições adicionais de driver/direção SQL inválidos, além
das 383 anteriores. O INI exercita equivalência com JSON, precedência,
BOM/CRLF, pontuação de senhas/ODBC, caminhos e rejeição de entradas inválidas.
O registro inicial de build TLPP interrompido é histórico: o aceite SQLite
posterior foi informado em relato manual. A nova configuração cliente `[hbBridge]`
também passou na rodada manual posterior descrita abaixo; esses testes no AppServer
não foram executados pela automação local.

A validação gerenciada posterior de 2026-10-04 passou em **416 verificações,
zero falhas e nenhum skip**, com o Harbour/Zig do próprio projeto. Log:
`tmp/tests-d1b829ff332c414f816a6e70748152d1/results.log`. Foram acrescentados
dois checks INI e dois de seleção explícita/case-sensitive de aliases SQL.
Esse resultado precede os ajustes PascalCase/HTTP de 2026-10-06.

[hbbridge.config.test.tlpp](../src/tlpp/tests/protheus/hbbridge.config.test/hbbridge.config.test.tlpp)
oferece `U_HBBridgeConfigTest()` para defaults, INI, argumentos prioritários,
destino inválido, números malformados, budgets zero/negativo/fracionário e
capacidade nativa de chunk. A leitura do INI ativo também é verificada;
complemente com Health/Query sem argumentos para confirmar o destino efetivo.
Foi informada execução manual bem-sucedida desse teste na sessão de 2026-10-04,
com todos os **13 checks verdadeiros**: `missingSectionDefaults`, `iniValues`,
`wildcardIsNotDestination`, `invalidIniNumber`, `explicitOverridesInvalidIni`,
`explicitZeroDisablesBudget`, `invalidExplicitPort`, `invalidTimeout`,
`nativeChunkCapacity`, `negativeBudget`, `fractionalBudget`,
`budgetBeyondSocketChunk` e `activeAppServerIni`.
O mesmo relato confirmou relógio, Health, ADDON, Echo e Query SQLite.
Não foram informados horário de execução, thread, hash do build, argumentos
das chamadas ou log de compilação. A leitura do INI ativo foi aceita; esse
relato não demonstra conexão com destino diferente dos padrões.

A tentativa local anterior via `build-totvs.cmd`, interrompida antes do
compilador ao parar os processos TOTVS, permanece como histórico em
`tmp/ini-totvs-build.log`. O aceite manual posterior supera a pendência de
execução dos novos testes. A [matriz](../docs/acceptance.pt-BR.md) distingue esse
resultado dos cenários ainda não homologados. A versão revisada acrescenta
`explicitProfile`, `noForcedProfile` e `invalidProfile`, totalizando 16 checks.
Em 2026-10-07 às 16:14:06, thread 30596, todos os 16 passaram. Foi
informada recompilação após a migração para `.hb`; os quatro testes Query,
Config, Connection e HTTP aceitam a regressão das classes/namespace TLPP
renomeados e dos novos caminhos de addon `.hb` no Windows alvo.
O log fornece horários/threads; não foram fornecidos log real do compilador,
hashes, argumentos ou destino efetivo. Esses testes não foram executados pela automação local.
Em 2026-10-08, o relato manual AppServer registrou **29 checks TCP
MSSQL aprovados**, thread 660, e **29 checks TCP SQLite aprovados**, thread
3192. As entradas de conveniência `U_HBBridgeQueryTestMSSQL()` e
`U_HBBridgeQueryTestSQLite()` selecionam aliases locais de exemplo; o cliente
genérico continua sem perfil forçado. Esse resultado manual é separado
dos 92 checks MSSQL nativos abaixo.

Depois, execuções manuais AppServer passaram nos **13 checks HTTP de cada backend**, em 2026-10-08:
`U_HBBridgeHTTPTestMSSQL`, thread 25976, início do programa 10:33:32, teste
10:33:33–10:33:34 (um segundo); `U_HBBridgeHTTPTestSQLite`, thread 9916,
início do programa 10:34:06, teste 10:34:07 (zero segundos exibidos). Horários
de São Paulo. Ambos incluem primeira/próxima página e valores do dataset
comum; os padrões das entradas selecionam `MSSQL/pData` e `sqlite_demo`.
São execuções manuais AppServer, separadas da automação nativa. Transcrição:
`tmp/protheus-http-mssql-sqlite-operator-20261008.log`.
Veja [homologação](../docs/acceptance.pt-BR.md). O aceite do mock dataset de D02
foi concluído em 2026-10-13; a integridade UTF-8/FLOAT de D03 permanece aberta
no [WIP](../WIP.pt-BR.md); M06, falhas controladas/recuperação independentes,
tem aceite separado de 2026-10-14 abaixo.
Esses relatos não implicam nova rodada nativa.

Uma prova posterior de constantes somente para leitura mostrou que
`CAST(123.4567 AS FLOAT)` continuou fracionário nativamente, mas virou `123`
no JSON; `DECIMAL(15,4)` virou `123.4567` e `DECIMAL(16,2)` virou `123.46`.
Os 92 checks nativos não cobriam esse caso de FLOAT sem CAST decimal no JSON.
O TCP também não seleciona `UTF8EX` como o HTTP e usa CP437 por padrão.
Os resultados das fixtures existentes não certificam precisão arbitrária nem
acentos TCP. As correções e os checks de equivalência dos transportes continuam
pendentes; veja [a análise](../docs/dataset.pt-BR.md).

Continuam pendentes HTTPS, identidades integrada/de serviço, destino
alternativo com argumentos omitidos, Linux e os cenários de falha/timeout de rede,
precisão/wrap, capacidades e tipos ampliados da [matriz](../docs/acceptance.pt-BR.md).

## Checks TLPP isolados do dataset

O [catálogo de consumidores](../examples/protheus/README.pt-BR.md) reúne os
grupos reorganizados, incluindo `hbbridge.helper.test/U_HBBridgeHelperTest`
(12 checks puros homologados), o mock dataset homologado de 67 checks e browses SRA/SX5.
`build-totvs.cmd` fornece lista recursiva explícita dos fontes, incluindo
os filhos dos diretórios pontuados.

Compile toda a árvore `src/tlpp`, incluindo os novos
[HBBridgeDataSetMockClient](../src/tlpp/tests/protheus/hbbridge.dataset.test/hbbridge.dataset.mock.client.tlpp)
e [U_HBBridgeDataSetTest](../src/tlpp/tests/protheus/hbbridge.dataset.test/hbbridge.dataset.test.tlpp),
e execute `U_HBBridgeDataSetTest()` ou a
[entrada WebApp](https://localhost:4321/webapp/?p=U_HBBridgeDataSetTest&e=PROTHEUS).
Não requer listener hbBridge, perfil SQL, credenciais nem tabela ERP.

Execução manual AppServer em 2026-10-13 às 17:56:23, horário de São Paulo,
thread 32332, passou em **67 checks, zero falhas e 31 chamadas simuladas**.
Todos os checks por chave foram verdadeiros; o resultado final foi
`OK; checks=67; mock calls=31`.
O teste cobre `MoreToRead()` entre páginas; verificações repetidas sem consumir
linhas; `Eof()`/`Skip()` locais à página preservados; cópias independentes de
`Header()`/`FieldInfo()`; ordem de colunas com `FieldCount()`/
`FieldName()`; cópia em `GetRow()`; estado vazio/fechado, metadados inválidos
e falha/recuperação de página. Também cobre preservação/troca do perfil,
cópias da página, navegação para trás e totais de linhas/páginas validados,
desconhecidos, vazios e inválidos. A tentativa de compilação local em
2026-10-08 retornou exit 1, `COMPILEERROR-300 Failed to open repository`, pois
`custom.rpo` estava em uso; total/sucessos/erros foram `0/0/0`, sem compilação dos
fontes. Log: `tmp/totvs-compile.log`. O AppServer ativo não foi parado. Aquela
tentativa se refere à versão anterior de 45 checks/17 chamadas. Na revisão de
2026-10-12, a fixture revisada de 67 checks/31 chamadas e os 12 checks de helpers
estavam preparados, com execução pendente. As rodadas manuais de 2026-10-13
encerram essa pendência de execução. O check histórico `dsStructDefensiveAlias`
usa uma cópia de `Header()` e `FieldInfo()`; `Header()` continua sendo a API
canônica, com `DSStruct()` removido.

[U_HBBridgeHelperTest](../src/tlpp/tests/protheus/hbbridge.helper.test/hbbridge.helper.test.tlpp)
passou em **12 checks puros, zero falhas**, em 2026-10-13 às 17:56:45, horário
de São Paulo, thread 28300. Todos os checks por chave foram verdadeiros;
o resultado final foi `OK; checks=12`. A cobertura inclui prefixação de alias
SQL com literais/comentários, substituições de texto e expressões tipadas de
filtros customizados.

Esses resultados manuais AppServer homologam o escopo de mocks dataset/helpers
de D02. Não exercitam rede, banco nem dados ERP. O trabalho de integridade
UTF-8/FLOAT ampliada de D03 permanece aberta; M06, falhas/recuperação
independentes, tem aceite runtime separado abaixo. Continue as tarefas
restantes no [WIP](../WIP.pt-BR.md). Veja [API do dataset
e falhas de integridade](../docs/dataset.pt-BR.md) e
[homologação](../docs/acceptance.pt-BR.md).

## Regressoes Harbour existentes

A fixture de addon mantém 12 HRBs FORCELOCAL ativos atrás de uma barreira
e verifica owner/id e counterBefore+1. Recargas sequenciais podem reciclar
STATICs; exigir contador sempre um seria testar uma premissa incorreta.
A contraprova deliberada com um handle e 12 threads rejeitou 11 respostas.
Addons inicializam estado por chamada explicitamente; veja
[semântica HRB](../docs/milestone1.pt-BR.md#estado-hrb-e-propriedade-do-addon).

[Os testes HTTP](integration/harbour/hbbridge.http.test.hb) usam hbhttpd nativo,
rotas autenticadas, separação de bearer/admin, Health/Echo/addon/SQL do
registro comum, equivalência NETIO, corpo JSON/erros, contextos concorrentes,
status web sem segredos e parada/reinício/rollback. As contagens históricas
abaixo antecedem esse adaptador; seu aceite é registrado separadamente em
[homologação](../docs/acceptance.pt-BR.md). Configuração e dependências estão
no [guia HTTP](../docs/http.pt-BR.md).

[integration/harbour/hbbridge.server.test.hb](integration/harbour/hbbridge.server.test.hb), com entrada `MTTests`, contem
verificacoes automatizadas de concorrencia, clientes ociosos, erros, limite de
workers e parada. Inclui `Echo` e resposta de erro com `HBBRIDGE/1`,
conferindo o contrato do servidor real. Assinaturas diferentes, JSON sem
enquadramento e wrappers de compressão diferentes de gzip são rejeitados.

A suite tambem exercita `Health` pela ponte C/Zig e a compilacao em memoria
do addon PRG de exemplo. Os clientes de teste usam `127.0.0.1` e as chamadas
das fixtures apontam explicitamente para os arquivos `.hrb` preparados.

Na raiz do projeto, com PowerShell 7 e Git, resolva as dependências gerenciadas:

```powershell
./scripts/bootstrap.ps1
./scripts/test-hbbridge.ps1
```

O [runner](../scripts/test-hbbridge.ps1) compila a biblioteca Zig, prepara as
fixtures em uma pasta exclusiva sob `tmp/` e compila
[hbbridge.server.test.hbp](integration/harbour/hbbridge.server.test.hbp). Esse projeto compartilha
[hbbridge.hbm](../hbbridge.hbm) com o produto, sem copiar os fontes do servidor.
O runner executa os testes com os addons isolados, registra `results.log` e
devolve o codigo de saida da suite. Nao substitui nem encerra `out/hbbridge.exe`.
Executada manualmente sem fixtures, a suite ainda informa `SKIP`; o runner
prepara ambas antes da execucao e a validacao registrada nao teve skips.

Validacao de 2026-10-01: **74 verificacoes, zero falhas**, incluindo HRBs de erro
e isolamento concorrente. O [registro histórico da reorganização](../docs/reorganization.pt-BR.md)
explica as correcoes de preparo da suite e a referencia anterior com 72 checks.
O teste TLPP real depende do AppServer e nao foi executado nessa validacao
automatizada. Recompilacao e o teste do Marco 1 OK em 2026-10-03;
os logs registram 3 fontes compilados sem erros, Health/ADDON/Echo
com sucesso e retorno integral do Echo. Ver [matriz](../docs/acceptance.pt-BR.md).

O runner tambem executa [configuracao](unit/hbbridge.config.test.hb),
[contrato/registro](contract/hbbridge.services.test.hb) e [NETIO nativo](integration/harbour/hbbridge.netio.test.hb),
usando o mesmo host/nucleo do produto. A integracao verifica argumentos/resultados
nativos, core, descoberta, addons, VF IO binario, admin separado, filtros RPC,
credenciais e parada/reinicio/rollback. As portas NETIO/admin dos testes sao
selecionadas entre portas livres; nao usa nem para os endpoints da instalacao.

Regressão local de falhas/recuperação dos transportes em 2026-10-13 passou em
**615 checks, zero falhas, sem skips**, incluindo 32 novas asserções de falhas
SQL/perfil/conexão e recuperação imediata por NETIO, TCP e HTTP RPC/REST.
Fixtures usam SQLite isolado e DSNs sintéticos ausentes; não homologa queda
MSSQL real, timeout SQL nativo nem AppServer. Veja [escopo/log](../docs/acceptance.pt-BR.md#falhas-e-recuperação-sql-nos-transportes-em-2026-10-13).

A regressão gerenciada de 2026-10-14 passou em **636 checks, zero falhas e
nenhum skip**, acrescentando 21 asserções das opções de timeout MSSQL nativo:
`tmp/tests-12c300f8399948e3bb3c20ee13eacc2d/results.log`. A cobertura de falhas
MSSQL reais usa a rota opt-in separada abaixo.

## Homologação MSSQL real do núcleo opt-in

Prepare um perfil privado com as [chaves de credenciais](../docs/configuration.pt-BR.md)
e execute:

```powershell
./scripts/test-hbbridge-mssql.ps1 -Config C:/tmp/hbBridge.ini -Profile MSSQL/pData
```

O [alvo MSSQL](integration/harbour/hbbridge.mssql.test.hbp) usa os componentes
compartilhados do produto e um alias explícito. Não abre listeners do host nem
substitui o executável ativo. Fixtures de constantes somente de leitura cobrem
resultados nomeados, tipos nativos/nulos/Unicode, páginas, recuperação,
restauração da workarea/conexão do chamador, quatro chamadas concorrentes e
três execuções de referência com 1000 linhas. Tipos e valores esperados são
declarados antes das asserções; representações incompatíveis falham, sem
conversão silenciosa para obter aprovação.

Saída 2 indica pré-requisito ausente/inválido, incluindo perfil inexistente ou
falha na conexão inicial; saída 1 indica falha de asserção/runtime. Somente a
saída 0 após executar as verificações homologa essa rota do núcleo. Os logs em
`tmp/mssql-tests-<id>/results.log` omitem strings de conexão e erros brutos do
driver. Essa rota é separada da suíte SQLite padrão e dos 29 checks TCP
Protheus. Compilação ou verificação de pré-requisito não homologa valores
MSSQL nem execução AppServer/HTTP.

A execução de 2026-10-08 passou em **92 checks, zero falhas e nenhum skip**
com SQL Server `16.0.1200.5`, banco `pData`, ODBC Driver `18.6.2.1`, Windows x64
e Harbour `UTF8EX`, autenticação SQL e alias `MSSQL/pData`. Log:
`tmp/mssql-tests-b3d676f0daaf470a97af605a98a9681c/results.log`.
O [patch SDDODBC](../config/patches/sddodbc.patch) preparado pelo build cobre
leitura incremental de `SQL_NO_TOTAL`, flag de campo binário e pares
substitutos UTF-16 em UTF-8. As fixtures preservam texto/binário longos, NULs
embutidos, valores vazios e NULLs. Os buffers de chunks não impõem teto total
de payload da aplicação. A referência de 1000 linhas executou três vezes em
31/32/31 ms, total 94 ms, concorrência um, sem medir memória. É uma referência
local, não uma garantia de desempenho. Veja [homologação](../docs/acceptance.pt-BR.md)
para o escopo preciso e os cenários restantes.

A repetição de 2026-10-14 passou em **92 checks, zero falhas, nenhum skip e
saída 0**, com SQL Server `16.0.1210.3`, banco `pData` e alias explícito
`MSSQL/pData`: `tmp/mssql-tests-c49ac62b333d4c9d8e94aabf5134cb1b/results.log`.
Essa repetição confirma a rota de núcleo existente após as mudanças de
timeout nativo; não acrescenta aceite de FLOAT bruto no JSON ou Unicode
TCP em geral.

## Falhas MSSQL reais e recuperação opt-in

```powershell
./scripts/test-hbbridge-mssql.ps1 -Config C:/tmp/hbBridge.ini -Profile MSSQL/pData `
    -Failures -FailureODBCDriver 'ODBC Driver 18 for SQL Server'
```

O [alvo de falhas](integration/harbour/hbbridge.mssql.failure.test.hbp)
verifica SQL inválido, perfis desconhecidos, conexão recusada e timeout
nativo de instrução pelo núcleo, NETIO, TCP e HTTP. Um SELECT de constante
bem-sucedido sucede cada falha. Também compara timeout explicitamente zero
com timeout nativo de 1 segundo usando WAITFOR limitado a 4 segundos.
Alias funcional e driver instalado são pré-requisitos explícitos; segredos
permanecem no arquivo privado. O destino recusado reserva uma porta de
loopback sem escuta e usa credenciais fictícias. Não para o serviço SQL
Server nem altera tabelas ERP.

Em 2026-10-14 essa rota passou em **46 checks, zero falhas e nenhum skip**:
`tmp/mssql-tests-e22aaf15b69e44ad806a5316060438ec/results.log`.
Essa rodada nativa é separada da execução Protheus. Acrescente `-Serve`
para manter o host isolado disponível por 600 segundos após a aprovação
dos checks nativos. O runner exibe as portas de teste; o token HTTP da
fixture é `m06-http-test-only`. O [guia de falhas Protheus](../src/tlpp/tests/protheus/hbbridge.failure.test/README.pt-BR.md)
documenta compilação, chamadas diretas e flags nomeadas de
`U_HBBridgeFailureCLI`. A execução automatizada via CLI AppServer em
2026-10-14 passou em **38 checks TCP** (08:28:56–08:29:12 de São Paulo,
thread 29120) e **51 checks HTTP** (08:28:13–08:28:29, thread 21392), ambos
com zero falhas e saída 0, incluindo o perfil opcional de timeout. Logs:
`tmp/m06-protheus-tcp-clean-output-20261014.log` e
`tmp/m06-protheus-http-output-20261014.log`. O compilador havia registrado
30 fontes com sucesso/zero erros às 08:23:38, thread 32272:
`tmp/totvs-compile.log`. O RPO real compilado foi executado com INI AppServer
privado separado; esse é o aceite runtime via `-run`, sem homologação manual
de SmartClient/WebApp ou interface gráfica. Os checks reais do dataset
verificam estado limpo e `MoreToRead()` após a falha; contagens/ausência de
novas tentativas têm aceite separado no mock dataset de 67 checks.
Timeouts nativos se aplicam por instrução, sem
cancelamento explícito no servidor ou prazo SQL compartilhado da requisição.

## Proximas verificacoes

- Validar chamadas sequenciais persistentes antes de pool e multiplexacao;
  verificar fragmentacao/coalescencia, desconexao e ausencia de reenvio indevido.
- Testar isolamento por chamada e propriedade/expiracao dos recursos de sessao,
  incluindo uso por tenant incorreto e limpeza apos falha.
- Homologar TLS/JWT no AppServer real; manter gRPC/Smartlink e AMQP como provas
  opcionais com criterios em [Transportes, sessoes e seguranca](../docs/transports-sessions-security.pt-BR.md).
- Comparar integralmente os dados recebidos, incluindo acentos, caracteres
  multibyte, valores nulos e estruturas JSON aninhadas.
- Testar dados pouco compressiveis, fragmentacao TCP e envios parciais.
- Homologar no AppServer timeout de socket, falhas na conexão ao listener e envios parciais forçados,
  incluindo os retornos de `Receive`/`GetError`; o fluxo normal já foi aceito.
- Verificar a configuração cliente com destino/porta diferentes dos padrões
  e ampliar MSSQL HTTP, tipos Protheus e outras plataformas na matriz de homologação.
- Testar limites de bytes comprimidos e descomprimidos, truncamento,
  timeout e entradas invalidas.
- Validar políticas positivas e desativadas com `0`, buffers configuráveis e
  prazo do servidor desligado; distinguir limites do runtime de opções operacionais.
- Homologar o `MAXSTRINGSIZE` efetivo e o comportamento das APIs TOTVS com
  valores maiores, incluindo o custo de materializar JSON/gzip completos.
- Ampliar a homologacao entre revisoes/codepages do Harbour; `HBBRIDGE/1`
  seguem no endpoint Protheus e NETIO no endpoint nativo.
- Validar acesso a dados reutilizando RDDSQL/SQLMIX e as contribs Harbour
  selecionadas, antes de ampliar a engine Zig.

`hb_Serialize()`/`hb_Deserialize()` tem roundtrip explicito de bloco
serializado no teste nativo. O NETIO tambem
serializa automaticamente os argumentos/resultados. A comparacao de compressao
adicional `HB_SERIALIZE_COMPRESS` permanece pendente. Esses testes nao
substituem a verificacao de interoperabilidade com o Protheus.

Validacao do Marco 1 em 2026-10-03: **159 verificacoes, zero falhas, sem skips**,
com Harbour `3.2.1dev (r2608271822)` e Zig `0.16.0` no Windows x64.

O [teste do contrato TCP](integration/harbour/hbbridge.framing.test.hb) amplia o
runner do Marco 2 com dados variados, gzip acima de 65.535 bytes nos dois
sentidos, JSON maior que 16 MiB, fragmentação deliberada, políticas opcionais
de tamanho, CRC inválido, truncamento, comprimento decimal canônico e cliente
lento sem renovação do prazo total. Os buffers de leitura são configuráveis;
não representam o máximo da mensagem. O compressor é exercitado de forma
incremental, usando os mesmos componentes C do produto.
O [contrato desta entrega](../docs/milestone2-framing.pt-BR.md) distingue essas
regressões da homologação TLPP de timeout/falhas de rede ainda pendente.

Na etapa anterior do contrato único, em 2026-10-03, foram **196 verificações,
zero falhas, sem skips**, no mesmo toolchain. O build isolado do produto
também passou; o executável ativo da instalação não foi substituído.
Esse resultado precede a remoção dos tetos e o compressor incremental; a
suíte anterior ao SQL passou em **305 verificações, zero falhas, sem skips**. O Echo
preservou todos os **24.000.000 bytes**, com JSON e gzip acima de 16 MiB nos
dois sentidos. Também passaram os orçamentos opcionais de requisição e
resposta, buffers menores, timeout positivo/zero e compressão incremental.
Os limites por chamada consideram as APIs de socket e zlib do build.
Os testes rejeitam assinaturas/formatos fora do contrato e aliases de addons,
preservando as regressões do produto e as chamadas nativas concorrentes.
O executavel do produto foi compilado em diretorio isolado; CLI `--help`
e configuracao numerica invalida foram verificadas separadamente.

## Homologação manual de falhas controladas em 2026-10-14

Confirmada a execução manual de `U_HBBridgeTCPAndHTTPFailureTest` às 14:30:50
São Paulo, thread 13796: **38 checks TCP e 51 HTTP, zero falhas**. Resolvida
a falha anterior de pré-requisito no host comum. Evidências e observações
nativas de handshake estão no
[registro manual](../docs/acceptance.pt-BR.md#manual-protheus-failure-recovery-on-2026-10-14); M07 tem aceite posterior abaixo.

## Concorrência MSSQL e liberação de recursos (M07)

```powershell
./scripts/test-hbbridge-mssql.ps1 -Config C:/tmp/hbBridge.ini -Profile MSSQL/pData -Concurrency
./scripts/test-hbbridge-mssql.ps1 -Config C:/tmp/hbBridge.ini -Profile MSSQL/pData -Concurrency -Serve
```

`-Concurrency`, `-Failures` e `-Pooling` são mutuamente exclusivos. Falta de configuração
privada, alias MSSQL funcional ou pré-requisito do backend falha com saída 2;
sem skip bem-sucedido. A suíte possui arquivo SQLite isolado e aliases em
memória `m07/mssql-clone` e `m07/sqlite`, mantendo o alias MSSQL informado.
Não altera INIs privados. Oito workers emitem 192 chamadas local/NETIO/TCP/
HTTP e verificam isolamento, recuperação e liberação lógica sob o mutex atual.

`-Serve` mantém o host isolado após os checks dos workers e imprime portas
TCP/HTTP loopback e token da fixture. Encerra após 600 segundos, Esc/Ctrl+Q,
ou criação de `m07.stop` no diretório informado. Checks de limpeza final
executam após encerrar o host; o aceite exige 458 checks e saída 0.
A [suíte Protheus](../src/tlpp/tests/protheus/hbbridge.concurrency.test/README.pt-BR.md)
usa quatro StartJobs, 112 chamadas e 417 checks. As duas rotas passaram em
2026-10-14; [escopo/evidências](../docs/acceptance.pt-BR.md#sql-concurrency-and-release-on-2026-10-14).

Resumos manuais posteriores com pausas passam até **500 jobs / 58449 checks**,
sem falhas reportadas. Contêm parâmetros de lançamento e totais de coleta,
sem identificar binário/pool ou os detalhes individuais necessários para
atribuir o resultado ao reuso físico.
[Homologação manual](../docs/acceptance.pt-BR.md#manual-protheus-concurrency-on-2026-10-15).

## Reuso físico MSSQL e isolamento de sessão

```powershell
./scripts/test-hbbridge-mssql.ps1 -Config C:/tmp/hbBridge.ini -Profile MSSQL/pData -Pooling -ODBCPooling off
./scripts/test-hbbridge-mssql.ps1 -Config C:/tmp/hbBridge.ini -Profile MSSQL/pData -Pooling -ODBCPooling driver
./scripts/test-hbbridge-mssql.ps1 -Config C:/tmp/hbBridge.ini -Profile MSSQL/pData -Concurrency -ODBCPooling driver
```

Cada modo executa em processo novo e passou em 61 checks no Windows.
Após dois leases de aquecimento registrados, 13 leases medidos usam 13
conexões físicas em `off`, uma em `driver`. Identificadores do banco e portas
TCP comprovam reuso; SET/contexto/temporárias/transação/banco, timeouts,
estado do chamador e liberação do ambiente nativo têm verificações próprias.
A conta precisa consultar sua conexão em `sys.dm_exec_connections`; falta de
pré-requisito falha visivelmente. Sem alterar tabelas ERP ou INIs privados.
`-OtherProfile <alias>` opcional testa outro banco MSSQL configurado; esse
caso e pooling Linux ainda não têm aceite em execução. A fixture de oito
workers com pooling passou em 458 checks, zero falhas/sem skips.
[Evidências e limites](../docs/acceptance.pt-BR.md#odbc-physical-reuse-on-2026-10-15).

## Referência MSSQL de tempo e memória (M08)

Usar `scripts/benchmark-hbbridge-mssql.ps1` para processos nativos Harbour,
TCP e HTTP separados, a fixture constante `m08.constant.v1` e amostras de
memória pelo SO. A [metodologia](../docs/benchmarking.pt-BR.md) define a carga
comum de 1000 linhas/páginas de 100, exclusão do aquecimento, cinco varreduras
medidas, um cliente, precisão do relógio e limites da memória de processo.
O [benchmark TLPP](../src/tlpp/tests/protheus/hbbridge.benchmark.test/README.pt-BR.md)
exercita os clientes e dataset do produto no AppServer com o mesmo SQL.
Registra suas próprias amostras por transporte, sem deduzir pooling do servidor
ou memória a partir dos tempos. Preservar relatórios aprovados e identidade
dos artefatos; os checks não estabelecem limiar de desempenho.

`U_HBBridgeBenchmark()` abre o consumidor visual FWWebEx opcional; os testes
do controlador e navegador exercitam validação/correlação sem SQL.
O [teste de ciclo do cliente](../src/tlpp/tests/protheus/hbbridge.client.lifecycle.test/README.pt-BR.md)
reutiliza um cliente em 6000 chamadas Health por padrão e verifica clientes
independentes, recusa/recuperação e fechamento explícito. É uma regressão
focada do componente nativo, sem medir vazamentos ou desempenho SQL.

A comparação opcional adiciona StartJob/REST Protheus via DBAccess e um HRB
que processa a carga dentro do hbBridge. Compilar o HRB com
`scripts/build-hbbridge-benchmark-addon.ps1`; executar os testes isolados do
registro com `scripts/test-hbbridge-benchmark-addon.ps1`. Esses testes não usam
banco nem listener e não homologam tempos MSSQL reais. O
[guia de configuração](../config/hbbridge.benchmark.rest.pt-BR.md) reutiliza o
REST 2.0 autenticado existente. Os testes de contrato AppServer são
`U_HBBridgeBenchmarkVisualTest()` e `U_HBBridgeBenchmarkRESTTest()`; as rodadas
reais usam `--compare-protheus=1 --with-addon=1` e empresa/filial explícitas do
Protheus. Preservar o tempo interno do addon separado da RPC completa.
