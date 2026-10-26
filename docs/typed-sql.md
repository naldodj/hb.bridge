# Typed SQL and native presentation: package 002 contract

[Português](typed-sql.pt-BR.md) · [WIP](../WIP.md) · [Current SQL](milestone3-sql.md)

**T01 specification closed on 2026-10-24**, against project base `98054b45`
and Harbour `6deac9cf3ad977ae829e5bca543d553b92dd4b6d` with managed patches.
T03 now implements the typed service and dataset under this bounded contract;
the [integration evidence](validation/typed.sql.windows.json) distinguishes
native backend/transport checks from AppServer mock checks. T04 implements
[native presentation](native-presentation.md), with AppServer conversion and
storage checks; combined backend/UI acceptance remains T05. Existing
`RPCRDD.Query`, result version 1 and dataset calls remain unchanged.

## Inventory and implementation boundary

The following inventory records the T01 baseline, before the T03 extension.

| Component | Observed implementation | Consequence |
| --- | --- | --- |
| [Query service](../src/hb/services/hbbridge.query.hb) | SQL text, optional page, SQLMIX workarea and separate count | No value bindings or physical-column metadata contract. |
| [SQL leases](../src/hb/services/hbbridge.sql.pool.hb) | Per-call connection under the shared SQL mutex; optional ODBC physical pooling | Preserve ownership/restoration; no persistent cursor or cache is implied. |
| SDDODBC | Direct execution; managed UTF-8/retrieval/timeouts/pooling patch | No existing `SQLBindParameter` path; prove the smallest native extension. |
| SDDSQLITE3 | Prepares/steps SQL without binding | Preparation alone proves neither binding nor NULL fidelity. |
| `hbodbc` | Prepare/execute wrappers; no bind wrapper in the pinned contrib | Not a ready replacement for the accepted SDDODBC path. |
| `hbsqlit3` | Native prepare/bind/step/column wrappers | Proof/reference candidate, not Query/SQLMIX integration. |
| [Dataset](../src/tlpp/hbbridge.rpc.dataset.tlpp) | Named rows, defensive metadata/row snapshots, totals and navigation | Reuse validation/navigation; typed methods do not exist yet. |
| [BrowseData](../src/tlpp/hbbridge.browse.data.tlpp) | Current-page FWBrowse arrays, navigation, filters and caller-side dictionary labels/masks | Reuse the UI; explicit-schema FWTemporaryTable support is additional work. |

Inspected pinned sources: [SDDODBC](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/contrib/sddodbc/core.c),
[SDDSQLITE3](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/contrib/sddsqlt3/core.c),
[ODBC wrappers](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/contrib/hbodbc/odbc.c)
and [SQLite wrappers](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/contrib/hbsqlit3/core.c).
The [manifest](../config/dependencies.json) and [ODBC patch](../config/patches/sddodbc.patch)
identify managed inputs. Building a contrib does not expose its APIs in hbBridge.

Current Query can ignore unknown parameters; adding `bindings` to that service
could execute SQL without binding. Legacy BrowseData decodes a serialized
row; the additional T04 path converts fields individually through shared
NUL-safe JSON helpers and uses explicit caller schema, not RDD display length. Current
SDDSQLITE3 can substitute defaults for mapped NULLs and use terminated text
retrieval. Expression-NULL checks do not prove nullable-column/NUL fidelity.
The new native typed readers address these binding/metadata/NULL gaps without
changing the existing Query/version-1 reader. T04 preserves the legacy Browse
API and adds explicit current-page native table ownership. `BrowseNative`
belongs to the local interactive example; a generic public native browse API
is deferred.

## Typed entry point and strict request

Use **`RPCRDD.QueryTyped`**, `requestVersion: 1`, **`resultVersion: 2`**.
An old server returns `SERVICE_NOT_FOUND`; never retry as unbound Query or
interpolate SQL literals. Both entry points must share execution, paging and
cleanup, extending the native boundary only where required.

