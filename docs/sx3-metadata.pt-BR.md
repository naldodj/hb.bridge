# Metadados do dicionário Protheus e exemplo SRA

[English](sx3-metadata.md) · [Apresentação nativa](native-presentation.pt-BR.md) · [WIP](../WIP.pt-BR.md)

A interpretação do dicionário pertence ao Protheus. O servidor hbBridge recebe
SQL, bindings e definições de resultado explícitos; não resolve SX3, empresa,
filial ou regras da aplicação.

## Snapshot reutilizável de metadados

`HBBridge.Protheus.HBBridgeSX3Metadata():Read("SRA")` retorna um
`JSONObject` novo com os metadados do dicionário. A implementação usa
`FWSX3Util():GetListFieldsStruct(cAlias,.T.,.F.)` para incluir os campos do
dicionário sem a restrição aos campos do browse, incluindo definições virtuais
e memo. Descrições, títulos e atributos adicionais vêm das APIs do dicionário
Protheus. Veja a [documentação oficial de FWSX3Util](https://tdn.totvs.com/display/public/framework/FWSX3Util).

O snapshot contém `schemaVersion`, `alias`, `count` e um objeto `fields`
indexado pelo nome do campo. Cada campo registra `position`, `name`, `type`,
`length`, `decimals`, `picture`, `caption`, `description`, `context`, `virtual`
e `dictionaryOrder`. A posição explicita a ordem; a ordem das chaves do objeto
JSON não é contrato de apresentação. A leitura não avalia inicializadores,
validações, gatilhos ou expressões de picture dos campos. Não adiciona cache
compartilhado, login de banco ou seleção automática de tabela ao hbBridge.

```advpl
jMetadata := HBBridge.Protheus.HBBridgeSX3Metadata():Read("SRA")
if jMetadata["fields"]:HasProperty("RA_SALARIO")
    nLength := jMetadata["fields"]["RA_SALARIO"]["length"]
    nDecimals := jMetadata["fields"]["RA_SALARIO"]["decimals"]
endif
```

A API retorna metadados, não valores dos funcionários ou regras de negócio
avaliadas. Uma nova leitura reflete o dicionário disponível no contexto ativo
do Protheus; o objeto retornado pertence ao chamador. Alias inválido, contexto
não preparado ou resultado de dicionário incompatível retorna `nil`. O helper
preserva a área selecionada e o cursor SX3 já aberto; não abre conexão ou área
do dicionário por conta própria.

## Definição compartilhada de apresentação

`HBBridge.Client.HBBridgePresentationTable():Definition(cAlias)` obtém o
snapshot do dicionário e o catálogo físico MSSQL no contexto Protheus preparado.
Seu método puro `Build(jMetadata,jColumns,cAlias,cTable)` monta a mesma
projeção/esquema a partir de snapshots explícitos, sem acessar banco ou
dicionário. SRA e SX5 usam essa implementação compartilhada, sem duplicar as
regras de conversão dos campos.

O resultado válido inclui `alias`, `table`, `projection`, `expressions`, `schema`, `metadata`,
`fieldStatus` e quantidades incluídas/excluídas. Campos conservam os nomes
originais do dicionário; `schema.projectionFields` mapeia explicitamente cada
projeção à origem. Campos de sistema suportados podem iniciar a projeção mesmo
quando todos os campos do dicionário forem excluídos. Uma projeção útil vazia
produz definição inválida. `Build()` deixa `sql` e `orderBy` vazios: o wrapper
específico fornece predicados e ordenação determinística.
`expressions` registra a expressão SQL confiável de cada campo de origem
incluído, antes do alias de saída, para a seleção reutilizar as mesmas regras
de conversão.

`HBBridgePresentationSRA():Plan(jMetadata,jColumns,cTable,cBranch)` e o
equivalente `HBBridgePresentationSX5():Plan(...)` completam esses snapshots
explícitos pelo mesmo caminho usado por `Definition()` de cada wrapper.
Validam todos os campos exigidos em filtros/ordenação antes de devolver SQL
executável: SRA exige `RA_FILIAL`, `RA_MAT`, `D_E_L_E_T_` e `R_E_C_N_O_`; SX5
exige `X5_FILIAL`, `X5_TABELA`, `X5_CHAVE`, `D_E_L_E_T_` e `R_E_C_N_O_`.
Filial/chaves de negócio devem ser campos caractere, o marcador de exclusão
deve ter um caractere e o número de registro deve ser numérico sem decimais.
A filial explícita deve caber no campo e não conter NUL. Falha devolve
`success: false` com `INVALID_SRA_DEFINITION` ou `INVALID_SX5_DEFINITION`;
SQL/ordenação permanecem vazios. Verifique `success` antes de usar a definição.
Esses métodos de planejamento não executam consulta nem descobrem contexto de
empresa/filial.

## Campos específicos e consultas com JOIN

`RPCRDD.QueryTyped` aceita SELECT SQL fornecido pelo chamador, incluindo listas
explícitas de colunas e JOINs suportados pelo backend configurado e pelo
contrato de uma única instrução do serviço. Não exige selecionar uma tabela
completa. Os builders de tabela inteira enumeram os campos físicos suportados
de uma tabela. `HBBridgePresentationTable():Project(jDefinition,jSelection)`
cria uma definição selecionada independente a partir de um resultado válido
de `Build()`, ainda não planejado e com `sql` vazio. A seleção ocorre uma
única vez: o resultado recebe `selectionApplied` e não pode ser projetado
novamente. Não seleciona sobre uma consulta já completada nem monta definição
de múltiplas tabelas. Exemplos explícitos com JOIN permanecem planejados.

A seleção é um `JSONObject` indexado pelo alias de saída. Cada entrada contém
exatamente `source` e `position`; as posições devem ser inteiros únicos e
contíguos de 1 até a quantidade de campos selecionados. Identificadores são
validados, aliases de saída devem ser únicos sem distinção de maiúsculas e
minúsculas e toda origem deve ser campo incluído e suportado da definição
original. Seleção vazia, origem desconhecida/não suportada ou entrada inválida
rejeita a seleção completa. Nenhum campo ou coluna de sistema é acrescentado
automaticamente e as entradas não aceitam expressões SQL arbitrárias.

```advpl
jSelection := JSONObject():New()
jSelection["REGISTRATION"] := {"source":"RA_MAT","position":1}
jSelection["NAME"] := {"source":"RA_NOME","position":2}
jSelection["AMOUNT"] := {"source":"RA_SALARIO","position":3}
jSelection["ADMISSION_DATE"] := {"source":"RA_ADMISSA","position":4}
jSelection["RECORD_ID"] := {"source":"R_E_C_N_O_","position":5}
jDefinition := HBBridge.Examples.HBBridgePresentationSRA():Definition(jSelection)
```

O esquema selecionado contém apenas os aliases de saída, na ordem pedida para
a projeção SQL, com `schema.projectionFields["AMOUNT"] == "RA_SALARIO"`.
Tipo, legenda, picture e CAST numérico continuam definidos pela origem;
o número de registro conserva a conversão BIGINT. O inventário completo de
metadados permanece disponível. `fieldStatus` continua indexado pela origem
e os campos suportados omitidos da seleção recebem `notSelected`.
Definição de entrada, seleção e metadados não são alterados nem emprestados
ao resultado. Origens não podem repetir neste caminho limitado de apresentação
nativa: MsMGet usa deliberadamente o nome original do dicionário em `aFields`
e `M->` para conservar os tratamentos específicos dos campos.

`Definition(jSelection)` e `Plan(jMetadata,jColumns,cTable,cBranch,jSelection)`
da SRA aceitam essa seleção opcional. Sem seleção, conserva-se a seleção de
todos os campos suportados. O wrapper valida seus campos obrigatórios de
origem/predicados antes da seleção, mesmo quando filial/exclusão são omitidos
da saída. A definição SRA selecionada deve incluir `R_E_C_N_O_` com qualquer
alias válido; a ordenação usa esse alias de saída como chave única, por exemplo
`RECORD_ID ASC`. Nomes de pesquisa e filtro também vêm dos aliases de saída.
Os predicados de filial e não excluído continuam vinculados aos campos físicos
originais.

A [validação isolada de 2026-10-30](validation/selected.presentation.windows.json)
compilou 78 fontes e passou 730 checks de dez suítes, incluindo 142 de
planejamento/seleção/SQLite nativo SRA. Um resultado tipado controlado foi
carregado no armazenamento nativo local real. Aceite visual manual separado
foi confirmado em 2026-10-30; veja o [escopo informado](acceptance.pt-BR.md#validação-visual-sra-selecionada-em-2026-10-30).
O relato não fornece logs por transporte ou identidades compiladas dos fontes
nem amplia a cobertura automatizada de backends/plataformas.

Para resultado restrito ou com JOIN, Protheus deve fornecer uma entrada no
esquema lógico por alias de saída, com nomes únicos e posições explícitas.
Obtenha os metadados SX3 de cada campo em sua origem real no dicionário e
declare `projectionFields`, por exemplo `AMOUNT` para `RA_SALARIO`. Expressões
calculadas precisam de definição explícita do chamador; não deduza uma origem
SX3 única para elas. O mapa atual contém nomes de campos, não linhagem
qualificada por tabela. Origens repetidas tornam a consulta inversa ambígua;
nesse caso, use o acesso pela projeção. Helpers View que usam os nomes originais
em `aFields`/`M->` também precisam de tratamento explícito antes de apresentar
uma mesma origem mais de uma vez.

A paginação do JOIN deve ordenar por uma chave que identifique unicamente
cada linha do resultado, incluindo a chave do lado associado quando a relação
multiplicar linhas. Apenas o número de registro do funcionário é insuficiente
em resultado um-para-muitos. NULLs de LEFT JOIN permanecem NULL no dataset
tipado; o destino nativo atual os rejeita. Protheus pode definir explicitamente
uma substituição SQL adequada quando a aplicação exigir apresentação nativa,
mantendo essa decisão de negócio no chamador. Resolução de tabelas/filiais,
predicados JOIN, política de excluídos, bindings e CASTs do dicionário também
permanecem responsabilidades do Protheus. Não se adiciona parser SQL automático
nem inferência de dicionário no servidor.

A SX9 pode fornecer relacionamentos candidatos junto às definições SX3 por
campo. Inspecionar os sentidos de domínio e contradomínio; a relação local
SRA/CTT está armazenada como CTT para SRA. A [análise SX9](sx9-relationships.pt-BR.md)
registra os pares de expressões SRA/SRB e CTT/SRA observados, os cuidados de
compartilhamento e o snapshot Protheus somente leitura proposto. Ainda não
implementa gerador de JOIN nem avalia expressões arbitrárias do dicionário.

## Browse nativo da SRA

Execute em contexto Protheus de empresa/filial já preparado, com perfil SQL
hbBridge correspondente e configuração de endpoints/autenticação dos clientes:

```advpl
U_HBBridgeNativeBrowseSRA("MSSQL/pData","TCP",100)
U_HBBridgeNativeBrowseSRA("MSSQL/pData","HTTP",100)
U_HBBridgeNativeBrowseSRASelected("MSSQL/pData","TCP",100)
U_HBBridgeNativeBrowseSRASelected("MSSQL/pData","HTTP",100)
```

Os padrões são TCP e 13 linhas por página; as chamadas acima solicitam
100 explicitamente. Perfil SQL omitido usa
`[hbBridge] SQLProfile` do INI AppServer ativo, sem fallback para demonstração.
HTTP exige gzip. O exemplo reutiliza o browse nativo local da SX5, com
paginação explícita, pesquisa, filtros tipados e View; não introduz API pública
genérica de browse.

`U_HBBridgeNativeBrowseSRASelected([cProfile],[cTransport],[nPageSize],[jSelection])`
usa `HBBridgePresentationSRA():SelectedFields()` quando a seleção é omitida.
A amostra seleciona matrícula, nome, salário, admissão e número do registro com
os cinco aliases acima. A seleção do chamador substitui a amostra. Reutiliza
o mesmo browse nativo, pesquisa/filtro por campo projetado e View do registro
atual; HTTP continua exigindo gzip. Compilar os exemplos mantidos no RPO de
teste interativo antes da execução.

`HBBridge.Examples.HBBridgePresentationSRA():Definition()` usa o builder
compartilhado para combinar o snapshot com o catálogo físico obtido por
`HBBridge.SQL.Tools.HBBridgeSqlTools():GetColumnMetadata(cTable)`.
O helper de catálogo atualmente suporta MSSQL e inspeciona a tabela pela
conexão Protheus DBAccess ativa. É distinto do perfil SQL hbBridge: ambos
devem apontar para o banco pretendido. Protheus resolve `RetSQLName("SRA")`
e `xFilial("SRA")`. As restrições de não excluído/filial atual permanecem como
predicados base com bindings quando pesquisa ou filtros mudam.

A definição retorna `success`, `code`, `message`, `alias`, `table`, `projection`,
`metadata`, `fieldStatus`, `includedCount`, `excludedCount`, `sql`, `orderBy`,
`schema` e `bindings`.
`fieldStatus[field]` informa `included` ou `excluded` e o motivo. O snapshot
retém todos os campos enumerados, mesmo quando seu valor não pode ser
selecionado para esse destino nativo. Os campos físicos de sistema
`D_E_L_E_T_`, `R_E_C_N_O_` e `R_E_C_D_E_L_` são incluídos quando disponíveis;
colunas físicas fora da SX3 e desses campos são registradas separadamente.

O perfil nativo aceita campos C do dicionário até 254 bytes, N até 32 posições/
16 decimais, D de tamanho 8 e L de tamanho 1. Também verifica existência e
compatibilidade do tipo físico. Definições virtuais, memo, binárias, texto
longo, ausentes ou não suportadas recebem motivos explícitos de exclusão.
O browse identifica quantidades incluídas/excluídas. Não trunca texto
silenciosamente nem substitui campo incompatível por conteúdo vazio. Portanto,
"todos os campos" significa inventário completo de metadados e todos os
valores físicos suportados, sem implicar nova capacidade de transporte LOB.

A ação **Field catalog** do diálogo SRA abre browse de metadados somente
leitura com colunas Field, Type, Length, Decimals, Caption, Status e Reason.
Inclui os itens do dicionário e os campos de sistema/físicos desconhecidos
registrados, permitindo inspecionar exclusões sem consultar novamente valores
dos funcionários. É uma visão do snapshot de metadados, não um browse da
tabela SX3 bruta ou editor de regras de negócio. Arrays nativos ficam no
datasource array exigido pelo `FWBrowse`; contratos reutilizáveis de metadados
e status permanecem objetos JSON indexados.

`GetNonBlobColumns()` sozinho é insuficiente para esse destino: exclui colunas
binárias, mas mantém texto longo. O exemplo SRA combina o catálogo físico e
a SX3 para decidir cada campo explicitamente. Valores memo/binários precisam
de leitor/transporte LOB próprio e permanecem no planejamento futuro.

Campos numéricos usam `CAST` SQL explícito definido pelo chamador com tamanho/
escala SX3 neste exemplo. Não introduz parser SQL genérico, consulta SX3 no
servidor, mudança global de SET ou arredondamento automático de negócio.
Datas usam explicitamente a representação Protheus YYYYMMDD, incluindo oito
espaços para data vazia. NULL continua distinto no resultado/dataset tipado;
o adapter nativo o rejeita pela política explícita de apresentação.

## Escopo da validação

Regressão do planejamento de campos selecionados e do armazenamento nativo
é distinta do aceite com dicionário ativo/interface. Fixtures determinísticas
podem verificar ordem da projeção, aliases/identidade da origem, CASTs, posse
defensiva, validação das origens obrigatórias e falhas sem ler valores dos
funcionários. O aceite SRA real ainda exige o browse selecionado por TCP e
HTTP gzip, com paginação, pesquisa/filtro, legendas, acentos, valores de
data/salário e View. Observações anteriores de SRA/SX5 com todos os campos não
comprovam o aceite dessa seleção.

Execute `U_HBBridgeSX3Browse("SRA")` (alias padrão: SRA) para inspecionar os
campos do dicionário de uma tabela sem abrir o browse dos dados SQL. Utiliza a
mesma grade de metadados de **Field catalog**, incluindo definições virtuais e
memo. Lê o snapshot da SX3 pelas APIs do framework; não consulta dados de
empregados nem edita regras do dicionário.

Confirmado o funcionamento manual da SRA em 2026-10-27. A
[regressão isolada registrada](validation/sra.presentation.windows.json)
cobre separadamente suas identidades anteriores dos fontes e uma medição
restrita à conversão; exclui as alterações posteriores de RDD local/índices
sob demanda. Essa medição e a observação manual não medem o tempo completo do
browse na revisão atual.

As capturas fornecidas em 2026-10-26 confirmam a exibição do browse SX5 real
por TCP e HTTP e de seu View do registro atual. Não identificam hashes de
executável/RPO nem comprovam isoladamente todos os cenários de filtro, falha
ou liberação. O manifesto SQL real automatizado mantém seu próprio escopo
de constantes e suas identidades.

O comportamento revisado de metadados/planejamento/armazenamento requer
regressão e aceite interativo com o dicionário/dados locais. Verifique quantidades/
motivos de exclusão, títulos, datas/datas vazias, lógicos, tamanhos/escalas
numéricos, acentos, paginação/pesquisa/filtro e View pelos dois transportes.
A apresentação SX5 aprovada não homologa por si o perfil mais amplo da SRA.
