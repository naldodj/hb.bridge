# Navegação do dataset, codificação e definições dos campos

[English](dataset.md) · [Contrato SQL](milestone3-sql.pt-BR.md) · [WIP](../WIP.pt-BR.md)

## Navegação e metadados

`HBBridge.RDD.HBBridgeRPCDataSet` expõe registros JSON por nome. `Header()`
devolve cópia independente do cabeçalho. `FieldInfo(nome)` devolve os metadados de um campo.
`FieldCount()` e `FieldName(posição)` enumeram a ordem original das colunas SQL
pelo `position` explícito, sem depender da ordem das chaves JSON.
`GetRow()` devolve cópia independente da linha atual, sem avançar.
`Header()` devolve `{}` quando fechado. `FieldInfo()` devolve
`{}` para campo ausente ou dataset fechado; `GetRow()` devolve `{}` no EOF.
`FieldName()` devolve `""` fora do intervalo iniciado em 1; `FieldGet()`
devolve `Nil` para campo ausente ou no EOF. Esses métodos não buscam páginas.
O chamador é dono das cópias JSON e as libera com `FreeObj()`.

Selecione o alias da conexão com `SetAliasProfile(alias)` antes de chamar
`OpenSQL(sql[, page])` ou `OpenPage(sql, number, size, orderBy)`.
`GetAliasProfile()` consulta essa seleção; `SetAliasProfile()` devolve seu
valor anterior. Trocar o alias fecha o resultado atual, impedindo que uma
página posterior mude silenciosamente de banco. `Close()` libera dados e
erros, mas mantém o alias selecionado para outra consulta. A biblioteca não
escolhe um alias de demonstração.

`FieldExist(name)` consulta o cabeçalho mesmo no EOF. `GetRows()` devolve uma
cópia independente **somente da página atual**, sem buscar ou concatenar outras
páginas. `GetOrderBy()` devolve a ordenação selecionada. `PreviousPage()` busca
a página anterior quando `HasPreviousPage()` é verdadeiro e posiciona o dataset
no primeiro registro devolvido. Os métodos de página fazem chamadas separadas.

Use `MoreToRead()` para varredura sequencial entre páginas:

```advpl
oDataSet:SetAliasProfile(cProfile)
if oDataSet:OpenPage(cSQL, 1, 10, cOrderBy)
    while oDataSet:MoreToRead()
        xValue := oDataSet:FieldGet("NAME")
        oDataSet:Skip()
    enddo
    if !Empty(oDataSet:ErrorCode())
        // Tratar falha de página separadamente do término normal.
    endif
endif
oDataSet:Close()
```

`MoreToRead()` é idempotente enquanto existe registro atual. No EOF da página,
busca a próxima somente se `HasNextPage()` for verdadeiro. Uma falha retorna
falso e preserva `ErrorCode()`/`ErrorMessage()`, sem repetir indefinidamente.
Portanto, realiza I/O na mudança de página. `Eof()` e `Skip()` preservam o
comportamento local à página para a navegação manual existente. `RowCount()`
continua contando a página atual, não a consulta inteira. Repetir a verificação
não consome registro. `GetRow()` exige `Skip()` explícito.

## Total de linhas e páginas

O serviço paginado atual retorna `totalRows` e `totalPages` na raiz do resultado
para a consulta base completa do chamador, separados do `rowCount` da página.
`TotalPages()` corresponde ao arredondamento para cima do total de linhas
dividido pelo tamanho da página; resultado vazio tem zero páginas. Os totais
contam a consulta recebida, incluindo `TOP`, `LIMIT` e filtros de negócio do
chamador, não todas as linhas de uma tabela de origem.

Consulte `HasTotals()` antes de exibir os totais:

| Estado do dataset | `HasTotals()` | `TotalRows()` / `TotalPages()` |
| --- | --- | --- |
| Fechado ou abertura com falha | falso | `0` / `0`. |
| Resultado aberto sem paginação | verdadeiro | Total de linhas / `0` quando vazio, senão `1`. |
| Resultado paginado aberto com ambos os totais | verdadeiro | Totais do servidor validados. |
| Resposta paginada anterior sem nenhum total | falso | `-1` / `-1`, explicitamente desconhecidos. |