```json
{
    "service": "RPCRDD.QueryTyped",
    "params": {
        "requestVersion": 1,
        "alias": "MSSQL/pData",
        "sql": "SELECT ID, NAME FROM explicit_table WHERE ID > ? AND NAME = ?",
        "bindings": {
            "1": { "type": "integer", "isNull": false, "value": 10 },
            "2": { "type": "text", "isNull": false, "value": "Harbour" }
        },
        "page": { "number": 1, "size": 10, "orderBy": "ID ASC" }
    }
}
```

This entry is registered when SQL profiles are configured. Required `params` members are
`requestVersion`, `alias`, `sql`, `bindings`; only `page` is optional. Reject
unknown members at each new contract level, wrong versions, empty profile/SQL,
invalid JSON types and malformed descriptors before execution. `page` requires
exactly `number`, `size`, `orderBy`, preserving current checked integer bounds,
identifier/order validation and deterministic caller ordering. Existing
transport envelope/authentication rules remain unchanged.

`bindings` is an object with canonical contiguous ordinal keys `"1"` through
`"N"`; `{}` means zero parameters. Bind by ordinal, not hash enumeration. Only
anonymous positional `?` markers are allowed, one descriptor per occurrence.
Named/numbered markers, output parameters, batches and stored procedures are
outside version 1. Validate native prepared parameter count and, where exposed,
native names: SQLite marker names must be null. Do not count characters or
rewrite literals/comments. If the connector cannot establish the allowed marker
contract, fail unsupported. Bindings supply values, never identifiers,
expressions or sort directions. Protheus resolves tenant/company/branch,
physical names and predicates; aliases remain opaque. Binding does not grant
table permissions or implement a general SQL parser.

For pagination, snapshot descriptors once and bind the same base values
independently to page and count statements on the same lease. Validate native
parameter counts for both. Generated row bounds remain checked integer
literals, introducing no markers or ordinal shifts. This is one **input
snapshot**, not transaction isolation: separate statements and later pages can
observe concurrent changes. No cross-call database snapshot is promised.

## Binding values, NULL and ranges

Every descriptor requires `type` and boolean `isNull`. Non-null values require
`value`; null descriptors forbid it. Only `decimal` additionally requires
`precision` and `scale`, including for typed NULL. Reject contradictory,
missing and unknown members. NULL, empty string, zero and false are distinct.

SQL NULL is a valid result, not a reason to reject a query. Preserve it through
the service, transport and dataset; Protheus owns any business substitution.
Dictionary membership or a nonnullable source column does not change this:
outer joins and expressions may still yield NULL. Adapter conversion errors
below concern an unrepresentable native destination, not rejection of NULL
by the query service or dataset.

| Type | Required non-null wire value | Native requirement |
| --- | --- | --- |
| `text` | UTF-8 JSON string, including empty/NUL | Explicit byte lengths; prove Unicode binding/retrieval. |
| `integer` | Integral JSON number in `[-9007199254740991, 9007199254740991]` | Integer binding and checked narrowing. Protheus must also retain its supplied integer exactly. |
| `int64` | Canonical signed decimal string in `[-9223372036854775808, 9223372036854775807]` | Checked native int64 parsing/binding without intermediate double. |
| `number` | Finite JSON number, approximate semantics | Native floating binding; reject NaN/infinity and overflow. |
| `decimal` | Plain exact decimal string plus integer `precision >= 1`, `0 <= scale <= precision` | Driver-supported exact binding without double. SQLite fixed decimal is unsupported without a separately proved exact mapping. |
| `boolean` | JSON true/false | Prove native BIT on MSSQL or explicit integer 0/1 input on SQLite; no truthiness coercion. |
| `date` | Valid calendar `YYYY-MM-DD` without timezone | Prove native SQL DATE on MSSQL or explicit ISO text input on SQLite. The latter does not create a native SQLite DATE result type. |

Integer strings follow `-?(0|[1-9][0-9]*)`, without negative zero. Decimal input
follows `-?(0|[1-9][0-9]*)([.][0-9]+)?`, without whitespace, plus sign or
exponent. Fraction digits fit `scale`; integer digits fit `precision - scale`,
excluding the leading zero of a fractional value. Reject negative zero and
rounding. Check connector bounds independently. This is the contract vocabulary;
the [connector guide](typed-sql-connectors.md) records implemented mappings and
their limits. No arbitrary MVP payload cap is restored.

