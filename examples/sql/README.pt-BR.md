# Exemplo SQL do hbBridge

[English](README.md)

Este exemplo prepara o servidor para `U_HBBridgeQueryTest`, incluindo consultas
paginadas. Usa o mesmo `out/hbbridge.exe` do produto e o
[launcher compartilhado](../../scripts/run-hbbridge.ps1); a implementação SQL
e os testes ficam nos fontes do produto.

Com o hbBridge atualizado já compilado, encerre a instância anterior com
Ctrl+Q e execute da raiz do repositório:

```powershell
.\examples\sql\run.ps1
```

Também pode usar o caminho completo:

```powershell
pwsh '<repository-directory>/examples/sql/run.ps1'
```

O padrão é [config/examples/sqlite.json](../../config/examples/sqlite.json),
com o perfil `sqlite_demo` e SQLite `:memory:`. O banco é novo a cada chamada;
o teste usa consultas de constantes e não precisa criar tabelas. O script
valida o perfil escolhido e informa a chamada Protheus com host e porta.
Se `-Profile` não for informado, escolhe o primeiro perfil do arquivo.

Também aceita INI, lido pela mesma validação nativa do servidor:

```powershell
.\examples\sql\run.ps1 -Config config/examples/sqlite.ini
```

Para INI, o launcher consulta `--config-info` do executável para obter
metadados sanitizados, sem iniciar listeners nem abrir bancos. Recompile o
produto atualizado antes de usar essa opção. JSON permanece compatível.
Veja a [configuração por arquivo](../../docs/configuration.pt-BR.md).

Esse script inicia o servidor. A execução do teste ocorre separadamente no
AppServer, após compilar `src/tlpp/` quando houver fontes novos:

```advpl
U_HBBridgeQueryTest("sqlite_demo", "127.0.0.1", 1512, 30000)
```

Com a seção `[hbBridge]` do AppServer alinhada ao perfil/destino do servidor, abra
[U_HBBridgeQueryTest no WebApp](https://localhost:4321/webapp/?p=U_HBBridgeQueryTest&e=PROTHEUS).
Na nova revisão cliente, a chamada sem argumentos lê essa seção do INI usado
pelo AppServer. O [template](../../config/examples/protheus-appserver.ini)
configura o destino local e deixa `SQLProfile` vazio e opcional. O destino
padrão é `127.0.0.1:1512`, com timeout de 30000 ms. Configure o perfil ou
informe-o explicitamente; sem alias o teste retorna `PROFILE_REQUIRED` antes
do acesso à rede. `sqlite_demo` é somente deste exemplo. Argumentos
explícitos têm prioridade.
O script não compila nem reinicia o ambiente TOTVS. Uma mudança somente no
perfil SQL do servidor não exige recompilar o TLPP já atualizado.

## Outros perfis e portas

Para MSSQL, configure primeiro um DSN ODBC acessível ao processo hbBridge,
ajuste o [arquivo de exemplo](../../config/examples/mssql.json) e execute:

```powershell
.\examples\sql\run.ps1 -Config config/examples/mssql.json -Profile mssql_demo
.\examples\sql\run.ps1 -Config config/examples/mssql.ini -Profile mssql_demo
./examples/sql/run.ps1 -Config config/examples/databases.ini -Profile mssql/pData
```

No Protheus, informe explicitamente o perfil:

```advpl
U_HBBridgeQueryTest("mssql_demo", "127.0.0.1", 1512, 30000)
U_HBBridgeQueryTest("mssql/pData", "127.0.0.1", 1512, 30000)
```

Para MSSQL, outro perfil ou outra porta, alinhe `[hbBridge]` no AppServer ou
use a chamada explícita mostrada pelo launcher. O link WebApp sem argumentos
usa essa configuração cliente, que pode diferir da configuração do servidor.
`-Config` aceita um caminho absoluto ou
relativo à raiz do projeto. `-Port` e `-MaxWorkers`, quando informados,
sobrepõem esses valores do INI/JSON; quando omitidos, preservam a configuração.
`-Profile` seleciona o perfil mostrado na chamada de teste, sem alterar o arquivo.
Os aliases são chaves opacas e distinguem maiúsculas/minúsculas; cada chamada
ou dataset pode selecionar outro perfil no mesmo cliente. Eles não resolvem
tenant, empresa, filial/xFilial ou nomes físicos de tabelas; Protheus prepara
esses dados e regras. Um nome `oracle/alias` não habilita um driver Oracle,
cujo suporte permanece futuro. Veja [arquitetura](../../docs/architecture.pt-BR.md)
e [credenciais](../../docs/credentials.pt-BR.md).

Para SQLite persistente, configure `database` com um arquivo existente.
Caminhos relativos de bancos são resolvidos a partir da pasta do INI/JSON.
O contrato, a paginação e os pontos ainda pendentes de homologação estão no
[Marco 3](../../docs/milestone3-sql.pt-BR.md).

## SERVICE_NOT_FOUND

Esse erro indica que o processo conectado não registrou `RPCRDD.Query`, antes
de abrir qualquer banco. Sem perfis no arquivo selecionado ou no `hbbridge.ini`
automático junto ao executável, o host usa `sqlProfiles = {}`.
Encerre essa instância e use o launcher SQL; confira também
a porta informada para o teste. Um perfil desconhecido em um serviço já
registrado produz `PROFILE_NOT_FOUND`.

As regressões Harbour anteriores passaram em **412 verificações**, sem falhas ou
skips, incluindo a leitura INI. A validação gerenciada posterior de 2026-10-04
passou em **416 verificações**, zero falhas e nenhum skip; o log fica em
`tmp/tests-d1b829ff332c414f816a6e70748152d1/results.log`. Esses resultados
precedem os ajustes PascalCase/HTTP de 2026-10-06.
O operador homologou SQLite no AppServer em
04/10/2026 às 00:40:06, com as 29 verificações do dataset e paginação verdadeiras.
MSSQL real permanece pendente. Esse aceite antecede a nova leitura da seção
`[hbBridge]` no AppServer. A nova configuração cliente foi aceita em relato
manual posterior, registrado na sessão de 2026-10-04: seus 13 checks,
incluindo `activeAppServerIni`, passaram, assim como relógio Windows,
Health, ADDON, ambos os Echo de 200.000 bytes e novamente os 29 checks de
Query `sqlite_demo`. Não foram informados argumentos das chamadas ou log de
compilação. Destinos diferentes dos padrões e cenários forçados de
timeout/falhas/envios parciais ainda precisam de homologação; o relato não
substitui o teste MSSQL. Veja a [matriz](../../docs/acceptance.pt-BR.md).
