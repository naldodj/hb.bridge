# Typed SQL and native presentation: package 002 draft

[Português](typed-sql.pt-BR.md) · [WIP](../WIP.md) · [Current SQL](milestone3-sql.md)

T01 design recorded on 2026-10-23 against project base `cbe4ccf` and Harbour
`6deac9cf3ad977ae829e5bca543d553b92dd4b6d`, with the managed ODBC patch.
This draft is parked pending review; **T01 remains unfinished**. The
user-prioritized hbBridge HTTP performance work takes precedence. Proposed
service names and shapes below are review inputs, not an available API or
connector acceptance. T02 must prove native bindings before T03 exposes them.
Existing `RPCRDD.Query`, result version 1 and dataset calls keep working.

## Inventory and implementation boundary

| Component | Observed implementation | Consequence |
| --- | --- | --- |
| [Query service](../src/hb/services/hbbridge.query.hb) | `alias`, SQL text, optional page; SQLMIX workarea; RDD field type/length/decimals; page and separate count | No value bindings or physical-column metadata contract. |
| [SQL leases](../src/hb/services/hbbridge.sql.pool.hb) | Per-call native connection under the shared SQL mutex; optional ODBC physical pooling | Keep ownership/restoration; prepared statements do not create persistent cursors or result caches. |
| SDDODBC | Direct statement execution; managed patch covers UTF-8, retrieval, timeouts and pooling | No current `SQLBindParameter` path. Add/prove a bounded connector extension. |
| SDDSQLITE3 | Prepares/steps SQL internally, without parameter binding | Preparing SQL alone does not establish bind support. |
| `hbodbc` | Exposes prepare/execute; no bind wrapper found in the pinned contrib | It is not a ready replacement for the accepted SDDODBC path. |
| `hbsqlit3` | Exposes native prepare/bind/step/column APIs | Useful proof/reference; not integrated into the product's SQLMIX query path. |
| [Dataset](../src/tlpp/hbbridge.rpc.dataset.tlpp) | Named rows, defensive header/row snapshots, totals and page navigation | Reuse validation/navigation; no typed-parameter method exists yet. |
| [BrowseData](../src/tlpp/hbbridge.browse.data.tlpp) | Current-page FWBrowse arrays, navigation, filters, Protheus-side dictionary labels/masks and cleanup | Reuse this presentation. An explicit-schema FWTemporaryTable adapter is additional work. |

Sources: pinned [SDDODBC](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/contrib/sddodbc/core.c),
[SDDSQLITE3](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/contrib/sddsqlt3/core.c),
[ODBC wrappers](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/contrib/hbodbc/odbc.c)
and [SQLite wrappers](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/contrib/hbsqlit3/core.c).
The [dependency manifest](../config/dependencies.json) and
[patch](../config/patches/sddodbc.patch) identify the inspected inputs.
Building a contrib does not mean that the executable links or exposes it.

Two gaps affect compatibility. Current Query validates required values but
does not reject every unknown top-level parameter key; an added `bindings`
key could be ignored by an old server. BrowseData currently decodes a whole
serialized row with `DecodeUTF8(...:ToJSON())`/`FromJSON()`. T04 must replace
that boundary with field conversion using the shared NUL-safe JSON helpers,
preserving the accepted dataset snapshot. Neither gap is silently considered
fixed by this document. The filter-schema fallback also assigns RDD length
as decimals when SX3 is absent; T04 must resolve decimals from the explicit
logical schema. Current SDDSQLITE3 does not prove general declared-column NULL
fidelity or embedded-NUL text retrieval: mapped fields can substitute defaults
and its text conversion is terminator-based. The expression-NULL regression
does not establish those broader capabilities.

## Explicit, compatible entry point

Reserve **`RPCRDD.QueryTyped`**, `requestVersion: 1` and `resultVersion: 2`
for the new contract. These are design names, not registered services today.
A separate service makes an older server return `SERVICE_NOT_FOUND` instead
of executing SQL after ignoring binding options. Discovery advertises the
service/version only after integration; it must not promise driver types
that were not proved for the selected profile. No fallback to literal SQL.

Both entry points must share the existing execution, paging and cleanup core.
Avoid a second query engine. Extend the SDD/native boundary only as required
to pass typed buffers and preserve source/null information; T02 determines
the viable extension from actual native tests. Its current area/open interface
carries SQL text without a per-call bind descriptor. Keep existing
unparameterized `RPCRDD.Query` calls on the accepted path; a proposed typed
call with `bindings: {}` still requires version 2 guarantees. Strictly validate
the new envelope and version before any database call. Audit old Query's ignored-key behavior separately in T03.

