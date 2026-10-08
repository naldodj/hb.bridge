# Navegação do dataset, codificação e definições dos campos

[English](dataset.md) · [Contrato SQL](milestone3-sql.pt-BR.md) · [WIP](../WIP.pt-BR.md)

## Navegação e metadados

`HBBridge.RDD.HBBridgeRPCDataSet` expõe registros JSON por nome. `Header()`
devolve cópia independente do cabeçalho; `DSStruct()` permanece como alias de
compatibilidade. `FieldInfo(nome)` devolve os metadados de um campo.
`FieldCount()` e `FieldName(posição)` enumeram a ordem original das colunas SQL
pelo `position` explícito, sem depender da ordem das chaves JSON.
`GetRow()` devolve cópia independente da linha atual, sem avançar.
`Header()`/`DSStruct()` devolvem `{}` quando fechado. `FieldInfo()` devolve
`{}` para campo ausente ou dataset fechado; `GetRow()` devolve `{}` no EOF.
`FieldName()` devolve `""` fora do intervalo iniciado em 1; `FieldGet()`
devolve `Nil` para campo ausente ou no EOF. Esses métodos não buscam páginas.
O chamador é dono das cópias JSON e as libera com `FreeObj()`.

Use `MoreToRead()` para varredura sequencial entre páginas:

```advpl
if oDataSet:OpenPage(cProfile, cSQL, 1, 10, cOrderBy)
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

As referências locais FileRead/FileNavigator orientaram essa interface.
Outra classe de navegação e um índice do resultado completo não são necessários
para esse caso sequencial. Cada página continua sendo outra consulta, sem
cursor persistente nem snapshot; use ordenação determinística com desempate
único. Protheus resolve tabela, exclusão lógica, empresa e filial antes da consulta.
Cada campo de `orderBy` deve existir na projeção SQL. Se a consulta usa
`TOP`/`LIMIT`, o chamador também deve selecionar esse subconjunto de forma
determinística; ordenar páginas externas não estabiliza um subconjunto sem ordem.

## Constatação de codificação em 2026-10-08

O worker HTTP atual e o teste MSSQL nativo selecionam Harbour `UTF8EX`.
O adaptador TCP não seleciona essa codepage e serializa JSON sem codificação
explícita. O padrão `EN` do Harbour fixado corresponde a CP437. A requisição
TCP TLPP também envia `ToJSON()` sem a conversão UTF-8 usada pelo HTTP.
Assim, o aceite TCP com ASCII não homologa textos acentuados.
`OemToAnsi(FieldGet(...))` corrigir a exibição é compatível com uma conversão
OEM intermediária; não comprova a codificação original da coluna SQL.

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

O próximo contrato versionado de resultado deve distinguir:

| Grupo de metadados | Significado |
| --- | --- |
| `source` | Tipo SQL do conector, precisão, escala anulável, tamanho em caracteres/bytes, nulidade e collation quando conhecida. |
| `logical` | Tipo, tamanho de exibição, precisão e escala fornecidos explicitamente pelo consumidor. |
| `wire` | Encoding textual e representação: número JSON, string decimal exata ou codificação binária. |

Esses grupos e `targetEncoding` são desenho, **não parâmetros adicionais
aceitos pelo serviço estrito atual**. Testar FLOAT fracionário, DECIMAL grande,
BIGINT acima de `2^53-1`, metadados de campos grandes e equivalência TCP/HTTP.

## Proteção de credenciais

Segredos SQL, NETIO, admin e HTTP no hbBridge, além das credenciais cliente
no AppServer, têm [desenho próprio](credentials.pt-BR.md). Criptografia
autenticada com chaves externas permanece sem implementação; navegação e
consultas bem-sucedidas não homologam proteção de credenciais.