## Version 2 result and stable column mapping

Choose one representation per column from prepared/native descriptors before
reading rows. Keep it across all rows/pages; never infer it from the first
non-null value. Keep keyed `header`/`rows`, uppercase unique projection names,
contiguous positions `1..FieldCount` and existing page/totals meanings. Every
row contains every header key; missing is malformed, while JSON null denotes
SQL NULL exclusively. Empty/all-NULL results retain complete metadata and the
same mapping. Duplicate normalized names are rejected.

All groups/members shown below are required. `position` is a positive integer;
`rdd.type` is string/null, its sizes nonnegative integers/null. Source
`typeCode` is native integer/null; type/origin names are strings/null;
precision/scale/lengths are nonnegative integers/null; `precisionRadix` is a
positive integer/null and `nullable` is boolean/null. Preserve native units:
MSSQL FLOAT may report precision 53 with radix 2; DECIMAL precision uses radix
10. Unknown metadata is **null**, never invented zero, empty string or false.
An inapplicable/unknown native radix of zero becomes null in version 2;
the raw native proof may still record zero as an observation.
`wire.kind`/`jsonType` follow the table below; encoding is `UTF-8` for strings,
null otherwise. RDD observations never replace source definitions.

Example service result, with textual exact DECIMAL and unknown expression
origin metadata:

```json
{
    "success": true,
    "resultVersion": 2,
    "driver": "mssql",
    "header": {
        "AMOUNT": {
            "position": 1,
            "rdd": { "type": null, "length": null, "decimals": null },
            "source": {
                "typeCode": 3,
                "typeName": "decimal",
                "precision": 12,
                "precisionRadix": 10,
                "scale": 2,
                "characterLength": null,
                "octetLength": null,
                "nullable": true,
                "catalog": null,
                "schema": null,
                "table": null,
                "column": null,
                "collation": null
            },
            "wire": { "kind": "decimal", "jsonType": "string", "encoding": "UTF-8" }
        }
    },
    "rows": { "1": { "AMOUNT": "123.45" }, "2": { "AMOUNT": null } },
    "rowCount": 2,
    "totalRows": 2,
    "totalPages": 1,
    "page": { "number": 1, "size": 10, "hasNext": false, "firstRow": 1, "lastRow": 2 }
}
```

Version 2 requires exact nonnegative safe JSON integer `totalRows`/`totalPages`;
unpaged totals equal rowCount and 0/1 pages. `page` appears only for paginated
requests. Row keys restart at `"1"` each page; empty firstRow/lastRow are zero.
Hide internal pagination ordinals. No partial success if count/mapping/fetch fails.

| Native source class | `wire.kind` / `jsonType` | Fixed rule |
| --- | --- | --- |
| Character/text with proved encoding | `text` / `string` | UTF-8, explicit lengths; preserve empty and NUL. |
| Exact integer whose entire declared range fits safe JSON integers | `integer` / `number` | Integral finite number without lossy narrowing. |
| Signed 64-bit integer, including SQLite declared integer-affinity columns | `int64` / `string` | All non-null rows use canonical integer strings, including small values. |
| Exact DECIMAL/NUMERIC | `decimal` / `string` | Exact plain strings with exactly source scale digits; no exponent/negative zero. Require known precision/scale and lossless native retrieval. |
| Native FLOAT/REAL/DOUBLE | `number` / `number` | Finite approximate value through the shared precision-preserving codec; no business scale inference. |
| Native BIT/boolean | `boolean` / `boolean` | Only verified boolean source types; no numeric truthiness conversion. |
| Native DATE | `date` / `string` | ISO `YYYY-MM-DD`; version 1 `YYYYMMDD` is unchanged. |
| TIME, TIMESTAMP, timezone types, binary/BLOB | unsupported | No implicit formatting, time stripping or binary-to-text conversion. |

