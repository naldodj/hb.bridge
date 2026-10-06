# Marco 3 — primeira entrega de RPCRDD.Query

O serviço [hbbridgequery.prg](../src/hb/services/hbbridgequery.prg) consulta bancos
pela implementação nativa `rddsql`/`SQLMIX` do Harbour. O produto vincula
`sddsqlt3` para SQLite e `sddodbc` para MSSQL via ODBC. Não há um RDD próprio.
SQLite e o cliente dataset/paginação foram homologados no AppServer pelo
operador em 04/10/2026, às 00:40:06, com 29 verificações verdadeiras.
A conexão MSSQL real permanece pendente. Esse aceite antecede a nova leitura
de `[hbBridge]` no AppServer. Em novo relato manual registrado na sessão de
2026-10-04, o operador confirmou essa leitura com os 13 checks do teste de
configuração cliente, além de relógio, Health, ADDON, Echo e novamente os
29 checks de Query `sqlite_demo`. O aceite cobre os testes executados no
Windows alvo; MSSQL e destinos não padrão continuam pendentes.

## Perfis no servidor

`sqlProfiles` é um hash interno do host, configurado por JSON ou seções
`[SQL/nome_do_perfil]` de INI, com padrão vazio. O catálogo
só registra `RPCRDD.Query` quando pelo menos um perfil está configurado.
O cliente envia o nome lógico em `alias`; caminhos, DSN e credenciais ficam
no servidor e não aparecem na descoberta nem nas mensagens de erro do serviço.
O armazenamento dos perfis no arquivo ainda não usa criptografia.
A precedência é padrões < um arquivo INI/JSON < CLI; sem `-config`, o host
procura `hbbridge.ini` junto ao executável. Um arquivo explícito substitui essa
seleção, sem mesclar dois arquivos. Veja [configuração](configuration.pt-BR.md).

O [exemplo SQLite](../config/examples/sqlite.json) configura `sqlite_demo`
com `database = ":memory:"`. Esse banco é novo em cada chamada e permite
testar consultas de constantes sem instalar outro serviço ou criar tabelas.
Para dados persistentes, use um arquivo SQLite existente; o caminho relativo
é resolvido a partir da pasta do INI/JSON. Um arquivo ausente resulta em
`CONNECTION_FAILED`, sem criação silenciosa de um banco vazio.

O [exemplo MSSQL](../config/examples/mssql.json) configura `mssql_demo` com
`driver = "mssql"` e `connectionString` de um DSN ODBC. O DSN e seu driver
devem existir no ambiente do processo hbBridge. Essa conexão acessa o banco
diretamente via ODBC, independentemente do DBAccess e do `LOCALFILES` do Protheus.
Os equivalentes [sqlite.ini](../config/examples/sqlite.ini) e
[mssql.ini](../config/examples/mssql.ini) configuram os mesmos perfis.

## Contrato por chave

Entrada do serviço, versão 1:

```json
{
    "service": "RPCRDD.Query",
    "params": {
        "alias": "sqlite_demo",
        "sql": "SELECT 1 AS ID, 'Harbour' AS NAME"
    }
}
```

Retorno: `success`, `header`, `rows`, `rowCount`, `driver` e `resultVersion = 1`.
`header` é um hash por nome de coluna em maiúsculas, com `position`, `type`,
`length` e `decimals` obtidos do RDD. `rows` é um hash por ordinal decimal
(`"1"`, `"2"`, ...); cada linha é um hash por nome de coluna. O cliente navega
de 1 até `rowCount`, sem depender da ordem de enumeração do hash.

Uma consulta vazia retorna `rowCount = 0`, `rows = {}` e mantém o cabeçalho.
Nomes duplicados após normalização resultam em `AMBIGUOUS_COLUMN`; use aliases
SQL distintos. Perfis desconhecidos, parâmetros inválidos, conexão ausente e
SQL inválido têm códigos próprios. O novo contrato usa hashes Harbour e
`JSONObject` TLPP; arrays aparecem apenas nas interfaces que o RDD nativo exige.
As únicas chaves aceitas em `params` são `alias`, `sql` e `page` opcional;
chaves adicionais retornam `INVALID_PARAMS`.

`sql` é entregue ao conector nativo. O serviço não implementa um analisador SQL,
controle de permissões de tabelas nem parâmetros vinculados nesta entrega.
As permissões de acesso e execução são as da conexão configurada no SGBD.

## Paginação no SGBD

O objeto opcional `params.page` tem `number`, `size` e `orderBy`:

```json
{
    "alias": "sqlite_demo",
    "sql": "SELECT 10 AS ID, 'Harbour' AS NAME UNION ALL SELECT 50, 'hbBridge'",
    "page": { "number": 1, "size": 1, "orderBy": "ID ASC" }
}
```

