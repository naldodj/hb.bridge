# Scripts

[build-hbbridge.ps1](build-hbbridge.ps1) e o caminho oficial de compilacao.
Usa Harbour/Zig em `<HbCompileRoot>/out/zig`, compila a biblioteca `hbbridge_zig`
e o projeto `hbbridge.hbp`, que inclui os componentes de `hbbridge.hbm`.
O parametro padrao continua `C:\GitHub\hb_compile`; informe o checkout local:

```powershell
.\scripts\build-hbbridge.ps1 -HbCompileRoot F:\GitHub\hb_compile
```

Antes do link, esse script encerra o `out/hbbridge.exe` ativo. Sua limpeza de
builds alternativos limita-se a `hbBridge-*.exe` e `hbBridge-*.pdb` diretamente
em `out/`. O resultado e o executavel canonico `out/hbbridge.exe`.

[test-hbbridge.ps1](test-hbbridge.ps1) compila e executa as regressoes Harbour
contra os mesmos componentes. Seu padrao de `HbCompileRoot` e o repositorio
irmao `hb_compile`; o parametro explicito tambem pode ser usado:

```powershell
.\scripts\test-hbbridge.ps1 -HbCompileRoot F:\GitHub\hb_compile
```

Esse runner prepara fixtures/artefatos em uma pasta exclusiva `tmp/tests-*`,
grava `results.log` e devolve o resultado da suite, sem parar o servidor do
produto. Os artefatos ficam disponiveis para diagnostico e sao ignorados pelo Git.
Ambos os scripts exigem PowerShell 7+ e Zig no PATH.

A suite inclui os testes unitarios de configuracao, contrato de servicos e
NETIO/admin/VF IO do [Marco 1](../docs/milestone1.pt-BR.md), alem das regressoes MT.
Os [testes TCP do produto](../tests/integration/harbour/hbbridgeframingtest.prg)
exercitam fragmentação gzip, comprimento canônico, CRC/truncamento, políticas
opcionais de tamanho, prazos e JSON maior que 16 MiB. A suíte compartilha o
compressor/decoder C e os componentes Harbour com o executável.
Para configurar o produto, use `out/hbbridge.exe "-config=config/examples/hbbridge.ini"`
ou o equivalente JSON; a precedência é padrões < arquivo < CLI.
o host inicia NETIO e Protheus no mesmo processo, e admin quando ha credencial.

As opções do atendimento podem ser sobrepostas pela CLI:

| JSON | CLI | Padrão |
| --- | --- | --- |
| `protheusMaxPayloadBytes` | `-maxpayloadbytes=` | `0`, sem teto adicional do aplicativo. |
| `protheusMaxWireBytes` | `-maxwirebytes=` | `0`, sem teto adicional do aplicativo. |
| `protheusReadChunkBytes` | `-readchunkbytes=` | `65536`, buffer de leitura. |
| `protheusTimeoutMs` | `-iotimeout=` | `30000`; `0` desativa o prazo no servidor Harbour. |
| `netioTimeout` | `-netiotimeout=` | `0`, convertido para `-1` nativo. |
| `maxWorkers` | `-maxworkers=` | `64`, concorrência por listener. |

Valores são validados contra as capacidades reais reportadas por
`HBBridgeRuntimeLimits()`. Payload/rede positivos são políticas opcionais da
instalação; o buffer não limita o tamanho total da mensagem. O cliente TLPP
mantém prazo positivo padrão de 30 segundos e os limites reais do AppServer,
incluindo `MAXSTRINGSIZE`. Corpo JSON em memória, blocos lógicos e negociação
devem ser distinguidos; a transferência em blocos continua pendente.

[build-totvs.cmd](build-totvs.cmd) compila a arvore `src/tlpp/`, incluindo
`tests/protheus/`, no ambiente `PROTHEUS`. Usa AppServer/includes em `C:\totvs`
e os scripts locais `stop-totvs.bat`/`start-totvs.bat`; execute com elevacao
quando os processos TOTVS estiverem elevados. Um erro na parada interrompe a
compilacao. O resultado do compilador e preservado durante o reinicio; o log
fica em `tmp/totvs-compile.log`.

