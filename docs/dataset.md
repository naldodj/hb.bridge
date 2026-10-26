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

## Typed queries and NULL

`OpenSQLTyped(sql, bindings[, page])` and
`OpenPageTyped(sql, bindings, number, size, orderBy)` call `RPCRDD.QueryTyped`
with request version 1 and require result version 2. They share the profile,
client, metadata snapshots and navigation of ordinary queries. An old server's
`SERVICE_NOT_FOUND` remains visible; there is no unbound fallback.

```advpl
jBindings := JSONObject():New()
jBinding := JSONObject():New()
jBinding["type"] := "integer"
jBinding["isNull"] := .F.
jBinding["value"] := 10
jBindings["1"] := jBinding
oDataSet:SetAliasProfile(cProfile)
if oDataSet:OpenPageTyped(cSQL, jBindings, 1, 100, "ID ASC")
    while oDataSet:MoreToRead()
        // FieldGet preserves the declared wire representation.
        xAmount := oDataSet:FieldGet("AMOUNT")
        oDataSet:Skip()
    enddo
endif
oDataSet:Close()
FreeObj(@jBindings)
```

The caller supplies SQL with anonymous `?` value markers and bindings keyed by
contiguous ordinals; an empty object means no parameters. Binding snapshots
remain available for later pages independently of caller/client mutations.
`Header()`/`FieldInfo()` expose nested `source`, `rdd` and `wire` metadata;
unknown attributes stay null. Source precision and radix do not establish a
business scale. See the [complete contract and supported mappings](typed-sql.md).

`FieldGet()` retains UTF-8 text, textual exact int64/decimal, ISO DATE, approximate
numbers and booleans. SQL NULL remains `Nil`; it is never replaced by empty text,
zero or false. Check `!Eof()` and `FieldExist(name)` before interpreting Nil,
since missing fields and EOF also return Nil. Protheus owns business substitution.
Decode text once at the presentation boundary and retain the UTF-8 dataset;
native table NULL/precision limits do not change query values.

The [native presentation adapter](native-presentation.md) implements this
explicit boundary with caller schema, a current-page FWTemporaryTable and
owned cleanup; it neither prefetches nor closes the borrowed dataset/client.

The typed validator rejects malformed/missing metadata, mixed wire types,
noncanonical exact strings and inconsistent versions/totals before publishing
state. A failed page clears the old result and does not automatically retry.
The [Windows integration record](validation/typed.sql.windows.json) separates
native backend/TCP/gzip HTTP checks from actual AppServer JSONObject/mock checks.
Real AppServer/backend and native presentation acceptance remain in T05.

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

These runs exercise no transport, SQL backend or ERP table. D03's subsequent
MSSQL/TCP/HTTP integrity acceptance is recorded below; package closure and
M09 remain separate. See [tests](../tests/README.md) and
[acceptance](acceptance.md) for the execution record.

## Encoding finding on 2026-10-08

At this review, the HTTP worker and native MSSQL harness selected Harbour
`UTF8EX`, but the TCP adapter serialized JSON without selecting an explicit
codepage. The pinned Harbour default `EN` is CP437. The TLPP TCP request also
sent `ToJSON()` without the explicit UTF-8 conversion used by HTTP.
Consequently, the earlier ASCII TCP acceptance did not certify accented text.
`OemToAnsi(FieldGet(...))` repairing display is consistent with an intermediate
OEM conversion; it does not establish the original SQL column encoding.
These gaps were corrected and exercised by D03, as recorded below.

### D03 source integrity priority on 2026-10-19

Confirmed contract: text exchanged between Protheus and hbBridge uses UTF-8
in both directions, for both TCP and HTTP requests/responses. Protheus sends
text encoded from its actual local codepage to UTF-8 and converts received
UTF-8 to its consumer codepage when needed. Each conversion has one explicit
owner, including any native parser/channel conversion. Consumer codepage
selection does not change the wire encoding. Binary values retain their
explicit binary representation and never enter these text conversions.
The implementation now follows this contract; the demonstrated acceptance
scope is the MSSQL fixture and AppServer runtime recorded below.

