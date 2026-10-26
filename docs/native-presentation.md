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

`New(oDataSet, jLogicalSchema[, lVerifyStorage])` snapshots the schema and
reserves one alias for the adapter's lifetime. The first successful
`LoadCurrentPage()` creates its owned `FWTemporaryTable` and one native search
index per mapped field. Later loads reuse the **same physical table, workarea,
alias and indexes**, clearing rows through `FWTemporaryTable:Zap()` before
refilling the current dataset page. Navigation never deletes/reopens the alias
or replaces the browse's data source.

`LoadCurrentPage()` does not query or move the dataset cursor. It validates all
conversions and native field definitions before accepting a page. Only then
do `Alias()` and `IsOpen()` expose that accepted result. The reserved alias is
not exposed before the first successful load or while a page is invalid.
`RowCount()` is page-local.
`FieldName(projection)` maps to generated native names of at most ten characters;
SQL aliases are never truncated or evaluated. `ProjectionName(position)` and
`FieldCount()` retain projection order. `Schema()` returns a defensive copy.

Search has a separate mapping: `SearchFieldName(projection)` returns the native
index field and `IndexOrder(projection)` returns its active-order number.
Character, numeric and date projections use their value fields. A logical
projection retains an L value field but uses a private C(5) `True`/`False`
shadow for its index, because `FWTemporaryTable` does not create an index on L.
This helper is excluded from public projection counts and schema; use
`FieldName()` to read the actual logical value. Date index expressions use
`DTOS(field)`. Search order must use the explicit mapping, not physical field
positions, and survives page refill.

For a nonempty page, `FWBulk():CanBulk()` selects the write strategy once.
Supported DBAccess profiles use `FWBulk` with the temporary table's
`GetTableNameForTCFunctions()` target and the validated field structure. Rows
are submitted in that structure's order, then flushed and closed before
`TCRefresh`. A failure in `AddData`, `Flush` or `Close` invalidates the page;
the adapter explicitly clears a failed refill, or deletes a failed first
creation. It never explicitly retries a bulk buffer or falls back to record
inserts after a partial bulk operation. This is cleanup of an owned destination,
not a claim that server work was cancelled. Unsupported profiles, including
SQLite, retain the record-write path selected before insertion. Empty pages retain the schema
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

`Close()` finally deletes the native table and indexes but retains schema and
the reserved alias for a later explicit load. It is not a page-navigation API.
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
indexed table and refresh the existing widget. Every mapped search column has
a corresponding native index, retained between page loads.
First, Previous, Next, Last and Refresh reload the current native page inside
that dialog. Close only ends the dialog; it does not request another page.
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

Before the subsequent browse/FWBulk revision, validation on 2026-10-25 passed
64-source compilation with zero errors, 32
conversion checks, 34 actual native-table checks, five SDK assertions and
77/67 typed/ordinary dataset regressions. The
[sanitized manifest](validation/native.presentation.windows.json) identifies
sources, executable, RPOs and scope. Fixed-width character storage pads spaces;
the adapter checks the padded native value against its explicit field width.
Numeric formatter observations are separate from native-value equality and
do not establish exact decimal storage for every declared numeric field.

For visual acceptance, compile the
[interactive fixture](../src/tlpp/tests/protheus/hbbridge.presentation.test/README.md)
and run `U_HBBridgeNativeBrowse()`. It uses real native tables over mock typed
pages. Navigation belongs inside the open browse; closing it ends the example
without a next-page confirmation. Verify the revised UI separately from the
historical CLI checks, including Flag, Day and Float column placement.
