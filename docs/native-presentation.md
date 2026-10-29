# Caller-owned native presentation

[Português](native-presentation.pt-BR.md) · [Typed contract](typed-sql.md) · [WIP](../WIP.md)

T04 implements a separate, explicit Protheus presentation boundary over the
existing typed dataset. Protheus supplies the complete logical schema; the
adapter does not read SX3/TOP_FIELD, infer company/branch or rewrite SQL.
The existing `HBBridgeBrowseData():Browse()` examples retain their interface.

`HBBridge.Client.HBBridgePresentationSchema():Validate(header, schema, @code,
@message)` checks projection correspondence, positions and caller definitions.
`ConvertRow(header, schema, row, @converted, @code, @message)` publishes native
C/N/L/D values only after every field passes. Input snapshots remain UTF-8.

- Character conversion decodes each field once and requires an encoding
  roundtrip and sufficient native byte capacity. Never decode serialized JSON.
- NULL stays in the query/dataset. This native destination rejects it under
  `nullPolicy: "reject"`, even when caller `nullable` is true. NUL also fails.
- Exact decimal/int64 strings convert to N only if fixed width/scale formatting
  returns the same exact value; no implicit rounding or DEC_CREATE escape.
  Explicit character targets can retain these digits as text.
- Native booleans require logical values. Dates require the caller's explicit
  ISO or YYYYMMDD format and a valid calendar; no field-name inference occurs.

