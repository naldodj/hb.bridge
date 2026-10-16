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

- [Configuration](unit/hbbridge.config.test.hb): defaults, precedence, paths,
  invalid values and endpoint conflicts.
- [INI](unit/hbbridge.config.ini.test.hb): JSON equivalence, autoload, BOM/CRLF,
  strict numbers, punctuation/paths/errors, multiple profiles and alias case.
- [Clock](unit/hbbridge.time.test.hb): monotonic waits/concurrent advancement.
- [Contract](contract/hbbridge.services.test.hb): registration/versions/channel
  permissions, types, independent metadata, handlers and JSON adaptation.
- [NETIO](integration/harbour/hbbridge.netio.test.hb): native arguments,
  core/discovery/addons, binary VF IO, separate admin, filters/credentials and
  stop/restart/rollback. Listeners choose free ports rather than installed ports.
- [HTTP](integration/harbour/hbbridge.http.test.hb): native hbhttpd routes,
  bearer/admin separation, shared Health/Echo/addon/SQL, NETIO equivalence,
  raw JSON body/errors, concurrent contexts, sanitized web status and
  shutdown/restart/startup rollback. HTTP acceptance is recorded separately;
  historical counts below predate this adapter.
- [Framing](integration/harbour/hbbridge.framing.test.hb): fragmented gzip,
  canonical lengths, CRC/truncation, optional budgets, deadlines, incremental
  codecs, exact 24-million-byte Echo and JSON/gzip beyond 16 MiB.
- [SQL](integration/harbour/hbbridge.query.test.hb): persistent SQLite, profiles,
  values/metadata, workarea/default-connection restoration, sanitized errors,
  16 concurrent calls, SQL pages/order/gaps/sentinel/full/partial/empty pages,
  representable ordinals, duplicate/reserved aliases, equivalent NETIO/TCP
  results and explicit case-sensitive slash profile selection.
- [MT](integration/harbour/hbbridge.server.test.hb): parallel/idle clients,
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

