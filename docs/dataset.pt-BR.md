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

Essas rodadas não exercitam transporte, backend SQL nem tabela ERP. O aceite
posterior de integridade MSSQL/TCP/HTTP da D03 está registrado abaixo;
fechamento do pacote e M09 permanecem separados. Veja
[testes](../tests/README.pt-BR.md) e [homologação](acceptance.pt-BR.md)
para o registro de execução.

## Constatação de codificação em 2026-10-08

Naquela revisão, o worker HTTP e o teste MSSQL nativo selecionavam Harbour
`UTF8EX`, mas o adaptador TCP serializava JSON sem selecionar uma codepage
explícita. O padrão `EN` do Harbour fixado corresponde a CP437. A requisição
TCP TLPP também enviava `ToJSON()` sem a conversão UTF-8 usada pelo HTTP.
Assim, o aceite TCP anterior com ASCII não homologava textos acentuados.
`OemToAnsi(FieldGet(...))` corrigir a exibição é compatível com uma conversão
OEM intermediária; não comprova a codificação original da coluna SQL.
Essas lacunas foram corrigidas e exercitadas pela D03, conforme registro abaixo.

### Prioridade D03: integridade da origem em 2026-10-19

Contrato confirmado: o texto trocado entre Protheus e hbBridge usa UTF-8
nos dois sentidos, nas requisições/respostas TCP e HTTP. Protheus envia texto
convertido de sua codepage local efetiva para UTF-8 e converte o UTF-8 recebido
para a codepage do consumidor quando necessário. Cada conversão tem um único
responsável explícito, inclusive quando realizada por parser/canal nativo.
A escolha da codepage do consumidor não altera a codificação do transporte.
Binários mantêm sua representação binária explícita e não passam por essas
conversões textuais. A implementação agora segue esse contrato; o escopo
homologado é a fixture MSSQL e o runtime AppServer registrados abaixo.

O primeiro critério de aceite é o caminho banco-driver/RDD-Harbour, antes de
JSON ou de uma interface Protheus. Confirmar os caracteres pretendidos com
uma fixture conhecida e referência do banco estabelecida independentemente.
Registrar tipo SQL, collation/encoding da coluna quando aplicável, driver,
tipo de leitura e codepage ativa no Harbour. VARCHAR, NVARCHAR e binários
exigem tratamentos distintos; alias e sistema operacional não estabelecem
sua codificação. Preservar o aceite nativo existente e ampliá-lo com checks
direcionados aos caminhos ainda não cobertos.

Validar cada fronteira separadamente:

1. **Leitura do banco:** comparar texto nativo Harbour, antes da serialização,
   com valores Unicode esperados e sua representação UTF-8 conhecida. Verificar
   valores longos/limites de blocos, caracteres suplementares, NULL/vazio e NUL
   embutido. Conferir bytes binários inalterados. Armazenamento do banco e UTF-8
   podem ter bytes distintos; o texto decodificado deve corresponder. Inspecionar
   bytes armazenados e metadados separadamente ao diagnosticar uma divergência.
2. **JSON/transporte:** verificar UTF-8 válido e igualdade semântica após ida e
   volta JSON via TCP e HTTP. Caracteres literais e escapes Unicode devem produzir
   valores equivalentes; escolhas de escape distintas não exigem bytes JSON iguais.
3. **Consumidor Protheus:** converter uma vez o texto UTF-8 confirmado para a
   codepage efetiva de destino quando necessário, depois comparar os valores.
   Para destino CP1252, `DecodeUTF8(cText, "cp1252")` é operação esperada se
   parser/cliente/canal ainda não realizou essa conversão.

Eliminar `DecodeUTF8()` não é critério de aceite D03. Sua aplicação pode
permanecer em fronteira explícita do consumidor enquanto se valida a origem.
Manter os ajustes de interface funcionais até suas substituições passarem nos
testes do consumidor real. Corrigir a exibição não homologa a leitura do banco;
decodificação posterior não recupera caracteres já perdidos, substituídos ou
truncados antes. Dados armazenados com codificação incorreta exigem diagnóstico
explícito da origem, sem heurística genérica de reparo. Preservação numérica
continua sendo check D03 separado; converter texto corretamente não a homologa.

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

Política implementada nas fronteiras:

1. JSON TCP/HTTP usa UTF-8. O adaptador TCP seleciona `UTF8EX` durante a
   requisição e restaura o estado anterior. Ambos os clientes TLPP codificam
   uma vez a requisição em texto comum AppServer, antes de medir/enquadrar bytes.
