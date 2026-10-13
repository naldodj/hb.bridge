# SQL connection reuse: future analysis

[Português](sql-connections.pt-BR.md) · [SQL contract](milestone3-sql.md) · [Roadmap](../TODO.md)

Observation recorded on 2026-10-12 for future evaluation. This is an
analysis item, not implemented pooling, an approved default or new INI keys.
The active WIP package retains its current tasks and completion criteria.

## Current behavior

`SQLQueryLocked()` connects for each call, opens/reads/closes its query area,
executes a separate count on the same connection for paged results, then
disconnects and restores the caller's workarea/default connection. A shared
SQL mutex protects the entire lifecycle. Reusing a connection would not remove
the page query/count cost or make SQL calls parallel under this mutex.

The inspected SDDODBC calls `SQLDriverConnect()` and `SQLDisconnect()` and
does not explicitly enable pooling. Logical connect/disconnect does not alone
prove a new physical network connection: with ODBC pooling enabled, disconnect
can return the physical connection for reuse. Verify the actual driver-manager
behavior before attributing latency to login. See
[Microsoft ODBC pooling](https://learn.microsoft.com/en-us/sql/odbc/reference/develop-app/driver-manager-connection-pooling?view=sql-server-ver17).

SDDODBC also allocates/frees environment and connection handles per call.
Check pooling mode, shared-environment lifetime and actual physical reuse.
Its disconnect wrapper ignores native ODBC return codes; `RDDI_DISCONNECT`
success alone cannot establish complete cleanup.

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
