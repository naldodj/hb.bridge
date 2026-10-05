# Testes

[English](README.md)

[hbbridgeconnectiontest.tlpp](../src/tlpp/tests/protheus/hbbridgeconnectiontest.tlpp) é o teste de integração Protheus do produto. Com o
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
`module = "examples/hbbridgesampleaddon.prg"` e os parâmetros do módulo (macro
`__IS_THE_ADDONS_EXECUTION_ENABLED__` habilitada) pelo cliente `HBBridgeClient`.
As chamadas usam JSON no frame `HBBRIDGE/1`, com compressao e descompressao de strings nos
dois sentidos: `GzStrComp`/`GzStrDecomp` no Protheus e
compressor/decoder gzip incrementais pela API C no Harbour. O frame completo e comprimido;
o tamanho declarado no cabecalho corresponde aos bytes do JSON
descomprimido. O contrato ativo é único: `HBBRIDGE/1`, JSON e gzip, com
constantes compartilhadas em [includes/hbbridge.h](../includes/hbbridge.h).

Antes do RPC, verifica os métodos estáticos de `hbbridge.client.HBBridgeTime`
em [hbbridgetime.tlpp](../src/tlpp/hbbridgetime.tlpp): diferença
de `TimeCounter()` após `Sleep(1000)`, unidade normalizada, leituras sem regressão
e aritmética do prazo. O fator Unix × 1000 trata a diferença reproduzida na
[issue #12](https://github.com/naldodj/totvs-protheus-open-issues/issues/12).
Uma escala incompatível interrompe o teste e registra os valores brutos,
inclusive se novos builds alterarem a unidade do contador.

O teste verifica `success` e compara integralmente a mensagem e os 200.000
caracteres `X` de `largePayload`. O Marco 2 acrescenta um segundo Echo com
ASCII variado e exige previamente gzip maior que 65.535 bytes. O conteúdo
retornado também é comparado integralmente. Os logs resumem resultado e
tamanho. O operador confirmou a execução manual em 2026-10-03: Health,
ADDON.Execute e os dois Echo passaram, com 200.000 bytes idênticos e gzip
de requisição de 152.964 bytes no caso variado. Timeout/falhas e a medição
detalhada do relógio ficaram pendentes naquela rodada. No novo relato manual
registrado na sessão de 2026-10-04, o operador confirmou novamente Health,
ADDON.Execute e os dois Echo, com os mesmos tamanhos e conteúdo idêntico.
O teste do relógio também passou: `Unix=false`, delta bruto `1097.692700`,
tempo normalizado `1097.773500 ms` após `Sleep(1000)` e `result=OK`.
Isso aceita a medição normalizada no Windows alvo; outras plataformas e
timeout/falhas provocados continuam na matriz de homologação.

O resultado aparece no console do Protheus. `Health` ainda depende da
biblioteca Zig demonstrativa do build atual. A execução do teste TLPP
no AppServer alvo foi confirmada pelos relatos manuais do operador; essa
execução não integra o runner Harbour.

## SQL e páginas

[hbbridgequerytest.tlpp](../src/tlpp/tests/protheus/hbbridgequerytest.tlpp)
acrescenta `U_HBBridgeQueryTest`: campos por nome, decimal, EOF, fechamento,
consulta vazia/inválida e recuperação, além de primeira/próxima/última página,
IDs com lacunas e parâmetros de paginação inválidos. Compile toda a árvore
`src/tlpp/` quando houver fontes novos. Encerre o servidor anterior com Ctrl+Q
e execute da raiz `.\examples\sql\run.ps1` para usar `sqlite_demo`, padrão
da entrada. O [launcher SQL](../examples/sql/README.pt-BR.md) valida o perfil e
informa a chamada de teste; a execução ocorre separadamente no AppServer.
O operador homologou SQLite no AppServer em 04/10/2026 às 00:40:06,
thread `41228`, perfil `sqlite_demo`, com todos os 29 checks verdadeiros.
Na nova rodada manual registrada na sessão de 2026-10-04, confirmou novamente
os 29 checks verdadeiros no perfil `sqlite_demo`, junto do novo teste de
configuração cliente. MSSQL real permanece pendente.

Com a seção `[hbBridge]` do AppServer alinhada ao servidor, abra
[U_HBBridgeQueryTest no WebApp](https://localhost:4321/webapp/?p=U_HBBridgeQueryTest&e=PROTHEUS).
Para MSSQL, configure um DSN ODBC e use
`.\examples\sql\run.ps1 -Config config/examples/mssql.ini -Profile mssql_demo`,
seguido de `U_HBBridgeQueryTest("mssql_demo", "127.0.0.1", 1512, 30000)` no
Protheus. O link sem argumentos usa `SQLProfile`, `Host` e `Port` dessa seção
cliente, com fallback `sqlite_demo` e `127.0.0.1:1512`. Alinhe a seção para
outros perfis/portas ou use a chamada explícita mostrada pelo launcher.
Alterar apenas o perfil no host não exige recompilar o TLPP.
INI e JSON são aceitos; para INI, recompile o produto que fornece
`--config-info`, usado pelo launcher para validar metadados sem iniciar o host.

`SERVICE_NOT_FOUND` indica que o processo conectado não registrou o serviço;
sem perfis no arquivo selecionado ou no `hbbridge.ini` junto ao binário,
`sqlProfiles` permanece vazio. Inicie o exemplo SQL
e confira a porta antes de repetir o teste. Um serviço já registrado com
perfil desconhecido retorna `PROFILE_NOT_FOUND`.

[hbbridgequerytest.prg](integration/harbour/hbbridgequerytest.prg) usa um SQLite
real em arquivo isolado, com perfis, valores, metadados, conexão/área restauradas,
erros sanitizados e 16 chamadas concorrentes. Verifica páginas no SGBD,
ordenação composta/descendente, lacunas, linha extra, página cheia/parcial/vazia,
ordinais representáveis, aliases duplicados/reservados e o mesmo resultado por
NETIO e TCP/JSON. O contrato está em [Marco 3](../docs/milestone3-sql.pt-BR.md).

Runner completo atual em 2026-10-04: **412 verificações, zero falhas, sem skips**,
SQLite **3.53.4**, Harbour/Zig Windows x64. Resultado em
`tmp/tests-236f1241c1174cf4b193c22f6eedb6e0/results.log`.
Inclui 26 verificações INI e três rejeições adicionais de driver/direção SQL inválidos, além
das 383 anteriores. O INI exercita equivalência com JSON, precedência,
BOM/CRLF, pontuação de senhas/ODBC, caminhos e rejeição de entradas inválidas.
O registro inicial de build TLPP interrompido é histórico: o aceite SQLite
posterior foi informado pelo operador. A nova configuração cliente `[hbBridge]`
também passou na rodada manual posterior descrita abaixo; o agente não executou
esses testes no AppServer.

[hbbridgeconfigtest.tlpp](../src/tlpp/tests/protheus/hbbridgeconfigtest.tlpp)
oferece `U_HBBridgeConfigTest()` para defaults, INI, argumentos prioritários,
destino inválido, números malformados, budgets zero/negativo/fracionário e
capacidade nativa de chunk. A leitura do INI ativo também é verificada;
complemente com Health/Query sem argumentos para confirmar o destino efetivo.
O operador informou execução bem-sucedida desse teste na sessão de 2026-10-04,
com todos os **13 checks verdadeiros**: `missingSectionDefaults`, `iniValues`,
`wildcardIsNotDestination`, `invalidIniNumber`, `explicitOverridesInvalidIni`,
`explicitZeroDisablesBudget`, `invalidExplicitPort`, `invalidTimeout`,
`nativeChunkCapacity`, `negativeBudget`, `fractionalBudget`,
`budgetBeyondSocketChunk` e `activeAppServerIni`.
O mesmo relato confirmou relógio, Health, ADDON, Echo e Query SQLite.
Não foram informados horário de execução, thread, hash do build, argumentos
das chamadas ou log de compilação. A leitura do INI ativo foi aceita; esse
relato não demonstra conexão com destino diferente dos padrões.

A tentativa anterior do agente via `build-totvs.cmd`, interrompida antes do
compilador ao parar os processos TOTVS, permanece como histórico em
`tmp/ini-totvs-build.log`. O aceite manual posterior supera a pendência de
execução dos novos testes. A [matriz](../docs/acceptance.pt-BR.md) distingue esse
resultado dos cenários ainda não homologados.

## Regressoes Harbour existentes

[integration/harbour/hbbridgeservertest.prg](integration/harbour/hbbridgeservertest.prg), com entrada `MTTests`, contem
verificacoes automatizadas de concorrencia, clientes ociosos, erros, limite de
workers e parada. Inclui `Echo` e resposta de erro com `HBBRIDGE/1`,
conferindo o contrato do servidor real. Assinaturas diferentes, JSON sem
enquadramento e wrappers de compressão diferentes de gzip são rejeitados.

A suite tambem exercita `Health` pela ponte C/Zig e a compilacao em memoria
do addon PRG de exemplo. Os clientes de teste usam `127.0.0.1` e as chamadas
das fixtures apontam explicitamente para os arquivos `.hrb` preparados.

Na raiz do projeto, com Zig no PATH e Harbour compilado com Zig:

```powershell
.\scripts\test-hbbridge.ps1 -HbCompileRoot F:\GitHub\hb_compile
```

O [runner](../scripts/test-hbbridge.ps1) compila a biblioteca Zig, prepara as
fixtures em uma pasta exclusiva sob `tmp/` e compila
[hbbridgeservertest.hbp](integration/harbour/hbbridgeservertest.hbp). Esse projeto compartilha
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

O runner tambem executa [configuracao](unit/hbbridgeconfigtest.prg),
[contrato/registro](contract/hbbridgeservicestest.prg) e [NETIO nativo](integration/harbour/hbbridgenetiotest.prg),
usando o mesmo host/nucleo do produto. A integracao verifica argumentos/resultados
nativos, core, descoberta, addons, VF IO binario, admin separado, filtros RPC,
credenciais e parada/reinicio/rollback. As portas NETIO/admin dos testes sao
selecionadas entre portas livres; nao usa nem para os endpoints da instalacao.

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
- Homologar no AppServer timeout, falhas de conexão e envios parciais forçados,
  incluindo os retornos de `Receive`/`GetError`; o fluxo normal já foi aceito.
- Verificar a configuração cliente com destino/porta diferentes dos padrões
  e manter MSSQL real e outras plataformas na matriz de homologação.
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

O [teste do contrato TCP](integration/harbour/hbbridgeframingtest.prg) amplia o
runner do Marco 2 com dados variados, gzip acima de 65.535 bytes nos dois
sentidos, JSON maior que 16 MiB, fragmentação deliberada, políticas opcionais
de tamanho, CRC inválido, truncamento, comprimento decimal canônico e cliente
lento sem renovação do prazo total. Os buffers de leitura são configuráveis;
não representam o máximo da mensagem. O compressor é exercitado de forma
incremental, usando os mesmos componentes C do produto.
O [contrato desta entrega](../docs/milestone2-framing.pt-BR.md) distingue essas
regressões da homologação TLPP de timeout/falhas ainda pendente.

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
