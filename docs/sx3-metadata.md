# Protheus dictionary metadata and the SRA example

[Português](sx3-metadata.pt-BR.md) · [Native presentation](native-presentation.md) · [WIP](../WIP.md)

Dictionary interpretation belongs to Protheus. The hbBridge server receives
explicit SQL, bindings and result definitions; it does not resolve SX3,
company, branch or application rules.

## Reusable metadata snapshot

`HBBridge.Protheus.HBBridgeSX3Metadata():Read("SRA")` returns a fresh
`JSONObject` with dictionary metadata. The implementation uses
`FWSX3Util():GetListFieldsStruct(cAlias,.T.,.F.)` to include dictionary fields
without the browse-only restriction, including virtual and memo definitions.
Descriptions, titles and additional attributes come from Protheus dictionary
APIs. See the official [FWSX3Util documentation](https://tdn.totvs.com/display/public/framework/FWSX3Util).

The snapshot contains `schemaVersion`, `alias`, `count` and a `fields` object
keyed by dictionary field name. Each field records `position`, `name`, `type`,
`length`, `decimals`, `picture`, `caption`, `description`, `context`, `virtual`
and `dictionaryOrder`. Position makes ordering explicit; JSON object key order
is not a presentation contract. Reading the metadata does not evaluate field
initializers, validations, triggers or picture expressions. It adds no shared
cache, database login or automatic table selection to hbBridge.

```advpl
jMetadata := HBBridge.Protheus.HBBridgeSX3Metadata():Read("SRA")
if jMetadata["fields"]:HasProperty("RA_SALARIO")
    nLength := jMetadata["fields"]["RA_SALARIO"]["length"]
    nDecimals := jMetadata["fields"]["RA_SALARIO"]["decimals"]
endif
```

This API returns metadata, not employee values or evaluated business rules.
A fresh read reflects the dictionary visible to the active Protheus context;
the caller owns the returned object. An invalid alias, unprepared context or
unusable dictionary result returns `nil`. The helper preserves the selected
workarea and an already-open SX3 cursor; it opens no connection or dictionary
workarea itself.

## Shared presentation definition

`HBBridge.Client.HBBridgePresentationTable():Definition(cAlias)` gathers the
dictionary snapshot and MSSQL physical catalog in the prepared Protheus
context. Its pure `Build(jMetadata,jColumns,cAlias,cTable)` method builds the
same projection/schema from explicit snapshots, without database or dictionary
access. SRA and SX5 use this shared implementation; they do not maintain
separate copies of field conversion rules.

The successful result includes `alias`, `table`, `projection`, `schema`,
`metadata`, `fieldStatus` and included/excluded counts. Fields retain their
original dictionary names; `schema.projectionFields` explicitly maps each
projection to its source. Supported system fields can form the first projected
columns even when dictionary fields are all excluded. An empty usable
projection is a failed definition. `Build()` leaves `sql` and `orderBy` empty:
the table-specific wrapper supplies predicates and deterministic ordering.

`HBBridgePresentationSRA():Plan(jMetadata,jColumns,cTable,cBranch)` and the
equivalent `HBBridgePresentationSX5():Plan(...)` complete those explicit
snapshots through the same code path used by each wrapper's `Definition()`.
They validate every required filter/order field before returning executable
SQL: SRA requires `RA_FILIAL`, `RA_MAT`, `D_E_L_E_T_` and `R_E_C_N_O_`; SX5
requires `X5_FILIAL`, `X5_TABELA`, `X5_CHAVE`, `D_E_L_E_T_` and `R_E_C_N_O_`.
The branch/business keys must be character fields, the deleted marker must
have one character and the record number must be numeric with zero decimals.
An explicit branch must fit its field and contain no NUL. Failure returns
`success: false` with `INVALID_SRA_DEFINITION` or `INVALID_SX5_DEFINITION`;
SQL/order remain empty. Inspect `success` before using a definition. These
planning methods execute no query and do not discover company/branch context.

## Selected fields and JOIN queries

`RPCRDD.QueryTyped` accepts caller-supplied SELECT SQL, including explicit
column lists and JOINs supported by the configured backend and the service's
single-statement contract. It does not require selecting a complete table.
The SRA/SX5 dictionary builders above currently enumerate every supported
physical field of one table; they do not expose a caller-selected projection
or a multi-table definition builder. Dedicated native-presentation examples
and acceptance for those cases remain planned.

For a restricted or joined result, Protheus must supply one logical-schema
entry per output alias, with unique output names and explicit positions. Read
each field's SX3 metadata from its actual dictionary origin and declare
`projectionFields`, for example `AMOUNT` to `RA_SALARIO`. Computed expressions
need an explicit caller definition; do not invent a single SX3 origin for
them. The current source map carries field names, not qualified table lineage.
Repeated origins make inverse source lookup ambiguous; use projected-key
access in that case. View helpers that use original dictionary names in
`aFields`/`M->` also need explicit handling before presenting the same origin
more than once.

JOIN pagination must use an order that uniquely identifies each result row,
including the joined-side key when a relation multiplies rows. An employee
record number alone is insufficient for a one-to-many result. LEFT JOIN NULLs
remain NULL in the typed dataset; the current native destination rejects them.
Protheus may explicitly define an appropriate SQL replacement when the
application requires native presentation, preserving that business decision
in the caller. Table/branch resolution, JOIN predicates, deleted-row policy,
bindings and dictionary-based CASTs also remain Protheus responsibilities.
No automatic SQL parser or server-side dictionary inference is added.

## SRA native browse

Run inside an already prepared Protheus company/branch context, with a matching
hbBridge SQL profile and existing client endpoint/authentication settings:

```advpl
U_HBBridgeNativeBrowseSRA("MSSQL/pData","TCP",100)
U_HBBridgeNativeBrowseSRA("MSSQL/pData","HTTP",100)
```

Defaults are TCP and 100 rows per page. An omitted SQL profile uses
`[hbBridge] SQLProfile` in the active AppServer INI, without a demo fallback.
HTTP requires gzip. The example reuses the same local native browse as SX5,
with explicit paging, search, typed filters and View; no generic public browse
API is introduced.

`HBBridge.Examples.HBBridgePresentationSRA():Definition()` uses the shared
definition builder to combine the metadata snapshot with the physical catalog from
`HBBridge.SQL.Tools.HBBridgeSqlTools():GetColumnMetadata(cTable)`.
The catalog helper currently supports MSSQL and inspects the table through
the active Protheus DBAccess connection. This is distinct from the hbBridge
SQL profile: both must refer to the intended database. Protheus resolves
`RetSQLName("SRA")` and `xFilial("SRA")`. Undeleted/current-branch restrictions
remain bound base predicates when search or filters change.

The definition returns `success`, `code`, `message`, `alias`, `table`,
`projection`, `metadata`, `fieldStatus`, `includedCount`, `excludedCount`,
`sql`, `orderBy`, `schema` and `bindings`.
`fieldStatus[field]` records `included` or `excluded` and its reason. The
dictionary snapshot retains every enumerated field, even when its value
cannot be selected into this native destination. Physical system fields
`D_E_L_E_T_`, `R_E_C_N_O_` and `R_E_C_D_E_L_` are included when available;
physical columns outside SX3 and these system fields are reported separately.

The native value profile accepts dictionary C fields up to 254 bytes, N fields
up to 32 positions/16 decimals, D of length 8 and L of length 1. It also checks
physical existence/type compatibility. Virtual, memo, binary, long-text,
missing and unsupported definitions receive explicit exclusion reasons.
The browse identifies included/excluded counts. It does not silently truncate
text or substitute an empty value for an unsupported field. Therefore
"all fields" means a complete metadata inventory and all supported physical
values, not a new LOB transfer capability.

The SRA dialog's **Field catalog** action opens a read-only metadata browse
with Field, Type, Length, Decimals, Caption, Status and Reason columns. It
includes dictionary entries and the reported system/unknown physical entries,
so exclusions remain inspectable without querying employee values again.
This is a view of the metadata snapshot, not a raw SX3 table browser or a
business-rule editor. Native arrays are limited to the `FWBrowse` array data
source; the reusable metadata and status contracts remain keyed JSON objects.

`GetNonBlobColumns()` alone is insufficient for this destination: it excludes
binary columns but retains long text. The SRA example uses physical catalog
metadata together with SX3 to decide each field explicitly. Memo/binary values
need a separately designed LOB reader/transport and remain future work.

Numeric fields use explicit caller-side SQL `CAST` with SX3 width/scale in this
example. No general SQL parser, server-side SX3 lookup, global SET change or
automatic business rounding is introduced. Dates explicitly use the Protheus
YYYYMMDD representation, including eight spaces for an empty date. NULL
remains distinct in the typed result/dataset; the native adapter still rejects
it under its explicit presentation policy.

## Validation scope

Run `U_HBBridgeSX3Browse("SRA")` (default alias: SRA) to inspect the dictionary
fields for a table without opening its SQL data browse. This uses the same
read-only metadata grid as **Field catalog**, including virtual and memo
definitions. It reads the SX3 snapshot through framework APIs; it is not an
employee-data query or a dictionary-rule editor.

Manual SRA operation was confirmed on 2026-10-27. The
[recorded isolated regression](validation/sra.presentation.windows.json)
separately covers its earlier source identities and a conversion-only
measurement; it excludes later local-RDD/lazy-index changes. Neither that
measurement nor the manual observation measures end-to-end browse speed for
the current revision.

Screenshots supplied on 2026-10-26 confirm the real SX5 browse displayed over
TCP and HTTP and its current-record View displayed successfully. They do not
identify executable/RPO hashes or independently prove every filter, failure
or cleanup scenario. The existing automated real-SQL manifest retains its own
constant-row scope and identities.

Revised metadata/planning/storage behavior requires regression results and
interactive acceptance with the local dictionary/data. Verify
field counts/exclusion reasons, titles, dates/empty dates, logical values,
numeric widths/scales, accents, paging/search/filter and View over both
transports. A successful SX5 presentation does not by itself accept the wider
SRA field profile.