2. O retorno textual permanece UTF-8. O consumidor aplica `DecodeUTF8()` uma
   vez onde precisa de sua codepage local e verifica o sucesso da conversão.
   Valores fora dessa codepage permanecem UTF-8 ou exigem outra representação
   explícita no consumidor. Binários não passam por conversões textuais.
3. O patch ODBC gerenciado trata explicitamente entrada SQL e leitura Unicode,
   incluindo caracteres suplementares e fronteiras de blocos. Divergência na
   origem ainda exige diagnóstico de tipo/collation, sem reparo baseado no alias.
4. A fixture no AppServer real cobre acentos, CJK, caracteres suplementares,
   escapes Unicode, NUL e NULL/vazio via TCP/HTTP. Leitura binária bruta e sua
   restrição JSON separada estão registradas abaixo.

Collation controla comparação/ordenação e influencia tipos SQL não Unicode;
não é o encoding da resposta. hbBridge não deve alterar silenciosamente a
collation do banco/coluna. O SQL do chamador pode selecionar uma collation
quando a semântica da consulta exigir. Referências:
[Microsoft collation/Unicode](https://learn.microsoft.com/en-us/sql/relational-databases/collations/collation-and-unicode-support?view=sql-server-ver17),
[conversão UTF-8 TOTVS](https://centraldeatendimento.totvs.com/hc/pt-br/articles/360025758092-Cross-Segmento-TOTVS-Backoffice-Linha-Protheus-ADVPL-Converte-uma-string-com-codifica%C3%A7%C3%A3o-UTF-8).

### Implementação e aceite D03 em 2026-10-21

A fixture somente leitura `d03.mssql.constants.v1` passou em **80 checks, zero
falhas**, pelos clientes TCP/HTTP do produto e dataset no Windows AppServer
**24.3.1.5**, usando RPO privado isolado. A cobertura inclui texto da origem,
FLOAT fracionário bruto, escala DECIMAL explícita, decimal textual exato, NUL,
cópias defensivas de linha/página e projeção binária hexadecimal explícita.
Recibo: `tmp/d03-protheus-9c3d1606250449c9a659f92f92c5c6e6/validation.json`.
SHA-256 do artefato servidor nativo:
`96A7AC7B0D29C2016B15CAC4D8DCD18E5FA4CE075AF1BA28DE4719A5E8BE5CA1`.
Isso homologa D03 nessa fixture/runtime; não certifica outros drivers, Linux,
todas as faixas de campos de negócio nem valores BLOB brutos em JSON.

A validação nativa anterior, em 2026-10-19, passou em **752 checks genéricos**,
**73 novos checks de integridade MSSQL**, **92 checks MSSQL existentes**,
**7 checks de referência .NET ODBC independentes** e **2 checks numéricos Zig**,
todos sem falhas. A referência independente não usa Harbour/JSON. O patch ODBC
gerenciado corrige entrada SQL UTF-8 com caracteres suplementares, além de
preservar leitura Unicode/binária; o checkout fixado da dependência não é alterado.

#### NUL embutido na implementação JSON do AppServer

A reprodução isolada nesse AppServer preservou `A` + `Chr(0)` + `B` na
propriedade direta, mas o `ToJSON()` nativo reduziu bytes `410042` para `41`.
O `FromJSON()` nativo reduziu `"A\u0000B"` para `4142`, removendo NUL. A falha
de serialização/parser está registrada na
[issue Protheus 14](https://github.com/naldodj/totvs-protheus-open-issues/issues/14).
Decodificação UTF-8 não recupera o byte perdido.

[`HBBridge.Client.HBBridgeJSON`](../src/tlpp/hbbridge.json.tlpp) agora preserva
NUL embutido por `Encode()`/`Parse()`, usados pelos dois clientes e pelas cópias
do dataset. Documentos comuns mantêm tratamento nativo de escalares/contêineres/
números; strings com NUL usam escapes JSON `\u0000`, sem sentinelas. O helper
não converte codepages. `Encode()` percorre os valores para detectar NUL, logo
a serialização comum tem uma varredura linear adicional e alocações nativas
para enumerar chaves. NUL no nome de propriedade é recusado explicitamente,
sem alterar a chave silenciosamente.

A rodada fechada `U_HBBridgeJSONTest()` passou em **31 checks, zero falhas**,
em 2026-10-21, independentemente de sockets/SQL. Evidência:
`tmp/d03-local-334459cffda64ccd89f8760b27c8d266/protheus.log`.
A rodada TCP/HTTP posterior de 80 checks comprova ida/volta NUL e cópias
defensivas `GetRow()`/`GetRows()` no caminho integrado.

#### Projeção binária

A leitura SQL nativa preserva os bytes binários exatamente. Rotas de consulta
JSON versão 1 retornam `BINARY_JSON_UNSUPPORTED` para resultado binário bruto,
sem conversão textual nem retorno de linhas parciais. O chamador pode selecionar
texto hexadecimal explicitamente, como
`CONVERT(varchar(max), binary_value, 2)` no MSSQL. O exemplo SRA resolve sua
própria projeção no Protheus e omite colunas binárias; texto longo comum não
é classificado como binário. Representação JSON automática de base64/BLOB bruto
permanece como contrato versionado futuro.

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
Isso identificou uma falha de serialização; os 92 checks MSSQL nativos anteriores
não cobriam o ciclo FLOAT bruto/JSON. D03 agora corrige o codec de transporte
e testa esse caso separadamente da navegação.

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

Isso não substitui a preservação genérica do transporte. SDDODBC preserva o
double FLOAT, mas associa metadados de formatação com zero casas; o encoder
JSON anterior usava esses metadados em formato fixo. O codec C/Zig implementado
preserva o valor aproximado recebido sem exigir CAST nem presumir duas casas
para todo campo numérico.

| Abordagem | Papel / situação |
| --- | --- |
| CAST para DECIMAL no SQL do chamador | Disponível; define escala/arredondamento do resultado SQL. |
| Corrigir serialização FLOAT bruta | Codec C/Zig implementado; ida/volta binary64 nativa e tolerâncias numéricas declaradas no AppServer verificadas separadamente. |
| Precisão/escala lógica explícita do chamador | Alternativa proposta sem mudar SQL; aplicar apenas a regra fornecida por campo e distinguir representação/arredondamento de exibição. Ainda não são parâmetros aceitos. |
| Decimal textual projetado no SQL | Opção disponível para dígitos decimais exatos além da capacidade double; manter string até conversão deliberada. |

O `hb_odbcNumSetLen()` upstream serviu como referência de inspeção para metadados
de formatação por item sem alterar o valor numérico nativo. Pertence à `hbodbc`,
que o produto não vincula. D03 usa o codec C/Zig de transporte; o helper upstream
não constitui nova API pública do hbBridge.
Referências: [helper de metadados numéricos ODBC](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/contrib/hbodbc/odbc.c#L1203),
[formatação numérica JSON](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/src/rtl/hbjson.c#L259).

O formatador implementado emite uma representação curta de ida/volta quando
a formatação fixa nativa alteraria o double recebido. Seu decoder preserva o
valor binary64 nativo; os testes incluem magnitudes pequenas/grandes, notação
científica, zero negativo e valores que exigem 17 dígitos significativos. Um
token com formato DECIMAL nativo só é mantido quando retorna ao mesmo valor.
O `hb_snprintf()` fixado mapeia especificadores gerais/científicos para formato
fixo, logo apenas mudar seu formato para `%.17g` era insuficiente.

Os checks Protheus usam valores nativos `N` com tolerâncias explícitas dentro
de 15 dígitos significativos, sem prometer identidade de bits binary64 em seu
parser JSON. `DEC_CREATE()` cria outro tipo decimal fixo; não recupera precisão
já perdida na leitura de um número JSON. Projetar DECIMAL/BIGINT grande como
texto quando o consumidor exigir dígitos exatos. FLOAT permanece aproximado;
correção de transporte e CAST não reconstroem dígitos ausentes na origem.

O próximo contrato versionado de resultado deve distinguir:

| Grupo de metadados | Significado |
| --- | --- |
| `source` | Tipo SQL do conector, precisão, escala anulável, tamanho em caracteres/bytes, nulidade e collation quando conhecida. |
| `logical` | Tipo, tamanho de exibição, precisão e escala fornecidos explicitamente pelo consumidor. |
| `wire` | Encoding textual e representação: número JSON, string decimal exata ou codificação binária. |

Esses grupos e `targetEncoding` são desenho, **não parâmetros adicionais
aceitos pelo serviço estrito atual**. Uma extensão futura ainda exige aceite
próprio de metadados lógicos/campos grandes e números exatos além das
representações exercitadas pela D03.

### Addon de metadados e reescrita SQL adiados

Decisão em 2026-10-13: manter addons de metadados Protheus e política decimal
automática em espera. CAST no SQL do chamador permanece como abordagem disponível
para escala de negócio. Naquela decisão, FLOAT bruto e aceite UTF-8 ampliado
continuavam pendentes; a implementação/homologação D03 separada acima tratou
depois seu escopo demonstrado, sem adicionar addons de metadados ou reescrita SQL.

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
