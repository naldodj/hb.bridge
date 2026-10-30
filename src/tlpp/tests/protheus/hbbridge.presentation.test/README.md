# Native presentation regression tests

[Português](README.pt-BR.md) · [Typed SQL contract](../../../../../docs/typed-sql.md)

T04 separates presentation conversion from native table and UI acceptance.
The conversion and synthetic tests use caller-supplied logical fields without
ERP dictionary/context resolution. The separate real SX5 example resolves
those Protheus details in its own definition; the native adapter stays generic.

The deterministic fixture uses the actual `JSONObject`, dataset and schema
implementation with the existing dataset mock client. Its assertions cover
schema validation, UTF-8 conversion exactly once, NULL rejection without
changing the dataset, explicit date formats, numeric width/scale without
rounding and defensive input/output snapshots. No SQL connection or browser
is required for those checks.

Native table checks use a prepared Protheus environment. `TOPCONN` storage and
FWBulk checks require DBAccess/`FWTemporaryTable`; `SQLITE_MEM` and `SQLITE_TMP`
select local SDK storage. They validate actual field storage, an empty page with
metadata, resource ownership, selected-area restoration and cleanup. The
presentation consumes a snapshot of the current page: it must not fetch a
later page, replace bindings or close the caller's dataset/client/workareas.
`HBBridgeNativeTable` defaults to `SQLITE_MEM`; explicit `TOPCONN` selects
FWBulk when supported and record writes otherwise. The local SQLite RDDs use
record writes. The test independently traverses every stored row and compares all seven
public fields. Separate index/seek checks exercise the private logical search
shadow.
Production full readback is opt-in through the constructor's third argument
`lVerifyStorage` (default `.F.`); the small fixture also exercises `.T.`.
The native adapter reserves its alias once and retains the same physical
table, workarea and already-created indexes through page refill/clear. A first
index is created after the first load, with others created on demand. Final
`Close()`/`Destroy()` releases the owned native resources; the SDK manages the
local SQLite database lifetime through the connection. Tests verify stable identity,
indexed seek after refill and recovery without replacing the browse source.
Inspect `WriteMode()` to identify the actual write path; compilation or a
record-only profile does not establish bulk acceptance. See the guide for
LIB/DBAccess requirements.

The native name APIs keep source identity separate from a SQL alias:

| API | Meaning |
| --- | --- |
| `FieldName("DESCRIPTION")` | Generated native value field `F...` |
| `FieldPos("DESCRIPTION")` / `FieldGet("DESCRIPTION")` | Native position / current value of that projected field; ordinals are also accepted |
| `ProjectionName(nPosition)` or `ProjectionName(cNative)` | Projected key, such as `DESCRIPTION`; strings identify native names only |
| `SourceFieldName("DESCRIPTION")` | Accepted source-column metadata or explicit caller map, such as `X5_DESCRI`; empty when unknown |
| `FieldCaption("DESCRIPTION")` | Caller-supplied logical-schema caption of that projected field |
| `SourceFieldPos/Get/Caption("X5_DESCRI")` | Native position / value / caption of the projection with that unique source |

Source metadata is captured from the accepted page, with optional
`schema.projectionFields` or the explicit second `LoadCurrentPage()` argument
filling missing origin. Existing schemas without this map remain valid. The
constructor snapshots it; page loads do not reread a dataset later moved by its
caller. The inverse source methods reject duplicate origins consistently and
allow projected-key fallback only when no source matches (second argument
defaults to `.T.`; `.F.` requests source-only resolution). Their failure values
are zero, `nil` and empty string respectively. Direct `FieldPos/Get/Caption`
remain unambiguous projected-key APIs. Unknown/private logical-shadow/closed-page
mappings are empty. Captions do not perform an SX3 lookup. For
`X5_DESCRI AS DESCRIPTION`, with reported or explicitly mapped origin:

```advpl
cProjection := oNative:ProjectionName(oNative:FieldName("DESCRIPTION"))
cField := oNative:SourceFieldName(cProjection)
if !Empty(cField)
    cTitle := GetSX3Cache(cField,"X3_TITULO")
endif
```

