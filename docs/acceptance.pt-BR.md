# Ambiente de referência e homologação

A homologação das alterações de reorganização anteriores
ao Marco 1 está OK. Os dados abaixo identificam esse ambiente de desenvolvimento;
não certificam versões distintas nem a execução das novas alterações nele.

Caminhos `tmp/...` abaixo são locais históricos de saída, não entradas a
preservar no projeto. Podem ser excluídos. Resumos sanitizados e comandos
atuais de reprodução por fontes estão em [validação](validation/README.pt-BR.md).

| Componente | Referência informada |
| --- | --- |
| Sistema | Windows 11, x64 |
| AppServer | `7.00.240223P-20260211`, versão `24.3.1.5`, símbolos de debug |
| Revisões AppServer | SVN `46783`, Vader `3792` |
| Porta AppServer | `1234`, independente das portas hbBridge |
| LIB | `20260706` — `20260703_152624` |
| Commit LIB | `72adb06b99257e6165f7484ba26679818c037720` |
| Smartclient WebApp | `7.00.240223P-20260702`, `10.2.1`, `HTML-10.2.1 WIN`, remoto 64 bits |
| Broker Proxy | Desabilitado |
| DBAccess | `20240224-20260522`, versão `24.1.1.3`, standalone MultiDB Windows x86_64 |
| DBAccess memória | Release, SmartHeap `11.6.1` |
| Banco | MSSQL `16.0.1200.5`, edição DEVELOPER |
| Ambiente | `PROTHEUS`, desenvolvimento |
| RPO e dicionário | `12.1.2510`, dicionário no banco |
| Local files | `SQLITE` |

Compilação/validação local do servidor:

| Componente | Referência |
| --- | --- |
| Harbour compilado | `3.2.1dev (r2608271822)`, VM multithread |
| Toolchain | `hb_compile/out/zig`, `hbmk2 -comp=zig` |
| Zig | `0.16.0` |
| Plataforma exercitada | Windows x64 |
| Bibliotecas selecionadas | `hbnetio`, `hbextern`, `rddsql`, `sddsqlt3`/SQLite, `sddodbc`/ODBC, runtime/compilador Harbour e `hbbridge_zig` |
| Código Harbour inspecionado | Checkout local `8d94c31367104a57eb9ae6fa248cca2abb8db309` |

A revisão do checkout inspecionado não é uma declaração de que o runtime
compilado provém desse commit: o identificador disponível do build é a
revisão Harbour mostrada acima. Builds de distribuição devem registrar também
o commit exato do runtime, opções, contribs e dependências externas.

Na homologação original do Marco 1, o teste usou os padrões de cliente
`127.0.0.1`, `1512` e `5000` ms, chamando Health, Echo e ADDON. Esse registro
não comprova o contrato modificado posteriormente.

Para homologar o produto atual, compile **`src/tlpp/` inteiro**, incluindo
[tests/protheus/hbbridgeconnectiontest.tlpp](../src/tlpp/tests/protheus/hbbridge.connection.test/hbbridge.connection.test.tlpp),
e execute `U_HBBridgeConnectionTest(cHost, nPort, nTimeout, nLargePayloadBytes)`.
Sem argumentos, a conexão consulta `[hbBridge]` no INI ativo; os fallbacks
são `127.0.0.1`, `1512`, `30000` ms e `0` bytes
para o Echo adicional opcional. O teste chama Health, Echo e `ADDON.Execute`
com `{module, params}`. O cliente mantém os três primeiros argumentos de
`New` e aceita mais três opcionais: teto de JSON, teto de gzip e tamanho de
buffer, com padrões `0`, `0` e `65536`. O timeout TLPP deve ser positivo.
Os aceites históricos não comprovam alterações posteriores. A nova
configuração cliente teve confirmação manual própria recebida em 2026-10-04,
registrada ao final deste documento.

## Resultado no AppServer em 2026-10-03

A recompilação e a execução manual pelo WebApp estão OK. Os logs
locais corroboram ambas as etapas:

- Compilação às **07:45:37**, horário de São Paulo: **3 fontes, 3 sucessos,
  0 erros**, incluindo `hbbridgeconnectiontest.tlpp` e os nomes então usados
  `thbbridgeclient.tlpp` e `trpcdataset.tlpp`; resultado em `tmp/console.log`.
- Execução às **08:00:30**, thread AppServer `32748`: **Health, ADDON e Echo
  com `success: true`**, no console configurado em
  `C:\totvs\protheus1212410\protheusdata\logs\console.log`.
- A resposta Echo preservou a mensagem e os **200.000 caracteres `X`**;
  a análise do JSON no log comparou o conteúdo integral, além do comprimento.

O registro resume a validação do adaptador existente contra o núcleo do
Marco 1. Não comprova fragmentação TCP, dados pouco compressíveis,
`MAXSTRINGSIZE`, codecs novos ou todos os serviços futuros.

O utilitário [build-totvs.cmd](../scripts/build-totvs.cmd) usa o caminho do
projeto para os fontes e grava `tmp/totvs-compile.log` nas próximas execuções.
Ele chama os scripts locais de parada/reinício TOTVS; para encerrar processos
que rodam elevados, execute-o com permissão administrativa. A tentativa local
encontrou **Acesso negado** ao parar o AppServer e foi
interrompida antes de recompilar. A compilação bem-sucedida registrada acima
foi realizada com sucesso e os testes executados OK.

