# Dataset navigation, encoding and field definitions

[Português](dataset.pt-BR.md) · [SQL contract](milestone3-sql.md) · [WIP](../WIP.md)

## Navigation and metadata

`HBBridge.RDD.HBBridgeRPCDataSet` exposes named JSON records. `Header()` returns
a defensive copy of the header.
`FieldInfo(name)` returns one field's metadata. `FieldCount()` and
`FieldName(position)` enumerate the original SQL column order, using the
header's explicit `position`, without relying on JSON key enumeration order.
`GetRow()` returns a defensive copy of the current row and does not advance.
`Header()` returns `{}` when closed. `FieldInfo()` returns `{}`
for an unknown field or closed dataset; `GetRow()` returns `{}` at EOF.
`FieldName()` returns `""` outside the 1-based field range; `FieldGet()`
returns `Nil` for a missing field or at EOF. These methods do not fetch pages.
The caller owns the JSON snapshots and releases them with `FreeObj()`.

Select the connection alias with `SetAliasProfile(alias)` before calling
`OpenSQL(sql[, page])` or `OpenPage(sql, number, size, orderBy)`.
`GetAliasProfile()` reads that selection; `SetAliasProfile()` returns its
previous value. Changing the alias closes the current result so a later page
cannot silently switch databases. `Close()` releases data and errors but
retains the selected alias for another query. The library chooses no demo alias.

`FieldExist(name)` checks the header even at EOF. `GetRows()` returns a defensive
copy of the **current page only**; it does not fetch or concatenate other pages.
`GetOrderBy()` returns the selected page order. `PreviousPage()` requests the
preceding page when `HasPreviousPage()` is true, resetting the row position to
the first record of the returned page. Page methods perform separate calls.

Use `MoreToRead()` for sequential navigation across pages:

```advpl
oDataSet:SetAliasProfile(cProfile)
if oDataSet:OpenPage(cSQL, 1, 10, cOrderBy)
    while oDataSet:MoreToRead()
        xValue := oDataSet:FieldGet("NAME")
        oDataSet:Skip()
    enddo
    if !Empty(oDataSet:ErrorCode())
        // Handle a failed page request separately from normal completion.
    endif
endif
oDataSet:Close()
```

`MoreToRead()` is idempotent while a current record exists. At page EOF it
requests the next page only if `HasNextPage()` is true. A failed request
returns false and preserves `ErrorCode()`/`ErrorMessage()`; it does not retry
indefinitely. It therefore performs I/O at a page boundary. `Eof()` and
`Skip()` retain their page-local behavior for existing manual navigation.
`RowCount()` remains the current page count, not the complete query count.
Repeated checks do not consume a record. `GetRow()` needs an explicit `Skip()`.

## Total rows and pages

The current paginated service returns top-level `totalRows` and `totalPages`
for the caller's complete base query, separate from page-local `rowCount`.
`TotalPages()` is the ceiling of total rows divided by page size; an empty
result has zero pages. Totals count the supplied query, including any `TOP`,
`LIMIT` or caller business predicates, rather than every row of a source table.

Use `HasTotals()` before displaying totals:

| Dataset state | `HasTotals()` | `TotalRows()` / `TotalPages()` |
| --- | --- | --- |
| Closed or failed open | false | `0` / `0`. |
| Open unpaged result | true | Complete row count / `0` when empty, otherwise `1`. |
| Open paged result with both totals | true | Validated server totals. |
| Older paged response without either total | false | `-1` / `-1`, explicitly unknown. |

The totals pair must contain non-negative exact integers within `2^53-1`,
with pages consistent with rows and page size. A missing half, wrong type,
fraction or inconsistent page count yields `INVALID_RESULT`. Unknown totals
are not inferred from the current page or `hasNext`.

