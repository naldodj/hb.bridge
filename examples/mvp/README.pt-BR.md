# Exemplo mínimo do hbBridge

[English](README.md)

Este exemplo executa o mesmo `out/hbbridge.exe` do produto, com os clientes e
addons compartilhados. Por padrão, o host atende Protheus em `0.0.0.0:1512`
e NETIO em `0.0.0.0:2941`, com até 64 workers por listener. Administração só inicia com
credencial configurada. A pasta contém apenas o launcher e estas instruções;
a implementação e os testes são os do produto. Seu nome registra a origem
do exemplo, e as provas de conceito anteriores ficam no histórico Git.

A partir da raiz do projeto, com PowerShell 7 e Git:

```powershell
./scripts/bootstrap.ps1
./scripts/build-hbbridge.ps1
.\examples\mvp\run.ps1
```

`run.ps1` delega ao [launcher compartilhado](../../scripts/run-hbbridge.ps1)
e posiciona a execução na raiz para o loader localizar `addons/`.
Aceita `-Port`, `-MaxWorkers` e `-Config` opcional para um INI/JSON do host.
Só encaminha os argumentos informados; os padrões `1512` e `64` pertencem ao
runtime e não sobrepõem valores do arquivo. Sem `-Config`, o executável procura
`out/hbbridge.ini`; na ausência dele, usa os padrões. A precedência é
padrões < arquivo < CLI, descrita em [configuração](../../docs/configuration.pt-BR.md).
Encerre com Ctrl+Q. O build recusa substituir uma saída em execução; use
`-OutputDirectory tmp/candidate` para compilar junto da instalação ativa.
As dependências gerenciadas pertencem ao projeto, conforme
[scripts](../../scripts/README.pt-BR.md).

Compile o [cliente TLPP](../../src/tlpp/hbbridgeclient.tlpp) e o
[teste Protheus](../../src/tlpp/tests/protheus/hbbridgeconnectiontest.tlpp)
no AppServer e execute `U_HBBridgeConnectionTest()`. Na nova revisão, os
argumentos omitidos vêm de `[hbBridge]` no INI usado pelo AppServer, com
`127.0.0.1:1512` na ausência dessas chaves; informe outro destino com
`U_HBBridgeConnectionTest(cHost, nPort, nTimeout)`. Compile `src/tlpp/` inteiro.
O [template cliente](../../config/examples/protheus-appserver.ini) deve ser
mesclado ao INI do AppServer, separadamente do INI do servidor hbBridge.
Os cenários são `Health`, `Echo` e
`ADDON.Execute` com `module = "examples/hbbridgesampleaddon.prg"` e os parâmetros
do módulo, usando o [addon compartilhado](../../addons/examples/hbbridgesampleaddon.prg).
O contrato Protheus é `HBBRIDGE/1`, JSON enquadrado e gzip nos dois sentidos.
O núcleo é genérico; Protheus resolve regras de negócio, tenant, empresa,
filial/xFilial e tabelas e fornece parâmetros explícitos aos serviços/addons.

Para SQL e consultas paginadas, encerre este servidor e use o
[exemplo SQL](../sql/README.pt-BR.md):

```powershell
.\examples\sql\run.ps1
```

Sem perfis SQL no arquivo selecionado ou no `out/hbbridge.ini` automático,
o host não registra `RPCRDD.Query`. Também é possível habilitar o perfil com
`.\examples\mvp\run.ps1 -Config config/examples/sqlite.ini`
ou o equivalente `sqlite.json`.
O exemplo SQL valida o perfil e informa a chamada de `U_HBBridgeQueryTest`.
Esses launchers iniciam o servidor; os testes Protheus são executados
separadamente no AppServer.

Para regressão Harbour automatizada, consulte [testes](../../tests/README.pt-BR.md).
NETIO nativo e VF IO Harbour já têm testes no [Marco 1](../../docs/milestone1.pt-BR.md).
O [Marco 2](../../docs/milestone2-framing.pt-BR.md) corrige a recepção TCP; Health,
ADDON.Execute e os dois Echo foram homologados no Protheus. Os limites de
payload/rede são políticas opcionais, desativadas por padrão; o buffer de
leitura não limita o tamanho total da mensagem. O [Marco 3](../../docs/milestone3-sql.pt-BR.md)
implementa SQLite e paginação no SGBD, com MSSQL via ODBC disponível para
homologação. O dataset SQLite e a paginação foram homologados no AppServer em
04/10/2026, com 29 verificações verdadeiras. A nova leitura da seção `[hbBridge]`
no AppServer recebeu aceite manual posterior, registrado em 2026-10-04,
com 13 checks, relógio Windows e RPC normal. Os renomes TLPP e a configuração
revisada com 16 checks precisam de nova compilação e homologação.
`SQLProfile` é opcional e vazio por padrão; `sqlite_demo` é somente um alias
de exemplo, nunca um banco fixo da biblioteca.
Fachada VF IO TLPP, serviço de sistema, negociação e depuração continuam
nas etapas descritas no [TODO](../../TODO.pt-BR.md).