O par de totais deve conter inteiros exatos não negativos dentro de `2^53-1`,
com páginas compatíveis com linhas e tamanho de página. Metade ausente, tipo
errado, fração ou total de páginas inconsistente resulta em `INVALID_RESULT`.
Totais desconhecidos não são inferidos da página atual nem de `hasNext`.

Cada chamada paginada executa a consulta da página e um `COUNT` separado na
mesma conexão. Isso acrescenta trabalho no banco; nem esse par nem as páginas
posteriores formam um snapshot. Mudanças concorrentes podem produzir
observações diferentes da página e da contagem. Use isolamento apropriado ou
um futuro contrato de snapshot/cursor quando for necessária consistência
entre requisições.

As referências locais FileRead/FileNavigator orientaram essa interface.
Outra classe de navegação e um índice do resultado completo não são necessários
para esse caso sequencial. Cada página continua sendo outra consulta, sem
cursor persistente nem snapshot; use ordenação determinística com desempate
único. Protheus resolve tabela, exclusão lógica, empresa e filial antes da consulta.
Cada campo de `orderBy` deve existir na projeção SQL. Se a consulta usa
`TOP`/`LIMIT`, o chamador também deve selecionar esse subconjunto de forma
determinística; ordenar páginas externas não estabiliza um subconjunto sem ordem.

## Aceite manual do dataset em 2026-10-13

`U_HBBridgeDataSetTest()` passou em **67 checks, zero falhas e 31 chamadas
simuladas**, em 2026-10-13 às 17:56:23, horário de São Paulo, thread 32332.
Todos os checks por chave foram verdadeiros; o resultado final foi
`OK; checks=67; mock calls=31`. A cobertura inclui cópias de cabeçalho/campo/
linha/página, ordem de colunas, existência de campo, seleção de perfil,
navegação anterior/próxima/`MoreToRead()`, checks repetidos, estados vazio/
fechado, falha/recuperação de página e totais validados, desconhecidos e inválidos.

`U_HBBridgeHelperTest()` passou em **12 checks puros, zero falhas**, às 17:56:45
na mesma data e fuso, thread 28300. Todos os checks por chave foram verdadeiros;
o resultado final foi `OK; checks=12`. A cobertura inclui prefixação de alias
SQL, substituições de texto e expressões tipadas de filtros customizados.

São resultados manuais de mocks no AppServer. A falha de compilação de
2026-10-08 ocorreu antes de compilar os fontes da fixture anterior de 45 checks;
os testes revisados ainda aguardavam execução na revisão de 2026-10-12.
Os resultados de 2026-10-13 homologam o escopo dataset/helpers de D02. A chave
histórica `dsStructDefensiveAlias` exercita uma cópia de `Header()` e
`FieldInfo()`. `Header()` continua sendo a API canônica de metadados;
`DSStruct()` continua removido.

Essas rodadas não exercitam transporte, backend SQL nem tabela ERP. D03 é a
próxima tarefa para as falhas de integridade UTF-8/FLOAT abaixo; o aceite
ampliado de textos e números por TCP/HTTP e M06–M09 continuam abertos. Veja
[testes](../tests/README.pt-BR.md) e [homologação](acceptance.pt-BR.md)
para o registro de execução.

## Constatação de codificação em 2026-10-08

O worker HTTP atual e o teste MSSQL nativo selecionam Harbour `UTF8EX`.
O adaptador TCP não seleciona essa codepage e serializa JSON sem codificação
explícita. O padrão `EN` do Harbour fixado corresponde a CP437. A requisição
TCP TLPP também envia `ToJSON()` sem a conversão UTF-8 usada pelo HTTP.
Assim, o aceite TCP com ASCII não homologa textos acentuados.
`OemToAnsi(FieldGet(...))` corrigir a exibição é compatível com uma conversão
OEM intermediária; não comprova a codificação original da coluna SQL.

### Observações de apresentação em 2026-10-13

Informada apresentação correta da SX5 por HTTP com
`jResponse:FromJSON(DecodeUTF8(jResponse:ToJSON()))` no exemplo FWWebEx.
No desktop, `OemToAnsi()` aparentemente melhora a apresentação, ainda sujeita
a validação ampliada. As observações abrangem os textos e a interface mostrados;
não estabelecem encoding de origem nem o contrato Unicode/binário completo.

