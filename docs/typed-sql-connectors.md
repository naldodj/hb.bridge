# Typed SQL connector extension

[Português](typed-sql-connectors.pt-BR.md) · [Typed SQL contract](typed-sql.md) · [WIP](../WIP.md)

**Decision recorded on 2026-10-24; T03 integration validated on 2026-10-25.**
The native SDD execution extension uses the existing SQL lease and common
Query lifecycle. The Windows SQLite/MSSQL integration passed **133 checks,
zero failures**, including real TCP and gzip HTTP/REST calls. This evidence
does not establish real-backend AppServer acceptance or native presentation.
The [binding manifest](validation/sql.bind.windows.json) retains the separate
T02 standalone evidence; it is not a substitute for integration validation.

## Decision and existing hooks

Use a strictly tagged internal hash request through `RDDI_EXECUTE`. Add a
typed branch to the native ODBC and SQLite SDD `Execute` callbacks, retaining
their existing string behavior. The branch receives the connection already
owned by the [SQL lease](../src/hb/services/hbbridge.sql.pool.hb); it does not
connect independently or expose a native pointer to Harbour callers.

The pinned Harbour revision is
`6deac9cf3ad977ae829e5bca543d553b92dd4b6d`, identified by the
[dependency manifest](../config/dependencies.json). At this revision:

| Existing hook | Consequence for the extension |
| --- | --- |
| `sqlbaseRddInfo()` dispatches `RDDI_EXECUTE` to `pConn->pSDD->Execute`. | Reuse the existing connection lookup and SDD dispatch. |
| RDDSQL pins the global connection's `uiAreaCount` during Execute and applies the SDD mutex where configured. | Keep native statement work inside this synchronous callback; retain the surrounding hbBridge SQL lifecycle mutex. |
| The Execute callback receives `SQLDDCONNECTION *`. | ODBC can use its owned `SQLHDBC`; SQLite can use its owned `sqlite3 *`, without copying their private structure layouts. |
| `HB_RDDINFO` copies its argument item; Harbour item copies retain shared hash contents. | A caller-held internal hash carries the completed result/diagnostic while the existing RDDI_EXECUTE return remains boolean. The integration tests verify success, rejection and unchanged request snapshots. |
| `SDDNODE` already has an Execute callback. | No new callback member, changed RDD structure layout or SDD ABI is required by this design. |