Each paged call executes the page query and a separate `COUNT` on the same
connection. This adds database work; neither the pair nor later pages form
a snapshot. Concurrent changes may produce different page/count observations.
Use suitable isolation or a future snapshot/cursor contract where consistency
across requests is required.

The local FileRead/FileNavigator references informed this interface. A second
navigator class and whole-result index are unnecessary for this sequential
case. Each page is still a new query, not a persistent cursor or snapshot;
use deterministic ordering with a unique tie breaker. Protheus resolves its
table, deletion, company and branch expressions before opening the dataset.
Every `orderBy` field must exist in the SQL projection. If caller SQL uses
`TOP`/`LIMIT`, it must also select that subset deterministically; ordering the
outer pages cannot stabilize an unordered inner subset.

## Manual dataset acceptance on 2026-10-13

`U_HBBridgeDataSetTest()` passed **67 checks, zero failures and 31 mock calls**
on 2026-10-13 at 17:56:23 São Paulo time, thread 32332. Every keyed check was
true; the final result was `OK; checks=67; mock calls=31`. Coverage includes
header/field/row/page copies, column order, field existence, profile selection,
previous/next/`MoreToRead()` traversal, repeated checks, empty/closed states,
page failure/recovery and validated, unknown and malformed totals.

`U_HBBridgeHelperTest()` passed **12 pure checks, zero failures**, at 17:56:45
on the same date and timezone, thread 28300. Every keyed check was true;
the final result was `OK; checks=12`. SQL alias prefixing, string replacements
and typed custom-filter expressions are covered.

These are manual AppServer mock results. The 2026-10-08 compilation failure
preceded source compilation of the older 45-check fixture; the revised tests
were still awaiting execution at the 2026-10-12 review. The 2026-10-13 results
accept D02's dataset/helper scope. The historical result key
`dsStructDefensiveAlias` exercises a `Header()` copy and `FieldInfo()`.
`Header()` remains the canonical metadata API; `DSStruct()` remains removed.

These runs exercise no transport, SQL backend or ERP table. D03 is the next
task for the UTF-8/FLOAT integrity findings below; broader TCP/HTTP text and
numeric acceptance and M06–M09 remain open. See [tests](../tests/README.md)
and [acceptance](acceptance.md) for the execution record.

## Encoding finding on 2026-10-08

The current HTTP worker and native MSSQL harness select Harbour `UTF8EX`.
The TCP adapter does not select it and serializes JSON without an explicit
codepage. The pinned Harbour default `EN` is CP437. The TLPP TCP request also
sends `ToJSON()` without the explicit UTF-8 conversion used by HTTP.
Consequently, existing ASCII TCP acceptance does not certify accented text.
`OemToAnsi(FieldGet(...))` repairing display is consistent with an intermediate
OEM conversion; it does not establish the original SQL column encoding.

Required correction, **not implemented by the navigation methods**:

1. Use UTF-8 consistently for TCP/HTTP JSON and execute requests under
   `UTF8EX`, restoring the worker's prior state.
2. Let the TLPP consumer choose its target text encoding, such as `cp1252`
   or `utf-8`, with a strict error for unrepresentable text. Convert text once
   after JSON decoding; never convert binary values as text.
3. Describe source text/binary semantics explicitly. Any legacy OEM override
   must identify its field and source encoding and preserve original bytes
   before a lossy ODBC conversion; never infer encoding from an alias or sample.
4. Verify accented text, CJK, supplementary characters, escaped Unicode,
   NULL/empty and binary data through both TCP and HTTP in the actual AppServer.

