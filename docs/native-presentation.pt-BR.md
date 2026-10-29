# Apresentação nativa pertencente ao chamador

[English](native-presentation.md) · [Contrato tipado](typed-sql.pt-BR.md) · [WIP](../WIP.pt-BR.md)

T04 implementa uma fronteira explícita de apresentação Protheus sobre o dataset
tipado existente. Protheus fornece o esquema lógico completo; o adapter não lê
SX3/TOP_FIELD, infere empresa/filial nem reescreve SQL. Exemplos existentes de
`HBBridgeBrowseData():Browse()` preservam a interface.

`HBBridge.Client.HBBridgePresentationSchema():Validate(header, schema, @code,
@message)` verifica correspondência da projeção, posições e definições do
chamador. `ConvertRow(header, schema, row, @converted, @code, @message)` publica
valores C/N/L/D somente após validar todos os campos. A entrada permanece UTF-8.

- Conversão de caracteres decodifica cada campo uma vez e exige roundtrip de
  encoding e capacidade em bytes. Nunca decodifica JSON serializado.
- NULL permanece na consulta/dataset. Este destino nativo o rejeita pela
  política `nullPolicy: "reject"`, mesmo com `nullable` verdadeiro. NUL também falha.
- Decimal/int64 exatos convertem para N somente se a formatação com tamanho/
  escala recuperar o mesmo valor exato, sem arredondamento ou escape DEC_CREATE.
  Destino character explícito pode conservar esses dígitos em texto.
- Lógicos exigem valores lógicos. Datas exigem formato ISO ou YYYYMMDD explícito
  e calendário válido, sem inferência por nome de campo.