The first acceptance gate is the database-to-driver/RDD-to-Harbour path,
before JSON or a Protheus UI. Confirm the intended characters using a known
fixture and an independently established database reference. Record the SQL
type, column collation/encoding where applicable, driver and retrieval type,
and active Harbour codepage. VARCHAR, NVARCHAR and binary values require
distinct handling; neither an alias nor the operating system establishes
their encoding. Preserve existing native acceptance and extend it with
targeted checks for the uncovered paths.

Validate each boundary separately:

1. **Database read:** compare native Harbour text, before serialization, with
   expected Unicode values and their known UTF-8 representation. Check long
   values/chunk boundaries, supplementary characters, NULL/empty and embedded
   NUL. Check binary bytes unchanged. Database storage and UTF-8 need not have
   identical bytes; their decoded text must agree. Inspect stored bytes and
   metadata separately when diagnosing a source mismatch.
2. **JSON/transport:** verify valid UTF-8 and semantic equality after a JSON
   round trip through TCP and HTTP. Literal characters and Unicode escapes
   must decode equivalently; different JSON escape choices need not produce
   identical serialized bytes.
3. **Protheus consumer:** convert the confirmed UTF-8 text once to the actual
   target codepage where needed, then compare the resulting values. For a
   CP1252 consumer, `DecodeUTF8(cText, "cp1252")` is an expected operation if
   the parser/client/channel has not already performed that conversion.

Removing `DecodeUTF8()` is not a D03 acceptance criterion. Its placement can
remain at an explicit consumer boundary while source integrity is validated.
Keep the working UI adjustments until replacements pass the actual consumer
tests. A display repair does not certify database retrieval; a later decode
cannot recover characters already lost, replaced or truncated upstream.
Previously misencoded stored data needs an explicit source diagnosis rather
than a generic repair heuristic. Numeric preservation remains a separate D03
check; successful text conversion does not establish it.

### Presentation observations on 2026-10-13

Correct SX5 presentation over HTTP was reported with
`jResponse:FromJSON(DecodeUTF8(jResponse:ToJSON()))` in the FWWebEx example.
Desktop presentation was reported to improve with `OemToAnsi()`. These were
observations about the shown text and UI boundary; they did not establish
source encoding or the complete Unicode/binary contract.

D03 supersedes those workarounds with the boundary policy below. Current
consumers convert each UTF-8 text value once with `DecodeUTF8()` when a local
codepage is required. `OemToAnsi()` is not the conversion for a known UTF-8
result. Whole-document recoding/reparsing can alter keys/control strings and
reintroduce the native JSONObject NUL defect; it is not the current policy.
`DecodeUTF8()` supports an explicit target encoding; see the TOTVS reference below.

Implemented boundary policy:

1. TCP/HTTP JSON uses UTF-8. The TCP adapter selects `UTF8EX` for request
   execution and restores its previous state. Both TLPP clients encode an
   ordinary AppServer text request once, before measuring/framing its bytes.
2. Returned text stays UTF-8. A consumer calls `DecodeUTF8()` once where its
   local codepage is required and checks conversion success. Values outside
   that codepage remain UTF-8 or need another explicit consumer representation.
   Binary values never enter these text conversions.
3. The managed ODBC patch handles Unicode SQL input and retrieval explicitly,
   including supplementary characters and chunk boundaries. A source mismatch
   still requires type/collation diagnosis, rather than an alias-based repair.
4. The actual AppServer fixture covers accents, CJK, supplementary characters,
   escaped Unicode, NUL and NULL/empty through TCP/HTTP. Raw binary retrieval
   and its separate JSON restriction are recorded below.