Manter a amostra funcional enquanto são testados UTF-8 direto, escapes Unicode,
texto fora da codepage de destino, NUL, null/vazio e binários. A política cliente
pretendida converte valores textuais uma vez para encoding escolhido explicitamente.
Recodificar/reanalisar o documento inteiro pode alterar chaves/strings de controle
e depende do comportamento dos serializadores/parsers nativos; ainda não é a
política padrão. `DecodeUTF8()` aceita destino explícito; veja a referência TOTVS abaixo.

Correção necessária, **não implementada pelos métodos de navegação**:

1. Padronizar JSON TCP/HTTP em UTF-8 e executar requisições sob `UTF8EX`,
   restaurando o estado anterior do worker.
2. Permitir ao consumidor TLPP escolher o encoding de destino, como `cp1252`
   ou `utf-8`, com erro estrito para texto não representável. Converter texto
   uma única vez após decodificar JSON; nunca converter binários como texto.
3. Descrever explicitamente texto/binário na origem. Exceção OEM legada deve
   identificar campo/encoding e preservar bytes antes de conversão ODBC que
   possa perder informação; não inferir encoding pelo alias ou por amostras.
4. Verificar acentos, CJK, caracteres suplementares, escapes Unicode,
   NULL/vazio e binários via TCP/HTTP no AppServer real.

