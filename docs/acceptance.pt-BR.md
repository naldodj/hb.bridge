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
  0 erros**, incluindo `hbbridgeconnectiontest.tlpp`, `hbbridgeclient.tlpp`
  e `hbbridgerpcdataset.tlpp`; resultado em `tmp/console.log`.
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

O novo `hbbridgetime.tlpp`, com a classe `hbbridge.client.HBBridgeTime` e seus métodos
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
`hbbridge.client.HBBridgeConfig():Read()` seleciona o INI por `GetSrvIniName()`
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
