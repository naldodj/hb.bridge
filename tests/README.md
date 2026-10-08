# Tests

[Português](README.pt-BR.md)

```powershell
./scripts/bootstrap.ps1
./scripts/test-hbbridge.ps1
```

The runner resolves managed Harbour/Zig, prepares isolated fixtures under
tmp/tests-<id>, compiles the shared product components through hbbridge.hbm,
records results.log and returns the suite exit code. It does not replace or
stop the installed product. Explicit HbCompileRoot/ZigPath overrides are
available; a standalone test target without fixtures may report SKIP, while
the runner prepares both. See [dependencies](../docs/dependencies.md).

## Automated Harbour coverage

- [Configuration](unit/hbbridgeconfigtest.hb): defaults, precedence, paths,
  invalid values and endpoint conflicts.
- [INI](unit/hbbridgeconfiginitest.hb): JSON equivalence, autoload, BOM/CRLF,
  strict numbers, punctuation/paths/errors, multiple profiles and alias case.
- [Clock](unit/hbbridgetimetest.hb): monotonic waits/concurrent advancement.
- [Contract](contract/hbbridgeservicestest.hb): registration/versions/channel
  permissions, types, independent metadata, handlers and JSON adaptation.
- [NETIO](integration/harbour/hbbridgenetiotest.hb): native arguments,
  core/discovery/addons, binary VF IO, separate admin, filters/credentials and
  stop/restart/rollback. Listeners choose free ports rather than installed ports.
- [HTTP](integration/harbour/hbbridgehttptest.hb): native hbhttpd routes,
  bearer/admin separation, shared Health/Echo/addon/SQL, NETIO equivalence,
  raw JSON body/errors, concurrent contexts, sanitized web status and
  shutdown/restart/startup rollback. HTTP acceptance is recorded separately;
  historical counts below predate this adapter.
- [Framing](integration/harbour/hbbridgeframingtest.hb): fragmented gzip,
  canonical lengths, CRC/truncation, optional budgets, deadlines, incremental
  codecs, exact 24-million-byte Echo and JSON/gzip beyond 16 MiB.
- [SQL](integration/harbour/hbbridgequerytest.hb): persistent SQLite, profiles,
  values/metadata, workarea/default-connection restoration, sanitized errors,
  16 concurrent calls, SQL pages/order/gaps/sentinel/full/partial/empty pages,
  representable ordinals, duplicate/reserved aliases, equivalent NETIO/TCP
  results and explicit case-sensitive slash profile selection.