Collation controla comparação/ordenação e influencia tipos SQL não Unicode;
não é o encoding da resposta. hbBridge não deve alterar silenciosamente a
collation do banco/coluna. O SQL do chamador pode selecionar uma collation
quando a semântica da consulta exigir. Referências:
[Microsoft collation/Unicode](https://learn.microsoft.com/en-us/sql/relational-databases/collations/collation-and-unicode-support?view=sql-server-ver17),
[conversão UTF-8 TOTVS](https://centraldeatendimento.totvs.com/hc/pt-br/articles/360025758092-Cross-Segmento-TOTVS-Backoffice-Linha-Protheus-ADVPL-Converte-uma-string-com-codifica%C3%A7%C3%A3o-UTF-8).

## Constatação numérica em 2026-10-08

`type`, `length` e `decimals` do cabeçalho atual vêm do RDD Harbour.
Não são definições SX3 nem metadados físicos SQL garantidos. Tamanho e escala
ODBC têm significados dependentes do tipo; escala FLOAT não é uma quantidade
de casas decimais declarada. O conector também guarda tamanho da coluna em um
campo RDD de 16 bits, insuficiente para descrever toda coluna SQL grande.
Referências: [tamanho ODBC](https://learn.microsoft.com/en-us/sql/odbc/reference/appendixes/column-size?view=sql-server-ver17),
[casas decimais](https://learn.microsoft.com/en-us/sql/odbc/reference/appendixes/decimal-digits?view=sql-server-ver17).

Uma prova com constantes, somente leitura no MSSQL local, reproduziu a perda:

```sql
SELECT CAST(123.4567 AS FLOAT) AS FLOAT_VALUE,
       CAST(123.4567 AS DECIMAL(15,4)) AS DECIMAL_FOUR,
       CAST(123.4567 AS DECIMAL(16,2)) AS DECIMAL_TWO;
```

O FLOAT nativo preservou `123.4567`, mas seus metadados RDD indicaram zero
decimais e o formatador JSON Harbour emitiu `123`. As colunas DECIMAL emitiram
`123.4567` e `123.46`. Evidência: `tmp/numeric-probe-20261008.log`.
Isso identifica uma falha de serialização; os 92 checks MSSQL nativos anteriores
não cobriam o ciclo FLOAT bruto/JSON. Melhorar a navegação não corrige essa falha.

Protheus deve resolver SX3/TOP_FIELD ou outro schema de negócio e fornecer
explicitamente as definições lógicas. hbBridge não deve consultar essas tabelas
nem deduzir regras de `RA_SALARIO`. `INFORMATION_SCHEMA.COLUMNS` descreve
armazenamento SQL; não reconstrói tamanho/escala lógicos de um campo Protheus.
TOTVS também distingue dicionário e conversão de campos de query:
[queries Protheus](https://tdn.totvs.com/display/public/framework/Desenvolvendo%2Bqueries%2Bno%2BProtheus).

No contrato atual, o SQL do chamador pode aplicar `CAST` explícito para
`DECIMAL(p,s)`. Isso controla escala/arredondamento SQL, não toda a precisão
do percurso. Quando os dígitos exatos forem necessários, selecione o decimal
convertido como texto, por exemplo
`CONVERT(varchar(40), CAST(value AS DECIMAL(16,2)))`, preservando esse texto
até uma conversão numérica deliberada. Ler DECIMAL como double e depois
converter para texto não recupera dígitos perdidos. FLOAT já é aproximado;
CAST não recupera perdas anteriores.
Referências: [SQL float](https://learn.microsoft.com/en-us/sql/t-sql/data-types/float-and-real-transact-sql?view=sql-server-ver17),
[SQL decimal](https://learn.microsoft.com/en-us/sql/t-sql/data-types/decimal-and-numeric-transact-sql?view=sql-server-ver17).

### Escala de negócio e FLOAT bruto: análise em 2026-10-13

`CAST(SRA.RA_SALARIO AS DECIMAL(12,2)) AS RA_SALARIO` é uma projeção explícita
válida quando o chamador exige essa precisão/escala e o valor cabe na faixa.
Ela arredonda para a escala decimal escolhida no SQL. A escolha permanece no
Protheus, incluindo resolução do dicionário. Precisão SQL conta dígitos e não
deve ser confundida com largura de exibição que inclui formatação.

Isso não substitui a correção genérica do transporte. O SDDODBC inspecionado
preserva o double FLOAT, mas associa metadados de formatação com zero casas;
o encoder JSON usa esses metadados em formato fixo. FLOAT bruto deve preservar
o valor aproximado recebido sem exigir CAST nem presumir duas casas para todo número.

| Abordagem | Papel / situação |
| --- | --- |
| CAST para DECIMAL no SQL do chamador | Disponível; define escala/arredondamento do resultado SQL. |
| Corrigir serialização FLOAT bruta | Correção genérica necessária; preservar double recebido entre encoder/decoder e parser cliente. Sem implementação. |
| Precisão/escala lógica explícita do chamador | Alternativa proposta sem mudar SQL; aplicar apenas a regra fornecida por campo e distinguir representação/arredondamento de exibição. Ainda não são parâmetros aceitos. |
| Decimal textual projetado no SQL | Opção disponível para dígitos decimais exatos além da capacidade double; manter string até conversão deliberada. |

O `hb_odbcNumSetLen()` upstream exemplifica metadados de formatação por item
sem alterar o valor numérico nativo. Pertence à `hbodbc`, que o produto não
vincula atualmente; pode ser avaliado um pequeno wrapper C equivalente.
Não é encoder universal de ponto flutuante nem nova API pública do hbBridge.
Referências: [helper de metadados numéricos ODBC](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/contrib/hbodbc/odbc.c#L1203),
[formatação numérica JSON](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/src/rtl/hbjson.c#L259).

A implementação precisa testar um formatador double geral/curto real e ambos
os parsers. O `hb_snprintf()` fixado mapeia especificadores gerais/científicos
para formato fixo; mudar apenas para `%.17g` ali é insuficiente. Usar 17 casas
fracionárias não equivale a 17 dígitos significativos. Cobrir magnitudes pequenas/
grandes, notação científica e valores que exigem 17 dígitos significativos,
preservando a semântica DECIMAL declarada. FLOAT continua aproximado; corrigir
transporte ou aplicar CAST não reconstrói precisão já ausente no armazenamento.

O próximo contrato versionado de resultado deve distinguir:

| Grupo de metadados | Significado |
| --- | --- |
| `source` | Tipo SQL do conector, precisão, escala anulável, tamanho em caracteres/bytes, nulidade e collation quando conhecida. |
| `logical` | Tipo, tamanho de exibição, precisão e escala fornecidos explicitamente pelo consumidor. |
| `wire` | Encoding textual e representação: número JSON, string decimal exata ou codificação binária. |

Esses grupos e `targetEncoding` são desenho, **não parâmetros adicionais
aceitos pelo serviço estrito atual**. Testar FLOAT fracionário, DECIMAL grande,
BIGINT acima de `2^53-1`, metadados de campos grandes e equivalência TCP/HTTP.

### Addon de metadados e reescrita SQL adiados

Decisão em 2026-10-13: manter addons de metadados Protheus e política decimal
automática em espera. CAST no SQL do chamador permanece como abordagem disponível
para escala de negócio. A falha de transporte FLOAT bruto e o aceite UTF-8 ampliado
continuam pendentes; essa escolha não os homologa nem conclui D03. M06 pode avançar.

Um futuro método estático opcional em `HBBridge.SQL.Tools.HBBridgeSqlTools`
poderia receber SQL e schema JSON resolvido pelo chamador e inserir CASTs
numéricos antes do envio. É proposta, não API implementada. Dicionário, tenant,
nomes de tabelas e mapeamento dos campos permanecem no Protheus. Um addon de
metadados usaria os mesmos parâmetros explícitos, sem ser obrigatório na consulta.

O chamador pode preencher o schema lógico com `TamSX3(cField)`: o array nativo
expõe tamanho na posição 1, decimais na 2 e tipo na 3. Chamadas diretas de
`GetSX3Cache(cField, "X3_TAMANHO"/"X3_DECIMAL"/"X3_TIPO")` fornecem as mesmas
propriedades. Copiar apenas as necessárias para JSONObject por campo, sem
consultar metadados a cada linha do resultado. Resolver também no Protheus o
mapeamento de tabela de origem/alias SQL. O dicionário descreve o campo original;
expressões calculadas continuam exigindo regra explícita para o resultado.

Preferir `TamSX3()`/`GetSX3Cache()` como provedor de metadados. SELECT direto
na SX3 de `X3_TIPO`, `X3_TAMANHO`, `X3_DECIMAL` e `X3_CAMPO` é alternativa
explícita quando o chamador resolve antes o nome físico/contexto do dicionário,
incluindo definições ativas/únicas. `RetSQLName("SX3")` é avaliado no Protheus
para montar SQL, sem execução como função do SGBD. Agrupar os campos solicitados
e produzir o mesmo schema JSON lógico; sem mover consultas ERP implícitas para
hbBridge. Não foi medida comparação de tempo entre os provedores.

[`TCSqlToArr()`](https://tdn.totvs.com/display/tec/TCSqlToArr) é candidata para
SELECT de dicionário em lote, com binds e tipagem opcional do resultado.
Seu array de retorno obrigatório é interface nativa: converter uma vez para
JSONObject por campo. A tipagem do retorno DBAccess não altera a consulta ODBC
separada do hbBridge. Comparar cache frio/aquecido com custo da consulta em lote
e conversão no volume real de campos antes de escolher o provedor mais rápido.

Inspeção somente leitura do `ApLib070.prw` local fornecido encontrou `ChangeQuery()`
usando APIs de banco/contexto, filtros SQL e um caso CAST PostgreSQL baseado no
dicionário. Serve como referência de responsabilidades, sem ser parser portável
ou código incorporado ao hbBridge. A finalidade documentada do framework é adaptar
dialetos: [orientação TOTVS para queries](https://tdn.totvs.com/display/framework/Desenvolvendo%2Bqueries%2Bno%2BProtheus).
O `sqlparse.parse()` Python agrupa tokens, mas é intencionalmente não validante;
resolução do catálogo e decisões de tipo/escala continuam na aplicação.
Veja a [introdução sqlparse](https://sqlparse.readthedocs.io/en/latest/intro.html).

Uma avaliação futura pode começar por transformação TLPP restrita e opt-in da
projeção: origens/aliases explícitos; precisão/escala SQL validadas e distintas
da largura xBase; colunas de origem completas e ordenadas para `*`/`alias.*`,
incluindo campos de sistema; preservação de CAST existente e idempotência.
Preservar literais, comentários e SQL não afetado. Expressões, agregações,
DISTINCT, GROUP BY, CTEs, subqueries e UNION exigem semântica definida ou
resultado explícito de não suportado; evitar deduções ou reescrita silenciosa.
Aplicar CAST antes de um cálculo pode arredondar entradas de forma diferente
do CAST no resultado. Ordem, duplicatas, NULLs e paginação devem ser intencionais.

Medir coleta de schema, parsing e execução completa antes de adicionar cache
ou implementação Zig. Python é referência possível, sem nova dependência de
runtime. A proposta permanece adiada junto com o addon de metadados.

## Proteção de credenciais

Segredos SQL, NETIO, admin e HTTP no hbBridge, além das credenciais cliente
no AppServer, têm [desenho próprio](credentials.pt-BR.md). Criptografia
autenticada com chaves externas permanece sem implementação; navegação e
consultas bem-sucedidas não homologam proteção de credenciais.
