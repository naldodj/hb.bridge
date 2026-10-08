# File and command-line configuration

[Português (Brasil)](configuration.pt-BR.md)

INI and JSON produce the same internal hash and share type, capacity, port,
directory and SQL-profile validation. Omitted fields use product defaults.
Precedence is **defaults < one INI/JSON file < CLI**.

~~~powershell
pwsh ./scripts/run-hbbridge.ps1 -Config config/examples/hbbridge.ini
pwsh ./examples/sql/run.ps1 -Config config/examples/sqlite.ini
~~~

JSON works with the same commands. The minimal launcher accepts `-Config`;
`-Port`/`-MaxWorkers` override the file only when explicitly supplied.

## Default file

Without `-config`, the executable looks for **hbbridge.ini in its own directory**
(`out/` for the canonical build). A missing file preserves defaults/CLI.
An invalid existing file prevents startup. An explicit `-config` replaces
the automatic file rather than merging them. Reading creates no file.

Examples: [server](../config/examples/hbbridge.ini),
[SQLite](../config/examples/sqlite.ini),
[MSSQL](../config/examples/mssql.ini), with equivalent JSON files.
Adjust relative paths when moving a configuration.

## INI sections

The layout follows the section-oriented style of AppServer/DBAccess, with
hbBridge's own settings.

| Section | Keys |
| --- | --- |
| `[General]` | `MaxWorkers`, `AddonRoot`. |
| `[Protheus]` | `Host`, `Port`, `MaxPayloadBytes`, `MaxWireBytes`, `ReadChunkBytes`, `TimeoutMs`. |
| `[NETIO]` | `Host`, `Port`, `Root`, `Password`, `TimeoutMs`. |
| `[Admin]` | `Host`, `Port`, `Password`. |
| `[HTTP]` | `Enabled`, `Host`, `Port`, `Password`, `TLS`, `Certificate`, `PrivateKey`. |
| `[SQL/profile_name]` | SQLite: `Driver`/`Database`; MSSQL: structured fields below or `Driver`/`ConnectionString`. |

~~~ini
[Protheus]
Host=0.0.0.0
Port=1512

[SQL/sqlite_demo]
Driver=sqlite
Database=:memory:
~~~

NETIO retains `0.0.0.0:2941`; admin is disabled without a password.
SQL profiles are consumed by `RPCRDD.Query`.

~~~ini
[SQL/mssql_demo]
Driver=mssql
DSN=hbBridgeMSSQL
Authentication=integrated
Encrypt=mandatory
TrustServerCertificate=false
~~~

An MSSQL profile advertises the service, but queries require an available
ODBC driver/DSN. Select the same alias in the Protheus test:

~~~powershell
pwsh ./examples/sql/run.ps1 -Config config/examples/mssql.ini -Profile mssql_demo
~~~

## MSSQL profiles

Rebuild hbBridge before using structured MSSQL fields. They normalize to the
same private ODBC connection string used by the existing SQLMIX/SDDODBC
executor. Choose one destination form and one authentication mode:

| INI key | JSON key | Meaning |
| --- | --- | --- |
| `Driver` | `driver` | `mssql`. |
| `DSN` | `dsn` | Existing ODBC DSN; excludes `ODBCDriver` and `Server`. |
| `ODBCDriver` | `odbcDriver` | Installed driver name; required with `Server` and `Database` when no DSN is supplied. |
| `Server` | `server` | SQL Server endpoint, such as `localhost,1433`; requires `ODBCDriver` and `Database`. |
| `Database` | `database` | Required without a DSN; optional database override with a DSN. |
| `Authentication` | `authentication` | Required: `sql` or `integrated`. These are hbBridge modes. |
| `Username` | `username` | Required, nonempty SQL login with `Authentication=sql`. |
| `Password` | `password` | Required, nonempty SQL password with `Authentication=sql`. |
| `Encrypt` | `encrypt` | Optional: `optional`, `mandatory`, `strict`, mapped to ODBC `No`, `Yes`, `Strict`. Omission retains the driver's default. |
| `TrustServerCertificate` | `trustServerCertificate` | Optional boolean: INI `true`/`false`, JSON `true`/`false`. |