Proposed request, **not executable against the current service**:

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

`bindings` is an object keyed by contiguous ordinal strings `"1"` through
`"N"`; `{}` means no bindings. Bind in ordinal order, independent of hash
enumeration. Use anonymous positional `?` markers, with one descriptor per
occurrence. Named/numbered SQLite markers, output parameters, batches and
stored-procedure contracts are outside this first version. Obtain marker
counts/identities from the native prepared statement. Typed descriptors come
from the caller, supplemented by native parameter metadata when available;
SQLite does not provide declared parameter types. Do not count question marks
in SQL strings or replace text inside literals/comments.

Bindings supply **values**, never table/column names, expressions or sort
directions. The caller resolves and validates identifiers/business predicates.
Keep existing page/order validation. Bind the same base values independently
to the page statement and its count statement on the same lease. Any future
generated page markers have a separate internal mapping; they cannot displace
caller ordinals. A parameterized query remains subject to database permissions;
binding is not table authorization or a general SQL parser.

Proposed TLPP additions are `OpenSQLTyped(sql, bindings[, page])` and
`OpenPageTyped(sql, bindings, number, size, orderBy)`. Keep existing signatures
unchanged. Retain a defensive binding snapshot for Next/PreviousPage, clear
it on close/reopen, and never retain caller-owned mutable JSON. Unsupported
service/version/type fails without retrying through unbound `OpenSQL`.

## Value types, NULL and range rules

Every descriptor requires `type` and boolean `isNull`. A null descriptor has
`isNull: true` and no `value`; a non-null descriptor has `isNull: false` and a
value of the required wire type. Reject missing, contradictory and unknown
members. NULL, `""`, zero and false are different values. A typed NULL still
needs its SQL type/required precision information at the native boundary.

| Proposed type | Wire value and validation | Native proof required |
| --- | --- | --- |
| `text` | UTF-8 string with explicit byte length; preserve empty and embedded NUL | Unicode binding/retrieval on MSSQL; length-aware SQLite text. Never use terminator-only input lengths. |
| `integer` | Integral JSON number in `[-(2^53-1), 2^53-1]`; consumer must retain the supplied integer exactly | Bind with an integer representation, with checked narrowing where applicable. Protheus producers must additionally respect their numeric precision. |
| `int64` | Canonical signed decimal string within the signed 64-bit range | Checked native int64 parsing/binding; no intermediate double. |
| `number` | Finite JSON number; approximate semantics | Native floating binding; no formatting through global SETs. Reject NaN/infinity. |
| `decimal` | Plain decimal string plus integral `precision`/`scale`, with `precision >= 1` and `0 <= scale <= precision`; exact representability, no implicit rounding | Exact decimal binding and declared driver bounds. SQLite has no native fixed-decimal storage guarantee; fail unsupported unless an explicit exact mapping is proved. |
| `boolean` | JSON true/false | Declared BIT mapping on MSSQL, 0/1 mapping on SQLite; no truthiness conversion. |
| `date` | Valid calendar string `YYYY-MM-DD`, without timezone | Native SQL date on MSSQL; explicit ISO text convention on SQLite. Empty text is not a date or NULL. |

Integer strings use `-?(0|[1-9][0-9]*)`; integer zero has no minus sign.
Decimal strings use `-?(0|[1-9][0-9]*)([.][0-9]+)?`, without whitespace,
a plus sign or exponent; negative fractions such as `-0.5` are valid. Fractional digits
must fit `scale`; integer digits must fit `precision - scale`, excluding the
zero before a fractional value. Validate driver limits without rounding.

Do not advertise this whole table as implemented support. T02 records each
driver/type result, including typed NULL, unsupported outcomes and recovery.
Timestamp/timezone, binary/LOB binding and array parameters remain deferred.
Driver limits and installation memory policy still apply; add no old MVP
payload cap. Exact decimal strings must not become doubles just to reuse an
RDD field. Caller SQL CAST remains available; it cannot recover missing digits
from approximate source values.

## Result metadata and representation

Keep version 1 untouched. Version 2 retains keyed `header`/`rows`, explicit
positions, rowCount and existing page/totals meanings, and separates metadata:

