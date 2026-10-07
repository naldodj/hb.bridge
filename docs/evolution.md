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

A first presentation adapter can create `FWTemporaryTable` in TLPP from an
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

These presentation/materialization services are design proposals and are not
implemented by the current query service.
