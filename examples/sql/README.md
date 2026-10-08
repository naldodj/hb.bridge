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
authentication through `DSN=hbBridgeMSSQL` and `Authentication=integrated`,
with `Encrypt=mandatory` and `TrustServerCertificate=false`. Rebuild the
product before using these structured fields. Windows uses the hbBridge
process identity; Linux requires Kerberos. The
[configuration guide](../../docs/configuration.md#mssql-profiles) covers
SQL-login credentials, DSN-less destinations, JSON keys and encryption options.
The [multiple-profile example](../../config/examples/databases.ini)
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
true, later reconfirmed with the client INI acceptance. The operator reconfirmed all 29 SQLite
checks on 2026-10-07, thread 27136, after reported recompilation of the renamed
TLPP classes. Changing only a server profile requires no further TLPP build.
See [milestone 3](../../docs/milestone3-sql.md),
[acceptance](../../docs/acceptance.md) and [tests](../../tests/README.md).

## Private MSSQL configuration and native acceptance

For a SQL login, fill the existing username and password in the prepared
`[SQL/mssql/pData]` template in `C:/tmp/hbBridge.ini`. Keep the whole template
commented until it is complete, then uncomment its lines. It uses `Driver=mssql`,
`DSN=pData`, `Database=pData`, `Authentication=sql`, `Username` and `Password`;
the [field reference](../../docs/configuration.md#mssql-profiles) includes a
DSN-less equivalent using `ODBCDriver`, `Server` and `Database`. The alias
selects only this configured connection; Protheus supplies its business inputs.

Keep the filled private file and backups outside Git with restricted access.
The current fields store the password in plaintext. No password is passed as
a command argument or sent by the Protheus dataset. Encrypted storage and a
credential editor remain future work; see [credentials](../../docs/credentials.md).

Rebuild the product and validate the completed file without opening a database:

```powershell
./scripts/build-hbbridge.ps1
./out/hbbridge.exe --config-info "-config=C:/tmp/hbBridge.ini"
```

Run the dedicated native MSSQL acceptance only after the profile is ready:

```powershell
./scripts/test-hbbridge-mssql.ps1 -Config C:/tmp/hbBridge.ini -Profile mssql/pData
```

Both arguments are required. This runner builds the current shared product
core in an isolated temporary directory and starts no listeners. It verifies
the constant connection probe, actual SQL Server version/database, named
values, decimals, nulls, native dates/timestamps, bit and exact Unicode values,
empty results, failure recovery, pages and hidden ordinals. It also checks
caller workarea/connection restoration, four concurrent calls and three
1000-row baseline executions. The shared mutex serializes SQL execution;
the baseline records elapsed time without a speed threshold.

Results go to `tmp/mssql-tests-*/results.log`, with fixed error codes and
sanitized metadata. Exit `0` means the exercised native checks passed; `1`
means acceptance failed; missing/invalid configuration, wrong profile type or
an unavailable connection returns prerequisite status `2`. Prerequisites are
never successful MSSQL tests. This command does not execute the separate
29-check Protheus TCP dataset test or the HTTP test.

For Protheus acceptance, start the product with the same private profile:

```powershell
./examples/sql/run.ps1 -Config C:/tmp/hbBridge.ini -Profile mssql/pData
```

Then run `U_HBBridgeQueryTest("mssql/pData", "127.0.0.1", 1512, 30000)` with
the actual client destination. Use the same explicit alias for
[HTTP acceptance](../http/README.md). The convenience entries
`U_HBBridgeQueryTestMSSQL()` and `U_HBBridgeQueryTestSQLite()` provide the
local example aliases without changing the generic client's defaults.

On 2026-10-08, the private SQL-login profile passed **92 native checks, zero
failures and no skips** against SQL Server `16.0.1200.5`, database `pData`,
ODBC Driver `18.6.2.1`, Windows x64 and Harbour `UTF8EX`. The staged
[SDDODBC patch](../../config/patches/sddodbc.patch) handles unknown-length
streamed text/binary values and UTF-16 surrogate pairs. The fixture verifies
long values, embedded NULs, empty strings and NULLs without an application
payload ceiling. The baseline selected 1000 rows three times in 31/32/31 ms
(94 ms total, concurrency one); memory was not measured and this is no speed
guarantee.

The operator separately passed **29 TCP checks for MSSQL**, thread 660, and
repeated **29 for SQLite**, thread 3192, on
2026-10-08. The operator subsequently passed **13 HTTP checks per backend**
through `U_HBBridgeHTTPTestMSSQL()` and `U_HBBridgeHTTPTestSQLite()`, threads
25976 and 9916. These entries select the local example profiles while reusing
the common HTTP test and dataset. HTTPS, Linux, integrated/service identities
and broader failure/type/resource/performance cases remain pending. See
[acceptance](../../docs/acceptance.md) for evidence and scope.

## SERVICE_NOT_FOUND

This means the connected process did not register Query, usually because it
loaded no SQL profiles. Check the binary/configuration/port and start this SQL
example. PROFILE_NOT_FOUND means Query exists but that alias is not configured.