The adapter never queries SX3 or guesses missing origin; see the
[mapping contract](../../../../../docs/native-presentation.md#current-page-table-and-browse).

UI dismissal and `FWBrowse` behavior require a separate visual run. A passing
conversion fixture does not prove native storage, database cleanup, encoding
support outside the tested local codepage or UI acceptance.

Run `U_HBBridgePresentationTest()` for conversion, and
`U_HBBridgePresentationTableTest([nRecords])` for native storage/ownership. The SDK
observation probe is `U_HBBridgePresentationProbe()`. Read the
[native presentation guide](../../../../../docs/native-presentation.md) for the
isolated runner and caller-owned API.

## Fixture source and record count

The data is synthetic typed JSON, generated by
[`HBBridgePresentationFixture:Row()`/`Result()`](hbbridge.presentation.fixture.tlpp).
The [native table test](hbbridge.presentation.table.test.tlpp) sets ID to the
row number and ID_CODE to its ten-digit, zero-padded form, alternates Flag,
Day (`2024-02-29`/`2000-02-29`) and signed Amount
(`123.25`/`-123.25`), sets Float to row / 4 and retains UTF-8 `ação` in Text.
There is **no ERP-table read or hbBridge network SQL query**. The mock supplies
dataset pages; DBAccess stores only the owned temporary destination, deleted
at final cleanup.

Public projection order is `ID_CODE` C(10), `ID` C(20), `AMOUNT`, `TEXT`,
`FLAG`, `DAY`, `FLOAT`. `ID_CODE` gives the character index a numeric-looking
sequence (`0000000001`, `0000000002`, ..., `0000000010`). `ID` retains its
exact int64 text contract; it is not converted to a floating-point value for
sorting. Each row's code and identifier refer to the same generated number.
The fixture's character criteria support `contains` and `starts with` on
`ID_CODE`, as on `ID` and `TEXT`; the padded code is not restricted to exact
equality searches.

The main load defaults to **1025 rows**, crossing FWBulk's 1024-row buffer.
The independent navigation cases remain fixed at **2 + 1 rows**; changing the
main load does not resize those cases. Run a larger main load directly:

```advpl
U_HBBridgePresentationTableTest(10000)
```

For isolated compilation/execution, use
`scripts/test-protheus-presentation.ps1 -NativeTables -NativeRows 10000` with
the SDK/INI/RPO/include arguments documented in the guide. Its CLI entry is
`U_HBBridgePresentationTableCLI`, accepting `--native-rows=10000`. This is a
correctness/load fixture, not a timing benchmark; choose a size supported by
the test environment's memory and execution budget.

## Interactive and headless browse checks

`U_HBBridgeNativeBrowseTest()` checks column metadata, value codeblocks and
native table/navigation without creating a `FWBrowse` widget in a CLI job.
Passing it does not establish interactive dialog acceptance.

After compiling into an interactive test RPO, run
`U_HBBridgeNativeBrowse([nRecords], [nPageSize])`. Its defaults are **1000
synthetic rows and 13 rows per page**, with real temporary storage. Increase
both quantities explicitly when needed:

```advpl
U_HBBridgeNativeBrowse(10000,100)
```

The record generator is `HBBridgePresentationBrowseClient():New(nRecords)`
in the [companion fixture client](hbbridge.presentation.browse.client.tlpp).
Without criteria it generates only the requested page; with search/filters
it evaluates the full configured source before paging. The headless navigation
test keeps its independent 12-row/four-per-page scenario and separately checks
a 10,000-row source with 100 rows per page.

`BrowseNative()` is a static function
local to [this example](hbbridge.presentation.browse.tlpp), not a method of `HBBridgeBrowseData`;
a generic public native browse API remains deferred. Page navigation, search
and filter actions stay inside the same open browse. Closing it ends the
example without asking to open another page. Neither table adapter nor UI
prefetches pages. `SetAlias()` binds once; callbacks refill the same indexed
native table and refresh the widget. Nine buttons provide First, Previous,
Next, Last, Refresh, Add filter, Clear filters, View and Close;
search and typed Field/Operator/Value filters apply before page selection in
the [companion fixture client](hbbridge.presentation.browse.client.tlpp), with
Clear filters to remove both filters and search. They do not implement
generic SQL rewriting. `FieldName()` maps values, while `SearchFieldName()`
and `IndexOrder()` map the corresponding native search field/order. `IndexOrder()`
does not create indexes and returns zero for an uncreated one. The dialog calls
`EnsureIndex()` when a search column is selected, using the SDK-owned
`aDetails[nOption][1][7]` field mapping. Logical search options and physical index
orders are distinct; the adapter keeps created physical orders stable. Flag displays `True`/`False` while its value
field remains logical; a private C(5) shadow supplies its search index. The
shadow is not a public column. Date indexes use `DTOS(field)`. Verify accents,
dates, masks, Flag/Day/Float alignment, ID_CODE sequence, page
transitions, search, filters, selected area and normal/cancel close. This
visual fixture is independent of a running hbBridge service; combined backend
acceptance remains separate in T05.

## Actual SQL and real SX5 examples

The synthetic entries above do not read a business table. For actual SX5 data
inside the same native browse, run from an already prepared Protheus company/
branch context, such as FWWebEx:

```advpl
U_HBBridgeNativeBrowseSX5("MSSQL/pData","TCP",100)
U_HBBridgeNativeBrowseSX5("MSSQL/pData","HTTP",100)
```

`U_HBBridgeNativeBrowseSX5([cProfile], [cTransport], [nPageSize])` defaults to
TCP and 100 rows per page. Supply the hbBridge profile for the intended database
or configure `[hbBridge] SQLProfile` in the active AppServer INI; there is no
demo fallback. Client configuration supplies endpoints and authorization;
the HTTP route requests gzip.

[`HBBridgePresentationSX5:Definition()`](hbbridge.presentation.sx5.tlpp) uses
the shared `HBBridgePresentationTable():Definition("SX5")` dictionary/catalog
builder. Supported projections keep their original names, including
`X5_FILIAL`, `X5_TABELA`, `X5_CHAVE` and `X5_DESCRI`, plus available system fields.
The local dictionary determines the full set; the former five display aliases
have been replaced by dictionary keys. Protheus resolves the physical table and branch;
bound undeleted/current-branch predicates stay fixed, with `R_E_C_N_O_` as the
final ordering tie-breaker. `schema.projectionFields` explicitly retains source
names. It performs no SX5 writes. This is a real query, not the seven-column fixture.

[`HBBridgePresentationSQLSource`](hbbridge.presentation.sql.source.tlpp)
provides the local dialog with a `Query()` result containing trusted SQL,
order and bindings. Search/filter names come from the actual logical schema.
Allowed criteria append typed parameters without interpolating values into
SQL; LIKE wildcards/escape characters and quotes stay literal input. Integer,
ISO date and logical criteria use int64 text, date and boolean bindings;
fractional native numbers use approximate numeric bindings. This example
keeps text inputs in the AppServer encoding; clients encode the complete
request into UTF-8 once. Do not pre-encode each binding value. The
controller is not a new public generic browse API or general SQL parser.

`U_HBBridgePresentationSQLTest()` is the separate headless real integration
test: MSSQL SELECT over five constant `VALUES` rows supplies the seven fixture
projections through actual TCP/gzip HTTP clients, typed dataset and native
temporary storage. It exercises types, paging, bound criteria, empty/failure
recovery and cleanup without reading/writing ERP tables. To run, start a fresh
`test-hbbridge-typed-sql.ps1 -Config '<private-ini>' -Profile '<mssql-alias>'
-Serve -ServeSeconds 1200` process, then pass its printed fresh endpoint file
to `test-protheus-presentation.ps1 -NativeTables -HBBridgeEndpointsFile
'<fresh-endpoints.json>'`, together with the SDK/INI/RPO/include arguments.
See the [full commands and ownership rules](../../../../../docs/native-presentation.md#reproduce-validation).
Keep `endpoints.json` private: it includes the temporary HTTP token. This
AppServer run modifies only its new owned INI. Real constant-row checks remain
separate from manual SX5 visual acceptance.

## SRA dictionary and field coverage

Use `U_HBBridgeNativeBrowseSRA("MSSQL/pData","TCP",100)` or the same call
with HTTP inside the prepared Protheus company/branch. It reuses this dialog,
search, typed filters, explicit paging and View with original SRA field keys.
HTTP requires gzip; omitted profile/page/transport follow the SX5 rules.

[`HBBridgeSX3Metadata:Read("SRA")`](../../../hbbridge.sx3.metadata.tlpp)
returns a fresh `JSONObject` inventory through `FWSX3Util` and dictionary APIs.
`HBBridgePresentationSRA:Definition()` combines it with the physical catalog
through the shared `HBBridgePresentationTable:Definition()`, using
`HBBridgeSqlTools:GetColumnMetadata()`, currently MSSQL, and Protheus-resolved
table/branch information. Supported physical dictionary
fields plus available system fields form a read-only SELECT. Every virtual,
memo, binary, long-text, missing or unsupported field has an explicit exclusion
reason; metadata retains the full inventory. Counts are visible in the example.
This does not add memo/BLOB transport or silently truncate values.

The example creates numeric CASTs from the caller's SX3 width/scale, without
adding a general SQL parser or server-side dictionary access. Dates use an
explicit YYYYMMDD contract, including eight spaces for an empty date. SQL NULL
is preserved by the typed dataset and rejected only by the native destination.
See [metadata contract and SRA usage](../../../../../docs/sx3-metadata.md).
The SRA dialog also offers **Field catalog**: read-only Field/Type/Length/
Decimals/Caption/Status/Reason rows from the metadata snapshot, including
excluded entries. It is not a raw SX3 table editor and fetches no employee
values. The metadata API remains reusable independently of that view.

`U_HBBridgePresentationSRATest()` supplies deterministic snapshots to the
shared `HBBridgePresentationTable:Build()` and the SRA/SX5 `Plan()` methods.
It checks shared field exclusions, original projection names/source maps,
system-only and empty projections, and the mandatory fields used in each
wrapper's WHERE/ORDER BY. It does not query employee values or read the live
dictionary; the interactive examples exercise that separate integration.
The wrappers return failed definitions before SQL execution when those
requirements are absent. See the [shared definition contract](../../../../../docs/sx3-metadata.md#shared-presentation-definition).

The same suite passes a selected five-column typed fixture through the real
dataset and owned `SQLITE_MEM` destination. It verifies output order, native
decimal/date/logical values, UTF-8 decoding, original dictionary names and
cleanup without closing the borrowed dataset. Invalid aliases such as
`VALUE;DROP`, `[VALUE]` and the empty key are assigned through `JSONObject`
indexing: TLPP JSON literals cannot express those keys. Their rejection is
required; no valid-alias fallback or unconditional passing assertion is used.

## Selected SRA dictionary fields

The selected-field example reads real SRA data using the same native browse:

```advpl
U_HBBridgeNativeBrowseSRASelected("MSSQL/pData","TCP",100)
U_HBBridgeNativeBrowseSRASelected("MSSQL/pData","HTTP",100)
```

An omitted fourth argument uses
`HBBridgePresentationSRA():SelectedFields()`: `REGISTRATION` from `RA_MAT`,
`NAME` from `RA_NOME`, `AMOUNT` from `RA_SALARIO`, `ADMISSION_DATE` from
`RA_ADMISSA` and `RECORD_ID` from `R_E_C_N_O_`, in that order. The profile,
prepared company/branch, endpoint settings and HTTP gzip requirements are the
same as the whole-table SRA example. This entry does not query the synthetic
fixture and does not change the no-selection behavior of the existing SRA
entry.

A caller can supply its own keyed `JSONObject` as the fourth argument:

```advpl
jSelection := JSONObject():New()
jSelection["NAME"] := {"source":"RA_NOME","position":1}
jSelection["AMOUNT"] := {"source":"RA_SALARIO","position":2}
jSelection["RECORD_ID"] := {"source":"R_E_C_N_O_","position":3}
U_HBBridgeNativeBrowseSRASelected("MSSQL/pData","TCP",100,jSelection)
```

`HBBridgePresentationSRA():Definition(jSelection)` and its deterministic
`Plan(...,jSelection)` first validate the mandatory source fields and branch,
then use `HBBridgePresentationTable():Project(jDefinition,jSelection)` on the
unplanned shared definition. Output aliases are explicit; search/filter and
schema keys use those aliases. Dictionary captions, pictures and CASTs come
from the original source, recorded in `schema.projectionFields`. View retains
the original dictionary name for MsMGet and its memory variables.

Every entry must contain exactly `source` and `position`, with unique
contiguous integer positions, valid identifiers and case-insensitively unique
output aliases. Repeated sources are rejected to avoid conflicting MsMGet
dictionary identities. Missing, unsupported, empty or malformed selections
fail completely. No arbitrary SQL expression or automatic system column is
added. SRA requires the record-number source under a selected alias for
deterministic order, for example `RECORD_ID ASC`; branch/deleted predicates
remain bound even when those fields are not displayed.

The result retains the complete metadata/field catalog; unselected supported
sources receive reason `notSelected`. Inputs and selected result snapshots
have independent ownership. `Project()` accepts a successful `Build()` result
before SQL planning, not an already planned query or projected definition. See the
[selection contract](../../../../../docs/sx3-metadata.md#selected-fields-and-join-queries).
This API remains limited to one table; explicit JOIN examples remain planned.

Isolated planning/storage checks exercise aliases, order, conversion and
ownership with controlled fixtures. They do not establish live-dictionary or
interactive acceptance. Run both transports in the prepared SRA environment
and verify paging, projected-field search/filter, captions, accents,
date/amount values and View; earlier whole-table observations do not replace
this acceptance.

## Recorded validation

Manual AppServer output supplied on **2026-10-26** recorded **50/50 native
browse checks** and **56/56 native table checks**, all passing. The table run
selected `bulk` for **1025 rows**, crossed the 1024-row buffer and confirmed
seven native search indexes, including the logical shadow and date expression.
The supplied logs do not identify executable/RPO hashes. The headless browse
result does not activate the dialog or establish visual/backend acceptance.
The [2026-10-25 manifest](../../../../../docs/validation/native.presentation.windows.json)
is historical: its 64-source compile and 32/34/5 conversion/native-table/SDK
checks plus 77/67 dataset regressions precede the browse/FWBulk revision.

The subsequent isolated **2026-10-26** run compiled **66 sources** with zero
errors and passed **59 browse / 62 native-table / 32 conversion / 5 SDK**
checks plus **77 typed / 67 ordinary dataset** checks. The main native load
wrote and independently verified **10,000 rows** using FWBulk. Revised checks
verify each ID_CODE against ID, index order across 9/10, Code search/prefix
filter and selected-index retention on refill/failure/recovery. See the
[revision manifest](../../../../../docs/validation/native.presentation.revision.windows.json)
for attributed identities and exit codes. It does not activate the UI.

T05 real-query validation on **2026-10-26** compiled **69 sources** with zero
errors and passed **83 actual MSSQL TCP/gzip HTTP → AppServer dataset/native
storage checks** plus the six regression suites above. The fresh native host
passed **133 backend/transport checks** and stopped both listeners without
active leases. The integration SELECT executes in MSSQL over constant rows;
it checks actual transport, Unicode input encoding once, paging/criteria and
native storage, without reading ERP data. See the
[real SQL manifest](../../../../../docs/validation/native.presentation.sql.windows.json).
Later screenshots supplied on **2026-10-26** confirm real SX5 browse display
over TCP/HTTP and current-record View. This visual observation does not supply
compiled hashes or independently prove every filter/failure/cleanup path.
The [earlier SRA/metadata manifest](../../../../../docs/validation/sra.presentation.windows.json)
records a later attributed regression and conversion-only measurement, with
its own source identities. Its limitations explicitly exclude the subsequent
local-RDD/lazy-index changes. The [2026-10-29 review manifest](../../../../../docs/validation/presentation.review.windows.json)
records the current 78-source compilation and 654 isolated checks, including
local RDDs 100, source mapping 36, SRA/SX5 planning 66, TOPCONN/FWBulk 122 and
browse callbacks 74. Final MsMGet dictionary-variable identity compiled
separately; the SRA assertion layout at that revision passed its 66 checks again.
The [2026-10-30 selected-projection manifest](../../../../../docs/validation/selected.presentation.windows.json)
records 78 compiled sources and 730 checks across ten suites, including 142
SRA planning/selection/native SQLite assertions. The three malformed-alias
fixtures retain their actual keys and must be rejected. Source definitions
and selections remain unchanged, including absent optional properties.
Separate selected-SRA visual acceptance was confirmed on 2026-10-30; see the
[reported scope](../../../../../docs/acceptance.md#selected-sra-visual-acceptance-on-2026-10-30).
The report does not supply per-transport logs or compiled identities and does
not extend the automated backend/platform coverage.