O perfil nativo versão 1 usa C até 254 bytes, N até 32 posições e 16 casas,
D de tamanho 8 e L de tamanho 1. O formato numérico também precisa comportar
parte inteira, separador e sinal. São restrições do destino SDK, sem limitar
linhas/payload SQL nem precisão da origem. Tamanho declarado não comprova
fidelidade numérica: todo valor passa pela conversão; a releitura completa do
armazenamento é diagnóstico opcional.
Veja [DBCreate](https://tdn.totvs.com/display/tec/DBCreate) e
[modelo numérico do SDK](https://tdn.totvs.com/display/framework/SDK%2BMicrosiga%2BProtheus).

`ConvertPage(header, schema, rows, @converted, @code, @message)` valida o esquema
invariável uma vez por página e preserva as verificações de cada linha/valor.
Retorna uma nova página apenas após todas as linhas passarem; uma entrada
inválida não publica página parcial. `ConvertRow` mantém sua validação
independente. O adaptador usa a conversão por página, e os callbacks do browse
resolvem as posições invariáveis ao criar as colunas. Índices de pesquisa e
snapshots defensivos do dataset são preservados.

## Mapeamento opcional dos campos de origem

O esquema lógico pode conter o objeto opcional `projectionFields`. Esquemas
versão 1 com apenas `schemaVersion` e `fields` continuam válidos. O mapa
associa chaves projetadas aos nomes originais declarados pelo chamador
Protheus; não interpreta SQL nem altera o header informado pelo driver.
Por exemplo, uma consulta com `RA_SALARIO AS AMOUNT` pode declarar:

```advpl
jLogicalSchema["projectionFields"] := {"AMOUNT":"RA_SALARIO"}
oNative := HBBridge.Client.HBBridgeNativeTable():New(oDataSet, jLogicalSchema)
```

Cada chave do mapa deve identificar uma projeção existente no esquema lógico.
Os valores devem ser strings não vazias, sem caracteres NUL. Mapas vazios ou
parciais são válidos, e projeções distintas podem indicar o mesmo campo de
origem. São metadados locais de apresentação fornecidos pelo Protheus, sem
consulta ERP executada pelo hbBridge nem novo parâmetro do serviço SQL.
O construtor faz uma cópia defensiva do esquema, incluindo esse mapa.

`LoadCurrentPage([cRDD], [jProjectionFields])` usa o mapa explícito quando o
segundo argumento é um objeto JSON; caso contrário, usa
`schema.projectionFields`, quando presente. Portanto, um objeto vazio
explícito seleciona nenhum mapeamento do chamador para aquele carregamento.
Após obter os metadados de coluna de origem da página aceita, o adapter
aplica o mapa selecionado por `SetSourceFieldName()` e preenche apenas nomes
de origem ausentes. A seleção é repetida em cada carregamento de página.
Uma chamada explícita a `SetSourceFieldName(jProjectionFields, .T.)` pode
substituir uma origem existente; `lForce` pertence ao setter, não a
`LoadCurrentPage()`.

Listas explícitas no SELECT e JOINs usam a mesma fronteira dataset/esquema:
defina apenas as projeções retornadas, com um alias de saída único para cada
uma, e forneça a origem quando o driver a omitir. Metadados do dicionário,
predicados de negócio e ordenação das linhas permanecem no chamador. Os builders
SRA/SX5 atuais enumeram os campos suportados de uma tabela; exemplos com campos
específicos/JOIN e seu aceite visual nativo são planejados separadamente. Veja o
[escopo de projeções/JOIN e a política de NULL](sx3-metadata.pt-BR.md#campos-específicos-e-consultas-com-join).

## Tabela e browse da página atual

```advpl
oNative := HBBridge.Client.HBBridgeNativeTable():New(oDataSet, jLogicalSchema)
if oNative:LoadCurrentPage()
    cAlias := oNative:Alias()
    // Consume the current-page alias in the caller's presentation.
else
    cCode := oNative:ErrorCode()
    cMessage := oNative:ErrorMessage()
endif
if oNative:Destroy()
    FreeObj(@oNative)
endif
```

`New(oDataSet, jLogicalSchema[, lVerifyStorage[, cRDD]])` copia o esquema e
reserva um alias para a vida útil do adapter. `cRDD` tem padrão `SQLITE_MEM`;
`SQLITE_TMP` e `TOPCONN` são alternativas explícitas.

| RDD de destino nativo | Armazenamento/gravação |
| --- | --- |
| `SQLITE_MEM` | Destino SQLite local em memória do SDK; gravação por registro |
| `SQLITE_TMP` | Destino SQLite temporário local do SDK; gravação por registro |
| `TOPCONN` | `FWTemporaryTable` própria via DBAccess; FWBulk quando suportado, senão gravação por registro |

Esse RDD escolhe o **armazenamento local da apresentação**, independentemente
do perfil SQL remoto do hbBridge. Uma consulta MSSQL pode preencher
`SQLITE_MEM`; o destino SQLite local não exige conexão DBAccess para gravar.
Uma definição SRA real ainda pode usar DBAccess Protheus para inspecionar seu
catálogo físico MSSQL. Os testes existentes de FWBulk solicitam `TOPCONN`
explicitamente.

`RDD()` informa o destino configurado. `LoadCurrentPage([cRDD],
[jProjectionFields])` pode escolher um driver suportado antes de criar o
armazenamento nativo. Driver inválido ou troca com armazenamento ativo devolve
`INVALID_PRESENTATION_RDD` ou `PRESENTATION_RDD_CHANGE_REJECTED` **antes de limpar
a página aceita**. Feche o armazenamento próprio antes de trocar seu driver.

O primeiro carregamento válido preenche a tabela e então cria um índice inicial
de pesquisa. Carregamentos seguintes reutilizam a **mesma tabela, área, alias
e índices já criados**, limpando as linhas próprias antes de preencher a página
atual do dataset. Navegação não exclui/reabre o alias nem substitui a fonte do
browse. Índices adicionais são criados somente quando solicitados.

`LoadCurrentPage()` não consulta nem move o cursor do dataset. Valida todas as
conversões e definições nativas dos campos antes de aceitar a página. Somente
então `Alias()` e `IsOpen()` expõem o resultado aceito. O alias reservado não
é exposto antes do primeiro carregamento bem-sucedido nem com página inválida.
`RowCount()` conta a página. `FieldName(projection)` mapeia nomes nativos gerados
com até dez caracteres; aliases SQL nunca são truncados ou avaliados.
`ProjectionName(position)` e `FieldCount()` preservam a ordem da projeção.
`Schema()` devolve cópia defensiva.

Nomes da origem SQL, da projeção e da tabela temporária permanecem distintos:

| Método | Entrada | Resultado para `X5_DESCRI AS DESCRIPTION` |
| --- | --- | --- |
| `FieldName()` | Chave projetada `DESCRIPTION` | Campo nativo de valor gerado `F...` |
| `FieldPos()` / `FieldGet()` | Chave projetada `DESCRIPTION` ou posição da projeção | Posição nativa / valor nativo atual |
| `ProjectionName()` | Posição da projeção ou nome nativo `F...` | `DESCRIPTION` |
| `SourceFieldName()` | Chave projetada `DESCRIPTION` | `X5_DESCRI`, quando informado nos metadados da origem ou declarado pelo chamador |
| `FieldCaption()` | Chave projetada `DESCRIPTION` | Legenda do esquema lógico fornecido pelo chamador |
| `SourceFieldPos()` / `SourceFieldGet()` / `SourceFieldCaption()` | Nome original `X5_DESCRI` | Posição / valor / legenda da projeção com essa origem única |

O sentido do mapeamento é explícito: uma projeção SQL pode chamar-se
`F000000004`. `ProjectionName()` interpreta strings como nomes nativos gerados;
`SourceFieldName()` e `FieldCaption()` usam chaves projetadas, enquanto os
métodos inversos de origem seguem a resolução abaixo. Converta entre esses
nomes explicitamente, sem inferir pelo formato.

`SourceFieldName()` copia `header[projection].source.column` e aplica o mapa
selecionado do chamador quando o carregamento da página é aceito. Não relê o
dataset emprestado após o chamador movê-lo, não interpreta SQL nem deduz a
origem pelo alias. Origem ausente das duas fontes devolve string vazia.
Projeções desconhecidas, campos auxiliares
lógicos privados e página nativa fechada/inválida devolvem mapeamentos vazios.
`FieldCaption()` mantém a consulta direta pela chave projetada. Os três métodos
inversos de origem pesquisam primeiro todos os mapeamentos aceitos; uma origem
única seleciona sua projeção, enquanto origens duplicadas são rejeitadas. Sem
origem correspondente, o segundo argumento opcional (padrão `.T.`) permite
usar a chave projetada. Passe `.F.` para resolver apenas a origem. Nomes
ausentes/ambíguos devolvem zero em `SourceFieldPos()`, `nil` em `SourceFieldGet()`
e string vazia em `SourceFieldCaption()`. Por exemplo, com `RA_NOME` sem origem
e `TEXT` mapeado para `RA_NOME`, `SourceFieldGet("RA_NOME")` lê `TEXT`;
`FieldGet("RA_NOME")` continua lendo a projeção homônima. Nenhum método de
legenda consulta SX3 nem deduz um título do dicionário pelos metadados da origem.

O helper de visualização `HBBridgeMsMGetEx` usa o nome original do dicionário
em `aFields` e nas variáveis `M->` quando há mapeamento de origem, com fallback
para a projeção quando a origem é desconhecida. Isso preserva o tratamento
nativo do Protheus para campos como `RA_BITMAP`. As consultas ao dicionário
usam esse mesmo nome original; os títulos vêm do esquema lógico da projeção
e os valores são lidos pela posição do campo nativo gerado. Essa integração
de interface não altera as chaves projetadas do dataset nem o contrato SQL
do servidor.

O Protheus pode usar explicitamente o campo de origem informado para consultar
seu próprio dicionário:

```advpl
cNative := oNative:FieldName("DESCRIPTION")
cProjection := oNative:ProjectionName(cNative) // DESCRIPTION
cField := oNative:SourceFieldName(cProjection) // X5_DESCRI if supplied or mapped
cCaption := oNative:FieldCaption(cProjection) // Caller-supplied caption
if !Empty(cField)
    cSX3Title := GetSX3Cache(cField,"X3_TITULO")
endif
```

A consulta ao dicionário pertence ao chamador Protheus. O adapter não executa
pedidos SX3 automáticos nem resolve uma origem não informada.

A pesquisa tem mapeamento separado: `SearchFieldName(projection)` devolve o
campo nativo de pesquisa. `IndexOrder(projection)` apenas consulta a ordem
física, sem alocar nem criar índice: devolve zero quando ele ainda não existe.
`EnsureIndex(projection)` cria um índice ausente sob demanda e devolve sua
ordem física; repeti-lo é idempotente. Não consulta SQL nem busca página do
dataset. Projeção desconhecida ou armazenamento indisponível devolve zero com
erro explícito do adapter. Não use a posição da projeção como ordem física.
Projeções caractere, numérica e data usam seus campos de valores. Uma projeção
lógica conserva seu campo L, mas usa um auxiliar privado C(5) `True`/`False`
no índice, pois o caminho nativo não indexa L diretamente. Esse auxiliar não
integra a contagem pública de campos nem o esquema; use `FieldName()` para ler
o valor lógico real. Expressões de índices de data usam `DTOS(field)`. A ordem
de pesquisa usa o mapeamento explícito, não a posição física do campo, e é
preservada no preenchimento de outra página.

Para página `TOPCONN` não vazia, `FWBulk():CanBulk()` escolhe a estratégia de gravação
uma vez. Perfis DBAccess compatíveis usam `FWBulk` com o destino
`GetTableNameForTCFunctions()` da temporária e a estrutura de campos validada.
Linhas são enviadas na ordem dessa estrutura, com flush e fechamento antes de
`TCRefresh`. Falha em `AddData`, `Flush` ou `Close` invalida a página; o adapter
limpa explicitamente um preenchimento malsucedido ou exclui uma primeira
criação malsucedida. Não repete explicitamente o buffer bulk nem usa inserts
individuais após operação bulk parcial. É limpeza de destino próprio, sem
afirmar cancelamento do trabalho no servidor. Perfis TOPCONN sem suporte e
os RDDs SQLite locais mantêm gravação por registro, escolhida antes da inserção. Páginas
vazias conservam o esquema sem
abrir gravador bulk. `WriteMode()` informa `bulk`, `record` ou string vazia
quando não houve gravação concluída; fechamento/falha limpa esse diagnóstico.
Informa o caminho escolhido, sem representar medição de desempenho.

O caminho bulk usa `SetOption(1)`, documentado para LIB 20250630 ou posterior
e DBAccess 24.1.0.1 ou posterior. Veja [FWBulk](https://tdn.totvs.com/display/public/framework/FWBulk)
para contratos de capacidade e retornos. Arrays ficam nas definições nativas
de campos e na entrada FWBulk por linha; esquema e registros da página
permanecem objetos JSON. Ambos aplicam as mesmas regras de conversão de
esquema/valores.

`lVerifyStorage` tem padrão `.F.`. Passar `.T.` como terceiro argumento do
construtor ativa releitura nativa completa após gravação e comparação exata
antes de aceitar a página. Esse diagnóstico acrescenta outra varredura
completa; a navegação de produção não a executa por padrão. Os testes de
integração nativa inspecionam independentemente cada valor gravado, inclusive
com a opção padrão, sem depender de ativar varredura na implementação de
produção. Comparações de caracteres consideram os espaços da largura fixa nativa.

Para trocar de página, chame `NextPage()`/`PreviousPage()` do dataset
explicitamente e então `LoadCurrentPage()`. O carregamento invalida e limpa a
página anterior, preservando identidade da tabela/índices, inclusive em falha;
linhas antigas não são apresentadas como novo resultado. `ClearPage()` executa
essa invalidação/limpeza explicitamente, sem liberar armazenamento ou índices
já vinculados à interface. `Alias()` fica vazio e `IsOpen()` falso até um novo
carregamento válido. Não implica materialização completa, pré-busca ou snapshot
entre chamadas.

`Close()` libera o alias próprio, índices e recursos de destino, conservando
esquema e alias reservado para carregamento explícito posterior. TOPCONN
exclui sua `FWTemporaryTable`. O ciclo dos recursos SQLite é gerenciado pela
conexão SDK; fechar um nome lógico de tabela/índice não comprova remoção física
do arquivo temporário subjacente. Não é API de navegação entre páginas.
`Destroy()` também libera configuração e referência emprestada ao dataset.
São explícitos/idempotentes; não fecham nem liberam dataset/cliente. Falha na
exclusão retém posse para nova tentativa e informa `PRESENTATION_CLOSE_FAILED`;
não libere o objeto após Destroy malsucedido. A área selecionada é restaurada.

`BrowseNative()` é uma função estática local do
[exemplo interativo](../src/tlpp/tests/protheus/hbbridge.presentation.test/hbbridge.presentation.browse.tlpp),
não um método público de `HBBridgeBrowseData`. O exemplo possui sua UI e recebe
dataset e adapter nativo emprestados. Uma API genérica reutilizável de browse
nativo permanece futura; o método `Browse()` existente é preservado. O
[contrato FWTemporaryTable](https://tdn.totvs.com/display/framework/FWTemporaryTable)
mantém a posse na thread Protheus que criou a tabela.

O exemplo interativo mantém um diálogo aberto com `FWBrowse` nativo.
`SetAlias()` é executado uma vez na construção da UI; callbacks de página
preenchem a mesma tabela e atualizam o componente existente. Selecionar uma
coluna de pesquisa chama `EnsureIndex()` antes de pesquisar; índices criados e
ordem física selecionada são preservados nas recargas. A opção/projeção lógica
do FWSeek é independente dessa ordem física. O callback lê diretamente o mapa
`aDetails[nOption][1][7]` do SDK, sem cópia JSON defensiva no caminho de pesquisa.
First, Previous, Next, Last e Refresh recarregam a página nativa nesse diálogo.
Close apenas encerra o diálogo, sem solicitar outra página. View apresenta a
linha atual no exemplo; o aceite visual dessa ação é separado dos checks sem
interface. A pesquisa, o
filtro tipado Field/Operator/Value e a ação Clear filters usam o mesmo fluxo de páginas.
`U_HBBridgeNativeBrowse([nRecords], [nPageSize])` tem padrão de **1000 registros
sintéticos e 13 registros por página**. Para uma carga visual maior:

```advpl
U_HBBridgeNativeBrowse(10000,100)
```

O [cliente da fixture](../src/tlpp/tests/protheus/hbbridge.presentation.test/hbbridge.presentation.browse.client.tlpp)
recebe a quantidade em `HBBridgePresentationBrowseClient():New(nRecords)`.
Sem pesquisa/filtros, gera somente a página solicitada. Com critérios, avalia
todas as linhas configuradas da origem **antes** de selecionar a página;
correspondências e totais descrevem a fixture filtrada, não só as linhas visíveis. Esse
comportamento pertence ao exemplo, sem implementar filtro SQL genérico nem
cache cliente de todo o resultado. Chamadores reais devem fornecer suas
regras equivalentes de consulta/filtro explicitamente.

São sete projeções públicas, nesta ordem: `ID_CODE`, `ID`, `AMOUNT`, `TEXT`,
`FLAG`, `DAY`, `FLOAT`. `ID_CODE` é um código C(10) preenchido com zeros à
esquerda, para que a ordenação pelo índice caractere acompanhe a sequência
numérica visual dentro dessa largura. É gerado a partir do mesmo identificador
da linha usado em `ID`. `ID` continua string int64 exata no transporte e C(20)
na apresentação; o código adicional de exibição/ordenação não o converte para
ponto flutuante nem altera o contrato tipado.
A fixture permite critérios `contains` e `starts with` em `ID_CODE`, `ID` e
`TEXT`, além dos operadores de comparação tipados.
As colunas usam posições nativas independentes para cada campo da projeção.
Flag exibe `True`/`False` e conserva armazenamento lógico nativo; Day e Float
possuem seus próprios vínculos de data/número. Verifique essas colunas,
máscaras e acentos ao homologar a interface revista.

## Ler dados reais da SX5 no browse nativo

A entrada separada
`U_HBBridgeNativeBrowseSX5([cProfile], [cTransport], [nPageSize])` lê linhas
reais da SX5 pelo hbBridge e reutiliza o mesmo diálogo local `BrowseNative()`.
Os padrões são `TCP` e 100 linhas por página:

```advpl
U_HBBridgeNativeBrowseSX5("MSSQL/pData","TCP",100)
U_HBBridgeNativeBrowseSX5("MSSQL/pData","HTTP",100)
```

Use o perfil SQL configurado no servidor hbBridge para o banco Protheus
pretendido. Omitir o perfil lê `[hbBridge] SQLProfile` do INI AppServer ativo;
não há fallback para perfil de demonstração. Endpoints TCP/HTTP e autorização
HTTP vêm da configuração cliente existente; HTTP solicita gzip. Execute em
contexto Protheus de empresa/filial já preparado, como no FWWebEx. Essa entrada
não prepara nem troca ambientes do ERP.

[`HBBridgePresentationSX5:Definition()`](../src/tlpp/tests/protheus/hbbridge.presentation.test/hbbridge.presentation.sx5.tlpp)
usa o builder compartilhado de dicionário/catálogo físico
`HBBridgePresentationTable():Definition("SX5")`. As projeções preservam nomes
SX3 originais suportados, incluindo `X5_FILIAL`, `X5_TABELA`, `X5_CHAVE` e
`X5_DESCRI`, além de campos de sistema disponíveis como `R_E_C_N_O_`; o conjunto
de colunas acompanha o dicionário local. `schema.projectionFields` preserva a
origem explicitamente mesmo quando o ODBC não a informa. Protheus resolve
`RetSQLName("SX5")` e `xFilial("SX5")`. O wrapper vincula o marcador de não
excluído/filial atual e ordena por `X5_FILIAL,X5_TABELA,X5_CHAVE,R_E_C_N_O_`,
com o número do registro como desempate. Pesquisa/filtros não removem esses
predicados base. A consulta é somente leitura; seu destino é armazenamento
separado de apresentação.

[`HBBridgePresentationSQLSource`](../src/tlpp/tests/protheus/hbbridge.presentation.test/hbbridge.presentation.sql.source.tlpp)
controla SQL, ordenação, esquema e bindings base confiáveis do exemplo.
`Query()` devolve SQL/bindings/ordenação para cada pedido explícito de página.
Aceita somente nomes de projeção mapeados no esquema e comparações tipadas
permitidas, acrescentando valores como parâmetros, sem inseri-los no texto
SQL. Critérios caractere escapam `%`, `_`, `[`, `]` e `~` para correspondência
literal em LIKE; entradas com aspas permanecem valores vinculados. Datas usam
valores ISO; critérios lógicos usam booleanos. Inteiros usam texto int64 exato;
critérios numéricos nativos fracionários usam bindings numéricos aproximados,
sem promessa de aritmética decimal exata. Esse controlador pertence ao exemplo,
sem ser parser SQL geral nem API pública genérica de browse. A seleção de
campos de filtro usa o esquema atual, permitindo compartilhar o diálogo entre
o SELECT SX5 definido pelo dicionário e a fixture sintética de sete colunas.

## Campos SRA e metadados SX3 reutilizáveis

`U_HBBridgeNativeBrowseSRA("MSSQL/pData","TCP",100)` reutiliza esse diálogo
para o esquema mais amplo da SRA; substitua TCP por HTTP para a rota gzip.
A definição Protheus combina um snapshot novo de
`HBBridgeSX3Metadata:Read("SRA")`, o catálogo físico de
`HBBridgeSqlTools:GetColumnMetadata()`, `RetSQLName` e `xFilial`. As projeções
preservam os nomes originais do dicionário, permitindo consultas explícitas
à SX3 sem inferi-los dos nomes temporários gerados.

O inventário mantém todas as definições do dicionário e registra inclusão ou
motivo de exclusão para cada campo. Valores físicos C/N/D/L suportados e campos
de sistema disponíveis formam o SELECT; definições virtuais, memo/binárias,
texto longo e incompatíveis não são convertidas nem truncadas silenciosamente.
CASTs numéricos usam a definição SX3 resolvida pelo chamador neste exemplo.
Datas vazias Protheus têm representação YYYYMMDD explícita de oito espaços;
NULL SQL permanece distinto e só falha quando esse destino nativo não o
representa.

`GetNonBlobColumns()` sozinho manteria texto longo; o exemplo usa o catálogo
físico e o dicionário. Não adiciona transporte LOB nem resolução automática
de ERP no servidor. Consulte o
[contrato de metadados e uso SRA](sx3-metadata.pt-BR.md) para posse dos objetos,
status por campo, escopo do conector e requisitos de validação.
A ação **Field catalog**, específica da SRA, exibe todo campo inventariado do
dicionário/catálogo físico com tipo, tamanho, escala, título e motivo de
inclusão/exclusão. Inspeciona o snapshot existente sem abrir browse da SX3
bruta ou solicitar valores dos funcionários novamente.

Os critérios textuais permanecem na codificação do chamador: o cliente
codifica o JSON completo em UTF-8 uma única vez. Não pré-codificar cada binding.

## Reproduzir validação

Use SDK/INI AppServer licenciado externo, RPOs, includes e perfil DBAccess
acessível para os testes opcionais de armazenamento nativo:

```powershell
./scripts/test-protheus-presentation.ps1 -AppServerDirectory '<sdk>' `
    -IniFile '<sdk-ini>' -RpoDirectory '<vendor-rpos>' `
    -IncludeDirectory @('<totvs-includes>', '<project>/includes') `
    -NativeTables -NativeRows 10000
```

O runner cria suas próprias pastas descartáveis SDK/RPO/INI e não interrompe
serviços existentes. Compila fontes atuais e executa regressões de apresentação
e dos datasets tipado/comum. `-NativeTables` também executa a sonda SDK, testes
de tabela temporária real no DBAccess configurado e a fixture de colunas/
navegação sem interface. `-NativeRows` controla a carga sintética principal;
o padrão é 1025 linhas para ultrapassar o buffer bulk de 1024 linhas. Os casos
pequenos de paginação continuam com duas linhas seguidas de uma linha.
Logs brutos ficam locais;
credenciais/conteúdo INI não são evidência publicável. Fechamento interativo
do browse nativo e execução conjunta hbBridge/backend exigem aceite separado em T05.
Mock ou compilação isoladamente não comprovam UI.

Para o teste separado de integração SQL real, mantenha uma fixture hbBridge
própria servindo em um terminal PowerShell:

```powershell
./scripts/test-hbbridge-typed-sql.ps1 -Config '<ini-privado>' `
    -Profile '<alias-mssql>' -Serve -ServeSeconds 1200
```

Aguarde o caminho novo de `endpoints.json` impresso pelo processo. Em outro
terminal, passe esse caminho a uma nova execução AppServer isolada:

```powershell
./scripts/test-protheus-presentation.ps1 -AppServerDirectory '<sdk>' `
    -IniFile '<ini-sdk>' -RpoDirectory '<rpos-fornecedor>' `
    -IncludeDirectory @('<includes-totvs>', '<projeto>/includes') `
    -NativeTables -HBBridgeEndpointsFile '<endpoints-novo.json>'
```

`-HBBridgeEndpointsFile` exige `-NativeTables` e acrescenta
`U_HBBridgePresentationSQLTest()`. Esse teste executa SELECT MSSQL real sobre
cinco linhas constantes de `VALUES`, com as sete projeções tipadas, passando
por TCP e HTTP gzip, dataset e tabela temporária nativa. Cobre paginação,
tipos, critérios, entradas literais, recuperação de falhas e liberação sem
ler nem gravar tabelas do ERP. Difere do SELECT SX5 interativo: aceite automático
de linhas constantes não comprova dicionário/contexto de negócio nem diálogo.

O arquivo de endpoints contém token HTTP temporário privado. Mantenha-o local
e não o versione nem cole em relatórios. O runner AppServer copia essas
configurações apenas para seu novo INI próprio, sem editar INIs da instalação.
A fixture servidora encerra ao atingir o prazo limitado ou quando
`stop.request` é criado naquela nova pasta da execução. A reprodução inicia
outra execução servidora, sem depender de endpoints temporários preservados.
Veja o [guia dos scripts](../scripts/README.pt-BR.md#apresentação-nativa-protheus-isolada).

Os registros são gerados em
[`HBBridgePresentationFixture:Row()`/`Result()`](../src/tlpp/tests/protheus/hbbridge.presentation.test/hbbridge.presentation.fixture.tlpp);
o [teste de armazenamento nativo](../src/tlpp/tests/protheus/hbbridge.presentation.test/hbbridge.presentation.table.test.tlpp)
atribui valores alternados de Flag, Day e Amount com sinal, além de Float =
linha / 4. Chegam à tabela temporária DBAccess real e privada por dataset
tipado com mock; **não há leitura de tabela ERP nem consulta SQL de rede pelo
hbBridge**. A tabela é excluída no Close/Destroy final; os dados da fixture não
ficam disponíveis para inspeção após o teste. Para alterar a carga principal
diretamente, chame `U_HBBridgePresentationTableTest(10000)` ou use a entrada
CLI AppServer isolada `-run=U_HBBridgePresentationTableCLI --native-rows=10000`
com o ambiente preparado pelo runner.

`U_HBBridgeNativeBrowseTest()` verifica tabela/navegação nativas reais,
metadados de colunas e blocos vinculados aos valores sem criar componente
`FWBrowse` em thread de job. Essa fixture sem interface não ativa nem homologa
o diálogo; use `U_HBBridgeNativeBrowse()` em sessão interativa para aceite visual.
O cenário pequeno de navegação conserva 12 registros com páginas de quatro,
independentemente dos padrões interativos; asserções separadas exercitam uma
origem de 10.000 registros com páginas de 100.

Validação manual no AppServer registrada em **2026-10-26**, a partir da saída
de console fornecida: aprovados **50/50** checks de browse nativo e **56/56**
de tabela nativa. A execução de tabela usou **1025 linhas**, selecionou `bulk`
e ultrapassou o buffer de 1024 linhas. A saída também confirmou sete índices
nativos de pesquisa, incluindo o auxiliar lógico e a expressão de data, além
da identidade estável de alias/área/índices após recarga. Esses logs fornecidos
não identificam os hashes do executável ou dos RPOs. O teste de browse valida
dados nativos, vínculos das colunas e navegação sem ativar o diálogo; os
resultados não comprovam aceite visual nem aceite conjunto hbBridge/backend.

A reexecução isolada posterior em **2026-10-26** compilou **66 fontes** sem
erros e passou em **59 checks do browse / 62 da tabela nativa / 32 de conversão /
5 SDK**, além de **77 do dataset tipado / 67 do comum**, sem falhas de asserção.
A carga principal gravou e conferiu independentemente **10.000 linhas** por
FWBulk. As novas asserções cobrem códigos correspondentes, sequência indexada
9-para10, pesquisa/filtro por prefixo de Code e preservação do índice
selecionado após recarga/falha/recuperação. Veja o
[manifesto da revisão](validation/native.presentation.revision.windows.json)
para identidades dos fontes/RPOs e códigos de saída. Continua sendo aceite de
fixture sem interface, separado da integração SQL AppServer-hbBridge real.

T05 passou posteriormente em **83 checks MSSQL TCP/HTTP gzip → dataset tipado
AppServer → armazenamento nativo reais**, em 2026-10-26. A compilação isolada
final passou em **69 fontes**, sem erros, e nas seis regressões acima. O host
nativo novo passou em **133 checks** e encerrou os dois listeners sem leases
ativos. A pesquisa Unicode verifica entrada nativa codificada uma vez pelo
cliente, complementando os checks de resultado UTF-8/armazenamento. Veja o
[manifesto SQL real](validation/native.presentation.sql.windows.json).
Esse aceite com SELECT real sobre constantes não ativa o diálogo SX5;
homologação visual e com registros ERP reais permanece manual.

Capturas posteriores fornecidas em **2026-10-26** confirmam a exibição correta
do browse SX5 real por TCP e HTTP e do View do registro atual. Essa observação
visual manual é separada dos manifestos automatizados atribuídos: capturas não
identificam hashes compilados nem comprovam todos os caminhos de filtro, falha
e liberação. A extensão mais ampla da SRA requer compilação/regressão e aceite
interativo próprios.

Antes da revisão posterior de browse/FWBulk, a validação em 2026-10-25 aprovou
compilação de 64 fontes sem erros, 32 checks de
conversão, 34 de tabela nativa real, cinco asserções SDK e regressões dos
datasets tipado/comum 77/67, todos aprovados. O
[manifesto sanitizado](validation/native.presentation.windows.json) identifica
fontes, executável, RPOs e escopo. Campos caractere de largura fixa recebem
espaços à direita; o adapter confere o valor nativo com essa largura explícita.
Observações do formatador numérico ficam separadas da igualdade do valor nativo
e não comprovam armazenamento decimal exato para todo campo declarado.

A revisão de **2026-10-29** compilou **78 fontes** sem erros e passou em
**654 checks** de dez suítes no SDK isolado: conversão/página 76/31,
planejamento SRA/SX5 66, RDDs locais 100, mapeamento 36, datasets 77/67,
SDK 5, TOPCONN/FWBulk 122 e browse sem interface 74. Os dois RDDs locais e
índices sob demanda foram exercitados; a escrita bulk de 1025 linhas
ultrapassou o buffer de 1024. O processo do dataset comum retornou -4 após
os 67 checks e APPLICATION END, aceito pelo runner existente; as demais
suítes encerraram com 0. O ajuste final da identidade do dicionário em
MsMGet compilou separadamente; o desdobramento atual das asserções SRA
também foi recompilado e passou novamente nos 66 checks. Veja o
[manifesto da revisão](validation/presentation.review.windows.json) para
identidades e escopos. Essas suítes não ativam o View do registro revisado.

Para homologação visual, compile o
[exemplo interativo](../src/tlpp/tests/protheus/hbbridge.presentation.test/README.pt-BR.md)
e execute `U_HBBridgeNativeBrowseSX5("MSSQL/pData","TCP",100)`, depois HTTP,
na empresa/filial Protheus preparada. Verifique registros SX5 reais, acentos,
paginação/pesquisa/filtro/View/fechamento. A fixture independente
`U_HBBridgeNativeBrowse()` continua útil para posição de Flag/Day/Float e
cargas sintéticas.