The version-1 native field profile uses C up to 254 bytes, N up to 32 positions
and 16 decimal places, D length 8 and L length 1. Numeric formatting also needs
space for its integer part, separator and sign. These are SDK destination
constraints, not SQL row, payload or source-precision limits. Declared width
does not guarantee numeric fidelity: every value passes conversion checks;
full storage readback is an optional diagnostic. See the official
[DBCreate](https://tdn.totvs.com/display/tec/DBCreate)
and [SDK numeric model](https://tdn.totvs.com/display/framework/SDK%2BMicrosiga%2BProtheus).

`ConvertPage(header, schema, rows, @converted, @code, @message)` validates the
unchanged schema once per page and preserves all per-row/value checks. It
returns a new page only after every row succeeds; invalid input never publishes
a partial page. `ConvertRow` retains its strict independent validation. The
native adapter uses page conversion, and browse callbacks resolve invariant
field positions when columns are created. Search indexes and defensive dataset
snapshots remain in place.

## Optional source-field mapping

The logical schema can include an optional `projectionFields` object. Existing
version-1 schemas containing only `schemaVersion` and `fields` remain valid.
The map associates projected keys with original field names declared by the
Protheus caller; it does not parse SQL or change the driver-reported header.
For example, a query containing `RA_SALARIO AS AMOUNT` can declare:

```advpl
jLogicalSchema["projectionFields"] := {"AMOUNT":"RA_SALARIO"}
oNative := HBBridge.Client.HBBridgeNativeTable():New(oDataSet, jLogicalSchema)
```

Every map key must name an existing logical-schema projection. Values must be
nonempty strings without NUL characters. Empty/partial maps are valid, and
different projections can name the same source field. This is local
presentation metadata supplied by Protheus, not an ERP lookup performed by
hbBridge or a new SQL-service parameter. The constructor takes a defensive
copy of the schema, including this map.

`LoadCurrentPage([cRDD], [jProjectionFields])` uses the explicit map when its
second argument is a JSON object; otherwise it uses `schema.projectionFields`,
when present. An explicit empty object therefore selects no caller mappings
for that load. After collecting the accepted page's source-column metadata,
the adapter applies the selected map through `SetSourceFieldName()` and fills
only missing source names. This selection is repeated on each page load.
Calling `SetSourceFieldName(jProjectionFields, .T.)` explicitly can replace an
existing source name; `lForce` belongs to the setter, not `LoadCurrentPage()`.

Explicit SELECT lists and JOINs use the same dataset/schema boundary: define
only the returned projections, give every output a unique alias and supply
each origin explicitly when the driver omits it. Dictionary metadata, business
predicates and result-row ordering remain caller-owned. The current SRA/SX5
builders enumerate one table's supported fields; selected-field/JOIN examples
and their native UI acceptance are planned separately. See the
[projection/JOIN scope and NULL policy](sx3-metadata.md#selected-fields-and-join-queries).

## Current-page table and browse

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

`New(oDataSet, jLogicalSchema[, lVerifyStorage[, cRDD]])` snapshots the schema
and reserves one alias for the adapter's lifetime. `cRDD` defaults to
`SQLITE_MEM`; `SQLITE_TMP` and `TOPCONN` are explicit alternatives.

| Native destination RDD | Storage/write path |
| --- | --- |
| `SQLITE_MEM` | Local SDK SQLite memory destination; record writes |
| `SQLITE_TMP` | Local SDK SQLite temporary destination; record writes |
| `TOPCONN` | Owned `FWTemporaryTable` through DBAccess; FWBulk when supported, otherwise record writes |

This RDD selects **local presentation storage**, independently of the remote
hbBridge SQL profile. An MSSQL query can populate `SQLITE_MEM`; the local
SQLite destination does not require a DBAccess connection for storage. A real
SRA definition may still use Protheus DBAccess to inspect its MSSQL physical
catalog. Existing tests of FWBulk request `TOPCONN` explicitly.

`RDD()` reports the configured destination. `LoadCurrentPage([cRDD],
[jProjectionFields])` may
choose a supported driver before native storage exists. An invalid driver or
a switch while storage is live returns `INVALID_PRESENTATION_RDD` or
`PRESENTATION_RDD_CHANGE_REJECTED` **before clearing the accepted page**.
Close the owned storage before deliberately changing its driver.

The first successful load fills the table and then creates one initial search
index. Later loads reuse the **same native table, workarea, alias and already
created indexes**, clearing owned rows before refilling the current dataset
page. Navigation never deletes/reopens the alias or replaces the browse's
data source. Additional indexes are created only when requested.

`LoadCurrentPage()` does not query or move the dataset cursor. It validates all
conversions and native field definitions before accepting a page. Only then
do `Alias()` and `IsOpen()` expose that accepted result. The reserved alias is
not exposed before the first successful load or while a page is invalid.
`RowCount()` is page-local.
`FieldName(projection)` maps to generated native names of at most ten characters;
SQL aliases are never truncated or evaluated. `ProjectionName(position)` and
`FieldCount()` retain projection order. `Schema()` returns a defensive copy.

Names at the SQL, projection and temporary-table boundaries remain distinct:

| Method | Input | Result for `X5_DESCRI AS DESCRIPTION` |
| --- | --- | --- |
| `FieldName()` | Projected key `DESCRIPTION` | Generated native value field `F...` |
| `FieldPos()` / `FieldGet()` | Projected key `DESCRIPTION` or projection ordinal | Native field position / current native value |
| `ProjectionName()` | Projection ordinal or native `F...` | `DESCRIPTION` |
| `SourceFieldName()` | Projected key `DESCRIPTION` | `X5_DESCRI`, when reported in source metadata or declared by the caller |
| `FieldCaption()` | Projected key `DESCRIPTION` | The caller's logical-schema caption |
| `SourceFieldPos()` / `SourceFieldGet()` / `SourceFieldCaption()` | Original source name `X5_DESCRI` | Position / value / caption of its uniquely mapped projection |

`SourceFieldName()` snapshots `header[projection].source.column` and applies
the selected caller mapping when a page load is accepted. It does not reread
a borrowed dataset after the caller moves it, parse SQL or infer origin from
an alias. Origin absent from both sources returns an empty string. Unknown
projection names, private logical shadow
fields and a closed/invalid native page return empty mappings.
`FieldCaption()` remains the direct projected-key lookup. The three inverse
source methods first search every accepted source mapping; a unique origin
selects its projection, while duplicate origins are rejected. If no origin
matches, the optional second argument (default `.T.`) allows a projected-key
fallback. Pass `.F.` for source-only resolution. Missing/ambiguous names return
zero from `SourceFieldPos()`, `nil` from `SourceFieldGet()` and an empty string
from `SourceFieldCaption()`. For example, with `RA_NOME` mapped to no source
and `TEXT` mapped to `RA_NOME`, `SourceFieldGet("RA_NOME")` reads `TEXT`;
`FieldGet("RA_NOME")` still reads the homonymous projection. Neither caption
method calls SX3 or derives a dictionary title from source metadata.

Mapping direction is explicit: a SQL projection may itself be named
`F000000004`. `ProjectionName()` treats a string as a native generated name;
`SourceFieldName()` and `FieldCaption()` use projected keys, while the inverse
source methods use the resolution rule above. Convert between these namespaces
explicitly rather than guessing from spelling.

The `HBBridgeMsMGetEx` record-view helper uses the original dictionary name in
`aFields` and its `M->` variables when a source mapping is available, falling
back to the projection when origin is unknown. This preserves native Protheus
field behavior, including fields such as `RA_BITMAP`. Dictionary queries use
that same original name; captions use the projection's logical schema and
values are read from the generated native field position. This UI integration
does not change the dataset's projection keys or the server SQL contract.

Protheus can explicitly use a reported source field to request its own
dictionary metadata:

```advpl
cNative := oNative:FieldName("DESCRIPTION")
cProjection := oNative:ProjectionName(cNative) // DESCRIPTION
cField := oNative:SourceFieldName(cProjection) // X5_DESCRI if supplied or mapped
cCaption := oNative:FieldCaption(cProjection) // Caller-supplied caption
if !Empty(cField)
    cSX3Title := GetSX3Cache(cField,"X3_TITULO")
endif
```

The dictionary lookup belongs to the Protheus caller. The core adapter makes
no automatic SX3 requests and leaves missing source origin unresolved.

Search has a separate mapping: `SearchFieldName(projection)` returns the native
search field. `IndexOrder(projection)` is a lookup with no allocation or index
creation: it returns the actual physical order number, or zero when that index
has not been created. `EnsureIndex(projection)` creates a missing index on
demand and returns its physical order; repeating it is idempotent. It performs
no SQL request and fetches no dataset page. Unknown projections or unavailable
storage return zero with an explicit adapter error. Do not use a projection
ordinal as a physical index-order number.
Character, numeric and date projections use their value fields. A logical
projection retains an L value field but uses a private C(5) `True`/`False`
shadow for its index, because the native index path does not index L directly.
This helper is excluded from public projection counts and schema; use
`FieldName()` to read the actual logical value. Date index expressions use
`DTOS(field)`. Search order must use the explicit mapping, not physical field
positions, and survives page refill.

For a nonempty `TOPCONN` page, `FWBulk():CanBulk()` selects the write strategy
once. Supported DBAccess profiles use `FWBulk` with the temporary table's
`GetTableNameForTCFunctions()` target and the validated field structure. Rows
are submitted in that structure's order, then flushed and closed before
`TCRefresh`. A failure in `AddData`, `Flush` or `Close` invalidates the page;
the adapter explicitly clears a failed refill, or deletes a failed first
creation. It never explicitly retries a bulk buffer or falls back to record
inserts after a partial bulk operation. This is cleanup of an owned destination,
not a claim that server work was cancelled. Unsupported TOPCONN profiles and
the local SQLite RDDs use the record-write path selected before insertion.
Empty pages retain the schema
without opening a bulk writer. `WriteMode()` reports `bulk`, `record` or an
empty string for no completed writes; close/failure clears it. This reports the
selected path, not a performance measurement.

The bulk path uses `SetOption(1)`, documented for LIB 20250630 or later and
DBAccess 24.1.0.1 or later. See [FWBulk](https://tdn.totvs.com/display/public/framework/FWBulk)
for capability and return-value contracts. Arrays are confined to native field
definitions and per-row FWBulk input; keyed schema and page records remain JSON
objects. Both write paths apply the same schema/value conversion rules.

`lVerifyStorage` defaults to `.F.`. Passing `.T.` as the third constructor
argument enables complete post-write native readback and exact comparison
before the page is accepted. This diagnostic adds another full traversal;
production navigation does not perform it by default. The native integration
tests independently inspect every stored value, including runs with the
default option, so their storage checks do not rely on enabling a production
scan. Fixed-width character comparisons account for native space padding.

To change pages, call the dataset's `NextPage()`/`PreviousPage()` explicitly,
then `LoadCurrentPage()` again. Loading invalidates and clears the previous
page while preserving storage/index identity, including on failure; stale
rows are never presented as the new result. `ClearPage()` explicitly performs
that invalidation/clear without releasing the bound storage or indexes. It
leaves `Alias()` empty and `IsOpen()` false until another load succeeds.
No full-result materialization, prefetch or cross-request snapshot is implied.

`Close()` releases the owned alias, indexes and destination resources but
retains schema and the reserved alias for a later explicit load. TOPCONN
deletes its owned `FWTemporaryTable`. SQLite resource lifetime is managed by
the SDK connection; closing a logical table/index name is not evidence that
an underlying temporary file has been physically removed. Close is not a
page-navigation API.
`Destroy()` additionally releases configuration and the borrowed dataset
reference. Both are explicit/idempotent; neither closes or frees the dataset or
client. Failed deletion retains ownership for a retry and exposes
`PRESENTATION_CLOSE_FAILED`; do not free the owner after a failed Destroy.
Methods restore the previously selected workarea.

`BrowseNative()` is a local static function in the
[interactive example](../src/tlpp/tests/protheus/hbbridge.presentation.test/hbbridge.presentation.browse.tlpp),
not a public method of `HBBridgeBrowseData`. The example owns its UI while
borrowing the dataset and native adapter. A reusable generic native browse API
remains future work; the existing `Browse()` method is unchanged. The native
[FWTemporaryTable contract](https://tdn.totvs.com/display/framework/FWTemporaryTable)
keeps ownership within the creating Protheus thread.

The interactive example keeps one dialog open around a native `FWBrowse`.
`SetAlias()` runs once during UI construction; page callbacks refill the same
table and refresh the existing widget. Selecting a search column calls
`EnsureIndex()` before seeking; created indexes and the selected physical
order survive page refill. FWSeek's logical option/projection is independent
of that physical order. The callback reads the SDK-owned
`aDetails[nOption][1][7]` mapping directly, without a defensive JSON copy in
the seek path.
First, Previous, Next, Last and Refresh reload the current native page inside
that dialog. Close only ends the dialog; it does not request another page.
View displays the current row within the example; visual acceptance of that
action remains separate from headless checks.
The search control, typed Field/Operator/Value filter and Clear filters action use the
same page flow. `U_HBBridgeNativeBrowse([nRecords], [nPageSize])` defaults to
**1000 synthetic records and 13 records per page**. For a larger visual load:

```advpl
U_HBBridgeNativeBrowse(10000,100)
```

The [companion fixture client](../src/tlpp/tests/protheus/hbbridge.presentation.test/hbbridge.presentation.browse.client.tlpp)
accepts the record count in `HBBridgePresentationBrowseClient():New(nRecords)`.
Without search or filters it generates only the requested page. With criteria,
it evaluates all configured source rows **before** page selection, so matches
and totals describe the filtered fixture rather than only visible rows. This is example
behavior, not a generic SQL filter implementation or full-result client cache.
Real callers must supply equivalent query/filter rules explicitly.

The fixture has seven public projections, in order: `ID_CODE`, `ID`, `AMOUNT`,
`TEXT`, `FLAG`, `DAY`, `FLOAT`. `ID_CODE` is a C(10) code padded with leading
zeros, so character index order matches the visual numeric sequence within
that width. It is generated from the same row identifier as `ID`. `ID` remains
an exact int64 wire string presented as C(20); the additional display/sort code
does not convert it to a floating-point number or change the typed contract.
The fixture supports `contains` and `starts with` criteria on `ID_CODE`, `ID`
and `TEXT`, alongside its typed comparison operators.
Columns bind independently to each projection's native field position.
The logical Flag column displays `True`/`False` while retaining logical native
storage; Day and Float use their own date/numeric bindings. Verify these
columns, masks and accents when homologating the revised interface.

## Read real SX5 data in the native browse

The separate `U_HBBridgeNativeBrowseSX5([cProfile], [cTransport], [nPageSize])`
entry reads actual SX5 rows through hbBridge and reuses the same local
`BrowseNative()` dialog. It defaults to `TCP` and 100 rows per page:

```advpl
U_HBBridgeNativeBrowseSX5("MSSQL/pData","TCP",100)
U_HBBridgeNativeBrowseSX5("MSSQL/pData","HTTP",100)
```

Use the SQL profile configured on the hbBridge server for the intended
Protheus database. An omitted profile reads `[hbBridge] SQLProfile` from the
active AppServer INI; there is no demo-profile fallback. TCP/HTTP endpoints
and HTTP authorization come from the existing client configuration; HTTP
requests gzip. Run inside an already prepared Protheus company/branch context,
such as FWWebEx. This entry does not prepare or switch ERP environments.

[`HBBridgePresentationSX5:Definition()`](../src/tlpp/tests/protheus/hbbridge.presentation.test/hbbridge.presentation.sx5.tlpp)
uses the shared `HBBridgePresentationTable():Definition("SX5")` dictionary/
physical-catalog builder. The projections retain supported original SX3 names,
including `X5_FILIAL`, `X5_TABELA`, `X5_CHAVE` and `X5_DESCRI`, plus available
system fields such as `R_E_C_N_O_`; the column set follows the local dictionary.
`schema.projectionFields` explicitly preserves their origin even when ODBC
does not report it. Protheus resolves `RetSQLName("SX5")` and `xFilial("SX5")`.
The wrapper binds the undeleted marker/current branch and orders by
`X5_FILIAL,X5_TABELA,X5_CHAVE,R_E_C_N_O_`, with the record number breaking ties.
Search/filter changes cannot remove these base predicates. The query is
read-only; its native destination is separate presentation storage.

[`HBBridgePresentationSQLSource`](../src/tlpp/tests/protheus/hbbridge.presentation.test/hbbridge.presentation.sql.source.tlpp)
owns the example's trusted SQL, order, schema and base bindings. `Query()`
returns SQL/bindings/order for each explicit page request. It accepts only
schema-mapped projection names and allowed typed comparisons, appending values
as parameters instead of SQL text. Character criteria escape `%`, `_`, `[`,
`]` and `~` for literal LIKE matching; quote-containing input remains a bound
value. Dates use ISO values and logical criteria use booleans. Integer criteria
use exact int64 text; fractional native numeric criteria use approximate
number bindings and do not promise exact decimal arithmetic. This controller
keeps input text in the caller's encoding: the production client encodes the
complete JSON request into UTF-8 once. Do not pre-encode individual bindings.
It is example-owned, not a general SQL parser or a public generic browse API.
The filter picker takes its fields from the current schema, so the
dictionary-driven SX5 query and seven-column synthetic fixture share the dialog.

## SRA fields and reusable SX3 metadata

`U_HBBridgeNativeBrowseSRA("MSSQL/pData","TCP",100)` reuses this dialog for
the wider SRA schema; replace TCP with HTTP for the gzip route. The Protheus
definition combines a fresh `HBBridgeSX3Metadata:Read("SRA")` snapshot,
physical `HBBridgeSqlTools:GetColumnMetadata()` results, `RetSQLName` and
`xFilial`. Field names remain the original dictionary keys, making explicit
SX3 lookups possible without inferring them from generated temporary names.

The inventory retains all dictionary definitions and records an inclusion or
exclusion reason for each field. Supported physical C/N/D/L values and available
system fields form the SELECT; virtual, memo/binary, long-text and unsupported
definitions are not silently converted or truncated. Numeric CASTs use the
caller-resolved SX3 definition in this example. Empty Protheus dates use an
explicit eight-space YYYYMMDD representation; SQL NULL remains distinct and
still fails only when this native destination cannot represent it.

`GetNonBlobColumns()` alone would retain long text, so the example uses the
physical catalog as well as the dictionary. No LOB transport or automatic
server-side ERP resolution is added. See the
[metadata contract and SRA usage](sx3-metadata.md) for object ownership, field
status, connector scope and validation requirements.
The SRA-only **Field catalog** action displays every inventoried dictionary/
physical field with its type, width, scale, title and inclusion/exclusion
reason. It inspects the existing metadata snapshot rather than opening a raw
SX3 table browser or requesting employee values again.

## Reproduce validation

Use a licensed external AppServer SDK/INI, vendor RPOs, include directories and
an accessible DBAccess profile for optional native storage tests:

```powershell
./scripts/test-protheus-presentation.ps1 -AppServerDirectory '<sdk>' `
    -IniFile '<sdk-ini>' -RpoDirectory '<vendor-rpos>' `
    -IncludeDirectory @('<totvs-includes>', '<project>/includes') `
    -NativeTables -NativeRows 10000
```

The runner creates its own disposable SDK/RPO/INI directories and never stops
existing services. It compiles current sources and runs presentation plus typed
and ordinary dataset regressions. `-NativeTables` also runs the SDK observation
probe, actual temporary-table tests through the configured DBAccess endpoint
and the headless column/navigation fixture. `-NativeRows` controls the main
synthetic storage load; its default is 1025 rows to cross the 1024-row bulk
buffer. Small fixed paging cases still use two rows followed by one row.
Raw logs remain local scratch; credentials/INI content are not acceptance data.
Interactive native browse dismissal and combined hbBridge/backend execution require
their separate T05 acceptance. A mock or compilation alone does not prove UI.

For the separate real SQL integration test, keep an owned hbBridge fixture
serving from one PowerShell terminal:

```powershell
./scripts/test-hbbridge-typed-sql.ps1 -Config '<private-ini>' `
    -Profile '<mssql-alias>' -Serve -ServeSeconds 1200
```

Wait for its printed fresh `endpoints.json` path. In another terminal, pass
that path to a new isolated AppServer run:

```powershell
./scripts/test-protheus-presentation.ps1 -AppServerDirectory '<sdk>' `
    -IniFile '<sdk-ini>' -RpoDirectory '<vendor-rpos>' `
    -IncludeDirectory @('<totvs-includes>', '<project>/includes') `
    -NativeTables -HBBridgeEndpointsFile '<fresh-endpoints.json>'
```

`-HBBridgeEndpointsFile` requires `-NativeTables` and adds
`U_HBBridgePresentationSQLTest()`. This test executes an actual MSSQL SELECT
over five constant `VALUES` rows, with the seven typed projections, through
TCP and gzip HTTP, the dataset and native temporary table. It covers paging,
types, criteria, literal input, failure recovery and cleanup without reading
or writing ERP tables. It differs from the interactive SX5 SELECT: automated
constant-row acceptance does not establish dictionary/business-context or
dialog acceptance.

The endpoint file contains a private temporary HTTP token. Keep it local and
do not commit or paste it into reports. The AppServer runner copies those
settings only into its newly owned INI; it does not edit deployment INIs.
The serving fixture stops at its bounded lifetime or when `stop.request`
is created in that fresh run directory. Reproduction starts a fresh serving
run, never relies on retained scratch endpoints. See the
[script guide](../scripts/README.md#isolated-native-protheus-presentation).

The records are generated in
[`HBBridgePresentationFixture:Row()`/`Result()`](../src/tlpp/tests/protheus/hbbridge.presentation.test/hbbridge.presentation.fixture.tlpp),
then the [native storage test](../src/tlpp/tests/protheus/hbbridge.presentation.test/hbbridge.presentation.table.test.tlpp)
assigns alternating Flag, Day and signed Amount values, with Float = row / 4.
They reach a real private DBAccess temporary table through a mock typed
dataset; there is **no ERP table read or hbBridge network SQL query**. The
table is deleted at final Close/Destroy, so fixture data is not retained for
inspection after the test. To change the main load directly, call
`U_HBBridgePresentationTableTest(10000)`, or use the isolated AppServer CLI
entry `-run=U_HBBridgePresentationTableCLI --native-rows=10000` with the runner's
prepared environment.

`U_HBBridgeNativeBrowseTest()` checks real native table/navigation, column
metadata and bound value codeblocks without creating a `FWBrowse` widget in a
job thread. That headless fixture does not activate or validate the dialog;
use `U_HBBridgeNativeBrowse()` in an interactive session for visual acceptance.
Its small navigation scenario retains 12 records and pages of four,
independently of the interactive defaults; separate assertions exercise a
10,000-record source and pages of 100.

Manual AppServer validation recorded on **2026-10-26**, from the supplied
console output: native browse **50/50** checks passed and native table
**56/56** checks passed. The table run used **1025 rows**, selected `bulk` and
crossed its 1024-row buffer. The output also confirmed seven native search
indexes, including the logical shadow and date expression, plus stable
alias/workarea/index identity after refill. These supplied logs do not identify
the executable or RPO hashes. The browse test validates native data, column
bindings and navigation without activating the dialog; these results do not
establish visual acceptance or combined hbBridge/backend acceptance.

The subsequent isolated run on **2026-10-26** compiled **66 sources** with zero
errors and passed **59 browse / 62 native-table / 32 conversion / 5 SDK**
checks plus **77 typed / 67 ordinary dataset** checks, with zero assertion
failures. The main table load wrote and independently checked **10,000 rows**
through FWBulk. Added assertions cover matching row codes, indexed 9-to-10
sequence, Code search/prefix filters and selected-index retention after
refill/failure/recovery. See the separate
[revision manifest](validation/native.presentation.revision.windows.json)
for source/RPO identities and exit codes. This remains nonvisual fixture
acceptance, separate from real AppServer-to-hbBridge SQL integration.

T05 subsequently passed **83 actual MSSQL TCP/gzip HTTP → AppServer typed
dataset → native storage checks** on 2026-10-26. The final isolated compile
passed **69 sources**, zero errors, and all six regression suites above.
The fresh native host passed **133 checks** and stopped both listeners with
no active leases. Unicode search verifies caller-native input encoded once
by the client, complementing UTF-8 result/native storage checks. See the
[real SQL manifest](validation/native.presentation.sql.windows.json).
This real constant-row SELECT acceptance does not activate the SX5 dialog;
the actual ERP-record and visual acceptance remains manual.

Subsequent screenshots supplied on **2026-10-26** confirm the real SX5 browse
displayed successfully over TCP and HTTP and the current-record View displayed
successfully. This manual visual observation is separate from the attributed
automated manifests: screenshots do not identify compiled hashes or prove all
filter, failure and cleanup paths. The wider SRA extension requires separate
compilation/regression and interactive acceptance.

Before the subsequent browse/FWBulk revision, validation on 2026-10-25 passed
64-source compilation with zero errors, 32
conversion checks, 34 actual native-table checks, five SDK assertions and
77/67 typed/ordinary dataset regressions. The
[sanitized manifest](validation/native.presentation.windows.json) identifies
sources, executable, RPOs and scope. Fixed-width character storage pads spaces;
the adapter checks the padded native value against its explicit field width.
Numeric formatter observations are separate from native-value equality and
do not establish exact decimal storage for every declared numeric field.

The **2026-10-29** review compiled **78 sources** without errors and passed
**654 checks** across ten isolated SDK suites: conversion/page conversion
76/31, SRA/SX5 planning 66, local RDDs 100, source mapping 36, datasets 77/67,
SDK 5, TOPCONN/FWBulk 122 and headless browse 74. Both local RDDs and lazy
indexes were exercised; the bulk write crossed its 1024-row buffer with 1025
rows. The ordinary dataset process returned -4 after its 67 checks and
APPLICATION END, accepted by the existing runner; the other suites exited 0.
The final MsMGet dictionary-identity change compiled separately; the current
SRA assertion layout was also recompiled and reran its 66 checks. See the
[review manifest](validation/presentation.review.windows.json) for exact
identities and scopes. These suites do not activate the revised record View.

For visual acceptance, compile the
[interactive fixture](../src/tlpp/tests/protheus/hbbridge.presentation.test/README.md)
and run `U_HBBridgeNativeBrowseSX5("MSSQL/pData","TCP",100)`, then HTTP,
inside the prepared Protheus company/branch. Verify actual SX5 records, accents,
paging/search/filter/View/close. The independent `U_HBBridgeNativeBrowse()`
fixture remains useful for Flag/Day/Float placement and synthetic load checks.