Local transport failure/recovery regression on 2026-10-13 passed **615 checks,
zero failures, no skips**, including 32 new assertions for SQL/profile/connection
failures and immediate recovery through NETIO, TCP and HTTP RPC/REST. Fixtures
use isolated SQLite and missing synthetic DSNs; this is not real-MSSQL outage,
native SQL timeout or AppServer acceptance. See [scope/log](../docs/acceptance.md#sql-transport-failures-and-recovery-on-2026-10-13).

The managed regression on 2026-10-14 passed **636 checks, zero failures and
no skips**, adding 21 assertions for optional MSSQL native timeout settings:
`tmp/tests-12c300f8399948e3bb3c20ee13eacc2d/results.log`. Real-MSSQL failure
coverage uses the separate opt-in route below.

## Opt-in real MSSQL core acceptance

Prepare a private profile using the [credential keys](../docs/configuration.md),
then run:

```powershell
./scripts/test-hbbridge-mssql.ps1 -Config C:/tmp/hbBridge.ini -Profile MSSQL/pData
```

The [MSSQL target](integration/harbour/hbbridge.mssql.test.hbp) uses the shared
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
and Harbour `UTF8EX`, with SQL authentication and alias `MSSQL/pData`. Log:
`tmp/mssql-tests-b3d676f0daaf470a97af605a98a9681c/results.log`.
The staged [SDDODBC patch](../config/patches/sddodbc.patch) covers incremental
`SQL_NO_TOTAL` reads, the binary field flag and UTF-16 surrogate pairs in UTF-8.
Fixtures preserve long text/binary values, embedded NULs, empty values and
NULLs. Chunk buffers impose no total application payload ceiling.
The 1000-row baseline ran three times in 31/32/31 ms, 94 ms total, concurrency
one, with memory unmeasured. This is a local reference, not a speed guarantee.
See [acceptance](../docs/acceptance.md) for precise scope and remaining cases.

A repeat on 2026-10-14 passed **92 checks, zero failures, no skips and
exit 0**, with SQL Server `16.0.1210.3`, database `pData` and the explicit
alias `MSSQL/pData`:
`tmp/mssql-tests-c49ac62b333d4c9d8e94aabf5134cb1b/results.log`.
This repeat confirms the existing core route after the native-timeout
changes; it does not add raw FLOAT JSON or general TCP Unicode acceptance.

## Opt-in real MSSQL failures and recovery

```powershell
./scripts/test-hbbridge-mssql.ps1 -Config C:/tmp/hbBridge.ini -Profile MSSQL/pData `
    -Failures -FailureODBCDriver 'ODBC Driver 18 for SQL Server'
```

The [failure target](integration/harbour/hbbridge.mssql.failure.test.hbp)
verifies invalid SQL, unknown profiles, a refused connection and a native
statement timeout through the core, NETIO, TCP and HTTP. A successful
constant SELECT follows each failure. It also compares an explicit zero
timeout against a 1-second native timeout using a bounded 4-second WAITFOR.
The working alias and installed driver are explicit prerequisites; secrets
remain in the private file. The refused endpoint reserves a loopback port
without listening and uses fictitious credentials. It does not stop the
SQL Server service or modify ERP tables.

On 2026-10-14 this route passed **46 checks, zero failures and no skips**:
`tmp/mssql-tests-e22aaf15b69e44ad806a5316060438ec/results.log`.
This native run is separate from Protheus execution. Add `-Serve` to keep
the isolated host available for 600 seconds after its native checks pass.
The runner prints its test ports; the fixture HTTP token is
`m06-http-test-only`. The [Protheus failure guide](../src/tlpp/tests/protheus/hbbridge.failure.test/README.md)
documents compilation, direct calls and `U_HBBridgeFailureCLI` named flags.
Automated AppServer CLI execution on 2026-10-14 passed **38 TCP checks**
(08:28:56–08:29:12 São Paulo, thread 29120) and **51 HTTP checks**
(08:28:13–08:28:29, thread 21392), both with zero failures and exit 0,
including the optional timeout profile. Logs:
`tmp/m06-protheus-tcp-clean-output-20261014.log` and
`tmp/m06-protheus-http-output-20261014.log`. The compiler had reported
30 successful sources/zero errors at 08:23:38, thread 32272:
`tmp/totvs-compile.log`. The compiled real RPO was executed with a separate
private AppServer INI; this is runtime acceptance through `-run`, without
manual SmartClient/WebApp or UI acceptance. The live dataset checks clear
state and `MoreToRead()` after failure; request counts/no retries have
separate acceptance in the 67-check dataset mock.
Native timeouts apply per statement, not as explicit server cancellation or
a shared request-wide SQL deadline.

## Protheus compilation and calls

The [consumer catalog](../examples/protheus/README.md) covers the reorganized
groups, including `hbbridge.helper.test/U_HBBridgeHelperTest` (12 accepted
pure checks), the accepted 67-check dataset mock and the interactive SRA/SX5 browses.
`build-totvs.cmd` now supplies an explicit recursive file list so dotted
directories do not omit their children.

Compile all src/tlpp, including tests/protheus. Public product APIs are
namespaced classes: HBBridgeClient, HBBridgeConfig, HBBridgeTime and
HBBridgeRPCDataSet. Existing procedure U_ entry points are retained; the
preprocessor also generates U_ from User Function, so no conversion is needed.
Renamed classes and optional-profile changes were manually accepted
on 2026-10-07 after reported recompilation following the `.hb` migration.
No compiler log or artifact hashes were supplied. The configurable
[build utility](../scripts/build-totvs.cmd) requires the licensed SDK.

Protheus sources remain under `src/tlpp` and the tests are now grouped in
subdirectories under [tests/protheus](../src/tlpp/tests/protheus):

| Directory | Entry points or support |
| --- | --- |
| `hbbridge.connection.test/` | `U_HBBridgeConnectionTest`. |
| `hbbridge.config.test/` | `U_HBBridgeConfigTest`. |
| `hbbridge.dataset.test/` | `U_HBBridgeDataSetTest` and its mock client. |
| `hbbridge.failure.test/` | Real SQL failure/recovery tests for TCP/HTTP and `U_HBBridgeFailureCLI`; [guide](../src/tlpp/tests/protheus/hbbridge.failure.test/README.md). |
| `hbbridge.http.test/` | Shared HTTP test and explicit MSSQL/SQLite wrappers. |
| `hbbridge.http.table.test/` | FWWebEx fixture/SX5 examples and `U_HBBridgeHTTPTableTest` mock: manual validation confirmed, 71 checks/zero failures on 2026-10-13; [evidence](../src/tlpp/tests/protheus/hbbridge.http.table.test/README.md). |
| `hbbridge.query.test/` | Shared Query test, SQLite wrapper and caller-side `FWGetTopInfo()` wrapper. |
| `hbbridge.browse.data.test/` | Generic browse example and caller-prepared SX5/SRA examples. |

Compile the nested sources with their product classes and includes. Moving a
source does not change its published `U_` entry point or constitute acceptance
of the new examples.

[Client INI template](../config/examples/protheus-appserver.ini): host/port/
timeout/budgets/chunk and optional SQLProfile. Omitted transport arguments
fall back to 127.0.0.1:1512, 30000 ms; 0.0.0.0 is not a client destination.
**SQLProfile now defaults to empty**. Each Query/dataset selects an alias;
the query test reports PROFILE_REQUIRED before I/O if none is supplied or
configured. sqlite_demo is only an example. Aliases do not resolve company,
tenant, xFilial or physical table names; the caller prepares business inputs.

[U_HBBridgeConfigTest](../src/tlpp/tests/protheus/hbbridge.config.test/hbbridge.config.test.tlpp)
checks defaults/INI/overrides, destination/numbers, zero/negative/fractional
budgets, native chunk capacity, active INI and now explicit/empty/invalid
profile selection. The 2026-10-04 acceptance covered 13 checks; the revised
16-check test passed on 2026-10-07 at 16:14:06, thread 30596, including
`explicitProfile`, `noForcedProfile` and `invalidProfile`.
Complement with no-argument Health/Query
against a configured nondefault destination.

[U_HBBridgeConnectionTest](../src/tlpp/tests/protheus/hbbridge.connection.test/hbbridge.connection.test.tlpp)
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

[U_HBBridgeQueryTest](../src/tlpp/tests/protheus/hbbridge.query.test/hbbridge.query.test.tlpp)
checks named fields/decimal/EOF/close, empty/invalid SQL, unknown profiles,
recovery and first/next/last/empty pages, hidden ordinals, gaps and invalid
order/page parameters. Run the [SQL example](../examples/sql/README.md), then
the separate Protheus call:

```advpl
U_HBBridgeQueryTest("sqlite_demo", "127.0.0.1", 1512, 30000)
U_HBBridgeQueryTest("MSSQL/pData", "127.0.0.1", 1512, 30000)
```

These four-argument calls run the constant SELECT fixture. The final optional
argument `lRunERPExamples` defaults to false. Passing true explicitly enables
the local SX5/SRA/SX3 examples for `MSSQL/pData` after the fixture:

```advpl
U_HBBridgeQueryTest("MSSQL/pData", "127.0.0.1", 1512, 30000, .T.)
```

Those examples use installation-specific physical table names and print field
values. Protheus prepares their SQL and dictionary formatting; this does not
make the bridge a Protheus dictionary/business-rule resolver. The examples
require separate manual acceptance and suitable caller-prepared inputs.

Use the [WebApp entry](https://localhost:4321/webapp/?p=U_HBBridgeQueryTest&e=PROTHEUS)
without arguments only with an appropriate optional SQLProfile configured.
The launcher does not edit the AppServer INI or execute tests. Config changes
alone need no TLPP recompile; source/class changes do. INI launchers use
sanitized --config-info from the updated executable. SERVICE_NOT_FOUND means
Query was not registered (usually no profiles); PROFILE_NOT_FOUND means
the service exists but the requested alias does not.

## Isolated TLPP dataset checks

Compile the whole `src/tlpp` tree, including the new
[HBBridgeDataSetMockClient](../src/tlpp/tests/protheus/hbbridge.dataset.test/hbbridge.dataset.mock.client.tlpp)
and [U_HBBridgeDataSetTest](../src/tlpp/tests/protheus/hbbridge.dataset.test/hbbridge.dataset.test.tlpp),
then call `U_HBBridgeDataSetTest()` or its
[WebApp entry](https://localhost:4321/webapp/?p=U_HBBridgeDataSetTest&e=PROTHEUS).
It requires no hbBridge listener, SQL profile, credentials or ERP table.

Manual AppServer execution on 2026-10-13 at 17:56:23 São Paulo time, thread
32332, passed **67 checks, zero failures and 31 mock calls**. Every keyed check
was true; the final result was `OK; checks=67; mock calls=31`. The test
covers `MoreToRead()` across pages; repeated checks without record consumption;
preserved page-local `Eof()`/`Skip()`; `Header()`/`FieldInfo()`
defensive copies; `FieldCount()`/`FieldName()` column order; `GetRow()` copies;
empty/closed state, malformed metadata and page failure/recovery. It also
covers selected-profile preservation/change, page snapshots, backward pages
and validated, unknown, empty and malformed row/page totals.
The local 2026-10-08 compile attempt returned exit 1,
`COMPILEERROR-300 Failed to open repository`, because `custom.rpo` was in use;
total/success/errors were `0/0/0`, without source compilation. Log:
`tmp/totvs-compile.log`. The active AppServer was not stopped. That attempt
concerned the earlier 45-check/17-call version. At the 2026-10-12 review, the
revised 67-check/31-call dataset fixture and 12 helper checks were prepared
with execution pending. The 2026-10-13 manual runs close that execution gap.
The historical `dsStructDefensiveAlias` check uses a `Header()` copy and
`FieldInfo()`; `Header()` remains the canonical API, with `DSStruct()` removed.

[U_HBBridgeHelperTest](../src/tlpp/tests/protheus/hbbridge.helper.test/hbbridge.helper.test.tlpp)
passed **12 pure checks, zero failures**, on 2026-10-13 at 17:56:45 São Paulo
time, thread 28300. Every keyed check was true; the final result was
`OK; checks=12`. Coverage includes SQL alias prefixing with literals/comments,
string replacements and typed custom-filter expressions.

These manual AppServer results accept D02's dataset/helper mock scope. No
network, database or ERP data is exercised. D03's broader UTF-8/FLOAT integrity
work remains open; independent M06 failure/recovery has separate runtime
acceptance above. Continue the remaining tasks in [WIP](../WIP.md).
See [dataset API and integrity
findings](../docs/dataset.md) and [acceptance](../docs/acceptance.md).

## Manual acceptance and remaining scenarios

[U_HBBridgeHTTPTest](../src/tlpp/tests/protheus/hbbridge.http.test/hbbridge.http.test.tlpp) exercises
`HBBridgeHTTPClient` with GET Health/discovery, POST Health/Echo/addon,
unknown/forbidden services, invalid bearer and recovery. It reuses the existing
dataset for optional first/next/last SQL pages. See [HTTP setup and calls](../examples/http/README.md).
The first manual report recorded **13 checks passed** on 2026-10-07, thread 25672.
Two later runs passed all 13 checks: thread 27296 (program start 16:10:40,
test 16:10:44–16:10:45) and thread 25456 (program start 16:15:02,
test 16:15:03–16:15:04), each in one second. Times are São Paulo local time.
This is AppServer evidence separate from the Harbour runner. None of these
2026-10-07 HTTP reports identifies its SQL profile/backend or establishes
HTTPS/broader Unicode; the identified 2026-10-08 runs are recorded below.

Manual AppServer report 2026-10-03: normal Health/ADDON/two Echo calls passed with
200000 identical bytes; varied request gzip 152964 bytes. Earlier milestone1
logs recorded three compiled sources without errors and successful RPC.
Initial SQLite/page acceptance: 2026-10-04 00:40:06, thread 41228,
sqlite_demo, all 29 checks true.

Later report recorded in the 2026-10-04 session reconfirmed those 29 checks,
RPC and all 13 client configuration checks, including activeAppServerIni.
Windows clock: Unix=false, raw delta 1097.692700, normalized 1097.773500 ms
after Sleep(1000), result OK. This is a manual AppServer run, separate from the
Harbour runner. It supplied no execution time/thread/hash/arguments/compile log and
does not prove nondefault destination selection. Earlier local stopping of
elevated TOTVS processes failed before compilation; manual acceptance superseded
that old execution gap, with history retained in the acceptance matrix.

The supplied 2026-10-07 log reconfirmed Query at 16:13:33, thread 27136:
all 29 checks true, `profile=sqlite_demo`. Configuration at 16:14:06,
thread 30596 passed all 16 revised checks. Connection at 16:14:31,
thread 27084 passed Health, ADDON and both exact 200000-byte Echo calls;
varied request gzip was 152964 bytes. Clock: `Unix=false`, raw
`1089.987500`, normalized `1090.088100 ms` after `Sleep(1000)`, `OK`.
With HTTP thread 25456 above, this accepts renamed TLPP and the `.hb` addon
paths after reported recompilation. It supplies times/threads,
but no actual compiler log, artifact hashes, arguments or effective destination.
These AppServer tests were not run through local automation.

On 2026-10-08 a manual AppServer report recorded **29 passing
MSSQL TCP checks**, thread 660, and **29 passing SQLite TCP checks**, thread
3192. The convenience entries `U_HBBridgeQueryTestMSSQL()` and
`U_HBBridgeQueryTestSQLite()` select the local example aliases; the generic
client retains no forced profile. This manual result is separate from the
92 native MSSQL checks above.

Subsequent manual AppServer runs passed **13 HTTP checks for each backend** on 2026-10-08:
`U_HBBridgeHTTPTestMSSQL`, thread 25976, program start 10:33:32, test
10:33:33–10:33:34 (one second); `U_HBBridgeHTTPTestSQLite`, thread 9916,
program start 10:34:06, test 10:34:07 (zero displayed seconds). São Paulo
times. Both include the shared dataset's first/next pages and values; the
entrypoint defaults select `MSSQL/pData` and `sqlite_demo`. These are manual
AppServer runs, separate from native automation. Transcript:
`tmp/protheus-http-mssql-sqlite-operator-20261008.log`.
See [acceptance](../docs/acceptance.md). D02's dataset mock acceptance completed
on 2026-10-13; D03's UTF-8/FLOAT integrity work remains open in
[WIP](../WIP.md); independent M06 controlled failures/recovery has separate
2026-10-14 acceptance above. No new native run
is inferred from these reports.

A later read-only constant probe found `CAST(123.4567 AS FLOAT)` remained
fractional natively but became `123` in JSON; `DECIMAL(15,4)` became `123.4567`
and `DECIMAL(16,2)` became `123.46`. The 92 native checks did not cover that
raw FLOAT JSON case. TCP also lacks HTTP's explicit `UTF8EX` execution and
currently falls back to CP437. Existing fixture results do not certify
arbitrary precision or accented TCP values. Runtime fixes and transport parity
checks remain pending; see [the analysis](../docs/dataset.md).

Pending: HTTPS, integrated/service identities, nondefault
destinations with omitted arguments, Linux, clock precision/adjustment/wrap, forced socket
timeout/connection failure/positive partial Send/Receive/GetError,
MAXSTRINGSIZE, broader Protheus null/nested/multibyte/non-ASCII values, larger/incompressible data
and Harbour codepage/revision compatibility. Persistent calls/pool/multiplex,
coalescence/disconnect/replay prevention, explicit-tenant session owner/TTL/
cleanup, TLS/JWT and optional gRPC/Smartlink/AMQP are roadmap work. Test technical
capacities separately from optional memory/worker/deadline policies.

## Manual controlled-failure acceptance on 2026-10-14

Confirmed manual `U_HBBridgeTCPAndHTTPFailureTest` execution at 14:30:50
São Paulo, thread 13796: **38 TCP checks and 51 HTTP checks, zero failures**.
This resolves the earlier normal-host prerequisite failure. Evidence and
native handshake observations are recorded in the
[manual acceptance](../docs/acceptance.md#manual-protheus-failure-recovery-on-2026-10-14); M07 has subsequent acceptance below.

## MSSQL concurrency and resource release (M07)

```powershell
./scripts/test-hbbridge-mssql.ps1 -Config C:/tmp/hbBridge.ini -Profile MSSQL/pData -Concurrency
./scripts/test-hbbridge-mssql.ps1 -Config C:/tmp/hbBridge.ini -Profile MSSQL/pData -Concurrency -Serve
```

`-Concurrency` and `-Failures` are mutually exclusive. Missing private config,
working MSSQL alias or backend prerequisite fails with exit 2; no successful
skip is allowed. The suite owns an isolated SQLite file and in-memory aliases
`m07/mssql-clone` and `m07/sqlite`, retaining the supplied working MSSQL alias.
It does not modify private INIs. Eight workers issue 192 calls through local,
NETIO, TCP and HTTP and verify profile/result isolation, recovery and logical
resource release under the unchanged SQL lifecycle mutex.

`-Serve` keeps the isolated host available after the worker checks and prints
its loopback TCP/HTTP ports and fixture token. It ends after 600 seconds,
Esc/Ctrl+Q, or `m07.stop` created in the printed run directory. Final cleanup
checks run after hosting ends; acceptance requires all 458 checks and exit 0.
The [Protheus suite](../src/tlpp/tests/protheus/hbbridge.concurrency.test/README.md)
uses four StartJobs, 112 calls and 417 checks. Both native and AppServer CLI
routes passed on 2026-10-14; [scope/evidence](../docs/acceptance.md#sql-concurrency-and-release-on-2026-10-14).
