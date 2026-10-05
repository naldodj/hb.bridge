# hbBridge SQL example

[Português](README.pt-BR.md)

The example prepares `U_HBBridgeQueryTest`, including pagination, using the
same `out/hbbridge.exe` and [shared launcher](../../scripts/run-hbbridge.ps1).
The product owns SQL implementation/tests. Build the current binary, stop the
previous instance with Ctrl+Q, then run from the repository root:

```powershell
./examples/sql/run.ps1
./examples/sql/run.ps1 -Config config/examples/sqlite.ini
```

Default: [sqlite.json](../../config/examples/sqlite.json), example profile
`sqlite_demo`, database `:memory:`. Each connection is new; constant SELECTs
need no tables. Persistent SQLite requires an existing database file.
The launcher validates a profile and displays host/port and the test call;
without `-Profile`, it selects the first configured profile. INI uses native
`--config-info`: sanitized metadata, no listeners or DB access. Rebuild the
product for this option. JSON remains compatible. See
[configuration](../../docs/configuration.md).

This script starts the server; compile all `src/tlpp/` and run the Protheus
test separately:

```advpl
U_HBBridgeQueryTest("sqlite_demo", "127.0.0.1", 1512, 30000)
```

The [WebApp entry](https://localhost:4321/webapp/?p=U_HBBridgeQueryTest&e=PROTHEUS)
uses the active AppServer INI's `[hbBridge]` section. Host/port fallback to
`127.0.0.1:1512`, timeout to 30000 ms. **SQLProfile is optional and empty by
default:** configure it or supply the alias explicitly. The updated test
reports PROFILE_REQUIRED if neither exists. `sqlite_demo` belongs only to
this example. This launcher does not edit the AppServer INI; align the
[template](../../config/examples/protheus-appserver.ini) separately. Changing
only a server profile needs no TLPP recompile.

## Other profiles and destinations

```powershell
./examples/sql/run.ps1 -Config config/examples/mssql.ini -Profile mssql_demo
./examples/sql/run.ps1 -Config config/examples/databases.ini -Profile mssql/pData
```

Configure an ODBC driver/DSN for the hbBridge process architecture. The
[MSSQL INI](../../config/examples/mssql.ini) and
[JSON](../../config/examples/mssql.json) contain no password and use integrated
authentication. The [multiple-profile example](../../config/examples/databases.ini)
contains SQLite and `mssql/pData`. Aliases are opaque, case-sensitive keys;
each call/dataset may select another alias. Their names do not resolve tenant,
company, branch, physical tables or ERP rules; Protheus prepares those inputs.
Oracle is a future connector, not implied support from an `oracle/alias` name.
See [architecture](../../docs/architecture.md) and
[credential design](../../docs/credentials.md).

```advpl
U_HBBridgeQueryTest("mssql/pData", "127.0.0.1", 1512, 30000)
```

The launcher shows a usable local destination for wildcard bind; remote
clients need a routable address. The test checks values/named fields/decimal,
EOF/close, empty/invalid SQL, unknown profile/recovery, pages/hidden ordinals,
IDs with gaps and invalid pagination/order. Queries select constants without
writing Protheus tables. Direct ODBC/SQLRDD does not perform DBAccess/business
workflows. Encrypted INI credentials and a local management utility are proposed.

Operator SQLite acceptance: 2026-10-04 00:40:06, thread 41228, all 29 checks
true, later reconfirmed with the client INI acceptance. Real MSSQL and broader
types/volumes/platforms remain pending. Renamed TLPP/revised profile behavior
requires a new compile/test. See [milestone 3](../../docs/milestone3-sql.md),
[acceptance](../../docs/acceptance.md) and [tests](../../tests/README.md).

## SERVICE_NOT_FOUND

This means the connected process did not register Query, usually because it
loaded no SQL profiles. Check the binary/configuration/port and start this SQL
example. PROFILE_NOT_FOUND means Query exists but that alias is not configured.