Collation governs comparison/sorting and influences non-Unicode SQL types;
it is not the response encoding. hbBridge must not silently change database
or column collation. Caller-supplied SQL can explicitly select a collation
where its query semantics require it. References:
[Microsoft collation/Unicode](https://learn.microsoft.com/en-us/sql/relational-databases/collations/collation-and-unicode-support?view=sql-server-ver17),
[TOTVS UTF-8 conversion](https://centraldeatendimento.totvs.com/hc/pt-br/articles/360025758092-Cross-Segmento-TOTVS-Backoffice-Linha-Protheus-ADVPL-Converte-uma-string-com-codifica%C3%A7%C3%A3o-UTF-8).

## Numeric finding on 2026-10-08

The current header's `type`, `length` and `decimals` come from the Harbour
RDD. They are neither SX3 definitions nor guaranteed physical SQL metadata.
ODBC column size and scale have type-dependent meanings; FLOAT scale is not
a declared decimal scale. The connector also stores column size in a 16-bit
RDD field, which cannot describe every large SQL column faithfully.
References: [ODBC column size](https://learn.microsoft.com/en-us/sql/odbc/reference/appendixes/column-size?view=sql-server-ver17),
[decimal digits](https://learn.microsoft.com/en-us/sql/odbc/reference/appendixes/decimal-digits?view=sql-server-ver17).

A read-only constant probe against the local MSSQL backend reproduced loss:

```sql
SELECT CAST(123.4567 AS FLOAT) AS FLOAT_VALUE,
       CAST(123.4567 AS DECIMAL(15,4)) AS DECIMAL_FOUR,
       CAST(123.4567 AS DECIMAL(16,2)) AS DECIMAL_TWO;
```

The native FLOAT retained `123.4567`, but its RDD metadata reported zero
decimals and Harbour's JSON formatter emitted `123`. The two DECIMAL columns
emitted `123.4567` and `123.46`. Evidence: `tmp/numeric-probe-20261008.log`.
This identifies a serialization defect; the earlier 92 native MSSQL checks
did not cover a raw FLOAT JSON round trip. Navigation improvements do not fix it.

Protheus must resolve SX3/TOP_FIELD or another business schema and supply its
logical definitions explicitly. hbBridge must not query those tables or infer
`RA_SALARIO` rules automatically. `INFORMATION_SCHEMA.COLUMNS` describes SQL
storage; it cannot reconstruct a Protheus field's logical width/scale.
TOTVS likewise distinguishes its dictionary and query field conversion:
[Protheus queries](https://tdn.totvs.com/display/public/framework/Desenvolvendo%2Bqueries%2Bno%2BProtheus).

For the current contract, caller SQL can explicitly cast a known field to
`DECIMAL(p,s)`. This controls SQL rounding/scale, not all end-to-end precision.
Where exact digits are required, select the converted decimal as text, for
example `CONVERT(varchar(40), CAST(value AS DECIMAL(16,2)))`, and retain that
text until a deliberately chosen numeric conversion. Reading DECIMAL as a
double and converting it to text afterwards cannot recover lost digits.
FLOAT storage is already approximate; CAST cannot recover earlier loss.
References: [SQL float](https://learn.microsoft.com/en-us/sql/t-sql/data-types/float-and-real-transact-sql?view=sql-server-ver17),
[SQL decimal](https://learn.microsoft.com/en-us/sql/t-sql/data-types/decimal-and-numeric-transact-sql?view=sql-server-ver17).

The next versioned result contract must distinguish:

| Metadata group | Meaning |
| --- | --- |
| `source` | Connector SQL type, precision, nullable scale, character/octet length, nullability and collation when known. |
| `logical` | Type, display length, precision and scale supplied explicitly by the consumer. |
| `wire` | Text encoding and representation: JSON number, exact decimal string or binary encoding. |

These groups and `targetEncoding` are a design, **not additional parameters
accepted by the current strict service**. Tests must include fractional FLOAT,
large DECIMAL, BIGINT beyond `2^53-1`, large-field metadata and TCP/HTTP parity.

## Credential protection

SQL, NETIO, admin and HTTP secret storage on hbBridge, plus client credentials
on the AppServer, have a separate [credential design](credentials.md).
Authenticated encryption with externally managed keys remains unimplemented;
dataset navigation and successful queries do not certify credential protection.