URL de execução: [WebApp — U_HBBridgeConnectionTest](https://localhost:4321/webapp/?p=U_HBBridgeConnectionTest&e=PROTHEUS).

O MSSQL e o SQLite identificam os alvos para `RPCRDD.Query`; o serviço foi
implementado no Marco 3, descrito abaixo. Não foi inferido um valor de `MAXSTRINGSIZE` a partir
da versão do AppServer. Esse limite/configuração e a compatibilidade de
codepages devem ser medidos e registrados ao homologar o novo contrato.

## Marco 2 — histórico e validação atual

A etapa anterior do [contrato e fluxo TCP](milestone2-framing.pt-BR.md), antes da
remoção dos tetos fixos e da inclusão do compressor incremental, passou no runner Harbour:
**196 verificações, zero falhas, sem skips**, incluindo gzip acima de
65.535 bytes nos dois sentidos, fragmentação, CRC/truncamento, limites e
cliente lento, recusa de formatos alternativos e ausência de aliases de addons.
O produto dessa etapa também foi compilado em diretório isolado. As
**196 verificações** são um resultado histórico, não uma validação dos
ajustes posteriores.

O produto atual aceita apenas `HBBRIDGE/1` e `ADDON.Execute`. As políticas
`protheusMaxPayloadBytes` e `protheusMaxWireBytes` usam zero por padrão,
sem teto adicional de aplicação. O buffer padrão é 65.536 bytes e o prazo
Harbour é configurável, com padrão de 30.000 ms e zero sem deadline.
NETIO zero é convertido para `-1` na API nativa. Compressão e descompressão
C usam estado incremental da zlib vinculada ao Harbour, enquanto o JSON
continua inteiro em memória. Capacidades de string e tipos das APIs são
informados por `HBBridgeRuntimeLimits()`: `stringBytesMax`,
`socketChunkBytesMax`, `zlibChunkBytesMax` e `netioTimeoutMsMax`. O buffer
deve caber no menor limite entre socket e zlib.

A parada Protheus preserva as chamadas já admitidas e aguarda seus workers.
Timeout Harbour zero permite que um cliente que não conclui nem fecha
mantenha essa espera indefinidamente; esta etapa não força cancelamento.
NETIO sinaliza e fecha suas conexões ao parar.

A execução anterior ao Marco 3 passou em **305 verificações, zero falhas, sem skips**,
com Echo de **24.000.000 bytes exatos**, JSON/gzip acima de 16 MiB nos dois
sentidos, compressor incremental, políticas zero/positivas e timeout
positivo/zero Harbour. Também validou um comprimento de nove dígitos sem
alocar um corpo de 100 MB. Resultado em
`tmp/tests-1156a4ae33964edc925ff65e09748ddb/results.log`.
Orçamento de resposta comprimida e limite por chamada zlib também passaram.
O build isolado do candidato final, sua opção `--help` e a rejeição de
configuração inválida passaram com as últimas guardas de capacidade.
As 29 verificações adicionais exercitam a fonte monotônica do servidor em
leituras repetidas, espera e oito threads concorrentes. O servidor usa
`GetTickCount64` no Windows para prazos/uptime; o caminho POSIX com
`CLOCK_MONOTONIC` foi compilado, sem execução homologada.

### Confirmação manual Protheus em 2026-10-03

Informado o seguinte resultado manual no AppServer para o teste ampliado:

```text
hbBridge Health Protheus OK: {"success":true,"message":"hbBridge Zig Engine Active"}
hbBridge ADDON.Execute Protheus OK: {"success":true,"addon_msg":"Executado via HRB Addon no hbBridge!"}
hbBridge Echo Protheus OK: 200000 bytes, conteudo identico.
hbBridge Echo fragmented Protheus OK: 200000 bytes, conteudo identico; gzip request=152964 bytes.
hbBridge RPC Protheus OK: todos os testes solicitados passaram.
```

Isso confirma os serviços Health e ADDON.Execute, os dois Echo com comparação
integral e a conclusão normal das chamadas. O caso ASCII variado produziu
gzip de requisição de 152.964 bytes, acima do buffer padrão de 65.536 bytes.
A evidência corresponde à execução manual no AppServer; esta rodada não foi
repetida na validação local.
O horário de execução, os argumentos e o hash do binário não foram informados.

O novo `hbbridgetime.tlpp`, com a classe `HBBridge.Client.HBBridgeTime` e seus métodos
estáticos, usa `TimeCounter()`; o teste atual verifica escala/avanço após
`Sleep(1000)` antes do RPC. A linha de relógio não constava no trecho
recebido nessa rodada anterior; os valores foram informados na confirmação
posterior de 2026-10-04, registrada ao final.
A conversão Unix × 1000 corrige a diferença reproduzida na
[issue #12](https://github.com/naldodj/totvs-protheus-open-issues/issues/12).
A homologação atual deve registrar escala, precisão e regressão/wrap no build
alvo, incluindo eventuais mudanças de unidade após correções do AppServer.
O Echo adicional configurável deve respeitar o `MAXSTRINGSIZE` medido no
AppServer; sua versão não permite inferir esse valor.
O fechamento normal foi aceito nesta execução. Permanecem os testes de
`Receive`/`GetError` em timeout/falha, envio parcial positivo forçado,
Windows/Linux e identificação do artefato exato do servidor usado.

## Marco 3 — SQL e paginação em 2026-10-04

`RPCRDD.Query` foi integrado ao registro usando RDDSQL/SQLMIX, `sddsqlt3`
e `sddodbc`, com perfis SQLite/MSSQL configurados no servidor. A regressão
inicial completa passou em **383 verificações, zero falhas, sem skips**:
`tmp/tests-245a7d7044724d3db678f1e6052194b7/results.log`.
O SQLite vinculado informou **3.53.4** por `sqlite_version()`; Harbour,
Zig e plataforma permanecem os da tabela de build acima.

Foi usado um SQLite em arquivo isolado, com dados persistidos. Passaram
resultados por chave, metadados, vazio, erros, nulo em expressão, preservação
da área/conexão anteriores e 16 chamadas concorrentes. As páginas usam
`ROW_NUMBER`/`BETWEEN` no banco, sem carregar todas as linhas para recorte.
Também passaram ordenação composta/descendente, IDs com lacunas, primeira/
última/página vazia, linha adicional, campo interno oculto e limites aritméticos.
Clientes Harbour NETIO e TCP/JSON obtiveram o mesmo resultado simples e paginado.

O novo `HBBridgeRPCDataSet` e `U_HBBridgeQueryTest` foram implementados. A tentativa
de compilação com `scripts/build-totvs.cmd` falhou na parada dos processos
TOTVS, antes de iniciar o compilador, registrada em `tmp/marco3-totvs-build.log`.
Nessa tentativa, não houve execução do novo teste no AppServer; o resultado
manual posterior está registrado abaixo. A conexão MSSQL
real permanece pendente; o teste de DSN inexistente verifica apenas
o erro ODBC sanitizado. Acesso ODBC direto não certifica uso do DBAccess.

Procedimento, contrato e exemplos em [Marco 3](milestone3-sql.pt-BR.md).

O produto foi compilado em `tmp/marco3-product/hbbridge.exe`, sem substituir
o executável ativo da instalação. Passaram `--help` e uma chamada SQL paginada
ao próprio executável, iniciado com JSON de perfil e portas isoladas; o retorno
foi a linha `ID = 10`, `rowCount = 1` e `hasNext = true`.
Log: `tmp/marco3-product-smoke.log`.
SHA-256 do candidato:
`8C90995602F336B1B5B395AD6AE36A4F2608079451E68A9BC142DE8EC9F6C17C`.

### Tentativa Protheus às 00:27:04 de 2026-10-04

Informada a execução manual de `U_HBBridgeQueryTest`, thread `30460`,
com retorno `SERVICE_NOT_FOUND; Servico nao suportado`. Isso confirma a
entrada do teste e o retorno do dispatcher; não certifica consulta SQL.
Uma sondagem posterior de `Service.List` em `127.0.0.1:1512` encontrou os
seis serviços básicos, sem `RPCRDD.Query`, registrada em
`tmp/sql-service-discovery.json`. O executável em `out` já possui a opção SQL
no `--help`; a linha de comando do processo ativo não ficou acessível nesta sessão.

O serviço só é registrado com `sqlProfiles` não vazio. A orientação nessa
tentativa foi reiniciar o produto atualizado com
`-config=config/examples/sqlite.json` e repetir a entrada TLPP já disponível
no RPO. Foram acrescentadas mensagens no início do host e no erro do teste
para explicar essa condição. O aceite SQL Protheus estava pendente até a
execução bem-sucedida abaixo.

O candidato com o novo diagnóstico foi recompilado em diretório isolado.
A inicialização registrou `RPCRDD.Query enabled; SQL profiles=1` e a chamada
paginada voltou a retornar `ID = 10`, uma linha e `hasNext = true`.
Log: `tmp/sql-registration-smoke.log`. SHA-256 dessa revisão do candidato:
`F2177CFA4AB76363EC2E773A39717057D0CA7CDA8F10B0FD03A13CB3DAC74490`.
O processo da instalação permaneceu ativo; essa verificação usou portas isoladas.

O launcher `examples/sql/run.ps1` também foi validado com o executável canônico
de `out`, perfil SQLite e portas isoladas, preservando a precedência de `-Port`
sobre o JSON. A consulta paginada passou; log em `tmp/sql-launcher-smoke.log`.
Isso verifica a preparação do host, sem acrescentar aceite no AppServer.

### Confirmação SQLite Protheus às 00:40:06 de 2026-10-04

Informada a execução manual de `U_HBBridgeQueryTest`, thread AppServer
`41228`, ambiente `PROTHEUS`, perfil `sqlite_demo`, com **29 checks `true`**.
O resultado aceita o dataset por nome, valores decimais, navegação/EOF,
fechamento, resultado vazio, erros SQL/perfil e recuperação após falhas.
Também aceita primeira/próxima/última página, IDs com lacunas, EOF local,
ordinal oculto e rejeição dos parâmetros de paginação/ordenação inválidos.

O horário é o do log informado, no fuso de São Paulo. Essa
execução foi manual e não foi repetida na validação local. Não foram informados o
hash do executável do servidor nem um log de compilação correspondente.
O aceite cobre SQLite e a revisão cliente usada nessa execução; não comprova
MSSQL real, outras codepages/tipos SQL ou as alterações posteriores do cliente.

### Configuração INI e validação atual do servidor

Após o aceite SQLite, o servidor passou a aceitar INI e JSON pela mesma
validação interna, com precedência **padrões < um arquivo INI/JSON < CLI**.
Sem `-config`, procura `hbbridge.ini` junto ao executável; um arquivo explícito
substitui essa seleção. O comando `--config-info` valida e informa metadados
sanitizados sem iniciar listeners, abrir bancos ou expor senhas/strings de
conexão/caminhos de dados. Os launchers só encaminham as opções de porta e
workers quando informadas. O launcher SQL consulta esse comando para INI,
sem duplicar o parser. Essas opções exigem o executável atualizado.

O runner Harbour atual passou em **412 verificações, zero falhas, sem skips**,
no mesmo Harbour/Zig e Windows x64 de referência. Log:
`tmp/tests-236f1241c1174cf4b193c22f6eedb6e0/results.log`.
São 26 verificações INI e três rejeições adicionais de driver/direção de
ordenação inválidos no contrato SQL além das 383 anteriores. Foram verificadas equivalência INI/JSON,
precedência, caminhos, BOM/CRLF, pontuação de senhas e strings ODBC,
autoload e rejeição de arquivos inválidos.

A nova leitura de `[hbBridge]` no AppServer é uma alteração posterior ao
teste das 00:40:06. Confirmados os testes em nova rodada manual no AppServer,
registrada abaixo. MSSQL real permanece pendente. As 412 verificações são
da suíte Harbour, separadas do aceite dessa configuração no AppServer.
`HBBridge.Client.HBBridgeConfig():Read()` seleciona o INI por `GetSrvIniName()`
e lê `Host`, `Port`, `TimeoutMs`, `MaxPayloadBytes`, `MaxWireBytes`,
`ReadChunkBytes` e `SQLProfile` por `GetPvProfString`. O cliente e os testes
sem argumentos passam a usar essa seção; argumentos explícitos têm prioridade.
O [template cliente](../config/examples/protheus-appserver.ini) precisa ser
mesclado ao INI do AppServer e alinhado ao servidor, separadamente do INI
Harbour. O link WebApp sem argumentos pode usar valores distintos dos
informados pelo launcher; a chamada explícita evita essa ambiguidade.
Regras e exemplos em [configuração](configuration.pt-BR.md).

O produto com INI foi recompilado em `tmp/marco3-product/hbbridge.exe`.
Os três exemplos INI passaram em `--config-info`, incluindo precedência CLI.
O launcher SQL passou com INI e portas isoladas, retornando a primeira página
`ID = 10`, uma linha e `hasNext = true`; usou uma cópia isolada do candidato
e dos scripts, sem substituir o executável da instalação.
Log: `tmp/ini-launcher-smoke.log`; SHA-256:
`F51BE0E77B64CAA94B0C12016E24BB49153035A1B2EE680A24FCE26ADBE9CF5B`.
Validar metadados MSSQL não executa consulta nem certifica DSN/driver/banco.

A seção `[hbBridge]` foi adicionada ao AppServer local preservando os bytes
anteriores e guardando uma cópia em `tmp`. A tentativa local de compilação
foi bloqueada antes do compilador porque os processos TOTVS não puderam ser
encerrados: `tmp/ini-totvs-build.log`. Foi preparado `U_HBBridgeConfigTest`
para resolução/precedência/erros; informado sucesso posteriormente em execução
manual no AppServer.

### Confirmação Protheus de configuração INI, relógio e SQLite

Resultado manual no AppServer informado na sessão de **2026-10-04**, após a
alteração da configuração cliente. Esses testes não foram
executados nem compilados durante a validação local.

| Entrada | Resultado informado |
| --- | --- |
| `U_HBBridgeConfigTest` | 13 checks verdadeiros: defaults, valores INI, precedência, override de valor inválido, budgets zero/negativo/fracionário, porta/timeout inválidos, capacidade nativa de chunk e leitura válida do INI ativo. |
| Relógio em `U_HBBridgeConnectionTest` | `Unix=false`, delta bruto `1097.692700`, normalizado `1097.773500` ms após `Sleep(1000)`, resultado `OK`. |
| Health/ADDON/Echo | Todos passaram; dois Echo de 200.000 bytes idênticos, incluindo requisição gzip de 152.964 bytes. |
| `U_HBBridgeQueryTest` | Perfil `sqlite_demo`, 29 checks verdadeiros, incluindo campos/decimal, erros/recuperação, vazio, paginação, EOF e fechamento. |

Os resultados exatos de configuração e SQL foram:

```text
hbBridge client configuration checks: {"missingSectionDefaults":true,"iniValues":true,"wildcardIsNotDestination":true,"invalidIniNumber":true,"explicitOverridesInvalidIni":true,"explicitZeroDisablesBudget":true,"invalidExplicitPort":true,"invalidTimeout":true,"nativeChunkCapacity":true,"negativeBudget":true,"fractionalBudget":true,"budgetBeyondSocketChunk":true,"activeAppServerIni":true}
hbBridge client configuration Protheus OK
hbBridge clock: Unix=false; TimeCounter delta=1097.692700; normalized=1097.773500 ms after Sleep(1000); result=OK
hbBridge RPC Protheus OK: todos os testes solicitados passaram.
hbBridge RPCRDD.Query checks: {"rowCount":true,"firstId":true,"firstName":true,"decimal":true,"missingField":true,"secondId":true,"secondName":true,"eof":true,"close":true,"empty":true,"emptyState":true,"invalidSql":true,"invalidSqlCode":true,"unknownProfile":true,"unknownProfileCode":true,"afterFailure":true,"afterFailureValue":true,"firstPage":true,"firstPageState":true,"hiddenOrdinal":true,"pageEof":true,"nextPage":true,"lastPageState":true,"noNextPage":true,"emptyPage":true,"invalidPage":true,"invalidPageCode":true,"invalidOrder":true,"pageClose":true}
hbBridge RPCRDD.Query Protheus OK; profile=sqlite_demo
```

Esse aceite supera a pendência de execução da nova configuração cliente.
Não foram informados hora/thread, argumentos, valores efetivos de Host/Port,
hash dos artefatos ou log de compilação dessa rodada. `activeAppServerIni`
confirma configuração válida lida do INI; não demonstra sozinho aplicação
de um destino diferente dos padrões. A escala/avanço do relógio no Windows
foi aceita; Linux, precisão/wrap real e alterações do relógio continuam em aberto.

Permanecem MSSQL real, destinos/perfis diferentes dos padrões com argumentos
omitidos, timeout/falhas de socket, envio parcial positivo forçado e ampliação
de tipos/volume/codepages. A suíte Harbour de 412 checks é uma verificação
independente. Nenhum fonte ou arquivo de configuração mudou ao registrar esse aceite.

## Dependências gerenciadas e revisão de perfis em 2026-10-04

O bootstrap do próprio projeto compilou o Harbour fixado e o hbrun usando
hb_compile/Zig gerenciados. As revisões Git foram hb_compile
`2cb6f3ef59c297025a2c49c4cfa8c7639f3a1455` e Harbour
`6deac9cf3ad977ae829e5bca543d553b92dd4b6d`; Zig 0.16.0.

A suíte Harbour isolada no Windows passou em **416 verificações, zero
falhas e nenhum skip**, log
`tmp/tests-d1b829ff332c414f816a6e70748152d1/results.log`. Sobre as 412
anteriores, dois casos INI e dois SQL verificam perfis múltiplos, preservação
de barra/caixa e seleção explícita que distingue maiúsculas/minúsculas.

O produto candidato foi compilado em `tmp/managed-product/hbbridge.exe`,
SHA256 `5443466A05A5206D7E6E1BC53F86DB604059EEF8F687A0C1B22973CFB7A76B18`,
log `tmp/managed-product-build.log`. Checks de metadados sanitizados de perfis
não consultaram MSSQL. A instalação canônica ativa não foi substituída.

Esse resultado precede os ajustes PascalCase e HTTP solicitados em
2026-10-06. Classes/namespaces TLPP renomeados e o teste revisado de
configuração com 16 checks não foram compilados nem homologados no Protheus.
HTTP, HTTPS direto, MSSQL real, Linux e mudanças posteriores exigem
validação registrada separadamente.

## PascalCase e HTTP nativo em 2026-10-06

A rodada HTTP específica final no Windows Harbour/Zig passou em **65
verificações, zero falhas e nenhum skip**. Os testes foram
executados localmente com o toolchain gerenciado. Log:
`tmp/http-tests-f3476462dfbb4fe6b64d63b0de1c1149/results.log`; log do script:
`tmp/http-target-test.log`; preparação das dependências:
`tmp/http-prepare.log`. Esses logs contêm a rodada final, substituindo as
iterações específicas anteriores de 45 e 57 checks.

A rodada exercitou hbhttpd junto de NETIO/TCP: Health autenticado via Zig,
Echo de 220 KB, resultados equivalentes pelo NETIO nativo, SQLite com alias
`memory/HTTP`, ADDON.Execute, descoberta, separação bearer/admin, erros de
serviço JSON estruturados, rejeição de Transfer-Encoding e Content-Length
duplicado/não decimal, oito contextos concorrentes, parada durante um
cabeçalho continuamente incompleto, reinício na mesma porta e rollback de
início. O painel administrativo apresenta somente status compartilhado e
fica desativado sem credencial admin. Campos ERP recebidos continuam como
parâmetros sem interpretação.

Os testes com workers UTF8EX também passaram em Content-Length por bytes,
acentos/CJK/caracteres suplementares brutos, escapes BMP, pares surrogate
com caixa mista e chaves de objetos, preservação de backslash/aspas escapados,
rejeição de UTF-8 inválido/conteúdo excedente, Unicode SQLite e execução
Unicode de serviço nativo. Surrogates órfãos/invertidos retornaram
`INVALID_JSON`/400 antes da execução. A normalização de surrogate fica no
adaptador HTTP, sem alterar hbjson global nem os outros transportes.

HTTP aberto vinculou hbhttpd/hbtcpio gerenciados, usando o patch do projeto
SHA256 `ab6de8a46ec4aa3b01493db5ad5c90dd005f1b76ed61f8d38c6356602a3f3d1c`.
O SHA256 do executável específico de teste foi
`65661E1F56C02217D58E7C1F40FB6EF48E71D4BD144A43A9B8C379702E877EF5`.
TLS direto hbssl/OpenSSL não foi vinculado nem exercitado. Parsing/prazos
HTTP continuam nativos e não herdam budgets TCP Protheus. Veja
[HTTP e dependências](http.pt-BR.md).

A rodada Windows completa de 2026-10-06 passou em **487 verificações, zero
falhas e nenhum skip**, incluindo esses casos HTTP e regressões TCP/NETIO/
SQL/addons. Log: `tmp/tests-f15616d6765e4c9c8103ca2992797c2d/results.log`;
wrapper: `tmp/full-tests-http-final.log`.
Essa rodada HTTP não compila/homologa os fontes TLPP renomeados no AppServer,
não comprova MSSQL real/Unicode ODBC/HTTPS/Linux nem implementa ações
administrativas.

### Semântica nativa de estado HRB e contraprova

O teste nativo isolado de propriedade passou com **12 HRBs FORCELOCAL
carregados simultaneamente**, barreira de sincronização, `owner=id` e
`counter=counterBefore+1`. Log: `tmp/addon-native-semantics.log`. A recarga
sequencial reutilizou frame STATIC inicializado: os contadores registrados
seguiram de 2 até 5, em vez de reiniciar em um. Loader/runtime não foram
alterados para forçar resets.

A contraprova deliberada com um único handle HRB compartilhado entre 12
threads rejeitou **11 de 12 respostas**, log
`tmp/addon-native-counterprobe.log`. Isso comprova que as verificações
detectam estado compartilhado e respeitam a reciclagem nativa do Harbour.
A fixture acrescenta seis checks à suíte completa, cujo resultado é
registrado separadamente. Addons devem inicializar seu estado de negócio
por execução com parâmetros/variáveis locais; FORCELOCAL não assegura reset.

## Estado da thread e candidato em 2026-10-07

A prova nativa THREAD STATIC passou em **31 asserções**, exit 0:
`tmp/thread-static-probe.log`. Doze threads compartilharam um HRB mantendo
proprietários/contadores privados; chamadas e quatro recargas na mesma thread
persistente conservaram valores. Essa prova é distinta da suíte com 487 checks.
hbhttpd já usa thread statics/reset por requisição; a auditoria manteve os
mutexes SQL/teste intencionalmente compartilhados. Veja a [análise](evolution.pt-BR.md).

A preparação HTTP atual passou com patch SHA256
`52F937F65EDD03110C6DBC19A86C2D6E4A8031D04A6D686DE0B5AFC3D304CC1B`,
log `tmp/http-prepare-20261007.log`. O `core.prg` resultante é idêntico ao
fonte da suíte anterior; hash histórico e logs acima permanecem literais.

O build isolado passou em `tmp/http-product-20261007/hbbridge.exe`, SHA256
`D9E891155C7F36723F7E480E543F2FE0502D83DA9BFC22CC347CDC0C18C090EF`.
Log de build: `tmp/http-product-build-20261007.log`; configuração:
`tmp/http-product-config-20261007.log`. O executável preservou HTTP desativado/
perfis vazios por padrão, overrides de bind wildcard/porta, aliases
`sqlite_demo`/`MSSQL/pData` e saída sem segredos/strings de conexão.
A inspeção de metadados não iniciou listeners nem consultou os bancos.

O crivo final passou para **135 arquivos**, incluindo `check.hb`, `commit.hb`,
`3rdpatch.hb`, nomes/indentação e pares de documentação. Log:
`tmp/commit-gate-20261007.log`. O hook pre-commit para conferir o índice foi
instalado localmente; não houve commit nem publicação. Links locais da
documentação e `git diff --check` também passaram.

Resolução automática OpenSSL externo, HTTP Zig e materialização SQL continuam
desenhos. Esse candidato não acrescenta aceite HTTPS/Linux/MSSQL/AppServer
aos registros anteriores.

<a id="homologação-http-tlpp-pelo-operador-em-2026-10-07"></a>

## Homologação HTTP TLPP manual em 2026-10-07

Após o ajuste da comparação de acentos e do tratamento Unauthorized do
FWRest, informada execução manual de `U_HBBridgeHTTPTest` em **PROTHEUS**, thread
**25672**. Programa iniciado às **15:16:12 São Paulo**; teste às
**15:16:14–15:16:15**, duração **00:00:01**. A pilha RPO informada contém
`tttm120.rpo`, `tlpp.rpo` e `custom.rpo`. Health retornou a mensagem Zig
com HTTP **200**. Transcrição recebida: `tmp/protheus-http-operator-20261007.log`.

Os **13 checks** passaram: `healthGet`, `healthPost`, `servicesGet`, `echo`,
`addon`, `unknownService`, `adminForbidden`, `unauthorized`, `afterFailure`,
`queryFirstPage`, `queryFirstValue`, `queryNextPage`, `queryLastValue`.
Echo compara 200000 bytes X e um campo acentuado, aplicando DecodeUTF8
somente nesse campo. A consulta usa o dataset existente e SQL constante
com dois IDs, exercitando páginas HTTP sem inferir tabelas ERP.

Nesse comportamento do FWRest, `cInternalError` contém Unauthorized enquanto
o código HTTP pode vir zerado. O cliente normaliza HTTP 401 e código local
UNAUTHORIZED. Erros JSON de serviço 403/404 foram preservados; o fallback 401
não é o corpo JSON original do servidor. Essa propriedade é dependência de
compatibilidade do framework; outra LIB precisa de homologação própria.
Uma inicialização defensiva posterior também trata 401 nativo sem motivo
interno, preservando o caminho homologado. O ramo alternativo não foi
exercitado em outra LIB.

Esse é aceite de execução manual informada no AppServer, sem teste local
nem log de sucesso do compilador fornecido. A tentativa local anterior
retornou -1073740791, e o log interpretou um diretório de includes como
ambiente; não comprova compilação bem-sucedida. A execução manual informada
supera essa lacuna nos fontes HTTP exercitados. Logs históricos:
`tmp/totvs-http-build-run.log` e `tmp/totvs-compile.log`.

O relato não identifica alias/backend SQL, URL/token/configuração cliente ou
hash do executável servidor. Portanto não acrescenta MSSQL real, HTTPS,
Linux, Unicode completo, configuração alternativa nem teste de configuração
cliente com 16 checks. Veja o [exemplo](../examples/http/README.pt-BR.md).

O crivo final da árvore de trabalho passou para **139 arquivos** com `check.hb`,
`commit.hb`, `3rdpatch.hb` e convenções; log:
`tmp/commit-gate-tlpp-http-20261007.log`. Whitespace da árvore/índice e links
locais em 59 documentos passaram. O índice existente foi
preservado; essas validações não criaram commit nem publicação.

## Extensão nativa dos fontes Harbour em 2026-10-07

Autorizada a adoção de `.hb` para os fontes Harbour próprios. Foram renomeados
os **26** arquivos em `src/hb/`, `tests/` e `addons/`; atualizados HBP/HBM do
produto/testes, scripts de fixtures, caminhos do addon e documentação atual.
A comparação com HEAD confirmou os corpos da implementação Harbour preservados,
exceto os nomes migrados e o texto descritivo do teste do addon de exemplo.
Fontes de terceiros e compatibilidade `.prg`/`.hrb` do loader foram preservados.

A regressão Harbour Windows passou com **487 verificações, zero falhas e sem
skips**, usando fontes `.hb` e o addon de exemplo `.hb` compilado em runtime.
Logs: `tmp/tests-1c63707aa3ab435082fe50a415a0a834/results.log` e
`tmp/hb-extension-tests-20261007.log`.

O build isolado passou em `tmp/hb-extension-product-20261007/hbbridge.exe`, SHA256
`E8A06659FB8E6D319392747753D008877962C2240F1FB232D38021133C6D07CF`.
Log: `tmp/hb-extension-product-build-20261007.log`. Verificações de ajuda e
metadados de configuração passaram sem iniciar listeners; log:
`tmp/hb-extension-product-smoke-20261007.log`.

O scanner de convenções inclui `.hb` para nomes de arquivos/classes,
PascalCase e indentação de quatro espaços. Passaram a análise sintática
PowerShell, oito casos positivos/negativos das convenções e os atributos xBase.

Nos dois testes TLPP, somente o caminho do addon de exemplo foi alterado para
`examples/hbbridgesampleaddon.hb`. Eles não foram recompilados nem executados
no AppServer durante a migração local. Os relatos posteriores
de recompilação/execução abaixo superam essa pendência de regressão. O aceite
anterior do RPO usava `.prg`. Os marcos MSSQL do pacote 001 continuam pendentes.

O crivo completo da árvore passou para **141 arquivos** com `check.hb`,
`commit.hb`, `3rdpatch.hb` e convenções; log:
`tmp/hb-extension-commit-gate-20261007.log`. Links locais em **61 documentos**
e `git diff --check` passaram. O índice foi preservado; nenhum commit criado.

<a id="homologação-protheus-pelo-operador-após-a-migração-em-2026-10-07"></a>

## Homologação Protheus manual após a migração em 2026-10-07

Confirmada a recompilação após a migração `.hb`, com saída HTTP manual do AppServer
informada no chat, seguida de Query/configuração/TCP/HTTP em `F:/tmp/hbridge.news.txt`.
Relatos preservados em `tmp/protheus-http-hb-operator-20261007.log` e
`tmp/protheus-suite-hb-operator-20261007.log`; a cópia do anexo original,
incluindo a RFC OpenBao separada, está em `tmp/hbridge-news-20261007.txt`.

Os horários abaixo são de São Paulo em 2026-10-07. Os relatos mostram `marin`
em `DNA-TECH-01` e a mesma pilha `tttm120.rpo`, `tlpp.rpo` e `custom.rpo`.

| Programa | Execução informada | Resultado |
| --- | --- | --- |
| `U_HBBridgeHTTPTest` | Programa 16:10:40, thread 27296; teste 16:10:44–16:10:45 | Todos os 13 checks true/PASS, Health HTTP 200; duração 1 s. |
| `U_HBBridgeQueryTest` | Programa 16:13:33, thread 27136 | Todos os 29 checks de dataset/páginas true; perfil `sqlite_demo`. |
| `U_HBBridgeConfigTest` | Programa 16:14:06, thread 30596 | Todos os 16 checks true, incluindo `explicitProfile`, `noForcedProfile` e `invalidProfile`. |
| `U_HBBridgeConnectionTest` | Programa 16:14:31, thread 27084 | Relógio, Health, ADDON e ambos os Echo exatos de 200000 bytes aprovados; gzip da requisição fragmentada 152964 bytes. |
| `U_HBBridgeHTTPTest` | Programa 16:15:02, thread 25456; teste 16:15:03–16:15:04 | Todos os 13 checks true/PASS, Health HTTP 200; duração 1 s. |

O relógio informou `Unix=false`, delta TimeCounter **1089.987500** e medida
normalizada **1090.088100 ms** após Sleep(1000), resultado OK. O teste de
configuração revisado cobre alias SQL opcional sem forçar perfil de demonstração.
As duas execuções HTTP incluem addon, credencial rejeitada, serviços proibido/
desconhecido, recuperação e valores das páginas inicial/seguinte/final.

São execuções manuais informadas no AppServer, sem teste AppServer local nem log
de sucesso do compilador fornecido. Superam a pendência dos renomes TLPP e
dos 16 checks de configuração nos casos exercitados. Os fontes agora usam
addon `.hb` por padrão; os relatos não mostram o argumento real do módulo,
argumentos de conexão ou hash do executável servidor. Query identifica SQLite;
HTTP não identifica backend SQL e não homologa MSSQL. Endpoints alternativos,
outras plataformas, ajuste/wrap do relógio e falhas de socket provocadas mantêm
suas tarefas de homologação próprias.

Os registros EN/PT de aceite e desenho OpenBao passaram nos três validadores
de commit para **141 arquivos**; log:
`tmp/operator-acceptance-openbao-gate-20261007.log`. Links locais em **61
documentos** e whitespace aprovados. Esta atualização documental não repetiu
a suíte nativa nem acessou servidor OpenBao/MSSQL.

<a id="homologação-tcp-protheus-mssql-e-sqlite-pelo-operador-em-2026-10-08"></a>

## Homologação TCP Protheus MSSQL e SQLite manual em 2026-10-08

Informada saída de execução manual no AppServer dos dois wrappers Query.
A transcrição está preservada em `tmp/protheus-mssql-sqlite-operator-20261008.log`.
Os horários abaixo são de São Paulo em 2026-10-08; o log identifica `marin`
em `DNA-TECH-01` e a pilha `tttm120.rpo`, `tlpp.rpo`, `custom.rpo`.

| Programa | Início informado / thread | Resultado |
| --- | --- | --- |
| `U_HBBridgeQueryTestMSSQL` | 10:06:10 / 660 | Todos os 29 checks true; `Protheus OK; profile=MSSQL/pData`. |
| `U_HBBridgeQueryTestSQLite` | 10:06:43 / 3192 | Todos os 29 checks true; `Protheus OK; profile=sqlite_demo`. |

Os checks cobrem campos nomeados e decimais, campos ausentes, EOF/close,
resultados vazios, SQL inválido, perfis desconhecidos, recuperação posterior,
páginas inicial/seguinte/final/vazia, ordinais ocultos, página/ordenação
inválidas e limpeza da paginação. O registro homologa a execução manual no AppServer
do contrato TCP existente de dataset/páginas com alias MSSQL explícito,
além da regressão SQLite repetida. O relato não inclui log de sucesso do
compilador nem hashes de artefatos; essas chamadas AppServer não foram
repetidas na validação local. As fixtures nativas ampliadas mantêm suas
evidências separadas.

O aceite HTTP com perfil MSSQL passou posteriormente em 2026-10-08; veja as
[execuções HTTP com wrappers identificados](#homologação-http-protheus-mssql-e-sqlite-pelo-operador-em-2026-10-08).
Os relatos HTTP anteriores sem backend SQL identificado mantêm seu escopo
histórico.

## Homologação MSSQL nativa em 2026-10-08

O aceite Harbour opt-in executado localmente passou com **92 checks, zero
falhas e nenhum skip** no banco SQL Server real. Evidências:
`tmp/mssql-tests-b3d676f0daaf470a97af605a98a9681c/results.log` e
`tmp/mssql-native-normalized-20261008.log`.

| Componente | Valor exercitado |
| --- | --- |
| Plataforma | Windows x64. |
| Alias SQL / banco | `MSSQL/pData` / `pData`. |
| SQL Server | `16.0.1200.5`. |
| Driver ODBC | Microsoft ODBC Driver 18, `18.6.2.1`, x64. |
| Autenticação | Login SQL da configuração privada do servidor; sem credenciais nas evidências. |
| Fontes Harbour | Commit fixado `6deac9cf3ad977ae829e5bca543d553b92dd4b6d`, build multithread. |
| Zig / codepage | `0.16.0` / `UTF8EX`. |

O executável foi compilado com o núcleo compartilhado do produto. Verificou
constantes de conexão/versão/banco, campos nomeados, valores numéricos/decimais,
NULL distinto de texto vazio, data/timestamp e bit nativos, texto acentuado/CJK
e bytes Unicode exatos. As fixtures ampliadas verificaram VARCHAR e binário
com 12000 bytes, NVARCHAR com 12000 caracteres, NULs internos, limites de
blocos, emoji codificado como par substituto UTF-16 e binários vazios/NULL.
Também passaram recuperação após SQL inválido/perfil desconhecido e erros
sanitizados, páginas ordenadas com lacunas/desempate, ordinais ocultos,
restauração da área/conexão padrão do chamador, liberação explícita de conexão
e quatro chamadas concorrentes com valores isolados sob o mutex SQL existente.

Essa rodada inclui o [patch SDDODBC](../config/patches/sddodbc.patch) em staging
para leitura variável com `SQL_NO_TOTAL`, flags de campos binários e conversão
de pares substitutos UTF-16 para UTF-8. SHA256 do patch:
`F0DDE4C85F89D2A72B27040E65EB556E9E0D59838E064FB0FC2254650DA637E6`.
O registro gerenciado informa SHA256 da biblioteca
`B64952AF699A354762AD0C78DFE9BDDEED2DA12973EF652A5B9C8365E8602B5E`.
SHA256 do executável de aceite:
`6FA1AAFA04DE72C496290F456F7CB00068BC36EFC9E8EBB9AC0A6774D3DF0F69`.
A preparação aplica o patch em cópia descartável e preserva o checkout fixado;
veja [dependências](dependencies.pt-BR.md). A execução usou fixtures de
constantes somente para leitura, sem gravar tabelas ERP nem reiniciar o host.

A referência nativa executou três vezes a fixture determinística de 1000
linhas, concorrência **1**, em **31, 32 e 31 ms**, total **94 ms**. Cada medição
inclui conexão, consulta/materialização do resultado e desconexão. A memória
**não foi medida**; os tempos são referência sem limite de desempenho e não
medem os transportes TCP ou HTTP.

A regressão Harbour padrão completa passou com **566 checks, zero falhas/sem
skips**, incluindo 79 novas asserções de configuração. Evidências:
`tmp/tests-f84004277a8d4cc2905131f706a1e181/results.log` e
`tmp/mssql-full-regression-20261008.log`. O build isolado do produto passou em
`out/mssql/hbbridge.exe`, SHA256
`1F157D4099E7F954652C2AF645E4EB80DB971078D6522CC3AFF6D5DAC5715ADB`;
log: `tmp/mssql-product-final-20261008.log`. Metadados sanitizados aceitaram
os perfis MSSQL/SQLite privados e os exemplos MSSQL INI/JSON equivalentes,
sem conectar: `tmp/mssql-config-final-smoke-20261008.log`.
Os três validadores e as convenções passaram em **146 arquivos**:
`tmp/mssql-commit-gate-20261008.log`. Links locais em 61 documentos e
whitespace aprovados. Nenhum commit ou publicação efetuado.

Isso fornece a evidência nativa de valores/tipos SQL de M03, junto do aceite
TCP manual separado acima. As [execuções HTTP abaixo](#homologação-http-protheus-mssql-e-sqlite-pelo-operador-em-2026-10-08)
homologam M05 nos 13 casos exercitados. Permanecem pendentes conexão
indisponível controlada/timeout nativo (M06), isolamento mais
amplo de perfis/recursos (M07), referências de transportes/memória (M08) e
evidências AppServer/finais restantes (M09); o pacote 001 não está concluído.

<a id="homologação-http-protheus-mssql-e-sqlite-pelo-operador-em-2026-10-08"></a>

## Homologação HTTP Protheus MSSQL e SQLite manual em 2026-10-08

Informada saída de execução manual no AppServer dos dois wrappers de teste HTTP.
Evidência: `tmp/protheus-http-mssql-sqlite-operator-20261008.log`. O relato
identifica `marin` em `DNA-TECH-01` e a mesma pilha `tttm120.rpo`, `tlpp.rpo`,
`custom.rpo`. Os horários abaixo são de São Paulo em 2026-10-08.

| Programa / perfil SQL padrão | Execução informada | Resultado |
| --- | --- | --- |
| `U_HBBridgeHTTPTestMSSQL` / `MSSQL/pData` | Programa 10:33:32, thread 25976; teste 10:33:33–10:33:34 | Todos os 13 checks true/PASS, Health HTTP 200; duração 00:00:01. |
| `U_HBBridgeHTTPTestSQLite` / `sqlite_demo` | Programa 10:34:06, thread 9916; teste 10:34:07–10:34:07 | Todos os 13 checks true/PASS, Health HTTP 200; duração 00:00:00. |

Os [wrappers HTTP fornecidos](../src/tlpp/tests/protheus/hbbridge.http.test/hbbridge.http.test.tlpp)
definem explicitamente o alias SQL padrão e encaminham ao teste comum.
Mantêm a resolução existente de URL/token/timeout quando os argumentos de
transporte são omitidos. Ambos passaram em `healthGet`, `healthPost`,
`servicesGet`, `echo`, `addon`, `unknownService`, `adminForbidden`,
`unauthorized`, `afterFailure`, `queryFirstPage`, `queryFirstValue`,
`queryNextPage` e `queryLastValue`. Isso homologa M05 nos 13 casos exercitados
com `MSSQL/pData`, incluindo os valores das páginas HTTP do dataset comum,
e repete a regressão HTTP SQLite.

São execuções manuais informadas no AppServer, sem log de sucesso do compilador
nem hashes de artefatos fornecidos; essas chamadas HTTP não foram repetidas na
validação local.
As durações informadas têm resolução de um segundo e não são benchmarks.
Não homologam HTTPS/Linux nem ampliam a cobertura de tipos SQL/Unicode além
da fixture HTTP exercitada. Relatos HTTP anteriores sem backend identificado
continuam como evidência histórica. Falhas controladas e timeout nativo,
isolamento mais amplo, referências de transportes/memória e evidências finais
restantes continuam nas tarefas M06–M09.

O alinhamento documental EN/PT passou nos três validadores e convenções para
**146 arquivos**, links locais em **61 documentos** e whitespace. Log do crivo:
`tmp/http-mssql-sqlite-commit-gate-20261008.log`. Os resultados de build/
regressão nativos acima não foram repetidos nesta atualização documental.

## Extensão do dataset e falhas de integridade em 2026-10-08

Após os aceites acima, solicitado acesso mais simples aos campos
e varredura sequencial das páginas. O dataset TLPP agora inclui `MoreToRead()`,
`Header()`, seu alias de compatibilidade `DSStruct()`, `FieldInfo()`,
`FieldCount()`, `FieldName()` e `GetRow()`. `Eof()`/`Skip()` mantêm o comportamento
local à página; `MoreToRead()` busca a próxima ao atingir EOF e preserva o
erro de uma requisição malsucedida. Cabeçalho, campo e linha retornam cópias
JSON independentes. Veja [comportamento e proposta de contrato](dataset.pt-BR.md).

O novo [U_HBBridgeDataSetTest](../src/tlpp/tests/protheus/hbbridge.dataset.test/hbbridge.dataset.test.tlpp)
isolado usa cliente simulado, sem SQL, credenciais, rede ou dados ERP.
Seu relatório esperado de sucesso contém **45 checks e 17 chamadas simuladas**,
cobrindo ordem/cópias de metadados, varredura automática, verificações repetidas,
estado fechado/vazio, metadados inválidos e falha/recuperação. A tentativa local
de compilação usou `scripts/build-totvs.cmd` em 2026-10-08 às 16:31:40 de São Paulo,
thread 36788. Retornou exit 1, `COMPILEERROR-300 Failed to open repository`:
`custom.rpo` estava em uso por um usuário. O compilador informou
total/sucessos/erros `0/0/0`, portanto não compilou esses fontes. Log:
`tmp/totvs-compile.log`. Não havia scripts de parada/início configurados e o
AppServer ativo não foi parado. O novo teste de execução continua pendente;
relatos manuais anteriores do AppServer não homologam esses métodos. D02 no
[WIP](../WIP.pt-BR.md) acompanha esse aceite.

Uma prova local separada, com constantes MSSQL somente para leitura,
reproduziu falha na serialização numérica: `CAST(123.4567 AS FLOAT)` preservou
a fração nativamente, mas emitiu `123` no JSON. `DECIMAL(15,4)` emitiu
`123.4567`, e `DECIMAL(16,2)` emitiu `123.46`. Evidência:
`tmp/numeric-probe-20261008.log`. Os 92 checks nativos não exercitaram ida e
volta JSON de FLOAT fracionário sem CAST decimal; seu sucesso anterior mantém
o escopo das fixtures, sem certificar precisão numérica arbitrária.

A inspeção dos fontes também identificou que o adaptador TCP usa o padrão
`EN`/CP437 do Harbour fixado, sem selecionar `UTF8EX` como o worker HTTP, e
seu caminho JSON não tem conversão UTF-8 explícita. Relatos TCP ASCII existentes
não certificam acentos/Unicode nem equivalência TCP/HTTP. O ajuste de exibição
com `OemToAnsi()` não comprova a codificação original da coluna SQL. Essas
correções de texto/números continuam sem implementação e são acompanhadas em
D03 antes de retomar M06.

Largura/decimais do cabeçalho RDD atual não são definições de negócio da
SX3/TOP_FIELD. O Protheus deve fornecer suas regras lógicas de campos e SQL
explícito; hbBridge não deve descobrir tabelas ERP, filiais ou regras de
salário implicitamente. A análise vinculada distingue metadados de origem,
lógicos e de transmissão como evolução do contrato, não como parâmetros
adicionais já aceitos pelo serviço.

Documentação dataset/segurança e convenções dos fontes passaram pelos três
validadores de commit em **150 arquivos**, links locais em **63 documentos** e
whitespace. Log: `tmp/dataset-commit-gate-20261008.log`. Saídas do pré-processador
TLPP são ignoradas como artefatos de build. A regressão nativa completa não
foi repetida para este trabalho de navegação TLPP e documentação.

## Revisão de fontes, exemplos e extensões em 2026-10-12

Revisados commits até `344c86b`, incluindo nomes pontuados,
helpers browse/filtro/SQL no cliente e grupos de testes Protheus. Caminhos e
exemplos de API atuais foram alinhados, preservando registros anteriores.
`Header()` é canônico; configurar `SetAliasProfile()` antes de `OpenSQL()`/
`OpenPage()` com argumentos SQL. O [guia de consumidores](../examples/protheus/README.pt-BR.md)
separa fixtures de exemplos ERP/UI locais.

Correções abrangem propriedade da área SQL na abertura parcial, detalhes
seguros de erros/JSON, totais e perfil do dataset, cópias das linhas do browse,
busca/filtro tipados e escapados, callbacks e erros de compilação dos helpers/
exemplos. A seleção original era válida: `dbSelectArea(0)` escolhe uma área
livre, não a área anterior do chamador. Preservados contagem real, cálculo
constante de páginas e `COUNT_BIG` MSSQL já corrigidos.

Regressão nativa: **583 checks, zero falhas**,
`tmp/tests-79526806a38f44a6a2a34c8e0feb2202/results.log`;
wrapper `tmp/review-harbour-final-20261012.log`. A única falha da primeira
rodada era uma fixture INI contraditória que exigia presença e ausência do
mesmo alias; o teste negativo agora usa outra grafia. Novos checks exercitam
detalhes seguros/JSON, totais exatos e restauração da área anterior. Não são
novos aceites MSSQL, HTTP Protheus, Linux ou execução de interface.

O compilador inicialmente interpretou sete pastas pontuadas como arquivos,
com 19 entradas/12 sucessos/7 erros. O launcher corrigido gera lista recursiva
no formato TOTVS: linha única separada e terminada por ponto e vírgula.
Compilação final: **24 fontes, 24 sucessos, zero erros**, `custom.rpo` atualizado
em 2026-10-12 16:18:59 São Paulo, thread 3112. Log:
`tmp/review-totvs-accepted-20261012-build.log`. Parada/partida administrativas
usaram os scripts fornecidos; partida retornou zero. O processo do
compilador continua encerrando com **0xC0000409 após concluir o build**;
não se afirma encerramento limpo. Tentativas parciais anteriores não homologam
toda a árvore.

O mock dataset espera **67 checks/31 chamadas**; o teste helper espera **12
checks**. Foram compilados, sem execução nesta revisão. Browse/filtro/busca
SRA/SX5, tipos e liberação exigem aceite manual no AppServer. A fixture query executa
SELECTs constantes por padrão; o quinto argumento habilita explicitamente os
exemplos ERP fornecidos. Esta análise não leu registros de funcionários.

A [análise do brainstorming](extensions-review.pt-BR.md) registra SQLRDD,
Duktape e CCHarbour como candidatos futuros com fontes primárias. Nenhum motor,
modelo externo, adaptador DBAccess ou dependência foi instalado. UTF-8/FLOAT,
credenciais cifradas e demais critérios do pacote continuam pendentes no WIP.

Os três validadores passaram em **170 arquivos**; links locais em **67
documentos** e whitespace aprovados. Log:
`tmp/review-commit-gate-final-20261012.log`. Disponibilidade após partida
verificada nas portas locais **5555, 7890, 1234 e 4321**. Índice existente
preservado; esta revisão não efetuou commit/publicação.

## Tabela HTTP FWWebEx: validação confirmada em 2026-10-13

Confirmada a validação do exemplo interativo de tabela HTTP como OK, com
seis capturas no [README do exemplo](../src/tlpp/tests/protheus/hbbridge.http.table.test/README.pt-BR.md).
Os artefatos foram conferidos localmente; registram execução manual informada no AppServer.

| Cenário visível | Resultado registrado |
| --- | --- |
| SX5 sem filtro | 11.764 registros; telas de 5 e 10 linhas com controles de paginação. |
| Pesquisa global SX5 | `TIPOS DE IMPOSTOS`: 1 registro, filtrado de 11.764. |
| Igualdade por campo SX5 | Description `TIPOS DE IMPOSTOS`: 1 registro, filtrado de 11.764. |
| Fixture constante | 10 linhas exibidas de 12; `O'Brien`, `100%_done` e `<b>literal text</b>` apresentados como texto. |
| Pesquisa global na fixture | `Harbour`: 1 registro, filtrado de 12. |

As descrições SX5 também mostram acentos nesses exemplos. Isso não conclui
a correção UTF-8/FLOAT mais ampla de D03. Protheus resolve perfil/tabela/
filial da SX5; hbBridge permanece executor genérico.

F01 preparatório do WIP está homologado nas telas demonstradas. O mock da
tabela HTTP tem aceite próprio abaixo. Dataset 67 checks/31 chamadas e
helpers 12 checks têm validação posterior no próximo registro. O exemplo
não exercita varredura automática/cópias/falhas exigidas em D02. As capturas
não identificam perfil/backend efetivos, horário, build de compilação ou
artefato do servidor; não são novos aceites desses atributos nem de M06–M09.

## Validação da regressão da tabela HTTP em 2026-10-13

Confirmada a execução manual de `U_HBBridgeHTTPTableTest` às **17:46:56 São Paulo**
(20:46:56 UTC), thread AppServer **27708**: **71 checks, todos PASS, zero falhas**;
resultado final `hbBridge HTTP table checks: 71; OK`.
Resumo do resultado recebido em `tmp/http-table-manual-20261013-174656.summary.txt`.

A rodada anterior às 08:16:18, thread 36400, registrou 62 checks e três falhas:
`rejectNulFilter`, `successAfterServiceFailure` e `missingTotalsAreVisible`.
A validação de filtros agora lê os valores originais antes de qualquer ciclo
JSON; a entrada referenciada é preservada. O mock usa cursor próprio de respostas,
impedindo que uma chamada inesperada pule uma fixture futura ou mascare resultados.

A rodada homologada cobre rejeição de NUL no início, meio e fim e como único
byte em filtros/pesquisa, preservação dos bytes de entrada, recuperação de
consulta, totais/erros e os checks existentes de páginas/filtros/ordem/projeção.
`noUnexpectedMockCalls` e `allQueuedResponsesConsumed` passaram; a fixture
contém **19 respostas enfileiradas**.

Linhas adicionais registram handshake com erro 10054 na thread 13968; o teste
termina com 71 PASS. Este registro não diagnostica essa conexão nem o TLS.
É um teste de contrato com mock, sem chamadas HTTP ou SQL reais.
F02 concluída. D02 tem validação posterior do dataset/helpers abaixo;
UTF-8/FLOAT em D03 permanece pendente.

## Validação do dataset e helpers em 2026-10-13

Confirmada a validação manual no AppServer, horário de São Paulo:

| Entrada | Início / thread | Resultado |
| --- | --- | --- |
| `U_HBBridgeDataSetTest` | 17:56:23 / 32332 | Todos os 67 checks true; 31 chamadas mock; `Protheus OK`. |
| `U_HBBridgeHelperTest` | 17:56:45 / 28300 | Todos os 12 checks true; `Protheus OK`. |

Resumo: `tmp/dataset-helper-manual-20261013.summary.txt`. São resultados
manuais recebidos, sem nova execução local nem novo log de sucesso do compilador.

O dataset homologa cópias de campos/cabeçalho/linhas e ordem das colunas,
EOF/Skip locais à página, varredura automática `MoreToRead()`, idempotência,
estados vazio/fechado, falha/recuperação de página, validação de metadados e
totais, página anterior e ciclo de perfil/resultado. O nome histórico do check
`dsStructDefensiveAlias` exercita cópias `Header()`/`FieldInfo()`; nenhum método
`DSStruct()` foi restaurado. Helpers homologam qualificação SQL sem modificar
literais/comentários, substituições e as expressões tipadas de filtro preparadas.

D02 concluída. Estes resultados mock/helpers não fazem chamadas SQL ou HTTP
reais; D03 ainda exige correções e homologação UTF-8/FLOAT nativas. O log
também registra handshake com erro 10054 na thread 34420; o helper termina OK.
Esses testes não diagnosticam a condição da conexão/TLS. Retomar D03 e depois
M06–M09; o pacote 001 permanece aberto.

## Falhas e recuperação SQL nos transportes em 2026-10-13

Após o adiamento explícito de addons de metadados/políticas decimais automáticas,
M06 foi retomada de forma independente. Reescrita SQL para CAST opcional permanece
como proposta registrada; CAST no chamador mantido e D03 UTF-8/FLOAT sem homologação.

O runner Harbour isolado no Windows passou em **615 checks, zero falhas, sem
skips**, acrescentando **32 asserções** à regressão anterior de 583 checks:

- SQL inválido, perfil desconhecido, banco SQLite ausente e DSN ODBC sintético
  ausente por NETIO nativo, TCP/JSON e ambas as rotas HTTP RPC/REST.
- Envelope exato de quatro campos em inglês, sem dataset parcial, SQL,
  caminhos ou credenciais fictícias de conexão. Erros HTTP mantêm status 500.
- SELECT constante aprovado imediatamente após cada falha, incluindo reuso
  da mesma conexão NETIO; HTTP RPC/REST recuperam em suas próprias rotas.
- Checks defensivos do resultado de recuperação registram respostas malformadas
  como falhas das asserções.

Log final: `tmp/tests-fa36c9bc67ca4f0089f3b49edc2642b7/results.log`;
wrapper de compilação: `tmp/review-m06-final-20261013.log`, saída 0. Data da
rodada: 2026-10-13 São Paulo / 2026-10-14 UTC. Revisão preliminar passou em
611 checks; rodada final acrescenta recuperação RPC imediata e checks de estrutura.

Fixtures usam diretórios de teste próprios, listeners locais efêmeros e
credenciais fictícias. A rodada não inclui conexão MSSQL real, serviços
instalados nem execução AppServer. DSN ausente comprova falha de conexão no
Driver Manager, sem simular indisponibilidade de um SQL Server real. Naquela
revisão, M06 continuava aberta para MSSQL real e AppServer controlados, e o
SDDODBC gerenciado não configurava timeout de login/statement nem API de
cancelamento. Orçamento de socket não comprovava cancelamento SQL. O registro
seguinte de [2026-10-14](#sql-native-timeouts-and-appserver-recovery-on-2026-10-14)
acrescenta timeouts nativos e aceite AppServer real; desconexão durante leitura
continua como evolução separada.

<a id="sql-native-timeouts-and-appserver-recovery-on-2026-10-14"></a>

## Timeouts SQL nativos e recuperação AppServer em 2026-10-14

M06 homologada para SQL inválido, perfil desconhecido, conexão indisponível
controlada, timeout nativo aplicável, erros sanitizados e recuperação imediata
nas rotas Windows escolhidas. D03 UTF-8/FLOAT bruto continua aberta;
addons de metadados e reescrita automática SQL para CAST permanecem adiados.
O pacote 001 prossegue com M07, verificação de recursos/concorrência.

| Execução | Resultado / evidência |
| --- | --- |
| Regressão Harbour padrão isolada | **636 checks, zero falhas**, saída 0; `tmp/tests-12c300f8399948e3bb3c20ee13eacc2d/results.log`, wrapper `tmp/review-m06-regression-20261014.log`. |
| Falhas MSSQL reais opt-in | **46 checks, zero falhas/sem skips**, saída 0; `tmp/mssql-tests-e22aaf15b69e44ad806a5316060438ec/results.log`, wrapper `tmp/review-m06-mssql-verified-20261014.log`. |
| Nova rodada do aceite MSSQL existente | **92 checks, zero falhas/sem skips**, saída 0; `tmp/mssql-tests-c49ac62b333d4c9d8e94aabf5134cb1b/results.log`. |
| Recompilação completa TLPP | Relatório do compilador AppServer: **30 fontes, 30 sucessos, zero erros**, 08:23:38 São Paulo, thread **32272**; `tmp/totvs-compile.log`. |
| AppServer local CLI TCP | **38 checks, zero falhas**, saída 0, 08:28:56–08:29:12 São Paulo, thread **29120**; `tmp/m06-protheus-tcp-clean-output-20261014.log`. |
| AppServer local CLI HTTP | **51 checks, zero falhas**, saída 0, 08:28:13–08:28:29 São Paulo, thread **21392**; `tmp/m06-protheus-http-output-20261014.log`. |

As execuções TLPP reais usam `-run=U_HBBridgeFailureCLI -env=PROTHEUS`, com
argumentos explícitos de transporte/perfil contra uma fixture Harbour isolada.
Executam as classes cliente reais no AppServer/RPO e **21 chamadas de serviço
por transporte**, incluindo chamadas do dataset. É execução local por CLI,
separada das execuções manuais WebApp informadas anteriormente. O AppServer
identifica **24.3.1.5**, build **7.00.240223P-20260211**, x64. Veja o
[guia dos testes de falha](../src/tlpp/tests/protheus/hbbridge.failure.test/README.pt-BR.md)
para entradas reproduzíveis.

A nova rodada dos 92 checks identifica SQL Server **16.0.1210.3**, banco
**pData**, Harbour `UTF8EX`, com perfil privado `MSSQL/pData`. A versão SQL
Server difere do relato histórico de 2026-10-08 (`16.0.1200.5`); ambas as
observações datadas permanecem registradas. O conector escolhido é
**Microsoft ODBC Driver 18 for SQL Server**, x64; o driver instalado
identificado durante o pacote é **18.6.2.1**. Credenciais permanecem na
configuração privada, ausentes do repositório e da saída de homologação.

### Fixture de falhas controladas e comportamento observado

- Um `SELECT 77 AS RECOVERY_ID` constante comprova a conexão MSSQL real antes
  das asserções de falha. Cada falha de serviço/dataset é seguida por uma
  consulta constante bem-sucedida.
- `m06/refused` usa porta TCP efêmera loopback mantida reservada por socket
  vinculado sem escutar, Driver 18 explícito, credenciais fictícias e opções
  nativas de login/consulta de um segundo. Comprova recusa de conexão controlada
  sem parar SQL Server nem alterar DSN/credencial existente; não testa queda
  efetiva de SQL Server nem expiração de login sem resposta.
- `m06/query-timeout` copia o perfil funcional com timeout nativo de consulta
  de um segundo. O lote SQL usa `WAITFOR DELAY '00:00:04'` antes do SELECT
  constante; um orçamento cliente de pelo menos sete segundos distingue
  o limite SQL nativo do timeout de transporte.
- Uma instrução nativa direta com timeout de consulta `0` explícito conclui
  o controle limitado de quatro segundos. Com timeout `1`, ODBC nativo
  informa `HYT00` e termina antes daquele controle. Asserções local/NETIO/TCP/HTTP
  confirmam a falha temporizada e recuperação seguinte. Os dois transportes
  TLPP reais também aprovam o check de prazo nativo (pelo menos 500 ms e abaixo
  de 4000 ms).
- Envelopes exatos de quatro campos em inglês preservam erros fixos do serviço
  e diagnósticos numéricos seguros. Omitem SQL, credenciais, caminhos de dados
  e cabeçalhos/linhas/totais parciais. Falhas HTTP retornam 500; consultas
  recuperadas retornam 200. Datasets com falha removem resultados/metadados/
  paginação anteriores e encerram `MoreToRead()`; reabrir retorna a constante.
  O teste real não conta/simula chamadas cliente para provar ausência de
  tentativas automáticas; essa asserção mantém a evidência anterior do mock
  de dataset com 67 checks.

### Opções nativas e procedência dos artefatos

`LoginTimeoutSeconds`/`QueryTimeoutSeconds` no perfil MSSQL (JSON
`loginTimeoutSeconds`/`queryTimeoutSeconds`) são opcionais. A omissão preserva
o padrão do driver; zero explícito desativa o timeout nativo correspondente.
Os 21 checks adicionais da regressão padrão aceitam omissão/zero/máximos
nativos e rejeitam tipos inválidos, frações, negativos e overflow nas duas
formas de configuração. Veja as [faixas exatas e a configuração](configuration.pt-BR.md#native-mssql-timeouts).

O [patch SDDODBC gerenciado](../config/patches/sddodbc.patch), verificado por
checksum, define e lê de volta os atributos ODBC explícitos: login antes da
conexão e novamente depois dela; consulta antes de cada instrução. Falha na
definição/leitura ou substituição pelo driver provoca falha e liberação dos
handles. Inclui os caminhos de abertura de consulta/execução nativa; busca
da página e sua contagem separada recebem, cada uma, seu timeout de consulta.
O checkout Harbour fixado permanece intacto. O registro gerenciado da primeira rodada homologada identifica
revisão Harbour `6deac9cf3ad977ae829e5bca543d553b92dd4b6d`, SHA256 do patch
`90B2B1EA3C6C895B677C3ACC42AD256C58734DD7ECE3D1C381E7BE6FE812F5F1`
e SHA256 da biblioteca
`01871BF984468CE83230901302FB8CE2B2CEE9B053839A99667222E554164FBB`.
SHA256 do executável homologado com 46 checks:
`FB89E787D12991D70717900646C55F3D12D085158264F674F3BE06F274FFED17`.
Detalhes do staging/registro estão em [dependências](dependencies.pt-BR.md).

O driver aplica cada timeout nativo de instrução. Conexão, espera pelo mutex
SQL, instruções separadas, materialização, JSON e transferência de rede não
compartilham um prazo de requisição. Timeout/desconexão do cliente sozinho
não comprova cancelamento SQL; API explícita de cancelamento hbBridge e aceite
de desconexão durante leitura continuam futuros. O mutex do ciclo de vida SQL
permanece preservado. Esses resultados Windows loopback não acrescentam aceite
GUI, HTTPS, Linux, outros drivers nem correção de FLOAT bruto.

### Rodada informada no host comum e pré-requisitos da fixture

O log fornecido registra `U_HBBridgeTCPAndHTTPFailureTest` em 2026-10-14
às 12:06:05 São Paulo, thread 4728: TCP **38 checks / sete falhas** e
HTTP **51 checks / sete falhas**. Outra rodada CLI, thread 42740, também
informa TCP 38/sete. Essas rodadas não estão homologadas. Usam o host comum
nas portas 1512/8080 em vez do launcher isolado de falhas. O INI privado
contém apenas `sqlite_demo` e `MSSQL/pData`; consultas HTTP constantes aos
aliases `m06/refused` e `m06/query-timeout` retornaram **500 / PROFILE_NOT_FOUND**
em ambos. Alias ausente não exercita conexão recusada nem timeout nativo de
consulta; as sete asserções falham por esse pré-requisito ausente. Evidência
sanitizada: `tmp/protheus-failure-reported-20261014.log`; o original permanece
fora do Git e o token HTTP foi ocultado na cópia local.

Repetir com `-Failures -Serve`, driver explícito e endpoints TCP/HTTP informados
pelo launcher. A fixture cria os aliases em memória e reserva a porta recusada
sem escutar. Não copiar credenciais SQL reais para perfis de demonstração nem
presumir que o host comum tenha esses aliases exclusivos do teste. O
[guia](../src/tlpp/tests/protheus/hbbridge.failure.test/README.pt-BR.md)
registra o comando completo. O teste revisado informa diagnóstico fixo de
pré-requisito quando falta um alias obrigatório da fixture. A entrada combinada
foi preservada; removidos reflexão/dumps de parâmetros para não imprimir o token.

Após esses ajustes de fonte, os **30 fontes TLPP compilaram com zero erros
de fonte** em 2026-10-14 às 13:09:29, thread 24144. As novas rodadas CLI passaram:
TCP **38/zero**, 13:10:46–13:11:02, thread 41452, e HTTP **51/zero**,
13:11:59–13:12:14, thread 10404; ambas com saída 0. Evidências:
`tmp/m06-protheus-tcp-updated-output-20261014.log` e
`tmp/m06-protheus-http-updated-output-20261014.log`. O processo do compilador
encerra com **0xC0000409 após o relatório concluído de build**, como na rodada
anterior; compilação dos fontes e execução posterior do RPO não homologam
saída normal do processo compilador. O reinício TOTVS configurado terminou
com saída 0 e porta 4321 disponível.

O gate final de commit aprova **186 arquivos** nos três validadores. Os
marcadores vazios de contexto do patch SDDODBC foram normalizados para atender
o check de espaços finais. O patch normalizado aplica com sucesso e produz
o mesmo fonte C testado após normalização das quebras de linha. O registro
gerenciado final tem SHA256 do patch
`4E8F24D6482A93585AD021DD7EEC9631C472A4BDA225240206F83C5302C4B9BE`
e da biblioteca
`68D9B00215ED11AA8DEEFD4F59C252E181B03659ABED06E35C4805FC45A85651`.
Os hashes anteriores identificam os artefatos da primeira rodada homologada.

<a id="manual-protheus-failure-recovery-on-2026-10-14"></a>

## Validação manual Protheus de falhas/recuperação em 2026-10-14

Confirmada a execução manual no AppServer de `U_HBBridgeTCPAndHTTPFailureTest`
em **2026-10-14 às 14:30:50 São Paulo**, thread **13796**. O log fornecido
contém **38 checks TCP PASS e 51 HTTP PASS**, correspondentes aos dois resumos
`failures=0; OK`. Homologada a execução manual dos casos M06 listados, resolvendo
as sete falhas por transporte da rodada anterior no host comum. As rodadas
anteriores sem aprovação permanecem como evidência histórica.

Os checks homologados abrangem SQL inválido, perfil desconhecido, conexão
indisponível, timeout nativo de consulta, envelopes de erro seguros, ausência
de resultado parcial, recuperação do serviço, limpeza/parada/reabertura do
dataset e filtragem de diagnósticos. HTTP também verifica status de erro e
recuperação. Os dois checks `queryTimeoutNativeDeadline` passaram. A rodada
real não conta requisições na rede; o mock de dataset de 67 checks mantém a
evidência separada de ausência de novas tentativas automáticas.

Evidência: `tmp/protheus-failure-manual-20261014-143050.log`, cópia exata em bytes do log fornecido.
O trecho não contém valores de credenciais; diagnósticos nativos e contexto
local de execução foram preservados no artefato local ignorado pelo Git.
Registradas nove linhas nativas com erro 10054 e outro diagnóstico SSL
`onSend`. Sua causa, associação a conexões e resolução não foram estabelecidas;
os 89 checks hbBridge reportam PASS. Isso não homologa handshake TLS sem
falhas nem transporte HTTPS.

Não foram fornecidos horário de término do programa, duração precisa, forma
de acionamento, argumentos explícitos, hash do artefato servidor ou novo
resultado de compilação. A rodada não homologa concorrência M07, desempenho
M08 nem integridade UTF-8/FLOAT ampliada. A próxima tarefa do WIP permanece
**M07**, e integridade D03 continua pendente.

<a id="sql-concurrency-and-release-on-2026-10-14"></a>

## Concorrência SQL e liberação de recursos em 2026-10-14

Homologada M07 no Windows com o perfil privado funcional `MSSQL/pData` e
fixtures SQLite isoladas. SQL Server havia sido identificado como 16.0.1210.3;
mantidos SDDODBC gerenciado e mutex do ciclo SQL. Usados somente SELECTs
constantes MSSQL e arquivo SQLite próprio do teste. Sem alterar sincronização
do produto, pooling, credenciais ou regras ERP.

| Execução | Workers / chamadas | Checks / falhas |
| --- | --- | --- |
| Nativo local, NETIO, TCP e HTTP | 8 / 192 | 458 / 0, sem skips |
| AppServer CLI TCP e HTTP | 4 / 112 | 417 / 0 |

A suíte nativa sincroniza oito workers, dois por rota, em três rodadas sobre
o alias funcional, `m07/mssql-clone` e `m07/sqlite`. Schemas, drivers e valores
por worker/rodada distintos detectam mistura de perfis. Checks abrangem leitura
sem páginas, primeira/última/página vazia e COUNT independente, SQL inválido,
colunas ambíguas, perfil desconhecido e recuperação. Áreas/conexão padrão do
chamador permanecem intactas e sua fixture continua legível. Conexões próprias
retidas desconectam após joins; os primeiros slots RDDSQL livres são reutilizados
antes/depois da rodada. O endpoint NETIO é liberado após todos os empréstimos.
O host isolado encerra com listeners parados e zero workers ativos.

A primeira rodada nativa teve uma falha de fixture entre 457 checks: esperava
que cada ponteiro NETIO emprestado fosse dono de uma desconexão do endpoint.
O pai passou a manter uma referência, liberá-la após os joins e conferir cache
vazio. A rodada corrigida passou em 458 checks, saída 0. Evidências:
`tmp/mssql-tests-e914432a7e5d49cc99b76cbb948605a1/results.log` e
`tmp/review-m07-concurrency-final-20261014.log`. Hosts isolados repetidos também
passaram nos 458 checks, incluindo limpeza final, antes de encerrar com saída 0.

`U_HBBridgeConcurrencyCLI` inicia dois StartJobs TCP e dois HTTP no AppServer.
Cada um possui cliente/dataset/JSON próprios, alterna MSSQL/SQLite em quatro
etapas e emite 28 chamadas. Passaram provas reais de backend/schema, páginas/
totais exatos, snapshots defensivos, falhas/recuperação e limpeza de estado
anterior. Registrados quatro workers distintos: 9712, 16572, 27392 e 24384;
o coletor era thread 24480. Publicação sucede liberação dos objetos; o pai
confirma os relatos e espera a limpeza final das chaves compartilhadas.
`StartJob` não expõe handle de join: registra-se conclusão lógica, sem join nativo.

Compilação às **18:15:58 São Paulo**, thread 17484, informou **32 fontes,
32 sucessos, zero erros**. Seu processo retornou posteriormente `0xC0000409`
(-1073740791), registrado separadamente da compilação dos fontes. O CLI do
teste seguinte terminou com **saída 0**, relatou 417 checks/zero falhas às
**18:18:12** e encerrou às **18:18:24**, sem THREAD ERROR ou exceção de shutdown.
Scripts de parada/início retornaram 0 e o listener comum do AppServer voltou.
Removido INI CLI isolado; INIs privados regulares permaneceram intactos.
Evidências: `tmp/totvs-m07-baseline-compile-20261014.log`,
`tmp/m07-totvs-build-result-20261014.json`,
`tmp/m07-protheus-concurrency-final-output-20261014.log` e
`tmp/m07-protheus-concurrency-final-20261014.log`.

A rodada CLI anterior relatou 416 checks/zero falhas de assertivas, mas depois
levantou `Application Server is Shutting Down` enquanto um worker aguardava
confirmação da coleta. Não foi homologada como ciclo limpo. O marcador final
no wrapper do worker e a barreira de conclusão do pai resolvem essa corrida
reproduzida do teste; a repetição bem-sucedida de 417 checks é o aceite.

### Carga manual adicional e diagnóstico em andamento

`HBBridgeConcurrencyTest.txt` fornecido contém relatos completos de 4, 40 e
100 workers, zero falhas e 112, 1120 e 2800 chamadas respectivamente. A rodada
de 100 tem threads reportadas distintas e tempos por worker de aproximadamente
31,94 a 49,72 segundos. Incluem espera e execução completa do worker, sem
representar latência por query ou medições de memória M08. Cópia da evidência:
`tmp/protheus-concurrency-manual-20261014.txt`.

Aumentar a constante mantém dois jobs TCP; os demais usam HTTP (38 e 98,
respectivamente). Não são cargas equilibradas entre transportes. O resumo
anterior fixava os checks do pai em 29, subcontando assertivas nos números
impressos 4413/11073: são 6 por worker e 5 compartilhadas. O relatório agora
conta as chaves JSON reais do pai. Sem mudar a distribuição, rodadas completas
de 40/100 workers informariam 4629/11649 checks. Novos diagnósticos de etapa/
workers pendentes distinguem início/prontidão, coleta e liberação, sem imprimir
tokens ou descrições brutas de exceções. A compilação/validação posterior e os
logs falhos de 140 workers estão registrados abaixo. Não se deduz limite do produto.

Reuso de handles e desconexão lógica não provam fechamento físico de sessões
ODBC nem ausência de vazamentos de heap/rede. Mantido mutex: chamadores
concorrentes podem aguardar enquanto ciclos SQL executam sequencialmente.
Linux, HTTPS, cancelamento, pooling e D03 UTF-8/FLOAT mantêm aceites próprios.
Permanece homologada a baseline de isolamento/ciclo exercitado; a carga
adicional reabre M07 antes das medições M08. Veja
[guia Protheus](../src/tlpp/tests/protheus/hbbridge.concurrency.test/README.pt-BR.md)
e [análise de reuso](sql-connections.pt-BR.md).

<a id="sql-concurrency-follow-up-on-2026-10-15"></a>

## Complemento de concorrência HTTP em 2026-10-15

A carga adicional reabre M07 após a baseline homologada de oito workers
nativos e quatro jobs AppServer. A baseline permanece, sem homologar 140
chamadores. O log anterior de 140, coletor thread 2680 em 2026-10-14, contém
140 relatos/3920 chamadas: 833 assertivas HTTP falhas, todas na etapa 4, e
136 checks do pai indicando workers com falhas, total 969. Os dois TCP passam
nos 83 checks; passam os checks de leitura/página/schema/valores anteriores
às operações finais de erro/recuperação. O número impresso 15513 usa a
contagem antiga fixa do pai, sem representar o total real. Evidência:
`tmp/protheus-concurrency-manual-140-20261014.log`.

O log posterior começa em 2026-10-15 **07:33:53.921 São Paulo**, coletor thread
34240, com **140 workers (2 TCP/138 HTTP), timeout 150 segundos por chamada e
coleta 120000 ms**. READY passa às 07:33:55.906; coleta termina exatamente às
**07:35:53.971**, informando **10002 checks, 894 falhas, 83 relatos coletados,
FAILED**. Alguns jobs registram depois. O trecho não contém THREAD ERROR.
Não é homologação bem-sucedida de 140 workers. Evidência:
`tmp/protheus-concurrency-manual-latest-20261015.log`.

Há 336 diagnósticos de resposta, todos na etapa 4: 204 com status HTTP 0 e
código UNRECOGNIZED. Os demais 132 mantêm status 200/500. Tempos entre
0,0223 e 34,0541 ms. Algumas operações posteriores ao ABORT não emitem
requisição; seu status/código anterior fica retido, e tempo submilissegundo
não é latência HTTP. Falhas rápidas anteriores ao prazo de coleta continuam
sem causa estabelecida; aumentar só o timeout por chamada não as resolveu.

A repetição CLI local de diagnóstico em 2026-10-14 também falhou: 113 relatos
coletados, 13332 checks/937 falhas e 27 erros de shutdown posteriores nos jobs.
A repetição de quatro passou em 417 checks, saída 0. Evidências:
`tmp/m07-protheus-diagnostics-140-output-20261014.log` e
`tmp/m07-protheus-diagnostics-4-output-20261014.log`. São rodadas distintas;
o sucesso com quatro não pode ser atribuído ao caso de 140.

O teste agora aceita quantidade de workers no argumento 8 (`--workers`) e
orçamento independente de coleta em segundos no argumento 9 (`--budget-seconds`).
Padrões mantidos em 4 e 120. Marca jobs pendentes antes do lançamento,
verifica ABORT após cada chamada, para sem interpretar chamadas não emitidas
e espera limpeza dos workers separadamente antes de apagar as chaves. O prazo
dessa espera é timeout por chamada mais 10 segundos; não cancela SQL nativo
nem implementa join nativo de StartJob.

Os controles atuais compilaram em 2026-10-15: **32 fontes, 32 sucessos, zero
erros**. O compilador voltou a retornar `0xC0000409` após concluir o relatório;
stop/start saíram com 0. A validação em execução é distinta:

| Rodada CLI controlada | Resultado |
| --- | --- |
| 4 workers, orçamento normal | 417 checks / 0 falhas, saída 0 |
| 4 workers, coleta deliberadamente insuficiente de 1 segundo | Falha esperada, 29 checks / 27 falhas, limpeza concluída, saída 1 sem THREAD ERROR |
| 140 workers, chamada 30 segundos / coleta 300 segundos | 140 relatos coletados, 16329 checks / 857 falhas, saída 1 sem THREAD ERROR |

Evidências: `tmp/m07-protheus-budget-4-output-20261015.log`,
`tmp/m07-protheus-abort-4-output-20261015.log` e
`tmp/m07-protheus-budget-140-output-20261015.log`. Corrigir a limpeza do teste
não resolveu a falha de transporte. A comparação isolada de backlog HTTP
também falhou nas duas opções: backlog 10 teve 1433 falhas, e a solicitação
`SOMAXCONN` teve 1010, ambas entre 16329 checks/140 relatos. São rodadas
distintas, sem comprovar melhoria de capacidade por mudar backlog. Os dois
hosts nativos isolados passaram nos 458 checks, inclusive shutdown.
Evidências: `tmp/m07-protheus-backlog10-140-output-20261015.log`,
`tmp/m07-protheus-somax-140-output-20261015.log` e seus logs nativos.
Regressão Harbour após configurar backlog: **656 checks / 0**, saída 0,
`tmp/m07-backlog-regression-final-20261015.log`.

O arquivo atual fornecido é um esboço de pool com falha de login ODBC
**10048/08001** no DBAccess, sem representar nova rodada bem-sucedida. Os
eventos System **Tcpip 4227** às **07:35:03 e 08:41:55 São Paulo** registram
falha ao alocar endpoint local de saída usado recentemente. Uma captura
contou 15264 conexões `TIME_WAIT`; a faixa IPv4 dinâmica é 49152–65535.
Estabelece pressão sobre reuso de portas no host, sem atribuir cada falha ou
porta ao hbBridge ou DBAccess. Evidências:
`tmp/protheus-concurrency-pool-proposal-20261015.txt` e
`tmp/m07-port-pressure-events-20261015.json`. Nenhuma opção TCP do SO foi
alterada. Os argumentos finais `150*10,120,150*10` significam timeout de
1500 segundos por chamada, 120 workers e coleta de 1500 segundos. Aumentar
o prazo não reduz criação de conexões físicas.

M07 permanece aberta. A próxima adaptação medida é reuso físico ODBC,
mantendo mutex SQL e propriedade lógica do chamador; reuso HTTP/TCP é
outra etapa. Veja a [revisão do desenho](sql-connections.pt-BR.md).

<a id="manual-protheus-concurrency-130-on-2026-10-15"></a>

## Rodada manual detalhada de 130 workers em 2026-10-15

Analisado o arquivo separado `HBBridgeConcurrencyTest_130.txt`, preservado
como `tmp/protheus-concurrency-manual-130-20261015.log`, SHA-256
`A507584F449BD08395DE6C94351529F2238EA72AD98CE6A707CD615061FD6C38`.
Contém todos os **130 relatos**, **130 IDs de thread distintos** e **3640
chamadas RPC reportadas**: dois workers TCP/56 chamadas e 128 workers
HTTP/3584 chamadas. O total de **15159 checks** reúne 14374 checks dos
workers e 785 do pai. A rodada falhou em **41 checks**.

As 41 falhas correspondem a **13 requisições HTTP recusadas**, todas na etapa 4:

| Operação | Requisições recusadas | Assertivas dos workers falhas |
| --- | --- | --- |
| Requisição com perfil desconhecido | 7 | 21: unknownProfile, unknownClears, unknownHTTPStatus |
| Recuperação após perfil desconhecido | 6 | 12: recoveryAfterUnknown, unknownRecoveryHTTPStatus |
| Agregação zeroFailures do pai | Nenhuma requisição adicional | 8, uma por worker afetado |

Os workers HTTP afetados foram 9, 13, 29, 41, 58, 75, 97 e 126. Os dois
TCP e os outros 120 HTTP informaram zero falhas. Todos os 13 diagnósticos
de resposta têm status **0**, código **NATIVE_REFUSED_DIAGNOSTIC** e duração
medida de **5,7892–34,1813 ms**. As sete chamadas de perfil desconhecido deveriam
receber PROFILE_NOT_FOUND/HTTP 500 antes de adquirir conexão SQL; essas
recusas são falhas de transporte, sem comprovar serviço não suportado ou SQL
de negócio incorreto. As seis recuperações esperavam HTTP 200. Os oito checks
do pai resumem os mesmos workers; não são oito novas requisições falhas nem
checks posteriores ao resumo final.

O lançamento foi registrado às **17:59:38.935 São Paulo**; todos ficaram READY
às **18:07:36.699** e o resumo final saiu às **18:09:41.514**. Foram **477764 ms**
do lançamento à prontidão e **124815 ms** da prontidão ao resumo. Todas as
recusas ocorreram entre **18:09:03.526 e 18:09:03.986**, intervalo de **460 ms**.
O timeout por chamada era **2100 segundos**, com orçamento total de
**2100000 ms**; nenhum explica as recusas rápidas. Se a rampa era 300/50/5000 ms,
suas pausas planejadas de 431450 ms deixariam 46314 ms de custo de lançamento/
prontidão, mas esse log anterior não registra os parâmetros de espaçamento.

Não há THREAD ERROR, erro de execução do pai, diagnóstico de pendência/
limpeza, erro DBAccess ou de fechamento de conexão SQL nesse log. Não contém
hash do binário, política de pooling ou identificação da adaptação nativa.
O diagnóstico de recusa não estabelece a causa subjacente no host/rede.
Preservar a rodada falha separadamente dos resumos aprovados posteriores.

<a id="manual-protheus-concurrency-on-2026-10-15"></a>

## Concorrência manual Protheus com espaçamento em 2026-10-15

O arquivo posterior `HBBridgeConcurrencyTest.txt` contém o exemplo de chamada
e seis pares de lançamento/resumo final. Seus bytes originais foram preservados
em `tmp/protheus-concurrency-manual-current-20261015-f067c9d9.log`, SHA-256
`F067C9D9747FF12AC0FADC6D799C9EE16440FF1AD9026984CB804171E65FBE1E`.
Todos os resumos informam coleta dos jobs esperados e **zero falhas**:

| Workers coletados/esperados | Checks / falhas | Timeout por chamada / orçamento total, segundos | Pausas planejadas, ms |
| --- | --- | --- | --- |
| 5 / 5 | 534 / 0 | 100 / 100 | 2250 |
| 15 / 15 | 1704 / 0 | 200 / 200 | 10500 |
| 20 / 20 | 2289 / 0 | 250 / 250 | 16500 |
| 30 / 30 | 3459 / 0 | 350 / 350 | 32250 |
| 150 / 150 | 17499 / 0 | 1550 / 1550 | 531450 |
| 500 / 500 | 58449 / 0 | 5050 / 5050 | 2281450 |

Os seis resumos somam **83934 checks, zero falhas**, com **720 jobs em
rodadas separadas**. Todas as contagens correspondem a `117 * workers - 51`.
Cada rodada destina dois workers ao TCP e os demais ao HTTP; a maior tem dois
TCP/498 HTTP. Pelo contrato de 28 chamadas por worker, os resumos implicam
**20160 chamadas RPC**, incluindo 14000 na rodada de 500; as contagens
individuais de chamadas não constam desse trecho.

Os seis lançamentos registram espaçamento explícito **300/50/5000 ms**.
O plano de 500 workers inclui **2281450 ms (38 minutos e 1,45 segundo)** de
pausas dentro do orçamento de **5050 segundos**. São pausas planejadas e prazos
configurados, sem representar medições de duração real. A criação dos jobs
recebe espaçamento; a barreira READY/GO ainda libera as requisições em conjunto.

Registrado aceite manual no escopo exercitado desses resumos com espaçamento,
incluindo as rodadas aprovadas de 150 e 500 workers. O trecho não contém
relatos individuais, IDs de thread, horários READY ou evidência de saída
final do processo; esses detalhes não podem ser auditados separadamente.
Não há linhas de mismatch, checks falhos ou THREAD ERROR no texto fornecido;
sua ausência desse resumo não equivale a um rastro completo de término das
threads. Os campos explícitos registram execução da revisão de relatório,
sem fornecer novo recibo de compilação ou identificar binário servidor,
política ODBC ou implementação do pool SQL. Não atribuir esse resultado à
adaptação nativa de reuso físico sem essas evidências.

As falhas anteriores de 130/140 workers permanecem evidências históricas
separadas; os resumos posteriores não identificam qual alteração eliminou
as recusas. O complemento manual com espaçamento de M07 está homologado no
escopo acima. O aceite nativo separado abaixo conclui M07 no escopo Windows
registrado; medições M08 e D03 UTF-8/FLOAT continuam abertas.

<a id="odbc-physical-reuse-on-2026-10-15"></a>

## Reuso físico ODBC nativo em 2026-10-15

A adaptação `HBBridgeSQLPool` mantém posse lógica exclusiva sob o mutex
existente do ciclo SQL. Conexões RDDSQL nativas ainda conectam/desconectam por
chamada; reuso físico MSSQL pertence ao ODBC Driver Manager. A política
mantém padrão **off**. A opção `driver` fica restrita à rota verificada
Windows ODBC 3.8; pooling Linux não integra este aceite.

A primeira tentativa usou 13 conexões físicas para 13 leases porque o ciclo
do ambiente ODBC não mantinha o pool aquecido. Manter um ambiente do processo
corrigiu esse ciclo. Aquisição fria e reuso estável são registrados
separadamente; o aceite final não oculta as conexões frias nem as dilui em
uma alegação de desempenho:

| Processo nativo isolado | Aquecimento frio | Leases medidos posteriores | Checks / falhas | Saída |
| --- | --- | --- | --- | --- |
| `driver` | 2 leases, 2 conexões físicas | 13 leases, 1 conexão TCP física | 61 / 0 | 0 |
| `off` | 2 leases de aquecimento registrados separadamente | 13 leases, 13 conexões físicas | 61 / 0 | 0 |

A identidade física é verificada por ID de conexão SQL Server, porta TCP do
cliente e horário de criação da conexão, sem depender apenas de SPID.
Mutações de configurações/contexto, tabela temporária local, transação aberta
e seleção de banco por `USE` foram observadas antes da desconexão. O lease
`driver` seguinte a cada mutação retornou ao estado original limpo **na mesma
conexão física**. Também passaram SQL inválido/recuperação, workarea/conexão padrão
zero e não zero do chamador, exclusividade de conexão de chamador ativo,
timeout de instrução de um segundo e recuperação com timeout maior. Todos
os leases lógicos próprios foram liberados; o ambiente nativo retido fechou
com sucesso e sua indicação de retenção foi apagada.

Evidências: `tmp/m07-mssql-pooling-driver-accepted-20261015.log` e
`tmp/mssql-tests-bb7664a7b9314a9492a88d8f098c5aff/results.log`;
controle separado off em `tmp/m07-mssql-pooling-off-accepted-20261015.log`.
A fixture nativa isolada de concorrência foi repetida com
`-ODBCPooling driver`: **8 workers, 192 chamadas, 458 checks, zero falhas,
nenhum skip, saída 0**, por local/NETIO/TCP/HTTP. Verifica isolamento de
perfil/schema/valor, recuperação, estado do chamador e liberação própria
mantendo mutex SQL. Evidências:
`tmp/m07-mssql-pool-concurrency-20261015.log` e
`tmp/mssql-tests-ea4ca5c6a2774bad8b2367822ef4cfd3/results.log`.

Homologados reuso físico e ciclo nativo exercitado no Windows com autenticação
SQL. Linux, autenticação integrada e perfil opcional de segundo banco MSSQL
configurado não foram exercitados. O reset de `USE` não homologa esse caso
de segundo perfil. Esses resultados permanecem separados dos resumos manuais
de 500 workers, sem identidade de binário/política ODBC. Não se deduz relação
causal com o sucesso manual, ganho de velocidade, quantidade máxima de workers
ou garantia de SQL paralelo.

M07 está concluída nos escopos nativo Windows e de resumos manuais com
espaçamento registrados acima. Retomar medições M08 de tempo/memória; checks
finais M09 e D03 UTF-8/FLOAT continuam abertos, sem encerrar o pacote 001.

<a id="m08-performance-baseline-on-2026-10-16"></a>

## Referência de desempenho M08 em 2026-10-16

Registrada a fixture comum somente de leitura `m08.constant.v1` com perfil
explícito `MSSQL/pData`, banco `pData`, SQL Server **16.0.1210.3**. Gera 1000
linhas com ID/nome/valores em quartos com `DECIMAL(15,2)`, páginas de 100
ordenadas por ID crescente. Nenhuma tabela ERP é lida ou alterada. SQL Harbour
e TLPP são idênticos byte a byte: 537 bytes ASCII, SHA256
`A5F3569517A2A638BEDAFED9D4CA348ADCA9C737C90213A18147B8D4078BDCC5`.
Consultar [metodologia/reprodução](benchmarking.pt-BR.md).

Cada rota usa um cliente, duas varreduras completas de aquecimento e cinco
completas medidas. Cada varredura medida valida as 1000 linhas e dez páginas,
incluindo ordem dos campos, valores, totais e estado da última página.
Cada página usa uma chamada Query e as instruções SELECT/COUNT separadas
do produto. Por rota: 20 chamadas/2000 linhas de aquecimento e 50 chamadas/
5000 linhas medidas. As amostras de aquecimento ficam visíveis e fora das
estatísticas. Uma consulta de identificação precede o aquecimento nativo;
não representa conexão fria nem cache frio do SGBD.

### Clientes nativos e memória do SO

Processos separados, em sequência, mediram dispatcher Harbour direto, TCP
nativo e HTTP nativo em cada política explícita de pooling. As seis rotas
retornaram sucesso e saída 0: **43366 verificações do benchmark, zero falhas**,
incluindo valores de aquecimento/medição, encerramento próprio, zero leases
ativos e restauração da workarea/conexão padrão do chamador. São checks do
benchmark, separados da regressão anterior de 712 checks do produto.

| Política | Cliente nativo | Média ms / varredura completa | Mín–máx ms | Pico amostrado working/private MiB na medição | Amostras de memória na medição |
| --- | --- | --- | --- | --- | --- |
| off | Harbour direto | 2881.20 | 2344–3546 | 21.35 / 4.93 | 180 |
| off | TCP | 2300.00 | 1938–2687 | 18.04 / 6.03 | 151 |
| off | HTTP | 2496.80 | 1891–3203 | 18.52 / 6.51 | 156 |
| driver | Harbour direto | 1159.40 | 985–1344 | 23.37 / 5.00 | 78 |
| driver | TCP | 1531.40 | 1235–1875 | 19.89 / 6.12 | 94 |
| driver | HTTP | 1303.00 | 969–1718 | 20.50 / 6.61 | 87 |

Os seis relatórios têm `memory.available=true` e amostras na fase medida.
A memória pertence ao processo completo de cada rota, incluindo cliente e
servidor isolado em TCP/HTTP; não representa alocação por query. Working set/
private bytes são contadores do processo no SO; observações do pico vitalício
ficam separadas no JSON. O intervalo solicitado é 50 ms mais o custo da coleta;
os tempos no CSV registram o espaçamento real. MiB corresponde a bytes divididos
por 1048576. O tempo nativo usa ticks Windows `GetTickCount64`; médias
fracionárias são valores derivados do agregado.

Artefatos:

- off: `tmp/mssql-benchmark-65e82528313e404e8395b801db49c2c7/benchmark.json`,
  `result.json`/`results.log`/`memory.csv` por rota;
  log `tmp/m08-native-baseline-off-20261016.log`.
- driver: `tmp/mssql-benchmark-458ec3e6699b4508aae6df881d16e31d/benchmark.json`,
  artefatos correspondentes por rota;
  log `tmp/m08-native-baseline-driver-20261016.log`.
- SHA256 do executável off:
  `6E992FA6FCD4C85315E5269B0E759457B9EEBA452390933099D2674E194225FD`;
  driver: `4F10EC0BF5F7DF8028832CA94ECF3F7482335F153B8932E4FFE468F374DD235B`.
  Os relatórios identificam também fontes próprios, manifesto/revisões das
  dependências, Zig 0.16.0 e hashes do patch/biblioteca ODBC gerenciados.

### Clientes reais do Protheus

A árvore TLPP completa compilou **34 fontes, zero erros de fonte**, incluindo
classe e entrada do benchmark. Depois, o compilador do fornecedor retornou
**0xC0000409** na finalização, separado da compilação dos fontes. Os scripts
de parada/inicialização retornaram 0 e os serviços normais foram restaurados.
Recibos: `tmp/m08-totvs-build-result-20261016.json`,
`tmp/totvs-m08-compile-20261016.log` e
`tmp/m08-totvs-lifecycle-20261016.log`.
Uma chamada CLI inválida com `--rows=0` retornou saída 1 e a validação esperada
do executor, confirmando a rejeição dessa entrada pelo programa compilado.

A execução real de `U_HBBridgeBenchmarkCLI` pelo AppServer licenciado passou
nos dois clientes/dataset do produto, com **saída 0** e JSON completo aprovado.
O hbBridge isolado usou política explícita `driver` e o executável nativo
identificado acima. Sua requisição preliminar da fixture fica separada das
medições AppServer. Os checks finais de limpeza do host passaram com saída 0.

| Cliente TLPP | Varreduras medidas | Média ms / varredura completa | Mín–máx ms | Chamadas / linhas medidas |
| --- | --- | --- | --- | --- |
| TCP | 5 | 1118.14 | 991.05–1263.63 | 50 / 5000 |
| HTTP | 5 | 1491.91 | 1299.71–1641.31 | 50 / 5000 |

As duas rotas passaram também nos dois aquecimentos de cada uma. O tempo inclui
navegação/validação de valores e Close do dataset, usando `TimeCounter()`
normalizado. TCP precede HTTP. O executor completo levou cerca de 19.016 s;
a duração do processo com inicialização/finalização foi de 33.232 s.
São intervalos distintos das médias acima. O campo interno de memória permanece
`UNAVAILABLE`; um amostrador externo forneceu memória do processo completo:

| Processo observado no ciclo combinado TCP/HTTP | Amostras | Pico working amostrado MiB | Pico private amostrado MiB |
| --- | --- | --- | --- |
| Cliente AppServer isolado | 405 | 297.98 | 310.72 |
| Servidor hbBridge isolado separado | 405 | 20.88 | 6.91 |

Essas amostras externas incluem inicialização/limpeza do cliente e as duas
rotas; não são memória da fase medida nem por rota. Snapshots do processo
não comprovam vazamento nem atribuem memória compartilhada do runtime à thread.
Artefatos: `tmp/m08-protheus-benchmark-c05255b72a8b48b68ef794b9329f7366/benchmark.json`,
`protheus.log`, `memory.csv` e `server/result.json`/`results.log`.
O fonte do amostrador está preservado em
`tmp/run-m08-protheus-benchmark-20261016.ps1`, identificado por hash no recibo.
O INI CLI privado fica fora do Git, junto ao AppServer; seu parser exige apenas
o nome em `-ini`. O `appserver.ini` ativo e a configuração SQL privada do
hbBridge não foram editados.

SHA256 da classe: `1A9C40240C0B8D36300DAA13518EA595F947DE8595BD75C7B4350D76C210B487`;
entrada: `C5A355E64DA8442079C3B35151C4363AD6268287F659AAD5AD25F344575BD533`.
O RPO informa 31489542 bytes, atualizado às 04:33:17 São Paulo; seu hash não
estava disponível devido ao bloqueio do arquivo pelo runtime em execução.
A limitação fica explícita; chamada aprovada e recibos do compilador
identificam a entrada exercitada.

### Escopo e sequência

As referências usaram a mesma estação Windows x64 compartilhada, 12 CPUs
lógicas, plano Equilibrado e AppServer/DBAccess/hbBridge normais também presentes.
Outras atividades da máquina e caches SQL compartilhados não foram controlados.
Rodadas preparatórias coincidiram com compilação/reinicialização dos serviços
e ficam preservadas separadamente, fora das tabelas. Não houve compilação do
agente durante as medições selecionadas. O inventário do Driver 18 instalado
informa versão de binário `2018.0187.0001.01`; a versão efetiva do driver da
conexão permanece `NOT_OBSERVED` pelo executor.

O smoke curto `-Route http -Rows 17 -PageSize 7 -Iterations 1 -Warmup 0
-ServeSeconds 1` também passou: última página parcial, aquecimento zero,
publicação de endpoints e encerramento do host próprio.
Artefatos: `tmp/mssql-benchmark-f00628fbfb824bb7bee7e3a65bc9170a/benchmark.json`
e `tmp/m08-benchmark-serve-smoke-20261016.log`.

M08 concluída para essa carga de referência Windows identificada. Os números
não representam comparação estatística isolada de pooling, garantia de
velocidade, capacidade de produção, SQL paralelo ou aceite de vazamentos.
Não se deduz aceite Linux, HTTPS, volume de negócio ERP ou D03 UTF-8/FLOAT
bruto. Retomar checks/documentação finais M09; D03 continua obrigatório
antes do fechamento do pacote 001.

Validação das ferramentas M08: os três validadores obrigatórios aprovaram
205 arquivos; links locais dos 81 documentos, sintaxe PowerShell e whitespace
passaram. Recibo: `tmp/m08-commit-check-20261016.log`. Esses checks não encerram
as exigências restantes de regressão/integridade do pacote em M09.

<a id="m08-manual-protheus-validation-on-2026-10-16"></a>

## Validação manual adicional M08 Protheus em 2026-10-16

Registrada validação manual a partir do resumo fornecido e da linha final
`hbBridge benchmark Protheus OK`. Run ID
`614056ED784ECE4AB68EAAE1EE863D89`, início **04:53:47 São Paulo**, fixture
`m08.constant.v1`, alias explícito `MSSQL/pData`, normalização Windows
(`serverUnix=false`). Carga: 1000 linhas, páginas de 100, um cliente,
dois aquecimentos e cinco varreduras completas medidas por transporte,
primeiro TCP, depois HTTP.

| Transporte | Varreduras medidas | Média ms / varredura completa | Mín–máx ms | Chamadas / linhas medidas |
| --- | --- | --- | --- | --- |
| TCP | 5 | 1039.60 | 770.08–1257.06 | 50 / 5000 |
| HTTP | 5 | 1122.12 | 951.03–1388.17 | 50 / 5000 |

Todas as amostras medidas e de aquecimento informam sucesso, 1000 linhas,
dez páginas e dez chamadas. O recálculo confirma totais/mínimo/máximo/médias
dentro do arredondamento de ponto flutuante. Somados os transportes:
**100 chamadas / 10000 linhas medidas**, excluídas **40 chamadas / 4000 linhas
de aquecimento**. Os intervalos medidos somam 10808.610 ms; o executor completo
levou **14887.055 ms**. Os 4078.445 ms restantes incluem aquecimento e demais
atividades fora dos intervalos medidos; não correspondem apenas ao aquecimento.

Evidência: `tmp/protheus-benchmark-manual-20261016-614056ed.log`, SHA256
`921B63D9F26D08B4294F938BD265739E3010B62F679CE55551DD33372A0D1DD7`.
É um resumo manual separado, sem nova execução automatizada local.
A memória permanece `UNAVAILABLE` neste relatório. Não foram fornecidos
destino efetivo, binário/versão do backend, política de pooling físico,
recibo de compilação nem código de saída do processo; esses dados não são
herdados da execução automatizada anterior nem de suas amostras externas de
memória. Não se deduz causalidade de otimização nem comparação de capacidade.
Acrescentada evidência manual ao M08 homologado; M09 e D03 continuam abertos.

<a id="m08-large-protheus-follow-up-on-2026-10-16"></a>

## Complemento do benchmark manual ampliado em 2026-10-16

O log `C:/totvs/protheus1212410/protheusdata/logs/console_appserver_hbbridge.log`
contém a rodada `93A0CC16D629E74FAA54843567C86E58`, iniciada às 07:09:41 São Paulo.
Fixture `m08.constant.v1`, `MSSQL/pData`: 100000 linhas, páginas de 10000,
500 iterações medidas, dois aquecimentos, concorrência um, TCP seguido de HTTP,
timeout de 30 segundos por requisição. Resultado geral **FAILED**.

| Transporte | Iterações medidas aprovadas | Chamadas / linhas das medições aprovadas | Média ms / varredura |
| --- | --- | --- | --- |
| TCP | 500 / 500 | 5000 / 50000000 | 7747.32 |
| HTTP | 135 / 500 | 1350 / 13500000 | 22312.04 |

Ambos concluíram dois aquecimentos. A amostra HTTP medida **136** falhou na
primeira chamada: `QUERY_FAILED`, 30020.834 ms, zero páginas/linhas concluídas.
Essa chamada tentada permanece na amostra de falha, fora do agregado de
sucessos. O núcleo durou 6967715.110 ms. A duração da falha está próxima do
prazo de 30 segundos; o resumo antigo não registra código de serviço/status
HTTP e não comprova origem no transporte, servidor ou SQL. Memória/pool/build
não são herdados da referência menor. O
[esclarecimento de 2026-10-19](#m08-manual-cli-validation-on-2026-10-19) registra parâmetros elevados
e timeout inadequado à carga como contexto operacional.

O erro fatal anterior de componentes por terminal foi fornecido separadamente,
às 06:45:23, antes da alteração provisória com socket estático de módulo.
A repetição deixou de apresentar esse erro fatal, mas sua falha HTTP continua
distinta. O cliente agora reutiliza um componente nativo por instância e expõe
`Close()`; as conexões continuam fechadas por requisição. O
[teste de ciclo](../src/tlpp/tests/protheus/hbbridge.client.lifecycle.test/README.pt-BR.md)
e os diagnósticos seguros de código/status/página apoiam a análise sem homologar
a carga ampliada completa.

Resumo/linha final sanitizados: `tmp/protheus-benchmark-large-static-20261016-93a0cc16.log`;
SHA256 `AC62382489B97B9CC00B41C1010A8AC5D9C60A6A3D24BEBDB444A403C4FCC986`.
O fonte provisório fornecido foi preservado em
`tmp/hbbridge.client.user-static-20261016.tlpp`. V01 registra esse complemento
solicitado e o consumidor visual; M09 e D03 continuam abertos.

<a id="v01-v02-benchmark-acceptance-on-2026-10-19"></a>

## Aceite V01/V02 do benchmark em 2026-10-19

V01/V02 estão concluídas para o fluxo Windows/AppServer demonstrado. Três
rodadas visuais manuais forneceram exports JSON/HTML em 2026-10-19. As quatro
rotas cliente (hbBridge TCP/HTTP, Protheus StartJob/REST) e o addon Harbour
local passaram. Esses resultados manuais são separados dos testes focados,
das tentativas CLI reprovadas e da carga ampliada histórica. D03 UTF-8/FLOAT
bruto, checks finais M09 e pacote 001 continuam abertos.

### Escopo manual e cálculos

Cada rota/rodada percorreu a fixture constante `m08.constant.v1`: alias
explícito `MSSQL/pData`, ambiente informado `PROTHEUS_NGROK`, 1000 linhas,
páginas de 100, cinco varreduras medidas e dois aquecimentos, concorrência um.
Passaram as 75 amostras medidas e 30 de aquecimento; cada amostra registra
1000 linhas, dez páginas/chamadas e ausência de falhas. As 75000 visitas a
linhas medidas repetem a fixture, sem representar registros de negócio
distintos. Os aquecimentos ficam fora das médias abaixo.

| Início local informado | ID da rodada | Média ms: TCP / HTTP / StartJob / REST Protheus |
| --- | --- | --- |
| 20261019/06:50:35 | `3FF23D3FFFA5984889F09C1DFAFF2459` | 835.00 / 1178.44 / 24876.41 / 1170.96 |
| 20261019/07:03:57 | `B7D7F6E890176D45BB3DC912EC61E8BA` | 1151.27 / 1090.36 / 27085.53 / 1189.93 |
| 20261019/07:09:26 | `E3D8EB828C914C48926D2633219F0724` | 985.58 / 1100.60 / 25737.92 / 1302.56 |

Nas 15 medições por rota, médias **990.62 ms TCP, 1123.13 ms HTTP, 25899.95 ms
StartJob e 1221.15 ms REST Protheus**. A média interna do addon é **825.00 ms**,
com outro escopo. TCP apresentou tempo 18.88% menor que REST no agregado;
HTTP 8.03% menor. Na primeira rodada HTTP ficou 0.64% acima do REST; TCP perdeu
para HTTP em uma rodada. Ordem fixa e amostra pequena não demonstram
significância estatística nem superioridade geral de desempenho.

A auditoria dos exports passou em **684 verificações de consistência**,
incluindo valores dos gráficos/médias HTML, contagens e status JSON e
recálculo de soma/média/mínimo/máximo. A maior diferença foi 4.95e-10 ms por
arredondamento numérico. Reconstituir o tempo total pelas amostras cliente e
uma RPC do addon deixa 8.59-14.06 ms por rodada fora desses intervalos,
coerentes com preparação/limpeza do executor.

StartJob abre um worker síncrono por página, incluindo preparação e liberação
do ambiente/conexão; REST usa worker preparado. A razão StartJob/TCP não
isola desempenho do motor SQL ou da linguagem. No addon, `rpcCalls=10` por
amostra e `measuredCalls=50` por rodada são dispatches locais. `networkCalls=1`
abrange o pacote inteiro de sete varreduras e retorna métricas, zero linhas
do dataset. As RPCs completas duraram 5884.622 / 5598.375 / 6194.857 ms,
incluindo carga do HRB, aquecimentos, medições e transporte do retorno.

Uma comparação adicional do pacote inclui aquecimentos dos dois lados:
três RPCs completas do addon somam **17.677854 s**, frente a **20.638174 s TCP,
23.892302 s HTTP e 26.260709 s REST Protheus**, somando os intervalos das
mesmas 21 varreduras cliente. O tempo do addon ficou 32.68% menor que REST
nesse somatório. O addon devolve métricas, enquanto clientes recebem páginas;
local de processamento e payload são diferentes. Intervalos cliente excluem
orquestração entre iterações; RPCs incluem a orquestração interna. Essa
comparação é separada das médias que excluem aquecimento. Diferença RPC/tempo
interno do pacote: 4.375-9.622 ms (menos de 0.17% observado), reunindo carga
HRB, serialização, transporte e quantização dos relógios, sem isolar tempo
de rede. O relógio do addon Windows tem granularidade do tick do sistema.

### Evidências focadas e aceite pela rede

| Método de validação | Resultado e escopo | Evidência local |
| --- | --- | --- |
| Ciclo do cliente no AppServer CLI | 6000 chamadas Health reais, 17 checks/0, saída 0; reuso por instância, clientes independentes, recusa/recuperação/Close, sem SQL nem medição de vazamento. | `tmp/comparison-protheus-0d6eed2eb4554737acfe9a05f902d8da/validation.json`, `results.lifecycle`. |
| Controlador no AppServer CLI | 61 checks/OK, saída 0; validação/posse determinística, sem SQL. | `tmp/comparison-protheus-e95c292052a44a1f943d84bcc16a7fe7/controller.log`. |
| Contrato REST no AppServer CLI | 43 checks/OK, saída 0; oito chamadas de página mock, autenticação/cabeçalhos/status/erros e preservação de área em entradas rejeitadas. | `rest-contract.log` da mesma execução. |
| Template no Chromium | Três testes, 46 checks/0; requisições/spinner, gráficos, correlação, exports independentes e grandes coleções; fixtures de comparação simuladas. | `tmp/benchmark-browser-validation-20261018.log`, `tmp/benchmark-browser-35740/result.json`. |
| Addon nativo | 47 checks/0; registro Query simulado, permissões, ABI antiga de um argumento, sem banco/listener; runner também confere identidade da fixture em três volumes. | `tmp/benchmark-addon-tests-51e2a7520b2048648bf2a1517db70c17/results.log`. |
| Regressão nativa do produto | 712 checks/0; regressão histórica separada após contexto opcional do addon. | `tmp/tests-78d22ed883da4f57b2d5aabb7f2bf91c/results.log`. |
| Listener REST Protheus real existente | Repetido em 2026-10-19: credenciais ausentes/incorretas/válidas 401/401/200; fixture inválida autenticada 400; recuperação 200. Páginas válidas com sete linhas, total 17, primeiro ID 1. | `tmp/v01-v02-acceptance-20261019/rest-network.json`. |

A prova REST reutilizou `https://localhost:4323/rest`, HTTPV11/REST 2.0,
Security=1 e a seção privada de credenciais existente. Não houve novo listener,
reinício de serviços nem alteração de configuração neste fechamento. A prova
ignorou validação do certificado somente na requisição HTTPS local; não
homologa certificados ou outros deployments TLS. Os recibos omitem credenciais.
O backup da consolidação anterior do INI continua privado ao lado do INI ativo:
`appserver.ini.benchmark-backup-20261018-162739.bak`.

A última compilação worker-connect registrou **45 fontes aprovados e zero
erros de fonte**. A finalização do processo continuou **0xC0000409**; scripts
de parada/início retornaram zero. Evidências:
`tmp/comparison-worker-connect-build-output-20261018.log` e
`tmp/comparison-worker-connect-totvs-build-result-20261018.json`. Logs rotativos
do compilador não substituem esses recibos. Nenhum fonte do produto mudou
neste fechamento documental; não houve nova recompilação.

### Rastreabilidade e limites restantes

Originais em `C:/Users/marin/Downloads/hbbridge-benchmark`. Cópias verificadas
e auditoria dos 684 checks preservadas em `tmp/v01-v02-acceptance-20261019/`;
`closure.json` registra os hashes dos 12 fontes TLPP e separa os resultados
manuais/locais. Os hashes correspondem ao último snapshot focado, sem provar
quais binários/RPO executaram as rodadas manuais. SHA256 de cada export original:

| Arquivo | SHA256 |
| --- | --- |
| `hbbridge-benchmark-3FF23D3FFFA5984889F09C1DFAFF2459.json` | `7cee8cbfd3b12bb9f9998a968f72f65f4aa01fbf984af536b4a013e3743821e9` |
| `hbbridge-benchmark-3FF23D3FFFA5984889F09C1DFAFF2459.html` | `8531b39b2d3270cfb5a75cb28c57bfc2f5253302b3c2b37625ecc79182710c1c` |
| `hbbridge-benchmark-B7D7F6E890176D45BB3DC912EC61E8BA.json` | `f292597a78b8323232353470b71d311c28c957a3d8fd2ab39a2990e2f9957588` |
| `hbbridge-benchmark-B7D7F6E890176D45BB3DC912EC61E8BA.html` | `f0d314994c5da523ea1945cf5e5831abc9b1ea17c3cf6261cd040fa56d9007c3` |
| `hbbridge-benchmark-E3D8EB828C914C48926D2633219F0724.json` | `daee9ca75807cb2a9d5abd3005ca6d0234a99b48da2e5e2d4a505e8e4343da6e` |
| `hbbridge-benchmark-E3D8EB828C914C48926D2633219F0724.html` | `c148285e5b2e3fd1af403a1039cfd7408be7a86a17c9e456e15920616deff5fe` |

Recibos automatizados agregados anteriores continuam reprovados: `e95c2920...`
registrou StartJob `ENVIRONMENT_FAILED`; `ea7029a0...`, `CONNECTION_FAILED`.
Usar somente seus resultados individuais aprovados de controlador/REST/ciclo.
Um processo REST intermediário falhou antes do programa por APPMAP/compartilhamento
de arquivo, sem reprovar uma asserção; a execução posterior passou em 43 checks.
O sucesso manual posterior homologa o ambiente demonstrado, sem alterar os
resultados CLI isolados de StartJob. O CLI TCP/HTTP passou posteriormente;
o resultado da amostra HTTP 136 tem contexto de carga/timeout registrado
[abaixo](#m08-manual-cli-validation-on-2026-10-19), sem caracterizar defeito genérico do CLI.

Exports não atestam mesmo backend físico, builds, driver, pooling, hardware,
endpoints/TLS/topologia ou carga concorrente. O nome do ambiente não comprova
túnel e `startedLocal` não informa fuso. Memória UNAVAILABLE e CPU não medida.
`transportOrder` omite o addon, executado por último no código; os campos de
tempo preservam seus escopos. ASCII/DECIMAL com CAST explícito não homologa
Unicode/binários/FLOAT bruto de D03. Próxima tarefa: D03, depois checks finais
M09; a preparação isolada de ambiente StartJob CLI anterior fica em registro
separado, sem reprovar o CLI de forma geral.

Os checks deste fechamento documental passaram em 2026-10-19: os três
validadores obrigatórios (`check.hb`, `commit.hb`, `3rdpatch.hb` somente leitura)
aprovaram 227 arquivos; links locais existem nos 85 documentos e os checks de
espaços passaram. Recibo: `tmp/v01-v02-acceptance-20261019/commit-check.log`.
Esses checks não concluem a integridade D03 nem os trabalhos finais M09.

<a id="m08-manual-cli-validation-on-2026-10-19"></a>

## Validação manual adicional do CLI TCP/HTTP em 2026-10-19

O fragmento fornecido registra a rodada `7482F7E82956EC4E961CEEE6C3A82222`
em 2026-10-19T08:13:33.576000-03:00, prefixo 35364, com sucesso geral e linha
final `hbBridge benchmark Protheus OK`. É evidência CLI manual, sem nova
execução automatizada. Fixture `m08.constant.v1`, alias `MSSQL/pData`: dez
linhas, página de dez, uma varredura medida por transporte, zero aquecimentos,
concorrência um. `protheusComparison=false` e `addonComparison=false`.

| Rota | Tempo ms | Páginas / chamadas / linhas concluídas | Resultado |
| --- | --- | --- | --- |
| hbBridge TCP | 94.799800 | 1 / 1 / 10 | Sucesso, sem erro de serviço. |
| hbBridge HTTP | 124.020300 | 1 / 1 / 10 | Sucesso, HTTP 200. |

Total/mínimo/máximo/média de cada rota coincidem com sua única amostra.
As duas varreduras somam 218.820100 ms; o total 232.731400 ms deixa
13.911300 ms fora dos intervalos medidos. O resultado confirma o fluxo CLI
TCP/HTTP nesses parâmetros, sem homologar CLI StartJob/REST/addon nem alterar
as estatísticas separadas de 1000 linhas. Não foram fornecidos comando,
timeout, identidade de binário/RPO ou código de saída do processo; memória
UNAVAILABLE. Resumo e revisão preservados em
`tmp/v01-v02-acceptance-20261019/cli-manual-20261019-7482f7e8.json` e
`cli-manual-20261019-7482f7e8-review.json`. O hash identifica esse fragmento
preservado, sem atestar um arquivo completo original do console.

Esclarecimento operacional registrado em 2026-10-19: a carga CLI anterior de
100000 linhas/500 iterações usou valores elevados sem timeout adequadamente
dimensionado. A chamada anterior tinha prazo de 30 segundos; o esclarecimento
trata de sua adequação, não da ausência de uma configuração numérica.
Preservar o FAILED da amostra HTTP 136 como resultado daquela carga/prazo,
com dimensionamento de carga/orçamento como contexto operacional, sem
caracterizar defeito genérico do CLI. Não deduzir nova execução nem medição
isolada da causa. Tentativas CLI isoladas de inicialização StartJob com
`ENVIRONMENT_FAILED`/`CONNECTION_FAILED` são outro registro de configuração.
V01/V02 continuam concluídas; D03 é a próxima e M09/pacote 001 seguem abertos.

<a id="d03-integrity-on-2026-10-21"></a>

## Integridade UTF-8, numérica e de NUL D03 em 2026-10-21

D03 homologada para o alvo Windows x64 / MSSQL / Microsoft
ODBC Driver 18 identificado e a fixture somente leitura
`d03.mssql.constants.v1`. Leitura nativa, serialização e consumidor Protheus
têm evidências separadas; conversão visual sozinha não comprova a leitura
correta do banco. M09/pacote 001 permanecem abertos.

Checks nativos concluídos em 2026-10-19, todos sem falhas:

| Escopo | Checks | Artefato |
| --- | --- | --- |
| Regressão padrão, incluindo codec JSON | 752 | `tmp/d03-native-final.log`; `tmp/tests-5733f80fe0ec4a30a4310adc37247e8c/` |
| Integridade MSSQL real nativo/TCP/HTTP | 73 | `tmp/d03-mssql-integrity-fixed.log`; `tmp/mssql-tests-d6d74b0b70be4cf8b4a6a0b0e8b56545/` |
| Regressão MSSQL real anterior | 92 | `tmp/d03-mssql-regression.log`; `tmp/mssql-tests-7c3c29255b1341dd988561123160de10/` |
| `System.Data.Odbc` independente de Harbour/JSON | 7 | `tmp/d03-odbc-reference.json` |
| Formatação/parsing binary64 Zig | 2 | Testes unitários de `src/zig/runtime/hbbridge.number.zig` |

O patch ODBC gerenciado corrige Unicode suplementar na entrada SQL UTF-8 e
nos blocos de saída UTF-16. Antes da correção de entrada, a rodada de 73 checks
teve cinco falhas: `tmp/d03-mssql-integrity.log`. O checkout upstream fixado
não foi alterado. O codec compartilhado preserva FLOAT nativo fracionário e
round trips binary64; comparações Protheus `N` usam tolerâncias dentro de 15
dígitos significativos. CAST define escala de negócio do chamador; decimais
grandes exatos usam projeção SQL textual explícita. SX3/TOP_FIELD não são deduzidos.

A rodada final automatizada no AppServer CLI real em 2026-10-21 passou
**80 checks, zero falhas, saída cliente/servidor 0**, contra host MSSQL isolado
pelos clientes TCP/HTTP de produção e dataset comum. Recibo:
`tmp/d03-protheus-9c3d1606250449c9a659f92f92c5c6e6/validation.json`;
`protheus.log` contém todos os checks. SHA-256 do host nativo:
`96A7AC7B0D29C2016B15CAC4D8DCD18E5FA4CE075AF1BA28DE4719A5E8BE5CA1`.
A rodada anterior de 80 checks também passou em
`tmp/d03-protheus-4c82aad9154f4bfe8ae533f6c947ac48/`.
Cobertura: VARCHAR acentuado, euro, Unicode fora de CP1252, limite de bloco
com surrogate, texto longo, frações/magnitudes FLOAT, escalas DECIMAL explícitas,
decimal textual exato, NUL/vazio/null, EOF, status HTTP e cópias defensivas de
linhas/página. Clientes codificam entradas CP1252 da fixture uma vez; valores
recebidos ficam UTF-8 e o consumidor usa `DecodeUTF8()` uma vez quando necessário.

Uma reprodução isolada no `JSONObject` confirmou outro defeito do AppServer:
a atribuição de `A + Chr(0) + B` preserva `410042`; `ToJSON()` emite
`{"text":"A"}`; `FromJSON('{"text":"A\u0000B"}')` retorna Nil e resulta em
`4142` (AB). O round trip resulta em `41` (A), sem SQL ou transporte.
Reprodução exata e build 7.00.240223P / 24.3.1.5 / SVN 46783 publicadas na
[issue #14](https://github.com/naldodj/totvs-protheus-open-issues/issues/14).
Artefato: `tmp/d03-local-7baba9a141dc4c2cae22a80db76779af/protheus.log`.

`HBBridge.Client.HBBridgeJSON` preserva escapes reais de NUL sem recodificar
UTF-8 nem alterar o tratamento escalar/numérico nativo. Ambos os clientes e
snapshots do dataset o utilizam. Remoção/truncamento de NUL continua sendo
falha; nenhum contorno troca o valor esperado por A/AB. Checks fechados no
AppServer passaram **31/zero falhas, saída 0**, incluindo posições/repetição
densa de NUL, escapes literais, chaves Unicode, contêineres vazios e limpeza
após falha: `tmp/d03-local-334459cffda64ccd89f8760b27c8d266/protheus.log`.

O RPO privado compilou os dez fontes selecionados com **zero erros de fonte,
saída 0**: `tmp/d03-protheus-rpo/compile.log`. Serviços/RPO instalados não
foram substituídos nem reiniciados nessas rodadas finais. Uma tentativa
intermediária indicou fonte vazio/corrompido apesar da saída 0; a compilação
completa posterior passou. Regressões simuladas AppServer também passaram:
dataset **67/31 chamadas** (`tmp/d03-local-bfc974373fdc40f78e6143d7500834bc/`),
helpers **12** (`tmp/d03-local-11b6fb42fcb94c788f9bdc0c52b1cede/`), tabela
HTTP **71** (`tmp/d03-local-496df9338ec545c8bd713748a2829dab/`). As duas
entradas procedure retornaram -4 ao processo sem retorno CLI numérico; o
aceite considera os resumos completos de asserções bem-sucedidas, sem inventar saída 0.

Binários nativos preservam bytes. JSON versão 1 recusa colunas binárias com
`BINARY_JSON_UNSUPPORTED`; projeção SQL hexadecimal explícita foi testada.
Isso não implementa BLOB automático em JSON. O helper de projeção Protheus
exclui tipos-base binários, mantém texto longo, ordena colunas, escapa o
literal de tabela e remove a suposição dbo. O browse SRA revisado compila;
sua execução visual/com dados de negócio não foi repetida aqui. Relatos
anteriores de acentuação/sem CAST/DecodeUTF8 preservam seu escopo manual.
Linux, outros drivers/páginas de código, JSON de precisão arbitrária, escala
ERP automática e representação binária versionada exigem implementação/aceite próprios.

Validações finais D03 de documentação/fontes aprovadas em 2026-10-21: os três
validadores obrigatórios aceitaram **242 arquivos**, links locais existentes
nos **89 documentos** e whitespace aprovado. Recibo:
`tmp/d03-final-commit-check.log`. Esses checks não encerram M09/pacote 001.

<a id="package-001-m09-closure-on-2026-10-21"></a>

## Encerramento do pacote 001 / M09 em 2026-10-21

Pacote `001-mssql-acceptance` concluído para o escopo Windows x64, MSSQL/SQLite
e AppServer registrado. M01–M09, D01–D03 e V01/V02 preservam seus aceites
atribuíveis; os checks finais abaixo passaram após a correção NUL e a revisão
de invariantes/agrupamento por tipo. WIP renovado para o pacote 002. O aceite
desse pacote não encerra o roadmap do produto.

| Requisito concluído | Evidência preservada |
| --- | --- |
| M01/M02: alvo privado identificado e pré-requisitos reproduzíveis | `MSSQL/pData`/`pData` explícitos; credenciais privadas fora do Git; DSN com Driver 18. Falta de pré-requisito continua sendo falha. |
| M03: SQL/tipos/páginas nativos | Aceite MSSQL original e regressões finais de 92 checks e 73 checks de integridade origem/transporte. |
| M04/M05: Protheus TCP/HTTP | Aceites manuais anteriores de 29 TCP/13 HTTP por perfil MSSQL/SQLite; rodada final de integridade AppServer com 80 checks. |
| M06: falhas e recuperação | Aceite de 2026-10-14: 46 checks nativos, 38 TCP/51 HTTP no AppServer. |
| M07: isolamento/recursos/concorrência | Aceites delimitados nativos/AppServer de leases, limpeza, reuso Driver Manager e carga espaçada. Mutex SQL preservado, sem prometer SQL paralelo. |
| M08/V01/V02: referência e local de execução | Baseline de 2026-10-16; comparação visual de 2026-10-19 com escopos de tempo cliente/addon separados. |
| D01/D02/D03: consumidor e integridade | Mocks dataset/helpers/tabela 67/12/71; FLOAT/UTF-8 nativos, texto exato, NUL nos clientes/snapshots e recusa explícita de binários. |
| M09: build, compilação, execução e documentação finais | Checks/identidades abaixo; instruções, roadmap e padrões bilíngues conciliados. |

Artefatos finais: `tmp/m09-20261021-b46a1d60bd7c4a0b8f349d9be66bd3bb/`.
O `manifest.json` registra hashes de 109 arquivos de fonte/build/dependências,
fingerprint, versões fixadas, metadados sanitizados do alvo e identidades dos
binários/RPO. Revisão Git base: `8db2823f5d33bdaf3bc0492560db20a49acfcbc9`.
O fonte validado inclui alterações da árvore de trabalho; não é uma tag de
release nem afirma que executáveis anteriores incorporam essas alterações.

| Verificação final | Resultado / artefato |
| --- | --- |
| Build isolado do produto; smoke de ajuda/configuração | Aprovados; `product-build.log`, `product-help.log`, `product-config.log`. Configuração usa exemplo SQLite público sem listeners. |
| Regressão nativa padrão | 752 checks / zero falhas: `tmp/tests-00991961f4cb4766a1a27792f611fa9e/results.log`. |
| Regressão MSSQL real | 92 checks / zero falhas/sem skips: `tmp/mssql-tests-515ed50affd34736b8f1a12e34e94b70/results.log`. |
| Integridade MSSQL origem/nativo/TCP/HTTP | 73 checks / zero falhas: `tmp/mssql-tests-c95e03bb826949709faaa24f931f8aad/results.log`. |
| Compilação TLPP completa | 49 fontes, zero erros de fonte, saída 0: `tlpp-compile.json`. |
| Compilação da última otimização JSON | Um helper alterado, zero erros, saída 0: `json-compile.json`, aplicado ao RPO privado completo. |
| Helper JSON no AppServer | 31 checks / zero falhas, saída 0: `tmp/m09-json-20da835242004b3cb6719689d2ddbb6f/protheus.log`. |
| Integridade AppServer TCP/HTTP MSSQL | 80 checks / zero falhas, saída cliente/servidor 0: `tmp/m09-protheus-f28bebb1e5d04ce182d8f02de7bc90bc/validation.json`. |

Inventário no encerramento: SQL Server **16.0.1210.3**, DSN de sistema `pData`
com Microsoft ODBC Driver 18 **18.7.1.1**. O inventário anterior
16.0.1200.5 / 18.6.2.1 permanece histórico. Fixture nativa em UTF8EX, conexão
lógica por chamada e pooling físico desativado nessa fixture. HTTP testado em
loopback próprio, sem TLS; não homologa HTTPS. AppServer 24.3.1.5. Compilação
completa e atualização JSON usam RPO isolado; serviços/RPO instalados não
foram substituídos nem reiniciados.

Identidades SHA-256:

| Artefato | SHA-256 |
| --- | --- |
| Executável do produto, escopo build/smoke | `E3F267D7053AC64D7814B0E857084554CCD6924EC442C4B8311DE71DD77C1018` |
| Host SQL nativo novo usado pelo AppServer | `2E9B44F4B83EE77F2E343FDBF21AD5610F2C3A1010479659525E33722B58E0F3` |
| RPO custom privado final | `6287F87912E694AA42938D3C82C9F3CA193FEF3EAB56920B36B3110D9E515A25` |
| Executável AppServer | `A14029C4CCD8F410FF9D0CA1782D0FFFD076283393D005A39D7BD072C64440D6` |
| Fingerprint de 109 arquivos de fonte/build | `5EAE7A708ADDE9BAA05B171FD78FFD9589572AE5CA93555A48AB496376EA14BC` |

Versões fixadas: hb_compile `2cb6f3ef59c297025a2c49c4cfa8c7639f3a1455`,
Harbour `6deac9cf3ad977ae829e5bca543d553b92dd4b6d` e Zig 0.16.0. O recibo ODBC
copiado identifica o patch gerenciado SHA-256
`BDB3C8D901A553CFABDF09CF20537521F4C39D872E7BDF172B0AD5D913E9D751`.
Rodadas anteriores com falhas/erro de finalização do compilador mantêm seus
registros datados; não foram reclassificadas como sucesso nem repetidas sem motivo.

A perda de conteúdo no JSONObject Protheus permanece registrada na
[issue #14](https://github.com/naldodj/totvs-protheus-open-issues/issues/14);
o helper homologado preserva NUL sem enfraquecer as asserções. Constantes e
tamanhos invariantes são resolvidos antes dos loops; tipos de segmentos que
mudam e verificações de posição/estado continuam por iteração. Declarações
locais agrupadas por tipo em ordem de prefixo, sem exigir ordenar o nome completo.

Pendências preservadas: binds/metadados lógicos e apresentação nativa no pacote
002; proteção portátil de segredos/TLS, leitores incrementais BLOB/CLOB,
negociação/streams, DBF/VF, serviços/Linux, benchmarks de addons C/Zig e
PostgreSQL/Protheus 12.1.2610 em seus escopos futuros. Escala de negócio/CAST e
identidade ERP ficam no chamador. Sem inferir BLOB automático em JSON, números
JSON de precisão arbitrária, ausência geral de vazamentos ou aceite de
plataformas não exercitadas.

Crivos finais M09 aprovados: `check.hb`, `commit.hb` e `3rdpatch.hb` em modo
somente leitura aceitaram **242 arquivos**; links locais existentes nos **89
documentos** e whitespace aprovado. Recibo: `commit-check.log` no diretório
final de artefatos. A validação inclui os padrões de fonte e a renovação do
pacote; encerrar o pacote não implica commit ou publicação.

<a id="source-conventions-review-on-2026-10-21"></a>

## Revisão das convenções de fonte em 2026-10-21

Manutenção geral revisou 38 fontes Harbour e 49 TLPP, seis módulos C e a
fixture JSON em C, módulos Zig/build, scripts, headers e fixture do navegador.
Declarações agrupadas pela ordem dos prefixos de tipo; comprimentos/constantes
invariantes antecipados aos loops. Preservadas dependências e ordem de
inicialização/chamadas, assinaturas/layouts nativos, sincronização SQL e posse
do estado por thread. Relógios, I/O, buffers variáveis e estado de filtros
mutável externamente continuam avaliados durante a varredura. Fontes de
terceiros não foram reformatados.

Revisão cruzada verificou 380 expressões de inicialização Harbour e 211
sequências de inicialização dos testes TLPP. Corrigida a referência existente
a `IgnoreToken`, sem declaração, em `NormalizeStringToken()`, usando o
parâmetro `cIgnoreToken`. A suíte helper agora cobre substituição comum e
tokens explicitamente ignorados (14 checks).

Estes checks novos de manutenção consideram a base `56128e9` e os ajustes da
árvore de trabalho, separados das evidências históricas do encerramento M09.
Artefatos: `tmp/source-standards-c880afdd71de4088864ab57b7e2023ac/`.
Seu `manifest.json` relaciona identidades dos fontes/binários/RPO e recibos.

| Verificação | Resultado |
| --- | --- |
| Build isolado do produto; ajuda/configuração SQLite pública | Aprovados; ambos os comandos smoke retornam 0, sem iniciar listeners do produto. |
| Regressão nativa / MSSQL real / integridade origem-transporte | 752 / 92 / 73 checks; zero falhas. |
| Recuperação de falhas MSSQL / concorrência / addon benchmark nativos | 46 / 458 / 47 checks; zero falhas. |
| Pooling ODBC nativo em modo driver | 61 checks; zero falhas. Não exercitado segundo banco configurado. |
| Smoke nativo de build/correção do benchmark local/TCP/HTTP | Uma linha e uma iteração medida por rota, sem aquecimento; aprovado. Não é baseline de desempenho. |
| Compilação TLPP privada | Todos os 49 fontes, seguidos de três atualizações de fontes de testes e duas de helpers; zero erros e saída 0 em cada compilação. |
| Suítes locais/simuladas no AppServer | JSON 31; dataset 67; helpers 14; tabela HTTP 71; benchmark visual 61; benchmark REST 43. Todas as asserções aprovadas. |
| Integridade MSSQL real no AppServer TCP/HTTP | 80 checks; zero falhas, saída cliente/servidor 0. |
| Zig / DOM real no Chromium | Dois testes unitários / dois testes de navegador aprovados. |
| Sintaxe PowerShell / crivos do repositório | 16 scripts, zero erros de análise; três validadores aceitaram 242 arquivos. Links locais nos 89 documentos e whitespace aprovados. |

Entradas procedure de dataset/helpers retornam -4 ao processo sem retorno CLI
numérico; seus resumos completos de asserções comprovam o resultado local/
simulado. Demais suítes locais retornam 0. Compilação/execução AppServer em
RPO isolado, sem substituir serviços/RPO instalados. Evidência de transporte
real: `tmp/standards-protheus-22dd10fb14bd4ecbb6ce550fa4a61634/validation.json`.
Escopo Windows/HTTP sem TLS e limitações existentes preservados. T01 do pacote
002 continua planejado; a revisão não implementa novas capacidades SQL, de
apresentação ou de credenciais.

## Diretórios de trabalho descartáveis em 2026-10-22

`tmp/` não é mais preservado por referências em documentação/manifests ou
ponteiros atuais. Toda entrada é descartável; permanecem as proteções de Git,
links, processos, idade e caminhos explicitamente preservados por operação.
A limpeza de `out/` mantém entregáveis e seleciona caches de build. Helpers
reutilizáveis ficam em `scripts/` e o probe/fixture HRB de estado por thread
em `tests/probes/`. [Resumos e comandos mantidos](validation/README.pt-BR.md)
eliminam a necessidade de entradas históricas em tmp; logs brutos são saídas
descartáveis opcionais.

Validação Windows aprovou **22 cenários Git isolados**, incluindo ausência de
tmp/out, descarte completo de tmp e ausência de retenção por documentação,
JSON/ponteiros. O probe nativo versionado passou **31 asserções/zero falhas**
usando seus fontes mantidos. Sintaxe PowerShell aprovada em **21 scripts**;
o launcher CLI recusou SDK ausente antes de iniciar processo. Ele não foi
utilizado para nova homologação AppServer.

Removidos nove helpers/ponteiros tmp obsoletos após a migração. O probe nativo
e o verificador mantido de documentação passaram novamente sem esses arquivos.

Os três crivos aceitaram **253 arquivos**; links locais aprovados nos **90
documentos visíveis ao Git**, sem dependência de tmp/out. Whitespace aprovado.
Preservadas as revisões de includes TLPP do benchmark e registrado `totvs.ch`
como padrão; headers específicos exigem símbolos/macros utilizados. O RPO
licenciado não foi recompilado aqui. Esses checks de manutenção não estendem
aceites SQL/runtime anteriores às mudanças atuais. T01 do pacote 002 segue planejado.