O servidor envolve a consulta em `ROW_NUMBER() OVER (ORDER BY ...)` e filtra
o ordinal com `BETWEEN`: início `(number - 1) * size + 1`, fim `number * size + 1`.
A linha adicional informa `hasNext` e não entra no dataset. Esse padrão segue
o exemplo local `userrestcrudadvpl.prw` analisado; `ID` nesse algoritmo representa
a posição no resultado, não o valor de uma chave primária. Chaves com lacunas
funcionam normalmente. Há um `ORDER BY` externo no ordinal para preservar a
ordem final. As regras nativas estão descritas na documentação de
[SQLite](https://www.sqlite.org/windowfunctions.html) e
[MSSQL](https://learn.microsoft.com/en-us/sql/t-sql/functions/row-number-transact-sql).

O retorno acrescenta `page` com `number`, `size`, `hasNext`, `firstRow` e
`lastRow`; `rowCount` conta apenas a página. `firstRow`/`lastRow` são zero
quando ela está vazia. As chaves de `rows` recomeçam em `"1"` a cada página.
O campo interno `__HBBRIDGE_ROWNO` não aparece no cabeçalho nem nas linhas.

`orderBy` aceita nomes simples de colunas expostas pela consulta, separados
por vírgula, com `ASC`/`DESC` opcionais. São permitidos letras ASCII, `_` e
dígitos após o primeiro caractere. Não aceita expressões SQL. Use aliases
distintos e evite `:` e o prefixo reservado `__HBBRIDGE_ROWNO`: SQLite pode
renomear colunas duplicadas de subconsultas com `:1`, e o serviço rejeita
esse caso em vez de expor nomes ambíguos. A consulta base precisa ser válida
como subconsulta nos dois bancos; deixe a ordenação da página em `orderBy`,
especialmente no MSSQL. Um ponto e vírgula final é removido antes de envolvê-la.

Número e tamanho são inteiros positivos, sem teto fixo de páginas ou linhas.
O ordinal final, incluindo a linha extra, deve caber em `2^53 - 1`, faixa
de inteiros exatos comum ao contrato JSON/TLPP. Entradas inválidas retornam
`INVALID_PAGE`. A ordem deve incluir um desempate único. Cada página é uma
nova consulta: alterações concorrentes podem deslocar linhas; não há snapshot.
Paginação por chave/cursores e ordenações mais amplas ficam para evolução.

## Ciclo de vida e custo

Cada chamada abre uma conexão e uma área, lê o resultado, fecha a área e
desconecta. A área selecionada e a conexão padrão anteriores são restauradas.
O RDDSQL inspecionado mantém sua tabela de conexões em variáveis C globais;
um mutex do serviço protege o ciclo inteiro. Requisições concorrentes são
atendidas com isolamento, mas suas operações SQL são serializadas nesta etapa.
Uso direto de RDDSQL por addons precisa respeitar a mesma coordenação antes
de ser homologado em paralelo.

O resultado é materializado pelo RDD e pelo serviço, e o cliente mantém o
objeto JSON completo. Não há um teto artificial de linhas; capacidade do
runtime, memória e políticas do transporte continuam aplicáveis. Com `page`,
o banco devolve no máximo `size + 1` linhas e a resposta mantém até `size`;
o resultado completo não é buscado para recorte no Harbour/TLPP. O banco ainda
pode ordenar/percorrer muitas linhas, principalmente em páginas profundas.
Cursores, cancelamento e timeout de execução SQL ainda não estão implementados.
O timeout de rede não interrompe uma consulta bloqueante no conector.

Tipos e nulos refletem o mapeamento do RDD vinculado. A regressão SQLite
distingue `NULL` em uma expressão de texto vazio. Isso não certifica o
mapeamento de todas as colunas nulas declaradas: conectores podem convertê-las
em valores padrão. Datas, BLOBs, codepages, precisão ampliada e representação
explícita de nulos continuam na evolução do contrato.

## Cliente e teste Protheus

[HBBridgeRPCDataSet](../src/tlpp/hbbridgerpcdataset.tlpp) usa `JSONObject` para o resultado,
com `OpenSQL`, `FieldGet`, `Skip`, `Eof`, `Close`, `RowCount`, `ErrorCode` e
`ErrorMessage`. `OpenPage(profile, sql, number, size, orderBy)`, `NextPage`,
`HasNextPage`, `PageNumber` e `PageSize` fazem a navegação paginada explícita.
`Skip` percorre apenas a página atual; `NextPage` realiza outra chamada.
`New(oClient)` aceita um `HBBridgeClient` já configurado;
`New()` cria o cliente usando os valores de `[hbBridge]` no INI do AppServer,
com fallback local quando as chaves não existem. `Close` libera o resultado; os erros
de abertura deixam o dataset vazio. A classe possui o objeto de resposta
completo para manter a validade dos objetos JSON internos.

Após compilar o hbBridge atualizado, encerre a instância anterior com Ctrl+Q
e execute na raiz do projeto:

```powershell
.\examples\sql\run.ps1
```

O [launcher SQL](../examples/sql/README.pt-BR.md) usa o perfil `sqlite_demo`,
valida a configuração e mostra a chamada Protheus. Compartilha
[scripts/run-hbbridge.ps1](../scripts/run-hbbridge.ps1) com o exemplo mínimo,
sem duplicar o servidor. Ele prepara o servidor; a execução do teste ocorre
separadamente no AppServer.
Para usar INI, informe `-Config config/examples/sqlite.ini`. O launcher consulta
`--config-info` do binário atualizado para validar e obter metadados sanitizados,
sem iniciar listeners; recompile o produto para essa opção. JSON continua aceito.

Quando houver fontes novos, compile toda a árvore `src/tlpp/`, incluindo o novo
[hbbridgequerytest.tlpp](../src/tlpp/tests/protheus/hbbridgequerytest.tlpp).
O utilitário do projeto é `.\scripts\build-totvs.cmd`. Alterar somente o
perfil SQL do host não exige recompilar o TLPP já atualizado.
Na nova revisão, `HBBridge.Client.HBBridgeConfig():Read()` lê o INI selecionado
por `GetSrvIniName()`, usando `GetPvProfString` para `[hbBridge]`. O
[template AppServer](../config/examples/protheus-appserver.ini) contém `Host`,
`Port`, `TimeoutMs`, `MaxPayloadBytes`, `MaxWireBytes`, `ReadChunkBytes` e
`SQLProfile`. Mescle essa seção no INI usado pelo AppServer e alinhe o destino
ao host hbBridge; ela não é o arquivo de configuração do processo Harbour.
Argumentos explícitos do cliente/testes têm prioridade sobre essa seção.
Execute [U_HBBridgeQueryTest](https://localhost:4321/webapp/?p=U_HBBridgeQueryTest&e=PROTHEUS)
ou `U_HBBridgeQueryTest("sqlite_demo", "127.0.0.1", 1512, 30000)`.
O teste verifica campos por nome, duas linhas, decimal, navegação, EOF,
fechamento, resultado vazio, erros SQL/perfil e recuperação após falhas.
Também verifica primeira/próxima/última página, IDs com lacunas, EOF local,
ordinal oculto e parâmetros de página/ordenação inválidos.
Para MSSQL, configure o DSN/perfil e inicie com:

```powershell
.\examples\sql\run.ps1 -Config config/examples/mssql.ini -Profile mssql_demo
```

Informe `mssql_demo` no primeiro argumento de `U_HBBridgeQueryTest`.
O link WebApp sem argumentos lê o perfil/destino de `[hbBridge]` no AppServer,
com destino padrão `127.0.0.1:1512`. `SQLProfile` é opcional e vazio por
padrão; configure-o ou informe o alias explicitamente. Sem alias, o teste
retorna `PROFILE_REQUIRED` antes do acesso à rede. `sqlite_demo` pertence
apenas ao exemplo SQLite. O launcher informa os valores do
servidor, sem alterar o INI do AppServer. Para MSSQL ou outra porta, alinhe a
seção cliente ou use a chamada explícita mostrada pelo launcher.
O teste de conexão já homologado permanece em `U_HBBridgeConnectionTest`.

Cada consulta/dataset pode escolher seu alias, como `mssql/pData`, no mesmo
cliente. Os aliases são opacos e distinguem maiúsculas/minúsculas; um nome
`oracle/alias` não implementa um driver Oracle. A validação atual admite
somente `sqlite` e `mssql`. O Protheus resolve tenant, empresa, filial/xFilial
e tabelas físicas e envia SQL e parâmetros explícitos. Veja
[arquitetura](architecture.pt-BR.md).

### SERVICE_NOT_FOUND ao executar o teste

`SERVICE_NOT_FOUND` significa que o processo conectado não registrou
`RPCRDD.Query`; ocorre antes de tentar abrir o banco. Um perfil ausente em
um serviço já registrado retorna `PROFILE_NOT_FOUND`, um caso diferente.
A configuração padrão e `config/examples/hbbridge.json` usam `sqlProfiles = {}`.
Compile o produto atualizado se necessário, encerre a instância anterior com
Ctrl+Q e inicie, da raiz:

```powershell
.\examples\sql\run.ps1
```

O início passa a informar `RPCRDD.Query enabled; SQL profiles=1` ou
`RPCRDD.Query disabled; sqlProfiles is empty`, sem imprimir caminhos/credenciais.
`Service.List` deve incluir `RPCRDD.Query` no endpoint que o teste utiliza.
O launcher `examples/mvp/run.ps1` só encaminha argumentos explícitos; sem
`-Config`, o host procura `out/hbbridge.ini`. Se nenhum arquivo configura
perfis SQL, o serviço fica desativado.
Ele também aceita `-Config config/examples/sqlite.ini` ou o JSON equivalente; o launcher SQL
acrescenta a validação do perfil e as instruções do teste.
Não é necessário recompilar TLPP apenas para corrigir a configuração do host.

## Regressões e referências

[hbbridgequerytest.prg](../tests/integration/harbour/hbbridgequerytest.prg) integra
o runner Harbour. Cria um SQLite real em arquivo isolado, consulta dados
persistidos, compara o serviço pelos transportes NETIO e TCP/JSON e exercita
concorrência, resultados vazios, nulos em expressão, perfis e erros. Inclui
paginação cheia/parcial/vazia, ordenação composta/descendente, lacunas,
metadados, coluna reservada, aliases duplicados e limites numéricos.

Validação anterior em 2026-10-04: **412 verificações, zero falhas, sem skips** no runner
completo, Harbour `3.2.1dev (r2608271822)`, Zig `0.16.0`, Windows x64 e
SQLite **3.53.4**, obtido por `sqlite_version()` no runtime vinculado.
Log: `tmp/tests-236f1241c1174cf4b193c22f6eedb6e0/results.log`.
As 29 verificações adicionais sobre a suíte de 383 cobrem 26 casos INI e
três rejeições adicionais de driver/direção de ordenação inválidos.
O teste SQL tem credencial NETIO própria: a API nativa pode herdar a senha
da conexão anterior quando recebe uma string vazia.

A revisão gerenciada de dependências/nomes/perfis passou em **416 checks,
zero falhas e nenhum skip** em 2026-10-04, log
`tmp/tests-d1b829ff332c414f816a6e70748152d1/results.log`. Foram dois casos
INI e dois SQL adicionais sobre aliases. Esse resultado precede os ajustes
PascalCase/HTTP de 2026-10-06 e não substitui seu aceite nem a homologação
Protheus dos novos nomes e dos 16 checks de configuração revisados.

A tentativa inicial de `scripts/build-totvs.cmd` não chegou à compilação:
a parada dos processos TOTVS falhou. Log: `tmp/marco3-totvs-build.log`.
Posteriormente, o operador executou `U_HBBridgeQueryTest` no AppServer em
04/10/2026 às 00:40:06, thread `41228`, perfil `sqlite_demo`: todos os 29 checks
retornaram `true`. Isso aceita os campos, navegação, erros/recuperação e
paginação SQLite daquela revisão.

Na rodada manual posterior registrada na sessão de 2026-10-04, o operador
confirmou novamente os 29 checks de Query no perfil `sqlite_demo` e os 13
checks de `U_HBBridgeConfigTest`, incluindo `activeAppServerIni`. Também
confirmou Health, ADDON, dois Echo de 200.000 bytes idênticos, gzip da
requisição variada de 152.964 bytes e relógio Windows: `Unix=false`,
delta `1097.692700`, tempo normalizado `1097.773500 ms` após `Sleep(1000)`,
`result=OK`. Isso aceita os novos testes TLPP e supera a pendência histórica
de execução que o bloqueio de parada deixou ao agente. Não foram informados
horário, thread, hash, argumentos de chamada ou log de compilação dessa rodada.
Destinos diferentes dos padrões, timeout/falhas/envios parciais forçados,
MSSQL real e outras plataformas permanecem pendentes, conforme
[homologação](acceptance.pt-BR.md).

O build do executável também passou em `tmp/marco3-product/hbbridge.exe`,
com `--help` e consulta paginada usando perfil JSON e portas isoladas. O produto
ativo da instalação não foi substituído naquela verificação. Esse smoke é
anterior à inclusão de INI e não certifica a nova configuração cliente.

Fontes primárias: [RDDSQL](https://github.com/harbour/core/blob/master/contrib/rddsql/readme.txt),
[tabela de conexões](https://github.com/harbour/core/blob/master/contrib/rddsql/sqlbase.c),
[exemplo SQLite nativo](https://github.com/harbour/core/blob/master/contrib/sddsqlt3/tests/test.prg)
e [exemplo ODBC](https://github.com/harbour/core/blob/master/contrib/sddodbc/tests/test1.prg).
