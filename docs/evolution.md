# Runtime, HTTP, dependencies and SQL results

[Português](evolution.pt-BR.md)

Design review of the four proposals supplied on 2026-10-07. This document
distinguishes native behavior and verified capabilities from implementation
work. hbBridge remains a generic executor: Protheus prepares business context,
table names and SQL, and receives explicit results.

## Thread state and request state

Harbour `THREAD STATIC` gives each thread its own variable value. It is the
appropriate declaration for persistent worker-local state. It does not imply
that every request starts with its initial value: a pool reuses threads, and
an HRB reload in the same thread can reuse initialized static storage.

| Intended lifetime | Storage |
| --- | --- |
| One request | Parameters, `LOCAL` values or an explicitly initialized request context. |
| One worker thread | `THREAD STATIC`, with explicit request reset where necessary. |
| Shared process resource | Ordinary `STATIC` plus synchronization and a defined lifecycle. |
| One loaded module | Independent HRB handles and `HB_HRB_BIND_FORCELOCAL`; thread-local state is a separate property. |

Native hbhttpd already declares response/context values as thread statics and
resets response state between requests. See the pinned [declarations](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/contrib/hbhttpd/core.prg#L29)
and [request reset](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/contrib/hbhttpd/core.prg#L557-L560).

The project SQL mutex and the test synchronization barrier must remain shared.
Syslog already uses thread statics. Static functions/methods and immutable C
garbage-collector tables are different declarations and require no conversion.

The managed native probe passed **31 assertions**: a shared HRB isolated state
across 12 threads; two calls in each worker retained its private counter; four
load/do/unload cycles in one worker produced counters 1, 2, 3 and 4. Two HRBs
in one thread retained independent module storage. Evidence:
`tmp/thread-static-probe.log`, `tmp/thread-static-probe.hb` and
`tmp/thread-static-addon.prg`. This complements the ordinary-STATIC module
isolation test, rather than replacing that coverage.

Current reproduction uses `scripts/test-harbour-thread-state.ps1` and the
versioned sources in `tests/probes/`. Old tmp paths above are historical only.


## HTTP transport alternatives

Keep hbhttpd as the current adapter and evaluate Zig when measured requirements
justify it. Existing gaps include HTTP methods beyond native GET/POST,
chunked request handling, admission queue policy and broader lifecycle/TLS
acceptance. An alternative should use the same service registry, permissions,
request context and result/error contract.

Zig can own HTTP parsing, network I/O and buffering while Harbour executes
services. A C ABI must define byte lengths, allocation/free ownership, errors,
deadlines and cancellation. Zig-created workers must enter the Harbour VM
through supported thread/VM interfaces or enqueue work to Harbour-owned
workers. Copying the executor, SQL implementation or Protheus business rules
into a second transport would defeat the shared-core design.

The [suggested tutorial](https://ziglang.com.br/tutoriais/zig-http-server/) is
an architectural reference, not a version-pinned implementation. Its
`std.net.Address` examples do not match the project's Zig 0.16.0 API. The
installed `std.http.Server` takes `std.Io.Reader`/`Writer` interfaces and
handles a connection lifecycle; listeners, routing, scheduling, authorization,
TLS and shutdown still need integration. Consult the official
[0.16.0 I/O/networking changes](https://ziglang.org/download/0.16.0/release-notes.html#Networking).

Before changing the default, compare both adapters with the same services,
payloads, concurrency, memory, byte integrity, malformed requests, shutdown
and Windows/Linux acceptance. A Zig HTTP transport is not implemented yet.

## One dependency resolver

hb_compile is already a pinned, project-owned bootstrap dependency. It should
own external Harbour build dependencies as well; hbBridge should select the
required capabilities and consume its generated environment and artifacts.

On Windows, the pinned runner supports selective resolution with
`-Full -Dependency openssl -DependencyTriplet x64-windows -StrictDependencies`.
This is the intended next integration for `HB_HTTP_TLS=1`. Explicit dependency
selection avoids bringing unrelated Qt/GUI/database SDKs into an HTTP build.
The generated `config/external-deps.generated.zig.ps1` belongs to hb_compile.
Its include/linker settings must survive separate build/test processes through
the scoped toolchain adapter. Receipt reuse must account for dependency
selection, target architecture, generated settings and runtime artifacts.

The current OpenSSL catalog expects dynamic Windows DLLs. Include/library
resolution alone does not deploy those DLLs with a service executable. Target
triplets, runtime deployment, vcpkg baseline and package versions/checksums
need an explicit contract before claiming reproducible external dependencies.
The current hbBridge scripts still require a supplied OpenSSL SDK for TLS;
delegation of that resolution is pending, not delivered by this review.

The pinned resolver uses Windows executables. Its Linux WSL/Docker profiles
are launched from Windows and differ from native Linux bootstrap. Native Linux
resolution must become an upstream hb_compile capability, or use a separately
declared supported build route. Keep this gap explicit; do not duplicate an
OpenSSL downloader in hbBridge. Licensed TOTVS resources and installation
identity remain outside the open-source dependency resolver.

## Tables for native Protheus presentation

Sharing a database does not share a connection or session. The current
`RPCRDD.Query` opens its own connection and closes it after collecting rows;
the client dataset receives JSON rather than an AppServer/DBAccess alias.
Microsoft documents the [session scope of SQL temporary tables](https://learn.microsoft.com/en-us/sql/t-sql/statements/create-table-transact-sql?view=sql-server-ver17#temporary-tables).
SQLite documents [private and shared in-memory databases](https://www.sqlite.org/inmemorydb.html);
even named shared-cache memory databases require connections in the same process.

| Result destination | Contract |
| --- | --- |
| MSSQL local `#temp` | Scoped to the creating SQL session; another DBAccess connection cannot automatically consume it. |
| MSSQL global `##temp` | Requires explicit lifetime, unique naming, ownership and connection handling; not the default materialization strategy. |
| Durable SQL staging table | Suitable for committed results read through another connection; needs a reserved output schema and managed result lifetime. |
| Protheus `FWTemporaryTable` | Created and owned by the Protheus thread; copy the current dataset for native browse/navigation. |
| SQLite `:memory:` | Not a shared AppServer result store; the current connection closes after each call. |
| SQLite file | Requires an explicitly shared location, compatible client access, schema, locks/journaling and cleanup. `LOCALFILES=SQLITE` alone does not provide that integration. |

`HBBridgeBrowseData` already presents the current page through FWBrowse arrays,
with Protheus-side labels/masks and a temporary table used by its filter UI.
It does not populate a native result table. Package 002's
[typed SQL/presentation draft](typed-sql.md) inventories this implementation;
T01 remains pending review while HTTP performance has priority.
A result-table adapter can create `FWTemporaryTable` in TLPP from an
explicit schema and copy paginated rows, returning the owning object and alias
for `FWMBrowse`. This retains the existing transport. The TOTVS
[temporary table contract](https://tdn.totvs.com/display/framework/FWTemporaryTable)
and [browse integration](https://tdn.totvs.com/display/framework/Dados%2BProtegidos%2Bno%2BBrowse)
define the native ownership and presentation APIs.

To avoid transferring all rows as JSON, introduce a separate materialization
contract, for example `RPCRDD.Materialize`, without changing `RPCRDD.Query`.
First proposed backend: an explicitly configured MSSQL staging schema. Return
an opaque result handle, target profile, schema/table reference, column
metadata, row count, ready state and expiry. Publish only after commit;
release must be idempotent, with leases, crash recovery and ownership checks.
Identifier restrictions, precision/scale, nulls, encoding and explicit row
order are part of the contract. A physical name is not an authorization token.

Protheus can consume the committed table with its own SELECT/TCGenQry or copy
it into a native temporary table where presentation requires one. A table
created by ODBC is not automatically registered in DBAccess or the Protheus
dictionary. [TCGenQry](https://tdn.totvs.com/display/tec/TCGenQry) defines the
connection/cursor contract. Company/branch/tenant rules, dictionary metadata,
captions, masks and actions remain with the caller. Benchmark staging writes
and reads against paginated JSON before choosing the default path.

The populated native result-table adapter and server materialization service
are proposals, not implemented capabilities of the current query service.

## In-memory results between requests

Future idea recorded on 2026-10-23, outside package 002 implementation:
materialize an SQL result once and reuse it across requests without repeating
the source SELECT. Harbour **MEMIO (`hbmemio`, `mem:`)** is an in-memory virtual
filesystem, distinct from `MemoRead()`/`MemoWrit()`. A DBF RDD can store its
table, memo and index files there. The contrib is in the managed dependency
catalog; the current product does not link/expose a MEMIO result-cache service.

The pinned [MEMIO implementation](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/contrib/hbmemio/memio.c)
retains named files after their last open handle closes, in shared process
storage. Closing an SQL connection or an RDD area need not remove those files.
This observation concerns ordinary named DBF/memo/index files. An RDD
temporary/auto-delete table can delete its files when its owning area closes
(for example through `DBI_ISTEMPORARY`); MEMIO does not override that policy.
An independent thread can reopen retained files with its own workarea/cursor. Explicit
deletion or process exit ends that lifetime; another process/host cannot read
the same MEMIO store. This is reuse within one running host, not durability
across service restarts. The source's byte-lock operations are stubs; its
internal critical section does not establish concurrent DBF write/record-lock
semantics. Start any future evaluation with immutable published results and
independent read-only areas, not concurrent writers.

The reusable [native probe](../tests/probes/hbbridge.memio.snapshot.test.hb)
and [runner](../scripts/test-harbour-memio.ps1) passed on 2026-10-23 with managed
Windows Harbour/Zig: **22 assertions in one process plus one fresh-process
assertion**, zero failures/exit 0. They cover producer close/thread exit,
DBF/FPT/CDX reopening, two independent reader threads/cursors, memo NUL bytes,
explicit three-file deletion and loss at process exit. No SQL connection,
product endpoint, cache service, write-lock or Linux acceptance is inferred.

Proposed future flow, with no service names or new API committed yet:

1. An authorized caller requests a materialized result using an explicit
   profile, SQL, values and caller-resolved access scope.
2. The host fetches once, creates a private result, validates its schema/values
   and publishes it read-only only after completing the copy/indexes.
3. Return an opaque authorized handle. Later requests read pages/seek through
   independent areas using that handle; they do not rerun the source SELECT.
4. Explicit release, expiration or memory eviction retires the result. Wait
   for active readers before deleting every associated file. Refresh creates
   and publishes a new result instead of rewriting a published snapshot.

This stores an observation made at materialization time. It does not create
database transaction/snapshot guarantees while the original query is fetched,
or notice later writes through DBAccess/other applications. The caller chooses
freshness/refresh and Protheus resolves tenant/company/branch; the host enforces
the supplied authorization scope. Do not transparently reuse another user's
SQL text/result or infer ERP context. A pathname is not an authorization token.

Before implementation, define ownership, scope isolation, expiry/last-use,
reference counts, cancellation/partial-build cleanup, configurable memory
budgets and exhaustion/eviction behavior. Prove UTF-8, NULL, long text, exact
numeric representation and index behavior; a DBF copy must not silently change
SQL types. Compare MEMIO/RDD with hashes or another explicit result store using
creation/copy/index cost, repeated-read latency, memory and source freshness.
Repeated database queries may already benefit from the database's own cache;
no speed advantage follows from storage in RAM alone.

Keep `RPCRDD.Query` fresh-query/page semantics unchanged. Result reuse is separate
from ODBC physical connection pooling, Protheus-owned FWTemporaryTable and MSSQL
staging materialization. One reusable result can reduce source work and stabilize
subsequent page traversal, at the cost of memory and deliberately older data.