| Group | Contract |
| --- | --- |
| `rdd` | Observed Harbour `type`, `length`, `decimals` when an RDD field is used; never rebrand these as SQL or SX3 definitions. |
| `source` | Native SQL type/type name, precision, scale, character/octet lengths and nullable flag, when available. Unknown properties are explicit null, not invented zero/false. Origin table/column/collation stay unknown for expressions or unreported descriptors. |
| `wire` | Representation (`text`, `number`, `integer`, `int64`, `decimal`, `boolean`, `date`) and UTF-8 for text. Exact int64/decimal use strings when native retrieval preserves those digits. |
| Caller `logicalSchema` | Projection-keyed type, length, precision, scale, nullable policy, caption and picture resolved on Protheus; supplied to presentation, not inferred by the server. |

The exact result JSON member names/types still need T01 review. Required
decisions include a representation stable across rows/pages (full exact int64
columns stay textual even for small values), the version 2 date format,
handling of native time/timestamp results, and an unknown/unsupported policy
for SQLite empty, all-NULL or mixed-type expressions. Current version 1 dates
serialize as `YYYYMMDD`; the ISO date input above does not change that output.
A concrete result-envelope example remains a prerequisite for closing T01.

Determine SQL NULL from native indicators/types **before** any RDD default
substitution. `rows[ordinal][column] = null` means SQL NULL; every projected
column must exist in every row. A missing key is malformed data, not NULL.
An EOF/missing-field getter returning Nil alone cannot express the distinction;
use field existence, current-row state and the versioned null representation.
In version 1, preserve observed connector behavior without claiming universal
nullable-column fidelity. Version 2 cannot claim null preservation until that
native path is proved.

Source SQL FLOAT remains approximate and has no business decimal scale.
Display length is not SQL precision. Never use SX3 automatically, convert a
large physical length through a 16-bit RDD field, or infer scale from current
values. Do not silently truncate long text, narrow numeric values or replace
NULL. Reject unsupported mappings. Keep current binary JSON rejection until
an independently accepted binary representation exists.

## Presentation ownership and conversion

Reuse the current BrowseData page UI and dataset; add an explicit-schema path
instead of duplicating browsing. An optional FWTemporaryTable/FWMBrowse
adapter owns its created object, alias, rows and UI resources. Caller-supplied
clients/datasets remain caller-owned. Build into private resources; publish
only after schema validation and successful population. Close/delete all owned
resources on failure, normal close and UI dismissal; never close a saved caller
area. Restore the previous selected area.

JSON text stays UTF-8 in both directions. Decode string field values once at
the Protheus display/native-table boundary, leaving the dataset snapshot intact.
Do not decode an entire serialized JSON document or apply `OemToAnsi()` to
UTF-8. Retain NUL-safe parsing/snapshots. Dates, logicals and exact numeric
strings convert only according to the explicit schema and tested native range.

A native table may not represent SQL NULL for a chosen field. Default to an
explicit unsupported-mapping error; a caller may explicitly choose a default
plus a separate null indicator. Never substitute silently. Rounding requires
an explicit caller policy; otherwise reject an inexact conversion. Pictures
control presentation, not stored value precision. Arrays are allowed only at
the SDK field-definition/browse boundaries that require them.

## T02 proof and subsequent acceptance

Create reproducible native probes using the managed sources, without modifying
an installed executable or using private credentials in fixtures. Prove actual
MSSQL and SQLite prepare/bind/execute/fetch/close, not SQL literal substitution.
Record source/patch/driver versions and explicit supported-type matrices.

- Check UTF-8 accents/supplementary characters, embedded NUL, empty/NULL,
  integer bounds, approximate numbers, exact int64/decimal, booleans and dates.
  Include nulls in declared columns as well as constant expressions.
- Check quotes/question marks/comments, repeated markers, missing/extra binds,
  invalid type/range/version and driver errors; recover with a valid request.
- Check page/count use the same values, totals/empty pages, defensive snapshots
  and old Query compatibility. Pagination still performs fresh statements;
  this contract does not promise a database snapshot.
- Verify statement/buffer lifetime until execute/fetch completes; release on
  all error paths. Preserve connection/workarea restoration and the SQL mutex.
- After T03/T04, compile changed TLPP and accept real TCP/HTTP and native
  presentation, NULL/type/encoding failures and resource cleanup in T05.

The first T02 decision is the smallest tested connector extension that keeps
one query implementation. If exact/native semantics cannot be demonstrated,
report the capability as unsupported and document the gap before integration.
MEMIO result reuse is [separate future work](evolution.md#in-memory-results-between-requests).
