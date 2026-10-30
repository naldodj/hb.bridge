# Testes de regressão da apresentação nativa

[English](README.md) · [Contrato SQL tipado](../../../../../docs/typed-sql.pt-BR.md)

T04 separa a conversão para apresentação da validação da tabela nativa e da
interface. Os testes de conversão/sintéticos usam campos lógicos fornecidos
pelo chamador, sem resolver dicionário/contexto ERP. O exemplo SX5 real separado
resolve os detalhes Protheus em sua própria definição; o adapter nativo
permanece genérico.

A fixture determinística usa as implementações reais de `JSONObject`, dataset
e schema com o mock de cliente existente. As verificações cobrem validação do
schema, conversão UTF-8 exatamente uma vez, rejeição de NULL sem alterar o
dataset, formatos explícitos de data, largura/escala numérica sem
arredondamento e snapshots defensivos das entradas/saídas. Essas verificações
não exigem conexão SQL ou navegador.

Os testes da tabela nativa usam ambiente Protheus preparado. Armazenamento
`TOPCONN` e checks FWBulk exigem DBAccess/`FWTemporaryTable`; `SQLITE_MEM` e
`SQLITE_TMP` escolhem armazenamento local do SDK. Validam o armazenamento real dos campos, página vazia com
metadados, posse dos recursos, restauração da área selecionada e liberação.
A apresentação consome um snapshot da página atual: não deve buscar a página
seguinte, substituir bindings ou fechar o dataset/cliente/áreas do chamador.
`HBBridgeNativeTable` tem padrão `SQLITE_MEM`; `TOPCONN` explícito escolhe FWBulk
quando suportado e gravação por registro nos demais casos. Os RDDs SQLite locais
gravam por registro. O teste percorre independentemente cada linha gravada e
compara os sete campos públicos. Checks separados de índice/pesquisa exercitam
o auxiliar privado de pesquisa lógica.
Releitura completa em produção é opcional pelo terceiro
argumento do construtor, `lVerifyStorage` (padrão `.F.`); a fixture pequena
também exercita `.T.`. O adapter reserva o alias uma vez e conserva a mesma
tabela, área e índices já criados durante preenchimento/limpeza da página. Um
índice inicial é criado após a primeira carga, com os demais sob demanda.
`Close()`/`Destroy()` final libera os recursos nativos próprios; o SDK gerencia
o ciclo do banco SQLite local pela conexão. Os testes
verificam identidade estável, pesquisa por índice após recarga e recuperação
sem substituir a fonte do browse. Consulte `WriteMode()` para identificar o
caminho efetivo; compilação ou perfil sem bulk não comprovam aceite desse
caminho. O guia informa os requisitos de LIB/DBAccess.

As APIs de nomes nativos separam identidade da origem e alias SQL:

| API | Significado |
| --- | --- |
| `FieldName("DESCRIPTION")` | Campo nativo de valor gerado `F...` |
| `FieldPos("DESCRIPTION")` / `FieldGet("DESCRIPTION")` | Posição nativa / valor atual desse campo projetado; posições da projeção também são aceitas |
| `ProjectionName(nPosition)` ou `ProjectionName(cNative)` | Chave projetada, como `DESCRIPTION`; strings identificam apenas nomes nativos |
| `SourceFieldName("DESCRIPTION")` | Metadado da coluna de origem aceita ou mapa explícito do chamador, como `X5_DESCRI`; vazio se desconhecida |
| `FieldCaption("DESCRIPTION")` | Legenda desse campo projetado no esquema lógico fornecido pelo chamador |
| `SourceFieldPos/Get/Caption("X5_DESCRI")` | Posição nativa / valor / legenda da projeção com essa origem única |

Metadados da origem são capturados da página aceita, com
`schema.projectionFields` opcional ou o segundo argumento explícito de
`LoadCurrentPage()` preenchendo origens ausentes. Esquemas sem esse mapa
continuam válidos. O construtor o copia; o carregamento não relê um dataset
posteriormente movido pelo chamador. Os métodos inversos de origem rejeitam
origens duplicadas de forma uniforme e permitem usar a chave projetada apenas
quando nenhuma origem corresponde (segundo argumento com padrão `.T.`; `.F.`
resolve apenas a origem). Seus retornos de falha são zero, `nil` e string vazia,
respectivamente. `FieldPos/Get/Caption` mantêm consulta direta pela chave
projetada. Mapeamentos desconhecidos/auxiliares lógicos privados/página fechada
ficam vazios. Legendas não consultam SX3. Para `X5_DESCRI AS DESCRIPTION`, com
origem informada ou mapeada explicitamente:

```advpl
cProjection := oNative:ProjectionName(oNative:FieldName("DESCRIPTION"))
cField := oNative:SourceFieldName(cProjection)
if !Empty(cField)
    cTitle := GetSX3Cache(cField,"X3_TITULO")
endif
```

O adapter nunca consulta SX3 nem deduz origem ausente; veja o
[contrato de mapeamento](../../../../../docs/native-presentation.pt-BR.md#tabela-e-browse-da-página-atual).

O fechamento da interface e o comportamento de `FWBrowse` exigem execução
visual separada. A aprovação da fixture de conversão não comprova o
armazenamento nativo, liberação no banco, suporte a codificações fora da página
de código local testada ou homologação da interface.

Execute `U_HBBridgePresentationTest()` para conversão e
`U_HBBridgePresentationTableTest([nRecords])` para armazenamento/posse nativos. A sonda
SDK é `U_HBBridgePresentationProbe()`. O
[guia de apresentação nativa](../../../../../docs/native-presentation.pt-BR.md)
documenta o runner isolado e a API pertencente ao chamador.

## Origem da fixture e quantidade de registros

Os dados são JSON tipado sintético, gerado por
[`HBBridgePresentationFixture:Row()`/`Result()`](hbbridge.presentation.fixture.tlpp).
O [teste de tabela nativa](hbbridge.presentation.table.test.tlpp) atribui o
número da linha a ID e sua forma de dez dígitos com zeros à esquerda a ID_CODE,
alterna Flag, Day (`2024-02-29`/`2000-02-29`) e Amount
com sinal (`123.25`/`-123.25`), define Float como linha / 4 e conserva `ação`
UTF-8 em Text. **Não há leitura de tabela ERP nem consulta SQL de rede pelo
hbBridge**. O mock fornece páginas ao dataset; DBAccess armazena somente o
destino temporário próprio, excluído na limpeza final.

A ordem pública da projeção é `ID_CODE` C(10), `ID` C(20), `AMOUNT`, `TEXT`,
`FLAG`, `DAY`, `FLOAT`. `ID_CODE` fornece ao índice caractere uma sequência
visual numérica (`0000000001`, `0000000002`, ..., `0000000010`). `ID` conserva
seu contrato de texto int64 exato, sem conversão para ponto flutuante na
ordenação. O código e o identificador de cada linha correspondem ao mesmo
número gerado.
Os critérios caractere da fixture permitem `contains` e `starts with` sobre
`ID_CODE`, assim como em `ID` e `TEXT`; a pesquisa pelo código com zeros não
fica restrita à igualdade exata.

A carga principal tem padrão de **1025 linhas**, ultrapassando o buffer de
1024 linhas do FWBulk. Os casos independentes de navegação permanecem fixos
em **2 + 1 linhas**; mudar a carga principal não redimensiona esses casos.
Execute uma carga principal maior diretamente:

```advpl
U_HBBridgePresentationTableTest(10000)
```

Para compilação/execução isoladas, use
`scripts/test-protheus-presentation.ps1 -NativeTables -NativeRows 10000` com os
argumentos de SDK/INI/RPO/includes documentados no guia. Sua entrada CLI é
`U_HBBridgePresentationTableCLI`, aceitando `--native-rows=10000`. É uma fixture
de correção/carga, não benchmark de tempo; escolha um tamanho compatível com
memória e prazo de execução do ambiente de teste.

## Verificações de browse interativas e sem interface

`U_HBBridgeNativeBrowseTest()` verifica metadados de colunas, blocos de valores
e tabela/navegação nativas sem criar componente `FWBrowse` em job CLI. Sua
aprovação não comprova aceite do diálogo interativo.

Após compilar no RPO de teste interativo, execute
`U_HBBridgeNativeBrowse([nRecords], [nPageSize])`. Os padrões são **1000 linhas
sintéticas e 13 linhas por página**, com armazenamento temporário real.
Aumente explicitamente as duas quantidades quando necessário:

```advpl
U_HBBridgeNativeBrowse(10000,100)
```

O gerador é `HBBridgePresentationBrowseClient():New(nRecords)`, no
[cliente da fixture](hbbridge.presentation.browse.client.tlpp). Sem critérios,
gera somente a página solicitada; com pesquisa/filtros, avalia toda a origem
configurada antes de paginar. O teste de navegação sem interface conserva o
cenário independente de 12 linhas/quatro por página e verifica separadamente
uma origem de 10.000 linhas com 100 linhas por página.

`BrowseNative()` é uma
função estática local [deste exemplo](hbbridge.presentation.browse.tlpp), não método de `HBBridgeBrowseData`;
uma API pública genérica de browse nativo permanece futura. Navegação entre
páginas, pesquisa e filtro ficam no mesmo browse aberto. Fechá-lo encerra o
exemplo sem perguntar se deve abrir outra página. Adapter e UI não fazem
pré-busca de páginas. `SetAlias()` vincula uma vez; callbacks preenchem a mesma
tabela nativa indexada e atualizam o componente. Nove botões oferecem First,
Previous, Next, Last, Refresh, Add filter, Clear filters, View e Close;
pesquisa e filtros tipados Field/Operator/Value são aplicados antes de selecionar
a página pelo [cliente da fixture](hbbridge.presentation.browse.client.tlpp),
com Clear filters para remover filtros e pesquisa. Não implementam
reescrita genérica de SQL. `FieldName()` mapeia valores; `SearchFieldName()` e
`IndexOrder()` mapeiam o campo/ordem nativa de pesquisa correspondente.
`IndexOrder()` não cria índices e devolve zero para um índice ainda ausente.
O diálogo chama `EnsureIndex()` ao selecionar uma coluna de pesquisa, usando
o mapa de campo `aDetails[nOption][1][7]` do SDK. Opções lógicas de pesquisa e
ordens físicas dos índices são distintas; o adapter mantém estáveis as ordens
físicas já criadas. Flag exibe `True`/`False` e conserva campo
nativo lógico; um auxiliar privado C(5) fornece seu índice de pesquisa, sem
ser coluna pública. Índices de data usam `DTOS(field)`. Verifique acentos,
datas, máscaras, alinhamento de Flag/Day/Float, sequência de ID_CODE, troca de
página, pesquisa, filtros, área selecionada e fechamento
normal/cancelamento. A fixture visual independe de serviço hbBridge ativo;
o aceite conjunto com backend permanece em T05.

## Exemplos com SQL efetivo e SX5 real

As entradas sintéticas acima não leem tabela de negócio. Para dados reais da
SX5 no mesmo browse nativo, execute em contexto Protheus de empresa/filial já
preparado, como no FWWebEx:

```advpl
U_HBBridgeNativeBrowseSX5("MSSQL/pData","TCP",100)
U_HBBridgeNativeBrowseSX5("MSSQL/pData","HTTP",100)
```

`U_HBBridgeNativeBrowseSX5([cProfile], [cTransport], [nPageSize])` tem padrões
TCP e 100 linhas por página. Informe o perfil hbBridge do banco pretendido ou
configure `[hbBridge] SQLProfile` no INI AppServer ativo; não há fallback de
demonstração. A configuração cliente fornece endpoints e autorização;
a rota HTTP solicita gzip.

[`HBBridgePresentationSX5:Definition()`](hbbridge.presentation.sx5.tlpp) usa o
builder compartilhado de dicionário/catálogo
`HBBridgePresentationTable():Definition("SX5")`. Projeções suportadas conservam
nomes originais, incluindo `X5_FILIAL`, `X5_TABELA`, `X5_CHAVE` e `X5_DESCRI`,
além de campos de sistema disponíveis. O dicionário local determina o conjunto
completo; os cinco aliases antigos foram substituídos pelas chaves do dicionário.
Protheus resolve tabela física e filial; predicados vinculados de não excluído/
filial atual permanecem fixos, com `R_E_C_N_O_` como último desempate.
`schema.projectionFields` mantém explicitamente os nomes de origem. Não grava
na SX5. É consulta real, distinta da fixture de sete colunas.

[`HBBridgePresentationSQLSource`](hbbridge.presentation.sql.source.tlpp)
fornece ao diálogo local `Query()` com SQL, ordenação e bindings confiáveis.
Nomes de pesquisa/filtro vêm do esquema lógico efetivo. Critérios permitidos
acrescentam parâmetros tipados sem interpolar valores no SQL; curingas/caractere
de escape de LIKE e aspas permanecem entrada literal. Inteiros, datas ISO e
lógicos usam bindings de texto int64, data e booleano; números nativos
fracionários usam bindings numéricos aproximados. Esse controlador do exemplo
não é nova API pública genérica de browse nem parser SQL geral.

`U_HBBridgePresentationSQLTest()` é o teste separado de integração real sem
interface: SELECT MSSQL sobre cinco linhas constantes de `VALUES` fornece as
sete projeções da fixture por clientes TCP/HTTP gzip efetivos, dataset tipado
e armazenamento temporário nativo. Exercita tipos, paginação, critérios
vinculados, recuperação após vazio/falha e liberação sem ler/gravar tabelas ERP.
Para executar, inicie outro processo
`test-hbbridge-typed-sql.ps1 -Config '<ini-privado>' -Profile '<alias-mssql>'
-Serve -ServeSeconds 1200`; passe então o novo arquivo de endpoints impresso a
`test-protheus-presentation.ps1 -NativeTables -HBBridgeEndpointsFile
'<endpoints-novo.json>'`, junto com os argumentos SDK/INI/RPO/includes.
Veja [comandos completos e posse dos recursos](../../../../../docs/native-presentation.pt-BR.md#reproduzir-validação).
Mantenha `endpoints.json` privado: contém token HTTP temporário. Essa execução
AppServer modifica somente seu novo INI próprio. Checks de constantes SQL reais
continuam separados do aceite visual manual da SX5.

Os valores textuais de entrada usam a codificação do AppServer; os clientes
codificam a requisição completa em UTF-8 uma única vez. Não pré-codificar cada
valor de binding.

## Dicionário SRA e cobertura dos campos

Use `U_HBBridgeNativeBrowseSRA("MSSQL/pData","TCP",100)` ou a mesma chamada
com HTTP no contexto Protheus de empresa/filial preparado. Reutiliza esse
diálogo, pesquisa, filtros tipados, paginação explícita e View com as chaves
originais SRA. HTTP exige gzip; perfil/página/transporte omitidos seguem as
regras da SX5.

[`HBBridgeSX3Metadata:Read("SRA")`](../../../hbbridge.sx3.metadata.tlpp)
retorna inventário novo em `JSONObject` por FWSX3Util e APIs do dicionário.
`HBBridgePresentationSRA:Definition()` combina-o com o catálogo físico real
pelo `HBBridgePresentationTable:Definition()` compartilhado, usando
`HBBridgeSqlTools:GetColumnMetadata()`, atualmente MSSQL, e tabela/filial
resolvidas no Protheus. Campos físicos suportados do dicionário e campos de
sistema disponíveis formam o SELECT somente leitura. Cada campo virtual,
memo, binário, texto longo, ausente ou incompatível recebe motivo explícito de
exclusão; os metadados retêm o inventário completo. O exemplo exibe quantidades.
Não adiciona transporte memo/BLOB nem trunca valores silenciosamente.

O exemplo cria CASTs numéricos a partir de tamanho/escala SX3 do chamador, sem
parser SQL genérico ou acesso ao dicionário no servidor. Datas têm contrato
YYYYMMDD explícito, incluindo oito espaços para data vazia. NULL SQL é
preservado no dataset tipado e rejeitado apenas pelo destino nativo.
Veja o [contrato de metadados e uso SRA](../../../../../docs/sx3-metadata.pt-BR.md).
O diálogo SRA também oferece **Field catalog**: linhas somente leitura de
Field/Type/Length/Decimals/Caption/Status/Reason do snapshot, incluindo itens
excluídos. Não é editor da SX3 bruta e não busca valores dos funcionários.
A API de metadados permanece reutilizável independentemente dessa visão.

`U_HBBridgePresentationSRATest()` fornece snapshots determinísticos ao
`HBBridgePresentationTable:Build()` compartilhado e aos métodos `Plan()` de
SRA/SX5. Verifica exclusões comuns de campos, nomes originais/mapas de origem,
projeções somente com campos de sistema e vazias, além dos campos obrigatórios
usados em WHERE/ORDER BY de cada wrapper. Não consulta valores dos funcionários
nem lê o dicionário ativo; os exemplos interativos exercitam essa integração
separada. Os wrappers devolvem definição inválida antes de executar SQL quando
esses requisitos não são atendidos. Veja o [contrato da definição compartilhada](../../../../../docs/sx3-metadata.pt-BR.md#definição-compartilhada-de-apresentação).

A mesma suíte passa uma fixture tipada selecionada com cinco colunas pelo
dataset real e pelo destino próprio `SQLITE_MEM`. Verifica ordem de saída,
valores nativos decimal/data/lógico, decodificação UTF-8, nomes originais do
dicionário e limpeza sem fechar o dataset emprestado. Aliases inválidos como
`VALUE;DROP`, `[VALUE]` e chave vazia são atribuídos por indexação em
`JSONObject`: literais JSON TLPP não representam essas chaves. A rejeição é
obrigatória, sem fallback para alias válido nem aprovação incondicional.

## Campos específicos do dicionário SRA

O exemplo de campos selecionados lê dados reais da SRA no mesmo browse nativo:

```advpl
U_HBBridgeNativeBrowseSRASelected("MSSQL/pData","TCP",100)
U_HBBridgeNativeBrowseSRASelected("MSSQL/pData","HTTP",100)
```

O quarto argumento omitido usa `HBBridgePresentationSRA():SelectedFields()`:
`REGISTRATION` de `RA_MAT`, `NAME` de `RA_NOME`, `AMOUNT` de `RA_SALARIO`,
`ADMISSION_DATE` de `RA_ADMISSA` e `RECORD_ID` de `R_E_C_N_O_`, nessa ordem.
Perfil, empresa/filial preparada, endpoints e requisito de gzip no HTTP são
os mesmos do exemplo SRA com tabela inteira. Essa entrada não consulta a
fixture sintética nem altera o comportamento sem seleção da entrada SRA
existente.

O chamador pode fornecer seu `JSONObject` indexado como quarto argumento:

```advpl
jSelection := JSONObject():New()
jSelection["NAME"] := {"source":"RA_NOME","position":1}
jSelection["AMOUNT"] := {"source":"RA_SALARIO","position":2}
jSelection["RECORD_ID"] := {"source":"R_E_C_N_O_","position":3}
U_HBBridgeNativeBrowseSRASelected("MSSQL/pData","TCP",100,jSelection)
```

`HBBridgePresentationSRA():Definition(jSelection)` e seu método determinístico
`Plan(...,jSelection)` validam primeiro os campos obrigatórios de origem e a
filial e depois usam `HBBridgePresentationTable():Project(jDefinition,jSelection)`
na definição compartilhada ainda não planejada. Aliases de saída são
explícitos; pesquisa/filtro e chaves do esquema usam esses aliases. Legendas,
pictures e CASTs vêm da origem no dicionário, registrada em
`schema.projectionFields`. View conserva o nome original do dicionário em
MsMGet e suas variáveis de memória.

Cada entrada deve conter exatamente `source` e `position`, com posições
inteiras únicas e contíguas, identificadores válidos e aliases de saída únicos
sem distinção de maiúsculas/minúsculas. Origens repetidas são rejeitadas para
evitar identidades conflitantes do dicionário em MsMGet. Campo solicitado
ausente/não suportado ou seleção vazia/malformada falha por completo. Não acrescenta
expressão SQL arbitrária nem campo de sistema automaticamente. A SRA exige a
origem do número de registro com um alias selecionado para ordenar de forma
determinística, por exemplo `RECORD_ID ASC`; predicados de filial/exclusão
permanecem vinculados mesmo quando esses campos não são exibidos.

O resultado retém o catálogo/inventário completo de metadados; origens
suportadas não selecionadas recebem motivo `notSelected`. Entradas e snapshots
do resultado selecionado têm posse independente. `Project()` aceita um
resultado válido de `Build()` antes do planejamento SQL, não uma consulta já
planejada ou definição já projetada. Veja o [contrato da seleção](../../../../../docs/sx3-metadata.pt-BR.md#campos-específicos-e-consultas-com-join).
A API continua limitada a uma tabela; exemplos explícitos com JOIN permanecem
planejados.

Checks isolados de planejamento/armazenamento exercitam aliases, ordem,
conversão e posse com fixtures controladas. Não comprovam aceite do dicionário
ativo ou da interface. Executar os dois transportes no ambiente SRA preparado
e conferir paginação, pesquisa/filtro por campo projetado, legendas, acentos,
valores de data/salário e View; observações anteriores da tabela inteira não
substituem esse aceite.

## Validação registrada

A saída manual do AppServer fornecida em **2026-10-26** registrou **50/50
checks de browse nativo** e **56/56 de tabela nativa**, todos aprovados.
A execução de tabela selecionou `bulk` para **1025 linhas**, ultrapassou o
buffer de 1024 linhas e confirmou sete índices nativos de pesquisa, incluindo
o auxiliar lógico e a expressão de data. Os logs fornecidos não identificam
hashes de executável/RPO. O resultado de browse sem interface não ativa o
diálogo nem comprova aceite visual/backend. O
[manifesto de 2026-10-25](../../../../../docs/validation/native.presentation.windows.json)
é histórico: sua compilação de 64 fontes e checks 32/34/5 de conversão/tabela
nativa/SDK, além das regressões 77/67 de dataset, precedem a revisão de
browse/FWBulk.

A reexecução isolada posterior em **2026-10-26** compilou **66 fontes** sem
erros e passou em **59 checks do browse / 62 da tabela nativa / 32 de conversão /
5 SDK**, além de **77 do dataset tipado / 67 do comum**. A carga principal
gravou e verificou independentemente **10.000 linhas** por FWBulk. Os novos
checks comparam ID_CODE/ID, ordem indexada entre 9/10, pesquisa/filtro por
prefixo de Code e preservação do índice selecionado após recarga/falha/
recuperação. Veja o
[manifesto da revisão](../../../../../docs/validation/native.presentation.revision.windows.json)
para identidades e códigos de saída. A execução não ativa a UI.

Validação T05 com consulta real em **2026-10-26** compilou **69 fontes** sem
erros e passou em **83 checks reais MSSQL TCP/HTTP gzip → dataset/armazenamento
nativo AppServer**, além das seis suítes de regressão acima. O host nativo novo
passou em **133 checks de backend/transporte** e encerrou os dois listeners
sem leases ativos. O SELECT da integração executa no MSSQL sobre linhas
constantes; confere transporte real, codificação Unicode de entrada uma vez,
paginação/critérios e armazenamento nativo, sem ler dados ERP. Veja o
[manifesto SQL real](../../../../../docs/validation/native.presentation.sql.windows.json).
Capturas posteriores fornecidas em **2026-10-26** confirmam exibição do browse
SX5 real por TCP/HTTP e View do registro atual. Essa observação visual não
fornece hashes compilados nem comprova isoladamente todos os caminhos de
filtro/falha/liberação. O
[manifesto anterior SRA/metadados](../../../../../docs/validation/sra.presentation.windows.json)
registra uma regressão posterior identificada e medição restrita à conversão,
com identidades próprias dos fontes. Suas limitações excluem explicitamente
as alterações posteriores de RDD local/índices sob demanda. O [manifesto da revisão de 2026-10-29](../../../../../docs/validation/presentation.review.windows.json)
registra compilação atual de 78 fontes e 654 checks isolados, incluindo RDDs
locais 100, mapeamento 36, planejamento SRA/SX5 66, TOPCONN/FWBulk 122 e
callbacks do browse 74. A identidade final das variáveis do dicionário em
MsMGet compilou separadamente; o desdobramento das asserções SRA daquela
revisão passou novamente nos 66 checks. O
[manifesto de projeções selecionadas de 2026-10-30](../../../../../docs/validation/selected.presentation.windows.json)
registra 78 fontes compilados e 730 checks de dez suítes, incluindo 142 de
planejamento/seleção/SQLite nativo SRA. As três fixtures de aliases inválidos
preservam as chaves reais e exigem rejeição. Definições e seleções de entrada
permanecem inalteradas, incluindo propriedades opcionais ausentes. O aceite
visual da SRA selecionada foi confirmado separadamente em 2026-10-30; veja o
[escopo informado](../../../../../docs/acceptance.pt-BR.md#validação-visual-sra-selecionada-em-2026-10-30).
O relato não informa logs por transporte ou identidades compiladas e não
amplia a cobertura automatizada de backends/plataformas.
