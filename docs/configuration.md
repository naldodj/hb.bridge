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
| `[SQL/profile_name]` | SQLite: `Driver`/`Database`; MSSQL: `Driver`/`ConnectionString`. |

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
ConnectionString=DSN=hbBridgeMSSQL;Trusted_Connection=Yes;
~~~

An MSSQL profile advertises the service, but queries require an available
ODBC driver/DSN. Select the same alias in the Protheus test:

~~~powershell
pwsh ./examples/sql/run.ps1 -Config config/examples/mssql.ini -Profile mssql_demo
~~~

## Reading rules

INI section/key names are case-insensitive; SQL aliases retain case as in JSON.
Driver values normalize to lowercase. Use `key=value` without extra quotes.
Outer spaces/tabs are trimmed; internal content stays intact.
Numbers use canonical decimal representation and shared validation.
Empty passwords preserve disabled/default behavior.

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
~~~

Host/Port select the Protheus endpoint, using a real IP/DNS; `0.0.0.0` is a
server bind. SQLProfile selects a remote alias; database credentials stay on
hbBridge. Client TimeoutMs must be positive. Zero budgets add no application
ceiling; positive values enforce local policies. ReadChunkBytes fits the native
signed 32-bit socket argument. Actual AppServer MAXSTRINGSIZE/memory still apply;
negotiation and blocks are pending, and no setting is automatically derived
from MAXSTRINGSIZE.

Static [HBBridgeConfig](../src/tlpp/hbbridgeconfig.tlpp), namespace
`hbbridge.client`, uses `GetSrvIniName()` and `GetPvProfString()`.
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
oClient := hbbridge.client.HBBridgeClient():new()
// Override Host/Port; retain other INI settings.
oClient := hbbridge.client.HBBridgeClient():new("bridge.example.local", 1512)
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

## Portable credential storage

**Current behavior:** INI/JSON can contain an ODBC connection string; there is
no implemented encrypted credential envelope, local credential utility or
administration GUI. An integrated-authentication connection uses the server
process identity. AppServer carries only SQLProfile.

**Proposed architecture:** retain public profile fields and a versioned encrypted
password envelope in INI/JSON, keeping its master key outside that file/repository.
A key-provider abstraction supports a protected external file on Windows/Linux
and optional environment/vault/OS providers. Use authenticated encryption from
an existing audited library, with version, salt/nonce, authentication tag and
explicit key identity. Fixed embedded keys and reversible obfuscation are not
password protection.

A local utility should prompt securely, update/remove/test credentials and
share its storage/connection core with a future GUI. Service account ownership,
file permissions, key rotation, backup and restoration must be tested on both
operating systems. A Windows credential manager is optional, not a prerequisite.
Do not extract DBAccess's internal password format; configure hbBridge's own
credential explicitly. See [credential design](credentials.md) and [TODO](../TODO.md).