Relevant pinned sources are
[RDDSQL dispatch](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/contrib/rddsql/sqlbase.c#L1245),
[SDD structures](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/contrib/rddsql/hbrddsql.h#L195),
[RDDINFO argument handling](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/src/rdd/dbcmd.c#L2092)
and [item/hash copy semantics](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/src/vm/itemapi.c#L1663).
These implementation hooks are not a newly exposed hbBridge API.

The internal request must have an explicit operation/version tag, validated
SQL and one immutable binding snapshot. A separate nested output receives
either a completed native result or a sanitized failure. Exact internal member
names remain an implementation detail; they are not additional fields in the
public QueryTyped request. Reject unknown tags, shapes and capabilities before
execution. An unrecognized hash must never fall through to string execution.

## One service and ownership lifecycle

`RPCRDD.QueryTyped` uses the common
[Query service](../src/hb/services/hbbridge.query.hb), sharing profile
validation, page planning, lease acquisition, totals, error envelopes, cleanup
and restoration. The existing Query/result-version-1 reader
continues to use its accepted SQLMIX path. The typed reader obtains native
metadata and exact wire values at the SDD boundary; it must not force exact
strings through approximate RDD numeric fields. This is one service pipeline
with connector-specific readers, not a second SQL service or connection pool.

For a typed call, the implemented lifecycle is:

1. Validate the public request and snapshot bindings before native execution.
2. Enter the existing SQL lifecycle mutex and acquire the ordinary logical lease.
3. Execute the page or unpaged statement through the tagged native callback:
   prepare, validate native markers/count, bind, execute, describe, fetch and
   close all statement resources before returning.
4. For pagination, independently prepare and bind the count statement from the
   same snapshot on the same lease. Release the page reader first; no simultaneous
   reader support is assumed. Generated row bounds remain checked integer
   literals and do not change binding ordinals.
5. Publish the complete service result only after mapping, fetch, count and
   statement cleanup succeed. Otherwise discard partial rows and return the
   stable failure category.
6. Release the lease and restore the previous connection/workarea, including on
   errors. A failed release remains visible and retains ownership.

The native callback owns its statement, parameter buffers and temporary
descriptors until fetching and close finish. It never owns the leased database
connection. Statements, native handles and binding-buffer pointers are not
exposed to Harbour callers. Native failure paths must release buffers and statements before
returning; a Harbour error raised before native cleanup is not a substitute for
that cleanup. Repeated calls and error recovery must not depend on worker-local
pending options or an earlier request.

Keep optional ODBC driver-manager physical pooling, current lease checks and
the SQL mutex unchanged. This decision does not introduce parallel SQL,
persistent cursors, a transaction snapshot across page/count statements or
cached results between requests.

## Native metadata, exact values and NULL

Apply the complete [version 2 mapping contract](typed-sql.md#version-2-result-and-stable-column-mapping).
Preserve native descriptors before any RDD narrowing or default substitution;
RDD observations, source definitions and caller logical schema remain separate.
Unknown metadata is null, not invented zero/false/empty text.

| Boundary | Required behavior |
| --- | --- |
| ODBC prepare/bind | Use native preparation, parameter discovery and input binding with checked native capacities and explicit lengths. Keep buffer storage valid through execution/fetch. Apply the configured query timeout to each statement. |
| ODBC descriptors | Retain signed SQL type, precision, precision radix, scale and native nullable status. Read supported type/origin/length attributes without deriving source precision from RDD display length. Unknown nullability and unavailable attributes remain null; collation requires separate evidence. |
| ODBC values | Detect `SQL_NULL_DATA` before conversion. Preserve UTF-8/NUL through proved Unicode retrieval. Retrieve exact DECIMAL and signed bigint without an intermediate double, using the contract's canonical strings. Approximate FLOAT remains approximate. |
| SQLite prepare/bind | Check the native parameter count and anonymous marker names, explicit lengths, one statement and its remaining SQL tail. Use the proved native binding types only. |
| SQLite descriptors | Select a stable mapping from supported declared columns. Unknown declarations, undeclared expressions and ambiguous metadata fail explicitly even for empty/all-NULL results. |
| SQLite values | Check `sqlite3_column_type()` for NULL before conversion, use explicit text byte lengths and check every non-null storage class/range against the fixed mapping. Do not sample the first row or silently switch types. |

The typed readers bypass the existing SDD string/result conversion paths:
ODBC maps DECIMAL to an approximate RDD numeric reader; SQLite can replace
mapped NULL with numeric defaults and retrieve text through a terminated-string
path. Native preparation alone proves none of the version 2 result guarantees.
The existing Query contract remains unchanged; adding the typed reader does
not attribute version 2 guarantees to Query/result version 1.

The scoped MSSQL probe reports FLOAT precision 53 with radix 2; that is not
53 decimal digits or a business scale. Keep `source.precisionRadix` alongside
the reported precision. Native decimal text such as `.00000000` needs lexical
normalization to `0.00000000`, retaining the source scale and canonical zero
without an intermediate numeric parse, double or rounding.

Preserve SQL NULL in the service, transport and dataset, separately from empty
text, zero and false. Protheus owns its business interpretation and any explicit
replacement, including for dictionary fields made nullable by joins. The native
presentation adapter may reject an unrepresentable NULL under its explicit
policy; that does not authorize hbBridge to replace or reject a valid query
result. No automatic SX3/TOP_FIELD lookup or business-scale inference is added.

## Managed extension and alternatives

Build the extension against the pinned dependencies through reviewed managed
patches and receipts. Reuse the existing
[ODBC patch](../config/patches/sddodbc.patch), including query-timeout and
variable-data helpers; the [ODBC preparation script](../scripts/prepare-odbc.ps1)
patches a disposable managed copy instead of the pinned source checkout.
The corresponding [SQLite patch](../config/patches/sddsqlt3.patch) is prepared
by [prepare-sqlite.ps1](../scripts/prepare-sqlite.ps1), invoked by ODBC
preparation before its cache check. Both receipts include the pinned revision,
patch, platform/compiler, installed library and project-owned native helper
hashes; helper changes invalidate reuse. The common
[typed helpers](../src/c/hbbridge.sql.typed.h) and
[binding validator](../src/c/hbbridge.sql.binding.c) retain explicit
[ODBC](../src/c/hbbridge.odbc.typed.c) and
[SQLite](../src/c/hbbridge.sqlite.typed.c) adapters.

The SQL admission guard accepts a bounded SELECT/CTE grammar and rejects
unsupported operations, batches and marker forms before native execution.
It is not a general SQL parser. Native preparation, parameter discovery and
SQLite statement-tail/read-only checks remain authoritative. Undeclared
SQLite result expressions cannot acquire a wire mapping by sampling rows;
the reserved internal count operation is separate from ordinary result mapping.
The bounded SQL vocabulary rejects command keywords, including `FETCH`; it
does not accept every valid dialect expression. MSSQL top-level CTEs can be
used unpaged, but paging/counting requires a base query valid inside a derived
table. A top-level MSSQL CTE with `page` fails native preparation; no SQL rewrite
or batch fallback is attempted. For SQLite pages, colon-suffixed and reserved
ordinal-prefix projection names are rejected, preserving duplicate detection
when SQLite renames derived columns. A final line comment is terminated before
the generated page/count suffix.

An external native bridge cannot currently obtain an RDDSQL lease's native
connection through a supported exported accessor. Opening another connection
would duplicate ownership, timeout/configuration behavior and pooling decisions;
copying private SDD structure layouts would couple unrelated code to internals.
Neither is selected. A new generic SDD callback could be a future upstream API,
but requires coordinated structure/ABI changes and is larger than the existing
Execute extension needed here.

## Integration evidence and remaining scope

The [Windows binding manifest](validation/sql.bind.windows.json) scopes the
standalone SQLite/MSSQL probes by source, driver, platform and operation. It is
evidence for individual native features, not service capability advertising.
The 2026-10-24 standalone Windows runs passed 252 SQLite checks and 75 MSSQL
checks, with zero failures; they do not execute the selected SDD hash extension.
Run the versioned [SQLite probe](../scripts/test-harbour-sqlite-bind.ps1) and
[MSSQL probe](../scripts/test-harbour-mssql-bind.ps1) with their documented
prerequisites; private credentials remain external.

The versioned [integration runner](../scripts/test-hbbridge-typed-sql.ps1)
builds the managed adapters and shared service in a fresh disposable directory.
Run SQLite alone or add an explicit private MSSQL profile:

```powershell
./scripts/test-hbbridge-typed-sql.ps1
./scripts/test-hbbridge-typed-sql.ps1 -Config '<private-ini>' -Profile '<alias>'
```

The 2026-10-25 Windows run passed 133 checks: 111 native SDD/service checks
and 22 real TCP/gzip HTTP/REST checks across SQLite and MSSQL. The runner
writes sanitized `result.json` and source/binary/dependency `receipt.json`,
plus disposable build/console logs. No credentials are copied into those
receipts. Reproduction depends on versioned sources and managed dependencies,
never a previous tmp directory. Covered behavior includes:

- Shared-hash output survives `RDDI_EXECUTE` replacing its local item with a
  boolean, including false/error results, while request snapshots remain intact.
- Tagged dispatch never executes malformed/unknown hashes as SQL, string
  execution remains compatible and no shared pending request state leaks.
- Native marker discovery checks the positional contract; named/numbered
  markers, count mismatches and multiple statements are rejected explicitly.
- Nullable declared columns, all-NULL/empty results, NUL/Unicode, exact integer
  and decimal bounds, invalid storage classes and unsupported results preserve
  the specified semantics or fail explicitly.
- Page/count use the same descriptor snapshot on one lease; an empty page keeps
  stable metadata/totals and exercised result-mapping failures discard partial
  output.
- Successful calls and exercised rejection paths release statements/leases;
  disconnect, caller-state restoration and subsequent valid calls succeed.

The wire checks verify exact values and metadata after TCP, gzip HTTP service
calls and REST routing, structured failure/recovery and owned listener shutdown.
They use Harbour consumers; record actual TLPP dataset and real-backend
AppServer acceptance separately. Allocation/driver-close failure injection,
Linux and other driver combinations are not established by this Windows run.
SQLite exact fixed decimals, unsupported result types, unavailable native
metadata and unproved driver/platform combinations remain unsupported.
