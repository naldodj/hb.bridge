# Ambiente de referência e homologação

A homologação das alterações de reorganização anteriores
ao Marco 1 está OK. Os dados abaixo identificam esse ambiente de desenvolvimento;
não certificam versões distintas nem a execução das novas alterações nele.

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
[tests/protheus/hbbridgeconnectiontest.tlpp](../src/tlpp/tests/protheus/hbbridgeconnectiontest.tlpp),
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
que rodam elevados, execute-o com permissão administrativa. A tentativa da
sessão do agente encontrou **Acesso negado** ao parar o AppServer e foi
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

O operador informou o seguinte resultado do teste ampliado:

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
A evidência foi fornecida pelo operador; esta rodada não foi executada pelo agente.
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

O operador informou a execução de `U_HBBridgeQueryTest`, thread `30460`,
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

O operador informou a execução de `U_HBBridgeQueryTest`, thread AppServer
`41228`, ambiente `PROTHEUS`, perfil `sqlite_demo`, com **29 checks `true`**.
O resultado aceita o dataset por nome, valores decimais, navegação/EOF,
fechamento, resultado vazio, erros SQL/perfil e recuperação após falhas.
Também aceita primeira/próxima/última página, IDs com lacunas, EOF local,
ordinal oculto e rejeição dos parâmetros de paginação/ordenação inválidos.

O horário é o do log informado pelo operador, no fuso de São Paulo. Essa
execução foi manual; não foi executada pelo agente. Não foram informados o
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
teste das 00:40:06. O operador confirmou seus testes em nova rodada manual,
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
anteriores e guardando uma cópia em `tmp`. A tentativa de compilação pelo agente
foi bloqueada antes do compilador porque os processos TOTVS não puderam ser
encerrados: `tmp/ini-totvs-build.log`. Foi preparado `U_HBBridgeConfigTest`
para resolução/precedência/erros; o operador informou sucesso posteriormente.

### Confirmação Protheus de configuração INI, relógio e SQLite

Resultado informado pelo operador na sessão de **2026-10-04**, após a
alteração da configuração cliente. A rodada foi manual; o agente não
executou nem compilou esses testes no AppServer.

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
verificações, zero falhas e nenhum skip**. O agente
executou os testes com o toolchain gerenciado. Log:
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
`sqlite_demo`/`mssql/pData` e saída sem segredos/strings de conexão.
A inspeção de metadados não iniciou listeners nem consultou os bancos.

O crivo final passou para **135 arquivos**, incluindo `check.hb`, `commit.hb`,
`3rdpatch.hb`, nomes/indentação e pares de documentação. Log:
`tmp/commit-gate-20261007.log`. O hook pre-commit para conferir o índice foi
instalado localmente; não houve commit nem publicação. Links locais da
documentação e `git diff --check` também passaram.

Resolução automática OpenSSL externo, HTTP Zig e materialização SQL continuam
desenhos. Esse candidato não acrescenta aceite HTTPS/Linux/MSSQL/AppServer
aos registros anteriores.

## Homologação HTTP TLPP pelo operador em 2026-10-07

O operador ajustou a comparação de acentos e o tratamento Unauthorized do
FWRest e informou `U_HBBridgeHTTPTest` executado em **PROTHEUS**, thread
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

Esse é aceite de execução pelo operador, sem teste executado pelo agente
nem log de sucesso do compilador fornecido. A tentativa anterior do agente
retornou -1073740791, e o log interpretou um diretório de includes como
ambiente; não comprova compilação bem-sucedida. A execução do operador
supera essa lacuna nos fontes HTTP exercitados. Logs históricos:
`tmp/totvs-http-build-run.log` e `tmp/totvs-compile.log`.

O relato não identifica alias/backend SQL, URL/token/configuração cliente ou
hash do executável servidor. Portanto não acrescenta MSSQL real, HTTPS,
Linux, Unicode completo, configuração alternativa nem teste de configuração
cliente com 16 checks. Veja o [exemplo](../examples/http/README.pt-BR.md).

O crivo final da árvore de trabalho passou para **139 arquivos** com `check.hb`,
`commit.hb`, `3rdpatch.hb` e convenções; log:
`tmp/commit-gate-tlpp-http-20261007.log`. Whitespace da árvore/índice e links
locais em 59 documentos passaram. O índice preparado pelo usuário foi
preservado; essas validações não criaram commit nem publicação.

## Extensão nativa dos fontes Harbour em 2026-10-07

O responsável autorizou `.hb` para os fontes Harbour próprios. Foram renomeados
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
no AppServer durante a migração executada pelo agente. Os relatos posteriores
de recompilação/execução abaixo superam essa pendência de regressão. O aceite
anterior do RPO usava `.prg`. Os marcos MSSQL do pacote 001 continuam pendentes.

O crivo completo da árvore passou para **141 arquivos** com `check.hb`,
`commit.hb`, `3rdpatch.hb` e convenções; log:
`tmp/hb-extension-commit-gate-20261007.log`. Links locais em **61 documentos**
e `git diff --check` passaram. O índice foi preservado; nenhum commit criado.

## Homologação Protheus pelo operador após a migração em 2026-10-07

O operador confirmou recompilação após a migração `.hb` e forneceu saída HTTP
no chat, seguida de Query/configuração/TCP/HTTP em `F:/tmp/hbridge.news.txt`.
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

São execuções do operador, sem teste AppServer executado pelo agente nem log
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