`Authentication=integrated` omits `Username` and `Password` entirely; even
empty credential fields are rejected. It uses the hbBridge process identity
on Windows. Linux requires an operational Kerberos setup and valid service
credentials. See [Microsoft's integrated-authentication guide](https://learn.microsoft.com/en-us/sql/connect/odbc/linux-mac/using-integrated-authentication?view=sql-server-ver17).

For SQL authentication, fill the existing login and password in a private
file outside Git. This example uses a DSN with an explicit database override;
replace both credential placeholders before enabling the profile:

~~~ini
[SQL/mssql/pData]
Driver=mssql
DSN=pData
Database=pData
Authentication=sql
Username=<SQL_LOGIN>
Password=<SQL_PASSWORD>
Encrypt=mandatory
TrustServerCertificate=false
~~~

To connect without a DSN, replace `DSN=pData` with both lines below and retain
`Database=pData`, authentication and the remaining settings:

~~~ini
ODBCDriver=ODBC Driver 18 for SQL Server
Server=localhost,1433
~~~

Do not add ODBC braces or quotes to these fields. The structured builder
braces driver/server/database/login/password values and escapes `}` as `}}`,
preserving internal `;`, `#` and `=`. DSN names are validated and emitted
without braces for Driver Manager lookup; authentication/TLS enums use fixed
ODBC values. A DSN cannot contain `\[]{}(),;?*=!@`, control characters or outer
whitespace. NUL and newline characters are rejected in connection fields.
INI trims outer spaces/tabs and has no quoted-value syntax, including for passwords.

For deployments, the public samples request `Encrypt=mandatory` and
`TrustServerCertificate=false`. A local development profile may explicitly
choose `Encrypt=optional` when its environment requires it; hbBridge never
retries by weakening encryption or certificate checks. Driver/server support
determines whether `strict` is usable. See [Microsoft's encryption settings](https://learn.microsoft.com/en-us/sql/connect/odbc/dsn-connection-string-attribute?view=sql-server-ver17#encrypt).

Existing `Driver=mssql` plus `ConnectionString` (`connectionString` in JSON)
remains accepted unchanged. It cannot be mixed with any structured field,
including authentication, database or encryption options. Store any
credential-bearing connection string in the same private installation file.
Structured fields provide configuration, without encrypted credential storage.

After rebuilding, validate the completed private file without opening SQL:

~~~powershell
./out/hbbridge.exe --config-info "-config=C:/tmp/hbBridge.ini"
~~~

Keep an unfinished SQL-authentication template commented out: blank
`Username`/`Password` in an enabled profile fail configuration validation.
Once filled and enabled, run the dedicated native acceptance explicitly:

~~~powershell
./scripts/test-hbbridge-mssql.ps1 -Config C:/tmp/hbBridge.ini -Profile mssql/pData
~~~

The runner builds in an isolated temporary directory and uses the shared
query core without starting listeners. Missing/invalid configuration,
wrong profile type or unavailable connection exits with prerequisite status
`2`; it does not certify MSSQL. See the [SQL example](../examples/sql/README.md).

On 2026-10-08, the native route passed **92 checks, zero failures and no skips**
against SQL Server `16.0.1200.5`, database `pData`, ODBC Driver `18.6.2.1`,
Windows x64 and Harbour `UTF8EX`, using the private SQL-authentication profile
`mssql/pData`. The operator separately passed **29 TCP checks per backend**
for MSSQL and SQLite. Later that day, `U_HBBridgeHTTPTestMSSQL()` and
`U_HBBridgeHTTPTestSQLite()` passed **13 HTTP checks each**, threads 25976 and
9916. Their convenience defaults select `mssql/pData` and `sqlite_demo` without
changing generic client defaults. Integrated/service identities, HTTPS, Linux
and broader failure/type cases remain pending; see [acceptance](acceptance.md).

The build stages the reviewed [SDDODBC patch](../config/patches/sddodbc.patch)
without changing the pinned upstream source. It handles `SQL_NO_TOTAL` through
incremental reads, uses the binary field flag and combines UTF-16 surrogate
pairs when producing UTF-8. The native fixture covers long text/binary values,
embedded NULs, empty values and NULLs. Transfer chunks impose no application
payload ceiling; runtime memory and native driver capacities still apply.

## Reading rules

INI section/key names are case-insensitive; SQL aliases retain case as in JSON.
INI `Driver`, `Authentication` and `Encrypt` values normalize to lowercase;
boolean values ignore case. JSON uses the exact lowercase enum values and
native booleans. Use `key=value` without extra quotes.
Outer spaces/tabs are trimmed; internal content stays intact.
Numbers use canonical decimal representation and shared validation. JSON
preserves password spaces; INI's trimming also applies to passwords. Other
structured text fields must contain more than whitespace.
Empty listener passwords preserve disabled/default behavior. An enabled
MSSQL SQL-authentication profile requires nonempty credentials.

Comments begin with `;`/`#` at the start of a line after indentation.
There are **no inline comments**: everything after the first `=` remains
part of the value, including `;`, `#` and other `=` in ODBC strings/passwords.
UTF-8, optional BOM, LF and CRLF are accepted.

Unknown keys/sections, duplicates, incomplete lines and includes are rejected
with line information. Harbour's `hb_iniReadStr` strips inline `#`, supports
includes and tolerates some malformed/duplicate lines; the project parser
preserves the connection-string semantics required here.

File-specified relative directories/SQLite paths resolve against the file's
directory. CLI-relative paths and omitted defaults remain working-directory
relative; launchers use the repository root.

## Check before startup

~~~powershell
./out/hbbridge.exe --config-info "-config=config/examples/sqlite.ini"
~~~

This validates selected configuration and returns sanitized JSON host/port,
worker and alias/driver metadata. It opens no listeners/databases and creates
no directories. Passwords, connection strings and data paths are omitted.
It describes a file, not the configuration of an already running process.
The SQL launcher uses this product command for INI instead of duplicating the
parser in PowerShell; existing JSON preparation remains compatible.

Quote the complete native `"-config=..."` argument in PowerShell to preserve
slash-containing paths and extensions. Launchers already use an argument array.

INI changes no capacity rules: optional payload/wire ceilings default zero,
buffers and deadlines follow [Milestone 2](milestone2-framing.md).

## HTTP listener

`[HTTP]` is optional and disabled by default, with loopback bind
`127.0.0.1:8080`. Enable it deliberately and configure a separate service
password; admin uses the existing adminPassword and must differ. The same
settings have `http*` JSON keys. HTTPS needs a build with hbssl/OpenSSL,
certificate and private key. Routes, authorization, native HTTP behavior
and build dependencies are described in [HTTP](http.md).

## Protheus client in AppServer INI

Add this section to the INI actually used by AppServer.
[The template](../config/examples/protheus-appserver.ini) contains the same values.

~~~ini
[hbBridge]
Host=127.0.0.1
Port=1512
TimeoutMs=30000
MaxPayloadBytes=0
MaxWireBytes=0
ReadChunkBytes=65536
; Optional installation default. A query may explicitly choose another alias.
SQLProfile=
HTTPURL=http://127.0.0.1:8080
HTTPToken=
HTTPTimeoutSeconds=30
~~~

Host/Port select the Protheus endpoint, using a real IP/DNS; `0.0.0.0` is a
server bind. SQLProfile selects a remote alias; database credentials stay on
hbBridge. Client TimeoutMs must be positive. Zero budgets add no application
ceiling; positive values enforce local policies. ReadChunkBytes fits the native
signed 32-bit socket argument. Actual AppServer MAXSTRINGSIZE/memory still apply;
negotiation and blocks are pending, and no setting is automatically derived
from MAXSTRINGSIZE.

`HBBridgeHTTPClient` independently reads `HTTPURL`, the required `HTTPToken`
and `HTTPTimeoutSeconds` (positive integer, default 30 seconds). The token
matches the server's `[HTTP] Password`; it is not a database/admin credential.
Omitted constructor arguments read the active INI; explicit arguments win.
Native HTTP timeout semantics differ from TCP `TimeoutMs`; no TCP framing,
gzip or socket budgets are applied. See [the TLPP example](../examples/http/README.md).

Static [HBBridgeConfig](../src/tlpp/hbbridgeconfig.tlpp), namespace
`HBBridge.Client`, uses `GetSrvIniName()` and `GetPvProfString()`.
[GetSrvIniName](https://tdn.totvs.com/display/tec/GetSrvIniName) supports the
AppServer's selected custom INI name.
Client precedence: **defaults < INI section < explicit arguments**.
Missing section/keys use defaults. Invalid integers, ports and required empty values
fail with `INVALID_CONFIGURATION` before socket creation.
A valid explicit argument can replace the same invalid INI value.

SQLProfile is optional and defaults to empty. The explicit Query alias wins;
otherwise the query test can use this installation default. With neither, it
reports PROFILE_REQUIRED before connecting. Each dataset opens any configured
alias, including `mssql/pData`, without changing a global database. INI profile
`[SQL/mssql/pData]` preserves slash and case; `driver` is separate. SQLite and
MSSQL are implemented; Oracle requires a future connector and acceptance.
See [architecture](architecture.md) and [multiple profiles](../config/examples/databases.ini).

~~~tlpp
// Read [hbBridge] from this AppServer's actual INI.
oClient := HBBridge.Client.HBBridgeClient():New()
// Override Host/Port; retain other INI settings.
oClient := HBBridge.Client.HBBridgeClient():New("bridge.example.local", 1512)
~~~

Each new client snapshots values; existing clients retain their configuration.
No-argument `U_HBBridgeConnectionTest()`/`U_HBBridgeQueryTest()` follow the
section, including SQL alias. `U_HBBridgeConfigTest()` checks resolution/errors
without executing SQL. The server launcher does not edit AppServer INI.

The local section was appended with a backup under `tmp`, preserving previous
bytes. An agent compilation attempt could not stop the elevated TOTVS processes.
The operator later reported all three tests successful in the 2026-10-04 session:
13 configuration checks including `activeAppServerIni`, Windows clock/RPC,
and 29 paginated SQLite checks. See [acceptance](acceptance.md).

That report did not supply arguments, effective Host/Port, execution time/thread,
artifact hashes or a compilation log. The active-INI check confirms valid
reading; nondefault destinations/no-argument behavior require an identified run.
The 412 Harbour checks remain independent evidence.

The operator-reported recompilation after the `.hb` migration and supplied
2026-10-07 São Paulo log accept renamed TLPP and all 16 revised configuration
checks at 16:14:06, thread 30596, including `explicitProfile`, `noForcedProfile`
and `invalidProfile`. Query at 16:13:33, thread 27136 reconfirmed all 29 checks
with `profile=sqlite_demo`; Connection at 16:14:31, thread 27084 reconfirmed
clock/Health/ADDON/two exact 200000-byte Echo calls. HTTP at 16:15:03–16:15:04,
thread 25456 passed all 13 checks in one second, without identifying its SQL
backend. This operator execution supplies times/threads, but no actual compiler
log, hashes, call arguments or effective Host/Port. The agent did not execute
the AppServer tests. The later 2026-10-08 native MSSQL and operator TCP/HTTP
results are recorded above and in [acceptance](acceptance.md).
Nondefault destination/no-argument behavior, Linux and broader
failure/clock/type scenarios remain pending.

## Portable credential storage

**Current behavior:** INI/JSON accept structured MSSQL connection fields,
including a plain SQL username/password, or an ODBC connection string. There is
no implemented encrypted credential envelope, local credential utility or
administration GUI. An integrated-authentication connection uses the server
process identity. AppServer carries only SQLProfile for selecting a database
profile. The strict parser does not yet accept proposed credential-provider
sections or fields.

This database boundary does not eliminate other client secrets: AppServer's
`HTTPToken` is currently plaintext too. The same provider design must cover
NETIO/admin/HTTP credentials on hbBridge and the relevant client credentials,
with independently provisioned keys. See the [full inventory](credentials.md).

**Proposed architecture:** retain public profile fields and a versioned encrypted
password envelope in INI/JSON, keeping its master key outside that file/repository.
A key-provider abstraction supports a protected external file on Windows/Linux
and optional environment/vault/OS providers. Use authenticated encryption from
an existing audited library, with version, salt/nonce, authentication tag and
explicit key identity. Fixed embedded keys and reversible obfuscation are not
password protection. The credential design targets stable SQL credentials:
in the operator's current Protheus deployment, database-password changes are
rare and require manual ODBC/DBAccess coordination. Optional OpenBao KV v2
would securely store and provide read access to that installed credential.
OpenBao, a database secrets engine, dynamic credentials and an MSSQL plugin
are not prerequisites for the initial provider or current MSSQL acceptance.

A local utility should prompt securely, update/remove/test credentials and
share its storage/connection core with a future GUI. Service account ownership,
file permissions, support for optional encryption master-key replacement,
backup and restoration must be tested on both operating systems. Changing the
master key re-encrypts the
same SQL password; OpenBao authentication-token renewal maintains access to
the same stored credential. Neither operation changes the database password.
Protected authentication bootstrap, CA/hostname validation, provider deadlines
and explicit refresh/unavailable-provider behavior remain necessary for the
optional OpenBao provider. The design retains future manual credential updates
and migration, without automatically changing external ODBC/DBAccess credentials.
A Windows credential manager is optional, not a prerequisite.
Do not extract DBAccess's internal password format; configure hbBridge's own
credential explicitly. See [credential design](credentials.md) and [TODO](../TODO.md).