Unsigned types outside these signed/range guarantees are unsupported. Detect
NULL through native indicators/storage types **before** RDD default
substitution. A Nil getter for EOF/missing field does not prove SQL NULL.
Preserve descriptors/NULL information alongside the shared query path; do not
force exact strings through approximate RDD numeric fields. Source FLOAT cannot
recover missing digits; caller CAST does not restore precision absent in storage.
Never derive decimal precision from display length or FLOAT column size.
Native decimal text can omit the integer zero (`.00000000`); canonical wire
text must insert it (`0.00000000`) without numeric parsing or rounding. The
2026-10-24 connector proof motivated explicit precision radix and lexical
zero normalization; both are implemented in the typed reader.

SQLite declared text/integer/real affinity is only a mapping candidate. Check
every non-null storage class/range against the fixed mapping; reject mixed
incompatible classes rather than switching wire types. Integer storage in a
REAL mapping converts only if exactly representable. Declared BOOL/DATE/DECIMAL
is not proof of native boolean/date/fixed-decimal semantics and is unsupported
in this bounded result contract. Undeclared expressions, unknown declarations
and unavailable/ambiguous metadata fail explicitly, including empty/all-NULL
results. SQLite CAST does not automatically supply a declared output type or
cure this limitation. Never sample values or substitute version 1 semantics.

## Typed failures and capability evidence

The typed path uses these categories in the existing safe service error
envelope. They do not change old Query errors:

| Code | Meaning |
| --- | --- |
| `INVALID_TYPED_REQUEST` | Unknown/missing members or malformed shape. |
| `UNSUPPORTED_REQUEST_VERSION` | Unsupported requestVersion. |
| `INVALID_BINDINGS` | Noncontiguous ordinals, missing/extra parameters or disallowed native marker names. |
| `BINDING_RANGE_ERROR` | Invalid calendar, noncanonical/inexact value, overflow or precision/scale violation. |
| `UNSUPPORTED_BINDING_TYPE` | Native input mapping is unavailable. |
| `UNSUPPORTED_RESULT_TYPE` | Unknown, mixed or unsupported result mapping. |
| `RESULT_RANGE_ERROR` | Native value cannot fit its fixed wire mapping without loss. |
| `RESULT_NULL_UNAVAILABLE` | Native NULL fidelity cannot be established. |
| `STATEMENT_PREPARE_FAILED` / `STATEMENT_BIND_FAILED` / `STATEMENT_EXECUTE_FAILED` / `STATEMENT_FETCH_FAILED` | Native operation failed; clean up before returning. |

Authentication, profile, connection and common service errors retain current
categories. Diagnostics may identify stage, profile key, driver, ordinal/column
position and sanitized native code; never echo SQL, connection strings,
credentials or bound values. Do not expose raw driver text containing them.
Clear partial results and permit recovery by a later valid call.

T02 records `supportedCapabilities` as **test evidence scoped to connector,
driver/version, platform and type/operation**, not current service advertising.
The mapping table is allowed vocabulary, not universal support. Discovery may
advertise QueryTyped/version only after T03 integration and cannot imply
unproved profile-specific capabilities.

## Dataset and caller-owned logical presentation

Use `OpenSQLTyped(sql, bindings[, page])` and
`OpenPageTyped(sql, bindings, number, size, orderBy)` on the existing dataset,
retaining `New(oClient)` and `SetAliasProfile(profile)` to select the profile;
no profile positional argument is added. Existing signatures are preserved.
The **version 2 validator** retains version 1 validation for old results.
Validate fixed wire types, contiguous metadata/rows, nulls, totals and version
before publishing state. Preserve defensive header/row/binding snapshots for
Next/PreviousPage; clear on close/reopen/failure. No old OpenSQL fallback or
reinterpretation of exact numeric strings.
`Header()`/`FieldInfo()` return defensive nested version 2 snapshots for typed
results. `FieldGet()` preserves wire values, including textual int64, decimal
and date, without business conversion. With a current row and a valid
`FieldExist()` guard, Nil means SQL NULL; EOF/missing field still requires its
own guard. No new public IsNull method is needed for this contract.