Collation governs comparison/sorting and influences non-Unicode SQL types;
it is not the response encoding. hbBridge must not silently change database
or column collation. Caller-supplied SQL can explicitly select a collation
where its query semantics require it. References:
[Microsoft collation/Unicode](https://learn.microsoft.com/en-us/sql/relational-databases/collations/collation-and-unicode-support?view=sql-server-ver17),
[TOTVS UTF-8 conversion](https://centraldeatendimento.totvs.com/hc/pt-br/articles/360025758092-Cross-Segmento-TOTVS-Backoffice-Linha-Protheus-ADVPL-Converte-uma-string-com-codifica%C3%A7%C3%A3o-UTF-8).

### D03 implementation and acceptance on 2026-10-21

The read-only `d03.mssql.constants.v1` fixture passed **80 checks, zero
failures**, through the production TCP/HTTP clients and dataset on Windows
AppServer **24.3.1.5**, using an isolated private RPO. Coverage includes source
text, raw fractional FLOAT, explicit DECIMAL scale, exact decimal text, NUL,
defensive row/page snapshots and explicit binary hexadecimal projection.
Receipt: `tmp/d03-protheus-9c3d1606250449c9a659f92f92c5c6e6/validation.json`.
The native server artifact SHA-256 is
`96A7AC7B0D29C2016B15CAC4D8DCD18E5FA4CE075AF1BA28DE4719A5E8BE5CA1`.
This accepts D03 for that fixture/runtime; it does not certify other drivers,
Linux, all business-field ranges or raw BLOB values in JSON.

Earlier native validation on 2026-10-19 passed **752 generic checks**,
**73 new MSSQL integrity checks**, **92 existing MSSQL checks**, **7 independent
.NET ODBC reference checks** and **2 Zig numeric checks**, all without failures.
The independent reference bypasses Harbour/JSON. The managed ODBC patch fixes
UTF-8 SQL input containing supplementary characters, as well as preserving
Unicode/binary retrieval; the pinned dependency checkout remains unchanged.

#### Embedded NUL in the AppServer JSON implementation

The isolated reproduction on this AppServer retained `A` + `Chr(0)` + `B`
in a direct property, but native `ToJSON()` reduced bytes `410042` to `41`.
Native `FromJSON()` reduced `"A\u0000B"` to `4142`, removing the NUL. This
serializer/parser defect is tracked in
[Protheus issue 14](https://github.com/naldodj/totvs-protheus-open-issues/issues/14).
UTF-8 decoding cannot recover the lost byte.

[`HBBridge.Client.HBBridgeJSON`](../src/tlpp/hbbridge.json.tlpp) now preserves
embedded NUL through `Encode()`/`Parse()` and is used by both clients and
dataset snapshots. Ordinary documents retain native scalar/container/numeric
handling; NUL-bearing strings use JSON `\u0000` escapes without sentinels.
The helper performs no codepage conversion. `Encode()` first walks the values
to detect NUL, so ordinary serialization has an additional linear traversal
and native key-enumeration allocations. NUL in a property name is rejected
explicitly, rather than silently changing the key.

The closed `U_HBBridgeJSONTest()` run passed **31 checks, zero failures**, on
2026-10-21, independently of sockets/SQL. Evidence:
`tmp/d03-local-334459cffda64ccd89f8760b27c8d266/protheus.log`.
The subsequent 80-check TCP/HTTP run proves NUL round trips and defensive
`GetRow()`/`GetRows()` copies in the integrated path.

#### Binary projection

Native SQL retrieval retains binary bytes exactly. Version 1 JSON query routes
return `BINARY_JSON_UNSUPPORTED` for a raw binary result instead of applying
text conversion or returning partial rows. The caller can select hexadecimal
text explicitly, for example `CONVERT(varchar(max), binary_value, 2)` on MSSQL.
The SRA example resolves its own projection on Protheus and omits binary
columns; ordinary long text is not classified as binary. Automatic base64/raw
BLOB JSON representation remains a future versioned contract.

#### Protheus projection helper

[`HBBridge.SQL.Tools.HBBridgeSqlTools():GetNonBlobColumns(cTable)`](../src/tlpp/hbbridge.sql.tools.tlpp)
returns an ordered, bracket-quoted column list for a caller-resolved physical
SQL Server table. It queries metadata through the active **Protheus DBAccess
connection**, independently of the dataset's hbBridge profile. The caller must
ensure that this connection's database and table/schema match the intended
hbBridge SQL destination. Table names, business predicates and profile selection
remain caller-owned.

The current MSSQL implementation resolves base types and excludes `image`,
`binary`, `varbinary`, `timestamp` and `rowversion`. It retains long text,
including `text`, `ntext`, `varchar(max)` and `nvarchar(max)`. The returned names
are unqualified; a caller constructing joins must supply the required aliases.
The helper does not fetch excluded values or implement a BLOB reader.

It returns `""` for blank input, an unsupported backend, a failed metadata query
or no visible eligible columns. These cases share the same return value; the
method exposes no structured `ErrorCode()`. Handle an empty projection before
constructing the query rather than substituting `*`. Metadata visibility and
SQL Server support for the aggregation used by this utility are prerequisites.

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
This identified a serialization defect; the earlier 92 native MSSQL checks
did not cover a raw FLOAT JSON round trip. D03 now corrects the wire codec
and tests this case separately from navigation.

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

### Business scale and raw FLOAT: analysis on 2026-10-13

`CAST(SRA.RA_SALARIO AS DECIMAL(12,2)) AS RA_SALARIO` is a valid explicit
business projection when the caller requires that precision/scale and the
value fits its range. It rounds to the selected decimal scale in SQL. Keep
the choice on Protheus, including dictionary resolution. SQL precision counts
digits and must not be confused with a display width that includes formatting.

This does not replace generic transport preservation. SDDODBC retains the
FLOAT double but attaches zero decimal-format metadata; the earlier JSON
encoder used that metadata with fixed-point formatting. The implemented
C/Zig wire codec preserves the received approximate value without requiring
a CAST or assuming that every numeric field has two decimal places.

| Approach | Role / status |
| --- | --- |
| Caller SQL CAST to DECIMAL | Available now; defines SQL result scale/rounding. |
| Correct raw FLOAT serialization | Implemented C/Zig codec; native binary64 round trips and the AppServer's stated numeric tolerances are verified separately. |
| Explicit caller logical precision/scale | Proposed alternative without changing SQL; apply only the supplied field rule, distinguish representation/rounding from display. Not accepted parameters yet. |
| Decimal text projected in SQL | Available option for exact decimal digits beyond double capacity; keep the string representation until intentional conversion. |

Harbour's upstream `hb_odbcNumSetLen()` was an inspection reference for per-item
formatting metadata without changing the native numeric value. It belongs to
`hbodbc`, which the product does not link. D03 instead uses the C/Zig wire codec;
the upstream helper is not a new public hbBridge API.
Source references: [ODBC numeric metadata helper](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/contrib/hbodbc/odbc.c#L1203),
[JSON number formatting](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/src/rtl/hbjson.c#L259).

The implemented formatter emits a shortest round-trip representation when
native fixed formatting would change the received double. Its decoder preserves
the native binary64 value; tests include tiny/large magnitudes, scientific
notation, negative zero and values requiring 17 significant digits. A native
DECIMAL-format token is retained only when it round-trips to the same value.
The pinned Harbour `hb_snprintf()` maps general/scientific specifiers to fixed
formatting, so merely changing its format to `%.17g` was insufficient.

The Protheus checks use native `N` values with explicit tolerances within
15 significant digits, not a promise of binary64 bit identity in its JSON
parser. `DEC_CREATE()` creates a different fixed-decimal type; it does not
restore precision already lost when reading a JSON number. Project exact large
DECIMAL/BIGINT digits as text when required by the consumer. FLOAT remains
approximate; neither a transport fix nor CAST reconstructs absent source digits.

The next versioned result contract must distinguish:

| Metadata group | Meaning |
| --- | --- |
| `source` | Connector SQL type, precision, nullable scale, character/octet length, nullability and collation when known. |
| `logical` | Type, display length, precision and scale supplied explicitly by the consumer. |
| `wire` | Text encoding and representation: JSON number, exact decimal string or binary encoding. |

These groups and `targetEncoding` are a design, **not implemented options of
the current service**. Current Query can ignore unknown top-level keys;
sending a design field does not enable it. The [typed SQL draft](typed-sql.md)
remains pending T01 review while HTTP performance has priority. A future
extension still needs its own large-field/logical metadata and exact-number
acceptance beyond the representations exercised by D03.

### Deferred metadata addon and SQL rewriting

Decision on 2026-10-13: keep Protheus metadata addons and automatic decimal
policy on hold. Caller SQL CAST remains the available business-scale approach.
At that decision, raw FLOAT and broader UTF-8 acceptance remained unresolved;
the separate D03 implementation/acceptance above subsequently addressed its
demonstrated scope without adding metadata addons or SQL rewriting.

A later optional static method on `HBBridge.SQL.Tools.HBBridgeSqlTools` could
accept SQL plus a caller-resolved JSON schema and insert numeric CASTs before
the query is sent. This is a proposal, not an implemented API. Keep dictionary,
tenant, table names and field mappings on Protheus. A metadata addon would use
the same explicit inputs rather than become a mandatory part of query execution.

The caller can populate the logical schema with `TamSX3(cField)`: its native
array exposes length at position 1, decimal places at 2 and type at 3. Direct
`GetSX3Cache(cField, "X3_TAMANHO"/"X3_DECIMAL"/"X3_TIPO")` calls provide the
same properties. Copy only required properties into a keyed JSONObject, not
one metadata lookup per result row. Resolve source table/SQL alias bindings on
Protheus as well. Dictionary metadata describes the original field; computed
expressions still need an explicit result rule.

Prefer `TamSX3()`/`GetSX3Cache()` as the metadata provider. A direct SX3 SELECT
for `X3_TIPO`, `X3_TAMANHO`, `X3_DECIMAL` and `X3_CAMPO` is an explicit fallback
when the caller resolves the dictionary's physical name and context first,
including active/unique definitions. `RetSQLName("SX3")` is evaluated on Protheus
to construct SQL, not executed as a database function. Batch requested fields
and produce the same logical JSON schema; do not move implicit ERP lookups into
hbBridge. No timing comparison between these providers has been measured.

[`TCSqlToArr()`](https://tdn.totvs.com/display/tec/TCSqlToArr) is a candidate for
one batched dictionary SELECT, with bind values and optional result typing.
Its mandatory result array is a native API boundary: convert once to keyed
JSONObject. DBAccess return typing does not affect hbBridge's separate ODBC
query. Compare cold/warm cache access against batch query/conversion cost at
actual field counts before choosing the faster provider.

Read-only inspection of the supplied local `ApLib070.prw` found `ChangeQuery()`
using database/context APIs, SQL filters and a dictionary-assisted PostgreSQL
CAST case. It is a reference for separation of concerns, not a portable parser
or code adopted into hbBridge. The framework's documented purpose is dialect
adaptation: [TOTVS query guidance](https://tdn.totvs.com/display/framework/Desenvolvendo%2Bqueries%2Bno%2BProtheus).
Python `sqlparse.parse()` produces grouped tokens but is intentionally
non-validating; catalog binding and type/scale decisions remain application work.
See the [sqlparse introduction](https://sqlparse.readthedocs.io/en/latest/intro.html).

Start any future evaluation with a restricted, opt-in TLPP projection transform:
explicit source/alias bindings; validated SQL precision/scale distinct from
xBase display width; ordered complete source columns for `*`/`alias.*`, including
system fields; existing CAST preservation and repeat-call idempotence. Preserve
literals, comments and unaffected SQL. Expressions, aggregates, DISTINCT,
GROUP BY, CTEs, subqueries and UNION require defined semantics or an explicit
unsupported result; do not guess field rules or silently rewrite them.
Applying CAST before a calculation can round inputs differently from casting
its result. Order, duplicates, NULLs and pagination must remain intentional.

Measure schema collection, parsing and complete query execution before adding
a cache or a Zig implementation. Python is a reference option, not a new runtime
dependency. This proposal remains deferred alongside the metadata addon.

## Credential protection

SQL, NETIO, admin and HTTP secret storage on hbBridge, plus client credentials
on the AppServer, have a separate [credential design](credentials.md).
Authenticated encryption with externally managed keys remains unimplemented;
dataset navigation and successful queries do not certify credential protection.
