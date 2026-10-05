# Milestone 3: first RPCRDD.Query delivery

[Português (Brasil)](milestone3-sql.pt-BR.md)

[The SQL service](../src/hb/services/hbbridgequery.prg) uses native Harbour
rddsql/SQLMIX, linked sddsqlt3 for SQLite and sddodbc for MSSQL/ODBC; it does
not implement a new RDD.
Operator SQLite dataset/page acceptance: 2026-10-04 00:40:06, all 29 checks.
Real MSSQL remains pending. A later report in the same session accepted all
13 AppServer-INI client configuration checks, clock/RPC and SQLite again.
These reports concern the Windows target, not new renames/Linux/nondefault
destinations.

## Server profiles

sqlProfiles is the host's named hash, from JSON or INI `[SQL/profile_name]`,
empty by default. RPCRDD.Query is registered only if profiles exist.
The client sends alias; paths/DSN/credentials stay on the server and are
excluded from discovery/service errors. Current profile files do not implement
encrypted credential storage; see [the portable proposal](credentials.md).

Precedence: defaults < one file < CLI. Automatic hbbridge.ini is executable-
adjacent; an explicit file replaces that selection without merging.
See [configuration](configuration.md).

[SQLite JSON](../config/examples/sqlite.json) selects sqlite_demo / :memory:.
A new in-memory database is created per call, allowing constant queries without
tables/services. Persistent data requires an existing SQLite file; relative
paths resolve against the selected configuration. Missing files return
CONNECTION_FAILED instead of silently creating an empty database.

[MSSQL JSON](../config/examples/mssql.json) selects mssql_demo with a
connectionString/ODBC DSN. The DSN/driver must be visible to hbBridge's process.
This is direct ODBC, independent of DBAccess and Protheus LOCALFILES.
[SQLite INI](../config/examples/sqlite.ini) and
[MSSQL INI](../config/examples/mssql.ini) configure equivalent profiles.

## Named contract

Version 1 input:

~~~json
{
    "service": "RPCRDD.Query",
    "params": {
        "alias": "sqlite_demo",
        "sql": "SELECT 1 AS ID, 'Harbour' AS NAME"
    }
}
~~~

Output: success, header, rows, rowCount, driver, resultVersion=1.
header is keyed by uppercase column name, with position/type/length/decimals
from the RDD. rows is keyed by decimal ordinal ("1", "2", ...); each row is
a named hash. Navigate 1..rowCount, not hash enumeration order.

Empty queries retain header and return rowCount=0/rows={}.
Duplicate normalized names yield AMBIGUOUS_COLUMN; use distinct aliases.
Unknown profiles, malformed inputs, missing connections and invalid SQL have
identified errors. Harbour hashes/TLPP JSONObject implement the contract;
arrays appear only at native RDD API boundaries.

Only alias/sql/optional page are allowed; extra keys return INVALID_PARAMS.
SQL is passed to the native connector. This delivery has no SQL parser,
table authorization or bound parameters; database permissions are those of the
configured connection.

## Database-side pagination

~~~json
{
    "alias": "sqlite_demo",
    "sql": "SELECT 10 AS ID, 'Harbour' AS NAME UNION ALL SELECT 50, 'hbBridge'",
    "page": { "number": 1, "size": 1, "orderBy": "ID ASC" }
}
~~~