`logicalSchema` belongs to Protheus/presentation, not the QueryTyped request.
Keys match projection keys; no automatic SX3, TOP_FIELD, table/branch or
business-scale inference. Reserved adapter input:

```json
{
    "schemaVersion": 1,
    "fields": {
        "AMOUNT": {
            "type": "numeric",
            "length": 12,
            "decimals": 2,
            "nullable": true,
            "caption": "Amount",
            "picture": "@E 999999999.99",
            "inputFormat": null,
            "nullPolicy": "reject",
            "roundingPolicy": "reject"
        }
    }
}
```

Validate schemaVersion, projection membership, required field definitions and
unknown members. Types are `character`, `numeric`, `logical`, `date`; `length`
is a positive integer and `decimals` nonnegative, zero for nonnumeric types.
Check SDK type-specific bounds before allocation. `nullable` records caller
intent, without authorizing source NULL replacement. `caption`/`picture` are
strings; pictures affect display, not stored precision. Version 1 requires
`nullPolicy: "reject"` and `roundingPolicy: "reject"`. Defaults, separate null
indicators and rounding modes require a later explicit adapter contract.
Preserve NULL in the dataset even when a native table cannot represent it;
reject unrepresentable NULL, encoding, exact numeric/range and date conversion.
All shown field members are required. `inputFormat` is null for non-date
targets; date targets require `"YYYY-MM-DD"` for native DATE wire strings or
explicit `"YYYYMMDD"` for caller-declared textual dates, such as Protheus
VARCHAR(8). Validate the calendar and source wire type; never infer these
formats from table/field names. Use an explicit caller CAST when source
rounding is intended; the adapter does not round automatically.

The explicit-schema native adapter decodes string fields **once**
at the Protheus UI/native-table boundary, preserving UTF-8 snapshots/NUL-safe
parsing. Do not decode serialized JSON or apply OemToAnsi to UTF-8. Validate
native string capacity/NUL support and reject truncation/replacement. Exact
numeric strings convert only under caller schema and proved SDK precision/
range, without implicit rounding.

The native table adapter owns its FWTemporaryTable and the local browse example
owns its UI resources. The adapter reserves its alias once and creates the
physical table and per-field indexes on first load. Paging clears/refills the
same storage; it never changes the bound browse's alias or workarea. Accept a
page only after validation/population succeed. Failure invalidates/clears the
page; final Close/Destroy deletes the owned storage. Full storage readback is
an optional constructor diagnostic (`lVerifyStorage`, default false), not an
unconditional second production scan. Restore the previous selected area and
never close caller-owned clients/datasets/workareas. Arrays remain at required
SDK boundaries; metadata and keyed records stay hashes/JSONObject. See the
[native presentation lifecycle](native-presentation.md).

## T02 proof and implementation gates

T01 has no remaining contract decision. Native support is an empirical T02
gate: reproducible probes use managed dependencies, no private credentials or
replacement of installed executables. Record prepare/bind/execute/fetch/close,
source/patch/driver identity and scoped capabilities.

- Cover allowed types, typed NULL, declared nullable columns, empty/all-NULL,
  UTF-8 accents/supplementary characters, NUL, exact integer/decimal bounds and
  explicit unsupported results. Constant expressions do not prove columns.
- Check native marker counts/names, repeated anonymous markers, quotes/comments,
  invalid descriptors/ranges, errors and subsequent valid statements.
- Keep buffers/statements alive through fetch; release every owned resource
  and restore connection/workarea state under the SQL mutex.
- Prove independent page/count binding from one descriptor snapshot, stable
  metadata across pages/empty pages, totals and no partial output.
- T03 integrates only proved mappings into the common Query/service/TLPP path;
  T04 adds presentation; T05 accepts real TCP/HTTP, native UI, failures and
  cleanup while preserving old Query behavior.

If minimum native semantics cannot be proved, report unsupported and record
the gap. Never weaken the contract or announce SQLMIX binding from a standalone
wrapper test. MEMIO reuse is
[separate future work](evolution.md#in-memory-results-between-requests).