Depois, acesse [U_HBBridgeConnectionTest no WebApp](https://localhost:4321/webapp/?p=U_HBBridgeConnectionTest&e=PROTHEUS).
Compilacao e teste reais confirmados em [homologacao](../docs/acceptance.pt-BR.md).

Para SQL, compile o produto atualizado e inicie-o com
`.\examples\sql\run.ps1`. Compile `src/tlpp/` quando houver fontes novos e
acesse [U_HBBridgeQueryTest](https://localhost:4321/webapp/?p=U_HBBridgeQueryTest&e=PROTHEUS).
O perfil `sqlite_demo` usa `:memory:` para consultas de constantes. Para dados
persistentes, indique um arquivo existente; para MSSQL, configure o DSN ODBC
do [perfil de exemplo](../config/examples/mssql.json). Detalhes de páginas,
dependências e homologação em [Marco 3](../docs/milestone3-sql.pt-BR.md).
O runner inclui SQLite real em arquivo, SQL paginado, concorrência e comparação
NETIO/TCP; não depende do MSSQL ou do DBAccess para essa regressão.
SQLite e paginação no AppServer foram homologados pelo operador em 04/10/2026,
às 00:40:06: 29 verificações verdadeiras. A nova leitura de `[hbBridge]` no
AppServer foi aceita em relato manual posterior, registrado na sessão de
2026-10-04: 13 checks do teste de configuração, incluindo `activeAppServerIni`,
relógio Windows, Health, ADDON, dois Echo de 200.000 bytes e novamente os 29
checks de Query `sqlite_demo` passaram. A execução foi feita pelo operador;
o bloqueio anterior de parada TOTVS pelo agente permanece histórico, sem
log posterior de compilação informado. Timeout/falhas/envios parciais forçados,
destinos não padrão, MSSQL real e outras plataformas permanecem pendentes.
O runner Harbour atual passou em **412 verificações, zero
falhas, sem skips**, incluindo INI e validação estrita dos parâmetros SQL.

## Iniciar o produto e os exemplos

[run-hbbridge.ps1](run-hbbridge.ps1) é o launcher compartilhado do executável
canônico. Resolve `-Config` em relação à raiz do projeto, prepara o diretório
de trabalho para o loader localizar `addons/` e preserva as opções do INI/JSON.
`-Port` e `-MaxWorkers` só sobrepõem a configuração quando informados:

```powershell
.\scripts\run-hbbridge.ps1 -Config config/examples/hbbridge.ini
```

Encerre a instância anterior com Ctrl+Q antes de iniciar outro exemplo nas
mesmas portas. O launcher não compila fontes nem encerra o AppServer.

O [exemplo mínimo](../examples/mvp/README.pt-BR.md) só encaminha argumentos explícitos.
Porta `1512` e `64` workers são padrões do runtime; o arquivo pode substituí-los.
Sem `-Config`, o executável procura `hbbridge.ini` junto ao próprio binário,
em `out/` na instalação canônica. Sem arquivo/perfis SQL, `RPCRDD.Query` não é
registrado. Um arquivo inválido encontrado impede o início.

O [exemplo SQL](../examples/sql/README.pt-BR.md) usa
`config/examples/sqlite.json`, valida o perfil selecionado e mostra a chamada
de `U_HBBridgeQueryTest` para o host/porta configurados:

```powershell
.\examples\sql\run.ps1
.\examples\sql\run.ps1 -Config config/examples/sqlite.ini
.\examples\sql\run.ps1 -Config config/examples/mssql.ini -Profile mssql_demo
```

Configure o DSN ODBC antes do exemplo MSSQL. A execução do teste é manual no
AppServer. Na nova revisão cliente, o link WebApp sem argumentos lê `[hbBridge]`
do INI usado pelo AppServer; o fallback de `SQLProfile` é `sqlite_demo`.
Alinhe o [template cliente](../config/examples/protheus-appserver.ini) ao destino
do servidor ou use a chamada explícita mostrada pelo script. O launcher não
altera o INI do AppServer e sua configuração pode ser diferente.
Alterar somente o perfil do host não exige recompilar o TLPP já atualizado.

Para INI, o launcher SQL usa `--config-info` do executável atualizado, sem
duplicar o parser em PowerShell. O comando valida e retorna metadados de
host/porta, workers e nomes/drivers dos perfis, sem senhas, strings de conexão
ou caminhos de dados; não inicia o host. Recompile o produto antes de usar
essa opção. Para verificar um arquivo manualmente:

```powershell
.\out\hbbridge.exe --config-info "-config=config/examples/sqlite.ini"
```

As regras de seções, caminhos e precedência estão em
[configuração](../docs/configuration.pt-BR.md). JSON continua aceito pelos launchers.
