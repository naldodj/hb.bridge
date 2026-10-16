# SQL connection reuse

[Português](sql-connections.pt-BR.md) · [SQL contract](milestone3-sql.md) · [Roadmap](../TODO.md)

Observation recorded on 2026-10-12; reprioritized during the M07 load
investigation on 2026-10-15. Reuse must preserve the generic executor,
profile isolation and caller state. The supplied pool sketch is design input;
its implementation is not adopted verbatim.

## Current behavior

`SQLQueryLocked()` connects for each call, opens/reads/closes its query area,
executes a separate count on the same connection for paged results, then
disconnects and restores the caller's workarea/default connection. A shared
SQL mutex protects the entire lifecycle. Reusing a connection would not remove
the page query/count cost or make SQL calls parallel under this mutex.

The original SDDODBC calls `SQLDriverConnect()` and `SQLDisconnect()` without
explicitly enabling pooling. Logical connect/disconnect does not alone
prove a new physical network connection: with ODBC pooling enabled, disconnect
can return the physical connection for reuse. Verify the actual driver-manager
behavior before attributing latency to login. See
[Microsoft ODBC pooling](https://learn.microsoft.com/en-us/sql/odbc/reference/develop-app/driver-manager-connection-pooling?view=sql-server-ver17).

SDDODBC also allocates/frees environment and connection handles per call.
Check pooling mode, shared-environment lifetime and actual physical reuse.
Its original/default-off disconnect wrapper ignores native ODBC return codes;
`RDDI_DISCONNECT` success alone cannot establish complete cleanup. The opt-in
pooled path checks rollback, disconnect and handle release, as accepted below.

## Alternatives to measure

| Alternative | Question to resolve |
| --- | --- |
| Current lifecycle | How much time is connection/authentication versus query/count/fetch/encoding/transport? |
| ODBC driver-manager pooling | Can supported Windows/Linux builds reuse physical MSSQL connections while retaining the logical lifecycle? |
| One reusable connection per profile | Does exclusive sequential reuse provide worthwhile savings under the current mutex? |
| Bounded host-managed pool | What measured concurrency warrants more connections, and which RDDSQL synchronization changes are safe? |

Measure repeated short queries and small pages, cold/warm behavior, elapsed
times and dispersion, sessions/memory/handles, failures and reconnects.
Identify the backend, driver, authentication/TLS and workload. Confirm physical
reuse separately from the timed query. Previous whole-call timings do not
isolate connection cost and imply no expected percentage gain.

## Ownership and acceptance questions

- Give each connection an exclusive lease for a call. Separate profiles,
  authenticated identities and effective connection options; invalidate reuse
  after relevant configuration/credential changes. Protheus still resolves
  its business context; pooling does not infer company/branch/tenant rules.
- Close cursors/statements, finish or roll back transactions and restore
  session/RDD state before returning a connection. An open connection is not
  itself an open transaction; retained transactions, temporary objects and
  `SET` options can affect the next caller. Do not assume universal automatic
  reset. [ODBC session-state considerations](https://learn.microsoft.com/en-us/sql/odbc/reference/develop-app/driver-manager-connection-pooling?view=sql-server-ver17).
- Verify stale/broken connections, server restart, idle expiry, maximum
  lifetime, bounded allocation/waiting and shutdown cleanup. Reconnection is
  distinct from replay: do not automatically repeat a command whose outcome
  is unknown, particularly an operation with side effects.
- Validate thread affinity and the global RDDSQL table/thread-local active
  connection. TCP workers currently end after a call; `THREAD STATIC` alone
  is not ownership for a long-lived pool. Preserve the mutex until a separately
  tested synchronization design permits greater concurrency.
- Evaluate SQLite separately. File connections have different costs, and
  retaining a `:memory:` connection changes database lifetime/isolation.
  Reusing a session does not create a snapshot between page/count calls or
  guarantee the same connection for temporary-table/cursor workflows; those
  need an explicit session lease contract.

SQL connection lifetime is independent of Protheus-to-hbBridge TCP/HTTP
connection lifetime. Database reuse can be evaluated without adopting a
persistent RPC transport. Select an implementation only after measurements
and isolation/recovery/resource acceptance on the supported platforms.

## Concurrent caller acceptance

M07 passed 458 native checks (8 workers/192 calls) and 417 AppServer CLI
checks (4 jobs/112 calls) on 2026-10-14. Profiles, schemas, values and owned
resource cleanup remained isolated under the existing lifecycle mutex.
This accepts concurrent callers, without removing synchronization or proving
physical connection release. It does not select a pooling strategy.
[Scope and evidence](acceptance.md#sql-concurrency-and-release-on-2026-10-14).
M08 still supplies the performance/memory measurements needed for reuse analysis.

## Port pressure observed on 2026-10-15

The latest supplied file contains DBAccess ODBC error **10048/08001** and a
login timeout, followed by a proposed `HBBridgeSQLPool`; it is not an OK test
report. DBAccess is a separate process. Local observations found 15264
`TIME_WAIT` connections in one snapshot and an IPv4 dynamic range of
49152–65535. Counts vary and are not a measure of leaked handles.

Windows System logs also contain **Tcpip 4227** at **07:35:03 and 08:41:55
São Paulo**: outgoing connections failed because the selected local endpoint
had recently connected to the same remote endpoint. This establishes a host
port-reuse pressure symptom during the investigation; per-process attribution
and its contribution to each HTTP failure still need measurement. Microsoft
distinguishes that evidence from a large `TIME_WAIT` count alone in its
[port-exhaustion diagnosis](https://learn.microsoft.com/en-us/troubleshoot/windows-client/networking/tcp-ip-port-exhaustion-troubleshooting).

Increasing HTTP backlog or request deadlines did not make the 140-worker
case pass. No Windows TCP registry or port-range setting was changed.
SQL reuse reduces database-side connection churn; Protheus-to-hbBridge
HTTP/TCP connection churn has a separate lifecycle and must also be measured.
[Run evidence](acceptance.md#sql-concurrency-follow-up-on-2026-10-15).

## Adaptation of the supplied sketch

| Sketch behavior | Required hbBridge adaptation |
| --- | --- |
| Remove the SQL lifecycle mutex | Retain it; the pinned SDDODBC is not marked `MT_AWARE`, and RDDSQL also serializes driver operations. |
| Retry `Acquire()` forever and connect/ping under the pool lock | Keep finite native timeouts and visible failures; do not add an unbounded retry loop or replay a command. |
| Return a handle absent from `inUse` | Require exact ownership; duplicate/foreign returns cannot make a handle available twice. |
| Destroy leased handles or swallow cursor-close failure | Drain active work, check cleanup and never lend a connection with an unresolved reader. |
| Restore only a positive previous default connection | Preserve previous zero too; native `RDDI_CONNECTION` ignores assigning zero. Retained RDDSQL handles need a different ownership design. |
| Use `SELECT 1` as a clean-session test | Verify transaction, temporary-object, database and session-option isolation; liveness does not reset state. |
| Replace MSSQL connection construction with generic ODBC concatenation | Preserve authentication/TLS validation, structured/raw exclusivity and existing type/encoding/pagination behavior. |
| Advertise Oracle/PostgreSQL/MySQL immediately | Add each driver/dialect only after its own acceptance; keep SQLite lifetime semantics unchanged. |

The implemented adaptation uses **physical pooling in the native ODBC driver
manager**, preserving logical per-call RDDSQL connect/disconnect and the SQL
mutex. `HBBridgeSQLPool` manages hash-based logical leases with a unique ID,
profile and owner thread. It rejects stale/duplicate/foreign returns and
refuses destruction while leases remain active. Configuration does not
recreate the singleton. This avoids a shared cache of RDDSQL handles and preserves restoration
of a caller whose previous connection was zero. An application-managed pool
remains a separate option if native reuse fails the measured requirements.

Pooling is process-wide, explicitly selected and frozen at first ODBC use.
`off` preserves the existing default; `driver` requests a pool per driver,
not the separate `SQL_CP_DRIVER_AWARE` feature. Exact matching of connection
options does not establish clean session state. The Windows ODBC 3.8 path
passed 61 checks in each mode: after two recorded cold-start leases, 13
measured logical leases reused one physical TCP connection with `driver`,
versus 13 with `off`. SET/context, temporary tables, transaction and database
selection were cleared before the next borrower on the reused connection;
timeouts, caller state and anchor release passed. This is no latency benchmark.
Linux retains `off` until its driver-manager/session-isolation path is accepted.
See the [native evidence](acceptance.md#odbc-physical-reuse-on-2026-10-15) and
[configuration](configuration.md) for supported settings and current evidence.

The native pool retains a matching environment reference between logical
connections, using an unconnected anchor DBC without credentials or a network
socket. The earlier connect/free-environment implementation requested pooling
but measured 13 physical connections for 13 logical calls. Keeping the shared
environment alive enabled actual reuse; its owned anchor is released at
process exit or explicit native-pool cleanup, after logical leases close.
Cold start used two physical connections; steady-state reuse is recorded
separately instead of claiming one physical connection for the whole process.

The later manual Protheus summary reports 500 workers/58449 checks with zero
failures and explicit launch pacing. It does not supply pool mode or a binary
hash, so it is separate from physical-reuse acceptance. StartJob/framework
database activity also needs separate measurement from hbBridge SQL and RPC
connections. [Manual scope](acceptance.md#manual-protheus-concurrency-on-2026-10-15).