- [MT](integration/harbour/hbbridgeservertest.hb): parallel/idle clients,
  invalid requests, worker settings, graceful shutdown, addon failure/isolation.
  The addon fixture holds 12 FORCELOCAL HRBs active behind a barrier and
  verifies owner/id plus counterBefore+1. Sequential reload may recycle
  STATIC values; a reset-to-one assertion would test an invalid assumption.
  A deliberate single-handle/12-thread counterprobe rejected 11 responses.
  Addons initialize per-call state explicitly; see
  [HRB semantics](../docs/milestone1.md#hrb-state-and-addon-ownership).

Prior Windows x64 run on 2026-10-04: **412 checks, zero failures, no skips**,
SQLite 3.53.4, log tmp/tests-236f1241c1174cf4b193c22f6eedb6e0/results.log.
That run included 383 previous checks, 26 INI checks and three strict SQL
rejections. New managed/renamed validation is recorded separately in
[acceptance](../docs/acceptance.md). The older 2026-10-01 MT baseline was
74 checks; the previous normalized 72-check baseline and fixture corrections
are in [reorganization](../docs/reorganization.md).

Managed-toolchain validation on 2026-10-04 passed **416 checks, zero failures,
no skips**, log tmp/tests-d1b829ff332c414f816a6e70748152d1/results.log.
It added two INI and two explicit SQL alias checks. This predates the
PascalCase/HTTP changes of 2026-10-06 and requires their separate validation.

## Opt-in real MSSQL core acceptance

Prepare a private profile using the [credential keys](../docs/configuration.md),
then run:

```powershell
./scripts/test-hbbridge-mssql.ps1 -Config C:/tmp/hbBridge.ini -Profile mssql/pData
```

The [MSSQL target](integration/harbour/hbbridgemssqltest.hbp) uses the shared
product components and an explicit alias. It opens no host listeners and does
not replace the running executable. Read-only constant fixtures cover named
results, native types/nulls/Unicode, pagination, recovery, caller workarea and
connection restoration, four concurrent callers and three 1000-row baseline
runs. Expected types and exact values are declared before the assertions;
unsupported representations fail instead of being silently converted.

Exit 2 means a missing or invalid prerequisite, including a missing profile
or unsuccessful connection probe; exit 1 means an assertion/runtime failure.
Only exit 0 after the actual checks accepts this core route. Logs under
`tmp/mssql-tests-<id>/results.log` omit connection strings and raw driver errors.
This opt-in route is separate from the default SQLite suite and from the
29 Protheus TCP checks. A compilation or prerequisite check certifies neither
MSSQL values nor AppServer/HTTP execution.

Execution on 2026-10-08 passed **92 checks, zero failures and no skips** against
SQL Server `16.0.1200.5`, database `pData`, ODBC Driver `18.6.2.1`, Windows x64
and Harbour `UTF8EX`, with SQL authentication and alias `mssql/pData`. Log:
`tmp/mssql-tests-b3d676f0daaf470a97af605a98a9681c/results.log`.
The staged [SDDODBC patch](../config/patches/sddodbc.patch) covers incremental
`SQL_NO_TOTAL` reads, the binary field flag and UTF-16 surrogate pairs in UTF-8.
Fixtures preserve long text/binary values, embedded NULs, empty values and
NULLs. Chunk buffers impose no total application payload ceiling.
The 1000-row baseline ran three times in 31/32/31 ms, 94 ms total, concurrency
one, with memory unmeasured. This is a local reference, not a speed guarantee.
See [acceptance](../docs/acceptance.md) for precise scope and remaining cases.

## Protheus compilation and calls

Compile all src/tlpp, including tests/protheus. Public product APIs are
namespaced classes: HBBridgeClient, HBBridgeConfig, HBBridgeTime and
HBBridgeRPCDataSet. Existing procedure U_ entry points are retained; the
preprocessor also generates U_ from User Function, so no conversion is needed.
Renamed classes and optional-profile changes were accepted by the operator
on 2026-10-07 after reported recompilation following the `.hb` migration.
No compiler log or artifact hashes were supplied. The configurable
[build utility](../scripts/build-totvs.cmd) requires the licensed SDK.

[Client INI template](../config/examples/protheus-appserver.ini): host/port/
timeout/budgets/chunk and optional SQLProfile. Omitted transport arguments
fall back to 127.0.0.1:1512, 30000 ms; 0.0.0.0 is not a client destination.
**SQLProfile now defaults to empty**. Each Query/dataset selects an alias;
the query test reports PROFILE_REQUIRED before I/O if none is supplied or
configured. sqlite_demo is only an example. Aliases do not resolve company,
tenant, xFilial or physical table names; the caller prepares business inputs.

[U_HBBridgeConfigTest](../src/tlpp/tests/protheus/hbbridgeconfigtest.tlpp)
checks defaults/INI/overrides, destination/numbers, zero/negative/fractional
budgets, native chunk capacity, active INI and now explicit/empty/invalid
profile selection. The 2026-10-04 acceptance covered 13 checks; the revised
16-check test passed on 2026-10-07 at 16:14:06, thread 30596, including
`explicitProfile`, `noForcedProfile` and `invalidProfile`.
Complement with no-argument Health/Query
against a configured nondefault destination.

[U_HBBridgeConnectionTest](../src/tlpp/tests/protheus/hbbridgeconnectiontest.tlpp)
checks TimeCounter after Sleep(1000), normalized units, nonregression and
deadline arithmetic. The reproduced Linux scale needs seconds × 1000
([issue 12](https://github.com/naldodj/totvs-protheus-open-issues/issues/12));
Windows uses milliseconds. A changed scale stops the test and reports raw data.
Then Health, Echo and ADDON.Execute use examples/hbbridgesampleaddon.hb with
__IS_THE_ADDONS_EXECUTION_ENABLED__. Echo compares all 200000 bytes, including
varied ASCII whose request gzip must exceed 65535 bytes. Logs summarize
integrity/size; Health still uses the demonstration Zig library.

The single active Protheus contract is HBBRIDGE/1, framed JSON and gzip.
TLPP uses GzStrComp/GzStrDecomp, C uses incremental codecs; the whole frame is
compressed but declared length counts uncompressed JSON. Constants live in
[hbbridge.h](../includes/hbbridge.h). Different signatures, unframed JSON and
non-gzip wrappers are rejected.

[U_HBBridgeQueryTest](../src/tlpp/tests/protheus/hbbridgequerytest.tlpp)
checks named fields/decimal/EOF/close, empty/invalid SQL, unknown profiles,
recovery and first/next/last/empty pages, hidden ordinals, gaps and invalid
order/page parameters. Run the [SQL example](../examples/sql/README.md), then
the separate Protheus call:

```advpl
U_HBBridgeQueryTest("sqlite_demo", "127.0.0.1", 1512, 30000)
U_HBBridgeQueryTest("mssql/pData", "127.0.0.1", 1512, 30000)
```

Use the [WebApp entry](https://localhost:4321/webapp/?p=U_HBBridgeQueryTest&e=PROTHEUS)
without arguments only with an appropriate optional SQLProfile configured.
The launcher does not edit the AppServer INI or execute tests. Config changes
alone need no TLPP recompile; source/class changes do. INI launchers use
sanitized --config-info from the updated executable. SERVICE_NOT_FOUND means
Query was not registered (usually no profiles); PROFILE_NOT_FOUND means
the service exists but the requested alias does not.

## Isolated TLPP dataset checks

Compile the whole `src/tlpp` tree, including the new
[HBBridgeDataSetMockClient](../src/tlpp/tests/protheus/hbbridgedatasetmockclient.tlpp)
and [U_HBBridgeDataSetTest](../src/tlpp/tests/protheus/hbbridgedatasettest.tlpp),
then call `U_HBBridgeDataSetTest()` or its
[WebApp entry](https://localhost:4321/webapp/?p=U_HBBridgeDataSetTest&e=PROTHEUS).
It requires no hbBridge listener, SQL profile, credentials or ERP table.

The expected successful result is **45 checks and 17 mock calls**. The test
covers `MoreToRead()` across pages; repeated checks without record consumption;
preserved page-local `Eof()`/`Skip()`; `Header()`/`DSStruct()`/`FieldInfo()`
defensive copies; `FieldCount()`/`FieldName()` column order; `GetRow()` copies;
empty/closed state, malformed metadata and page failure/recovery.
The agent's 2026-10-08 compile attempt returned exit 1,
`COMPILEERROR-300 Failed to open repository`, because `custom.rpo` was in use;
total/success/errors were `0/0/0`, without source compilation. Log:
`tmp/totvs-compile.log`. The active AppServer was not stopped. These new
sources still require compilation and execution; expected counts are not
accepted results.
See [dataset API and integrity findings](../docs/dataset.md).

## Manual acceptance and remaining scenarios

[U_HBBridgeHTTPTest](../src/tlpp/tests/protheus/hbbridgehttptest.tlpp) exercises
`HBBridgeHTTPClient` with GET Health/discovery, POST Health/Echo/addon,
unknown/forbidden services, invalid bearer and recovery. It reuses the existing
dataset for optional first/next/last SQL pages. See [HTTP setup and calls](../examples/http/README.md).
The operator first reported **13 checks passed** on 2026-10-07, thread 25672.
Two later runs passed all 13 checks: thread 27296 (program start 16:10:40,
test 16:10:44–16:10:45) and thread 25456 (program start 16:15:02,
test 16:15:03–16:15:04), each in one second. Times are São Paulo local time.
This is AppServer evidence separate from the Harbour runner. None of these
2026-10-07 HTTP reports identifies its SQL profile/backend or establishes
HTTPS/broader Unicode; the identified 2026-10-08 runs are recorded below.

Operator report 2026-10-03: normal Health/ADDON/two Echo calls passed with
200000 identical bytes; varied request gzip 152964 bytes. Earlier milestone1
logs recorded three compiled sources without errors and successful RPC.
Initial SQLite/page acceptance: 2026-10-04 00:40:06, thread 41228,
sqlite_demo, all 29 checks true.

Later report recorded in the 2026-10-04 session reconfirmed those 29 checks,
RPC and all 13 client configuration checks, including activeAppServerIni.
Windows clock: Unix=false, raw delta 1097.692700, normalized 1097.773500 ms
after Sleep(1000), result OK. This is operator execution, not the Harbour
runner. It supplied no execution time/thread/hash/arguments/compile log and
does not prove nondefault destination selection. Earlier agent stopping of
elevated TOTVS processes failed before compilation; manual acceptance superseded
that old execution gap, with history retained in the acceptance matrix.

The supplied 2026-10-07 log reconfirmed Query at 16:13:33, thread 27136:
all 29 checks true, `profile=sqlite_demo`. Configuration at 16:14:06,
thread 30596 passed all 16 revised checks. Connection at 16:14:31,
thread 27084 passed Health, ADDON and both exact 200000-byte Echo calls;
varied request gzip was 152964 bytes. Clock: `Unix=false`, raw
`1089.987500`, normalized `1090.088100 ms` after `Sleep(1000)`, `OK`.
With HTTP thread 25456 above, this accepts renamed TLPP and the `.hb` addon
paths after operator-reported recompilation. It supplies times/threads,
but no actual compiler log, artifact hashes, arguments or effective destination.
The agent did not run these AppServer tests.

On 2026-10-08 the operator supplied **29 passing
MSSQL TCP checks**, thread 660, and **29 passing SQLite TCP checks**, thread
3192. The convenience entries `U_HBBridgeQueryTestMSSQL()` and
`U_HBBridgeQueryTestSQLite()` select the local example aliases; the generic
client retains no forced profile. This operator result is separate from the
92 native MSSQL checks above.

The operator then passed **13 HTTP checks for each backend** on 2026-10-08:
`U_HBBridgeHTTPTestMSSQL`, thread 25976, program start 10:33:32, test
10:33:33–10:33:34 (one second); `U_HBBridgeHTTPTestSQLite`, thread 9916,
program start 10:34:06, test 10:34:07 (zero displayed seconds). São Paulo
times. Both include the shared dataset's first/next pages and values; the
entrypoint defaults select `mssql/pData` and `sqlite_demo`. These are operator
AppServer runs, separate from native automation. Transcript:
`tmp/protheus-http-mssql-sqlite-operator-20261008.log`.
See [acceptance](../docs/acceptance.md). The owner's new dataset request and
UTF-8/FLOAT findings take priority as D02/D03 in [WIP](../WIP.md), before M06
controlled failures/recovery. No new native run is inferred from these reports.

A later read-only constant probe found `CAST(123.4567 AS FLOAT)` remained
fractional natively but became `123` in JSON; `DECIMAL(15,4)` became `123.4567`
and `DECIMAL(16,2)` became `123.46`. The 92 native checks did not cover that
raw FLOAT JSON case. TCP also lacks HTTP's explicit `UTF8EX` execution and
currently falls back to CP437. Existing fixture results do not certify
arbitrary precision or accented TCP values. Runtime fixes and transport parity
checks remain pending; see [the analysis](../docs/dataset.md).

Pending: HTTPS, integrated/service identities, nondefault
host/port/profile, Linux, clock precision/adjustment/wrap, forced socket
timeout/connection failure/positive partial Send/Receive/GetError,
MAXSTRINGSIZE, broader Protheus null/nested/multibyte/non-ASCII values, larger/incompressible data
and Harbour codepage/revision compatibility. Persistent calls/pool/multiplex,
coalescence/disconnect/replay prevention, explicit-tenant session owner/TTL/
cleanup, TLS/JWT and optional gRPC/Smartlink/AMQP are roadmap work. Test technical
capacities separately from optional memory/worker/deadline policies.