The server wraps SQL with ROW_NUMBER() OVER(ORDER BY ...) and BETWEEN:
start=(number-1)*size+1; end=number*size+1.
The extra row determines hasNext without entering the dataset.
This follows the reviewed local userrestcrudadvpl.prw pattern; its ordinal
represents result position, not primary-key value, so gaps work.
An outer ORDER BY on the ordinal preserves result order.
References: [SQLite window functions](https://www.sqlite.org/windowfunctions.html),
[MSSQL ROW_NUMBER](https://learn.microsoft.com/en-us/sql/t-sql/functions/row-number-transact-sql).

The result adds page={number,size,hasNext,firstRow,lastRow}.
rowCount covers only the page; empty firstRow/lastRow are zero.
Rows restart at "1" each page. Internal __HBBRIDGE_ROWNO is hidden.

orderBy accepts exposed simple column names separated by commas with optional
ASC/DESC; ASCII letters/underscore, then digits are allowed.
Expressions are rejected. Use distinct aliases, avoiding ":" and reserved
__HBBRIDGE_ROWNO; SQLite's duplicate ":1" renames are rejected as ambiguous.
Base SQL must be a valid subquery in both engines; put page order in orderBy,
especially for MSSQL. One trailing semicolon is removed before wrapping.

number/size are positive integers without arbitrary row/page ceilings.
The last ordinal plus sentinel must fit **2^53-1**, the JSON/TLPP exact-integer
range. Invalid requests return INVALID_PAGE.
Use a unique tie-breaker. Each page is a fresh query; concurrent writes can shift
rows. Snapshot, keyset/cursor pagination and broader order grammar are future work.

## Resource lifecycle and cost

Each call connects, opens an area, reads, closes and disconnects, restoring the
previous selected area/default connection. Inspected RDDSQL uses global C
connection tables; a service mutex covers the entire lifecycle.
Concurrent requests are isolated but SQL execution is serialized here.
Direct RDDSQL addons must coordinate with that mutex before concurrent acceptance.

RDD/service/client JSON results are materialized. Runtime/memory/transport
policies apply. With page, SQL returns at most size+1, response at most size;
the bridge does not fetch all rows to slice them.
The database may still scan/sort extensively for deep pages.
Cursors, cancellation and SQL execution timeout are not implemented;
network deadlines do not interrupt a blocking connector query.

Types/nulls follow the linked RDD. SQLite regression distinguishes NULL
expressions from empty text, not every declared nullable-column mapping.
Some connectors substitute defaults. Dates/BLOBs/codepages, expanded precision
and explicit null semantics remain contract work.

## Protheus dataset and test

[HBBridgeRPCDataSet](../src/tlpp/hbbridgerpcdataset.tlpp) uses JSONObject:
opensql, fieldget, skip, eof, close, rowcount, errorcode, errormessage.
openpage(profile,sql,number,size,orderBy), nextpage, hasnextpage, pagenumber,
pagesize implement explicit pages. skip stays in the current page;
nextpage makes a new call.

new(oClient) accepts an existing HBBridgeClient; new() creates one from
AppServer [hbBridge], falling back to defaults when keys are absent.
close releases the result; open failure leaves an empty dataset.
The dataset owns the complete response so nested JSON references remain valid.

Stop an old host with Ctrl+Q, build the current product, then launch from root:

~~~powershell
pwsh ./examples/sql/run.ps1
pwsh ./examples/sql/run.ps1 -Config config/examples/sqlite.ini
~~~

[The SQL launcher](../examples/sql/README.md) defaults to sqlite_demo,
validates configuration and prints the Protheus call.
It shares [the product launcher](../scripts/run-hbbridge.ps1) with the minimal
example. Starting the server does not execute AppServer tests.
INI preparation uses the updated binary's sanitized --config-info.
JSON remains supported.

Compile the entire src/tlpp tree, including
[hbbridgequerytest.tlpp](../src/tlpp/tests/protheus/hbbridgequerytest.tlpp),
through scripts/build-totvs.cmd or the configured TOTVS tools.
Changing only a server SQL profile does not require recompiling updated TLPP.

hbbridge.client.HBBridgeConfig:read() selects GetSrvIniName and reads
GetPvProfString values from [hbBridge]. Merge
[the template](../config/examples/protheus-appserver.ini) into the actual
AppServer INI: Host/Port/TimeoutMs/MaxPayloadBytes/MaxWireBytes/ReadChunkBytes/
SQLProfile. This client INI differs from Harbour host configuration.
Explicit test/client arguments take precedence.

Run [U_HBBridgeQueryTest](https://localhost:4321/webapp/?p=U_HBBridgeQueryTest&e=PROTHEUS)
or `U_HBBridgeQueryTest("sqlite_demo", "127.0.0.1", 1512, 30000)`.
It checks named fields, two rows/decimal, navigation/EOF/closure, empty results,
SQL/profile errors and recovery, plus first/next/last pages, gapped IDs,
hidden ordinal, local EOF and invalid page/order inputs.

~~~powershell
pwsh ./examples/sql/run.ps1 -Config config/examples/mssql.ini -Profile mssql_demo
~~~

For MSSQL pass mssql_demo as the first test argument, or set the client section.
The no-argument WebApp URL uses AppServer values, falling back to
sqlite_demo / 127.0.0.1:1512. The launcher prints host settings but does not
modify AppServer INI. Keep U_HBBridgeConnectionTest for normal RPC.

### SERVICE_NOT_FOUND troubleshooting

SERVICE_NOT_FOUND means the connected process has not registered RPCRDD.Query;
it occurs **before** connecting to SQL.
An unknown alias on a registered service returns PROFILE_NOT_FOUND instead.
Defaults/config/examples/hbbridge.json use empty sqlProfiles.

Restart the updated host with the SQL launcher/configuration. Startup prints
`RPCRDD.Query enabled; SQL profiles=1` or
`RPCRDD.Query disabled; sqlProfiles is empty`, excluding credentials/paths.
Service.List must show SQL on the test's actual endpoint.

The minimal launcher forwards only explicit arguments; without Config,
the host searches out/hbbridge.ini. If no profiles are configured, SQL stays
disabled. It can also receive the SQLite INI/JSON; the SQL launcher adds profile
validation/test guidance. No TLPP recompile is required for host configuration alone.

## Regression and acceptance evidence

[SQL tests](../tests/integration/harbour/hbbridgequerytest.prg) create an isolated
persistent SQLite file and compare NETIO/TCP named results under concurrency.
Coverage includes empty/null expressions/profiles/errors, complete/partial/empty
pages, compound/descending order, gaps, metadata, reserved/duplicate aliases
and numeric boundaries.

Pre-refactor current baseline on 2026-10-04:
**412 checks, zero failures, no skips**, Harbour 3.2.1dev(r2608271822),
Zig 0.16.0, Windows x64, linked SQLite **3.53.4** from sqlite_version().
Log: tmp/tests-236f1241c1174cf4b193c22f6eedb6e0/results.log.
Compared with 383 checks: 26 INI cases and 3 strict invalid driver/order-direction
rejections. The SQL test has its own NETIO password because passing an empty
password can inherit a previous connection's credential.

The agent's TOTVS attempt stopped before compilation because process shutdown
failed (tmp/marco3-totvs-build.log).
The operator accepted Query at 00:40:06, thread 41228, sqlite_demo, all 29 true.
Later they confirmed all 29 again, 13 configuration checks, Health/ADDON/two
200,000-byte Echo results, varied gzip 152,964 bytes, Windows clock raw
1097.692700/normalized1097.773500ms after Sleep(1000), OK.
Time/thread/artifact hashes/call arguments/build log were not provided for that
later report. MSSQL, nondefault no-argument destinations, forced partial sends,
failures/timeouts and other platforms remain pending.

An isolated product JSON/page smoke returned ID=10, rowCount=1, hasNext=true;
a later INI launcher smoke did the same without replacing the active canonical
installation. Historical smoke is not new TLPP acceptance.
Detailed dates/hashes are in [acceptance](acceptance.md).

Primary references:
[RDDSQL](https://github.com/harbour/core/blob/master/contrib/rddsql/readme.txt),
[connection table](https://github.com/harbour/core/blob/master/contrib/rddsql/sqlbase.c),
[SQLite example](https://github.com/harbour/core/blob/master/contrib/sddsqlt3/tests/test.prg),
[ODBC example](https://github.com/harbour/core/blob/master/contrib/sddodbc/tests/test1.prg).
