# Scripts de compilação, execução e validação

[English](README.md)

São necessários PowerShell 7 e Git. O bootstrap gerenciado resolve cópias
fixadas de hb_compile, Harbour e Zig; veja [dependências](../docs/dependencies.pt-BR.md).
Não depende de um checkout pessoal nem de Zig instalado globalmente.

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

## Validação de commits

Antes de cada commit:

```powershell
./scripts/commit-check.ps1
```

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
`HBBRIDGE_TOTVS_START_SCRIPT` opcionais indicam scripts do operador; não
se presume instalação fixa nem parada de processos elevados. Falha de
parada configurada interrompe a compilação. O reinício é tentado após o
compilador, preservando seu resultado. O log fica em `tmp/totvs-compile.log`.
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
./examples/sql/run.ps1 -Config config/examples/databases.ini -Profile mssql/pData
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
alias, como `mssql/pData`. Sem alias, o teste informa PROFILE_REQUIRED.

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

O operador aceitou os 13 checks INI, relógio Windows, RPC normal e os 29
checks SQLite no relato registrado em 2026-10-04. Tentativas anteriores de
parada TOTVS permanecem históricas; não houve log posterior de compilação
informado. Novos nomes e os 16 checks revisados precisam de novo aceite.
Falhas/envios parciais forçados, destinos não padrão, MSSQL e Linux continuam
pendentes. A [proposta de credenciais](../docs/credentials.pt-BR.md) descreve
armazenamento portátil; gerenciamento de credenciais cifradas ainda não foi
implementado.
