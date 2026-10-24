# Protheus client and server performance benchmark

[Português](README.pt-BR.md) · [Active package](../../../../../WIP.md) · [Test catalog](../../../../../tests/README.md)

`HBBridge.Test.HBBridgeBenchmarkTest` measures the production TLPP TCP and HTTP
clients against the same read-only MSSQL fixture, `m08.constant.v1`. The fixture
contains IDs from 1 through the requested row count, `NAME = hbbridge-<ID>` and
`AMOUNT = ID / 4`, projected as `DECIMAL(15,2)`. Five constant digit relations
support 1 through 100000 rows without reading or changing ERP tables.
That bound belongs to this fixture, not to hbBridge payload or query capacity.
The profile is an explicit opaque alias; no demo or Protheus database is assumed.

Compile all sources in this directory together with the complete `src/tlpp`
tree. Selected hbBridge routes require an existing process with the selected
MSSQL profile and their required listeners. No service restart or configuration edit is
performed by the benchmark.

The selected `http` route requires gzip and sends
`Accept-Encoding: gzip, identity;q=0`, regardless of `HTTPAcceptEncoding` in
the AppServer INI. Reports record `httpRequireGzip=true` and the effective
`httpAcceptEncoding`; identity fallback fails with `HTTP_COMPRESSION_REQUIRED`.
Keep server `[HTTP] Compression=auto`. `Compression=off` yields 406 for this
request. Recompile the full TLPP client and benchmark together to enable this
contract; see [HTTP validation](../../../../../docs/http.md#http-review-on-2026-10-24).

## Visual benchmark

Run `U_HBBridgeBenchmark()` in the Protheus UI with FWWebEx and
`FWWebEx.Tools.FWExampleTools` installed in the RPO. The page follows the
[HTTP table example](../hbbridge.http.table.test/README.md) and uses the same
measurement core as the command-line benchmark. It does not require a chart
library: the average and iteration charts use SVG, with exact values in tables.
FWWebEx is an optional dependency of the visual consumer, not of the core.

The form has five numeric fixture/call fields: rows per iteration, rows per
page, measured iterations, warmups and call timeout. An additional operational
timeout ceiling and automatic/manual selection control the effective budget. Route controls
select actual execution; presets only select server-enabled capabilities. Profile,
TCP destination, HTTP URL and HTTP token are selected on the AppServer; the
browser cannot supply SQL, credentials or a different destination/profile.
`U_HBBridgeBenchmark()` reads the active `[hbBridge]` section, including
`SQLProfile`. Explicit trusted parameters can be supplied from TLPP:

```tlpp
HBBridge.Examples.HBBridgeBenchmarkExample():Show("MSSQL/pData", ;
    "127.0.0.1", 1512, "http://127.0.0.1:8080", cToken, 30)
```

The page displays complete/partial status, selected/skipped routes, measured
row/call counts, min/max/mean/median/P95, population standard deviation and CV,
row/call throughput, per-iteration latency and separate warmup
observations. Failed or missing samples create chart gaps; partial results
remain marked as failed. Large series are sampled for display; full samples
remain in the JSON export. Memory remains explicitly unavailable unless
separately measured. Timing does not identify the physical pooling policy.

`Export JSON` downloads the full report. `Export HTML report` downloads a
standalone results page containing the rendered tables and SVG charts, with
no execution form, channel or scripts. The HTML snapshot reflects the displayed
sampled charts and warmup table; preserve JSON for complete machine-readable
samples. CSV export is not implemented.

Only one request can be outstanding per dialog. A waiting notice does not
cancel AppServer processing or enable another run. Closing the page removes
its response listener; it does not cancel an already executing benchmark.
Instance/request identifiers reject stale responses. Large counts can make
the synchronous AppServer callback run for a long time; start with the defaults.

`U_HBBridgeBenchmarkVisualTest()` is the separate deterministic controller
regression, without SQL/HTTP execution. V01/V02 acceptance on 2026-10-19
combines three manual five-route runs with separate controller/REST/lifecycle
and Chromium checks. [Evidence and limits](../../../../../docs/acceptance.md#v01-v02-benchmark-acceptance-on-2026-10-19).
Earlier M08 results retain their own scope. D03/M09 were pending at that
acceptance; their later closure and the current package are recorded in WIP.

## Programmatic measurement and command line

`HBBridge.Test.HBBridgeBenchmarkTest():Measure(...)` accepts the same arguments
as `Run(...)` and returns the report `JSONObject` to its caller without printing
the summary. The caller owns the returned object and releases it with
`FreeObj(@jReport)` after reading or exporting it. `Run(...)` keeps the existing
numeric 0/1 result and console summary. The visual controller calls `Measure`
so the same fixture, traversal checks, time source and statistics apply.

```tlpp
cToken := GetPvProfString("hbBridge", "HTTPToken", "", GetSrvIniName())
nResult := U_HBBridgeBenchmarkTest("MSSQL/pData", "127.0.0.1", 1512, ;
    "http://127.0.0.1:8080", cToken, 30, 1000, 100, 5, 2)
```

The argument order is profile, TCP host, TCP port, HTTP URL, HTTP token,
per-request timeout in seconds, rows per iteration, page size, measured
iterations and warmup iterations. Only the profile is required. Omitted
transport settings read the active AppServer `[hbBridge]` Host, Port,
HTTPURL and HTTPToken keys. Numeric defaults are 30 seconds, 1000 rows,
100 rows per page, five measured iterations and two warmups. Page size accepts
1 through 100000; measured iterations accept 1 through 1000000 and warmup
accepts 0 through 1000000. These are harness counts, not product limits.

For a licensed AppServer command-line environment, use the existing private
CLI INI described in the [failure guide](../hbbridge.failure.test/README.md):

```bat
appserver.exe -ini private-benchmark.ini -run=U_HBBridgeBenchmarkCLI -env=PROTHEUS --profile=MSSQL/pData --rows=1000 --page-size=100 --iterations=5 --warmup=2 --timeout=30
```

Optional flags `--host`, `--port`, `--url` and `--token` override the same
transport settings; prefer the private INI for credentials. Recognized flags
must be unique and use `--name=value`. Numeric values require canonical decimal
integers; only `--warmup` permits zero. The CLI borrows the native variadic
argument array; keyed JSON objects hold samples and reports. No response,
exception description, complete SQL, endpoint or token is printed.

Each selected scenario runs at concurrency **1**, in fixed route order. The
default remains TCP followed by HTTP. Each selected route performs
its own warmup before its measured iterations. One iteration opens page one,
fetches every subsequent page with the production dataset, validates every
ID/name/amount plus column order and page totals, and closes the dataset.
The same SQL and `ID ASC` order apply to both transports. Each page is one RPC
request and also performs the product's COUNT query. With default settings,
each transport makes 20 warmup and 50 measured RPC calls, reading 2000 warmup
and 5000 measured rows. It does not mix `StartJob`, readiness barriers or
worker launch pacing into the baseline.

The normalized `HBBridgeTime`/`TimeCounter` clock measures the full traversal,
including network calls, JSON/dataset processing, value checks and close.
Client construction is outside the iteration timer. A regressing counter fails
the run. Warmup samples remain visible but are excluded from measured
total/min/max/average. Statistics summarize successful measured iterations;
compare runs only when the complete report has `success=true` and the public
entry returns 0. A failed warmup or iteration stops that scenario; failures
are retained in the report and cannot become a successful benchmark.

The summary is a single `hbBridge benchmark summary:` JSON record with fixture,
volume, iteration counts, concurrency, transport order and per-iteration samples.
Memory is explicitly `UNAVAILABLE` inside this TLPP harness: no unverified or
private memory API is used. External AppServer process sampling can complement
the report; process memory includes shared runtime and other activity, and is
not this thread's allocation or proof of leak freedom. Preserve the AppServer,
hbBridge and ODBC versions, host configuration, pooling mode, process memory
source and sampling interval with each run. Physical pooling is not inferred
from successful queries or warmup. Fixed transport order and shared server/SQL
cache conditions are comparison limitations. This baseline introduces no
speed threshold and does not establish D03 text/FLOAT integrity acceptance.

Validation confirmed on 2026-10-16: all 34 TLPP sources compiled with zero
source errors, including this class/entry. Compiler finalization separately
returned 0xC0000409; normal services were restored. Actual AppServer CLI
execution passed both routes with exit 0: five measured traversals/50 calls/
5000 rows per route plus two warmups each. Mean complete traversal times were
1118.14 ms TCP and 1491.91 ms HTTP against the identified isolated server with
ODBC policy driver. External memory covers the combined process lifecycle,
not each transport separately. [Evidence and limits](../../../../../docs/acceptance.md#m08-performance-baseline-on-2026-10-16).

The tested AppServer parser rejects directory information in `-ini`.
`run-protheus-cli.ps1` therefore requires the explicitly supplied private INI
beside the explicitly supplied isolated SDK executable. It passes another INI
as a basename argument and omits `-ini` for the default `appserver.ini`.
It never copies a private INI into or changes a running installation. See the
[TOTVS command-line reference](https://tdn.totvs.com/display/tec/Application%2BServer%2B-%2BCommand%2BLine)
and [launcher guide](../../../../../scripts/README.md).
An isolated destination is available through the native runner's
`-Route http -ServeSeconds 600`; use its `http/endpoints.json` ports/profile
and public fixture-only token. See [methodology](../../../../../docs/benchmarking.md).

Additional manual validation recorded at 04:53:47 São Paulo on 2026-10-16:
both routes passed five measured traversals plus two warmups each. Means per
1000-row traversal: 1039.60 ms TCP and 1122.12 ms HTTP. Memory is unavailable;
pool/build/process exit are not supplied by this summary. Preserve its scope
separately from the automated run.
[Manual evidence](../../../../../docs/acceptance.md#m08-manual-protheus-validation-on-2026-10-16).

## Isolated routes and statistical controls

`Run`, `Measure` and `U_HBBridgeBenchmarkTest` accept an optional `jRoutes`
after `jComparison`. Pass a `JSONObject` with all six boolean fields:

```tlpp
jRoutes := JSONObject():New()
jRoutes["tcp"] := .F.
jRoutes["http"] := .T.
jRoutes["protheusStartJob"] := .F.
jRoutes["protheusRest"] := .F.
jRoutes["hbbridgeAddon"] := .F.
jRoutes["protheusServer"] := .F.
jReport := HBBridge.Test.HBBridgeBenchmarkTest():Measure("MSSQL/pData", ;
    Nil, Nil, "http://127.0.0.1:8080", cToken, 30, 1000, 100, 5, 2, ;
    Nil, jRoutes)
// The caller reads/exports the result, then releases both owned objects.
FreeObj(@jReport)
FreeObj(@jRoutes)
```

Only selected routes are constructed/executed. A malformed TCP destination
does not invalidate an HTTP-only run; missing Protheus REST credentials do
not invalidate a StartJob-only run. No selection means the existing default:
TCP/HTTP, with the previous optional Protheus/addon settings; the new server-only
route is opt-in. A supplied map must be boolean, contain no unknown keys and
select at least one route. The previous five-key map remains valid, normalizing
missing `protheusServer` to `false`; current reports/maps contain all six keys.

CLI supports explicit isolation without combining legacy comparison flags:

```text
--profile=MSSQL/pData --routes=http --rows=1000 --page-size=100 --iterations=5 --warmup=2 --timeout=30
--profile=MSSQL/pData --routes=protheusStartJob --company=99 --branch=01 --rows=1000 --page-size=100 --iterations=5 --warmup=2 --timeout=60
--profile=MSSQL/pData --routes=hbbridgeAddon --rows=1000 --page-size=100 --iterations=500 --warmup=2 --timeout=auto --timeout-max=900
--profile=MSSQL/pData --routes=protheusServer --company=99 --branch=01 --rows=1000 --page-size=100 --iterations=5 --warmup=2 --timeout=auto --timeout-max=900
```

Append these arguments to the existing licensed AppServer CLI entry. Destinations,
REST credentials and addon module remain private server/TLPP settings. The
explicit timeout policy supplies the effective complete server-call budget;
legacy calls without a policy preserve the private addon timeout setting. `--routes` uses the exact names `tcp`, `http`,
`protheusStartJob`, `protheusRest`, `hbbridgeAddon`, `protheusServer`; unknown, duplicate or empty
selections fail before execution. Selected routes run in that fixed order.
An addon-only run still needs its TCP transport. The visual route controls
can select only capabilities enabled by the trusted example/controller.

Reports add `routeSelectionVersion=1`, a complete `selectedRoutes` boolean map
and `routeStates` (`skipped`, `notStarted`, `completed`, `failed`). An unselected
route is skipped, not passed. Only all selected routes completing successfully
can produce a successful run; failures and partial observations remain visible.

Successful measured samples supply `sampleCount`, `medianMs`, `p95Ms`,
`stdDevMs`, `cvPct`, `throughputRowsSec`, `throughputCallsSec` and
`statisticsMethod`. P95 uses nearest rank, standard deviation is population
based, and warmups/failures are excluded. Throughput covers complete validated
traversals, not raw SQL/network transfer. Five samples make P95 the observed
maximum; this is insufficient to infer a production tail. Missing/zero
denominators remain unavailable. Relative client comparisons require matching
complete successful workloads; addon and Protheus-server internal timing remain
together in a server-processing section, outside client charts and rankings.
Complete calls remain in a separate totals section, not average cards.
See the [statistical method and timing scopes](../../../../../docs/benchmarking.md#route-selection-and-measured-statistics).

This maintenance requires its own focused regression/real AppServer checks.
Current isolated compilation passed for 54 TLPP sources, zero errors/exit 0;
actual isolated AppServer CLI passed 82 control, 81 visual/controller and 43
REST contract checks.
A real MSSQL single-StartJob correctness smoke passed (10 rows, page size 5,
two measured traversals, one warmup); it is not a performance baseline.
Post-codec full native/addon suites passed 752/93 checks, including exact
SQL-mock TCP iteration boundaries. Final 54-source TLPP compilation passed
with zero errors/exit 0.
Latest actual Chromium checks passed three core suites: 69 main DOM assertions,
30 optional-route/server/timeout/layout assertions and the no-channel guard. A later
actual-TLPP-client 500-iteration SQL-mock reproduction isolated an aggregate
precision failure at the addon JSON ABI. Actual TLPP-client 255/500 SQL-mock checks passed after the codec repair;
real MSSQL 255 measured + two warmups also passed with 1000 rows/page100,
ODBC pooling off and no artificial sleeps. A later provided FWWebEx1500 run passed; its source/pooling identity is not
supplied. Confirm the revised live layout after recompilation. Any subsequent source
changes require targeted recompilation. The 2026-10-19 acceptance below
identifies the earlier version.

Compile the complete benchmark directory and library tree, then run
`U_HBBridgeBenchmarkControlTest()` and `U_HBBridgeBenchmarkVisualTest()` in the
licensed AppServer. The control regression uses deterministic clients to check
route execution, skipped dependencies, selection failures and measured-sample
arithmetic; it does not establish backend performance. The visual regression
checks controller requests/capabilities without a browser or live SQL. Run the
actual extracted HTML separately:

```powershell
node --test tests/unit/browser/hbbridge.benchmark.page.test.mjs
```

This requires a local Chromium browser; `HBBRIDGE_TEST_BROWSER` can select its
executable. Browser fixtures run without production endpoints. Follow these
checks with real CLI/visual isolated routes and a matched multi-route workload
against the explicitly configured MSSQL deployment. Preserve safe summaries
and source/RPO identities for that new execution scope.

## Timeout policy and server-only Protheus

The current visual default is automatic timeout with a user-editable ceiling
of 900 seconds. Editing Call timeout selects manual mode. The server derives
an automatic budget of `Min(maximum, 30 + (iterations + warmup) * pages)` when
addon or `protheusServer` is selected; `pages = Max(1, Ceiling(rows/pageSize))`.
Client-only routes use `Min(maximum,30)` per page. This one-second-per-page
heuristic is not a measured prediction or completion guarantee. Both modes
accept ceilings 1..2147483 seconds; a manual request above the ceiling is
rejected without clamping. Smaller ceilings are not increased silently.

CLI uses `--timeout=auto --timeout-max=900` for automatic policy, or
`--timeout=120 --timeout-max=900` for an explicit manual budget. A numeric
`--timeout` without `--timeout-max` preserves the former no-policy behavior.
For TLPP, pass `{mode:"auto",maximumSeconds:900}` as `jTimeoutPolicy` after
`jRoutes` in `Run`/`U_HBBridgeBenchmarkTest`; `Measure` reserves the intervening
`bClientFactory` test seam, so pass `...,jComparison,jRoutes,Nil,jTimeoutPolicy`.
The caller owns and frees its input JSON and returned report.

The controller accepts the original five numeric parameters, six with
`routes`, and seven with `routes` plus `timeoutPolicy`. Current page maps have
six route keys. The report records the effective `timeoutSeconds` and resolved
policy (`mode`, `maximumSeconds`, `timeoutSeconds`, `estimatedSeconds`,
`ceilingReached`, `method`, `scope`, `success`). Completed HTML/exports retain
that report-owned policy; old reports without it say unavailable. Explicit
policy applies to the complete addon RPC and is not replaced by the legacy
separate addon timeout. [Detailed policy and limits](../../../../../docs/benchmarking.md#automatic-and-manual-call-timeouts).

`protheusStartJob` keeps its per-page jobs. `protheusServer` prepares one job
and executes all warmup/measured paged traversals inside Protheus/DBAccess,
returning only metrics. Its internal `samples.*.elapsedMs` excludes job setup;
`callElapsedMs` includes the complete StartJob, environment preparation, all
iterations and result. Both internal server routes share aligned cards, charts and one statistics
table. Complete RPC/StartJob requests are in a separate totals table with all
warmup/measured counts; compare matching
internal scopes or matching whole calls. StartJob remains synchronous and its
deadline can only be checked after blocking work returns. Page closure or a
client timeout does not prove cancellation.

The supplied 255-iteration failure completed valid measured/warmup samples;
only aggregate validation failed. Its 87.9255-second complete call was below
the 900-second timeout. Native `hb_jsonEncode()` under `SET DECIMALS TO 2`
rounded `1/3` to `0.33` at the internal addon ABI before the wire codec.
The repair uses existing `HBBridgeJSONEncode()`/`HBBridgeJSONDecode()` for addon
input/output and native host handoff, retaining strict statistics validation.
Rebuild host and HRB together. This is not a diagnosed iteration limit or
whole-call timeout. [Diagnosis and exact scope](../../../../../docs/benchmarking.md#addon-json-precision-diagnosis-on-2026-10-23).

The `hb_idleSleep(1.5)` workaround is removed: it changed pacing and added
1.5 seconds per traversal outside measured samples without repairing JSON
precision. Preserve that limitation for prior reports. Post-codec ABI suite:
93 checks passed, including SET DECIMALS 2/18 × FIXED off/on and restoration. Actual TLPP clients passed 255 measured + two warmups and
500 + zero through the real Harbour TCP host/HRB and mock Query service,
with strict aggregate validation. The full native suite and 54-source TLPP
compilation also passed after repair. Actual TLPP→TCP→HRB→MSSQL also passed
255 measured + two warmups, 1000 rows/page100, with strict aggregate checks,
ODBC pooling off and no artificial sleeps. The later provided manual FWWebEx1500 run passed; its source/pooling identity
is not supplied. A separate automated MSSQL500 attempt exhausted its launcher
budget and is inconclusive. Confirm the revised live layout after recompilation. These correctness fixtures do not
establish performance gains or all-platform acceptance. Rebuild hbBridge,
HRB and TLPP together before repeating the supplied case.

## Reproduce the addon host with an explicit MSSQL profile

In a separate terminal, build and serve a fresh isolated host/HRB:

```powershell
./scripts/test-hbbridge-benchmark-addon.ps1 -Serve -ServeSeconds 1800 `
    -Config C:/tmp/hbbridge.ini -Profile MSSQL/pData
```

The ready line prints the ephemeral loopback port and module
`hbbridgebenchmarkaddon.hrb`. Only that configured MSSQL profile is loaded;
private INI content is not printed or changed. No existing listener/service is
restarted. The fixture is temporary and expires after the requested serving
seconds, or when `stop.request` is created in its printed run directory.
Without `-Config`/`-Profile`, serve mode uses a SQL mock with profile
`opaque/profile`, one row and one row per page.

In the dedicated, licensed test AppServer INI beside its isolated SDK, set the
trusted fixture module (the fixture uses a basename, whereas an installed
production addon may use `examples/hbbridgebenchmarkaddon.hrb`):

```ini
[hbBridge]
BenchmarkAddonModule=hbbridgebenchmarkaddon.hrb
```

Use the printed port and current compiled test RPO. For example:

```powershell
$fixturePort = 12345 # Replace with the ready line's port.
$arguments = @('--profile=MSSQL/pData', '--host=127.0.0.1', "--port=$fixturePort",
    '--routes=hbbridgeAddon', '--rows=1000', '--page-size=100',
    '--iterations=255', '--warmup=2', '--timeout=auto', '--timeout-max=900')
./scripts/run-protheus-cli.ps1 -AppServerDirectory C:/private/appserver-benchmark `
    -IniFile C:/private/appserver-benchmark/appserver.ini `
    -Program U_HBBridgeBenchmarkCLI -Argument $arguments -TimeoutSeconds 1800
```

Repeat with `--iterations=500`; retain the same selected workload and explicit
policy. Increase the user ceiling deliberately when the reported estimate is
capped or the deployment requires it; do not treat a chosen estimate as a
completion guarantee. With a private profile, this fixture honors its
`[SQL] ODBCPooling` policy before connecting and prints effective `odbcPooling`
in the ready line; other runtime settings are not implicitly reproduced.
The earlier automated 255 run used pooling off. Record the current ready
policy instead of assuming it matches that run or the active deployment.
Its correctness measurements do not assume the user's running server has the
same pooling/cache/load or prove a performance improvement. For matched
performance comparisons use the rebuilt product with explicitly recorded
runtime settings, keeping server-internal and whole-call scopes separate.

## Large manual run and client-component lifetime

The 2026-10-16 manual retry, run `93A0CC16D629E74FAA54843567C86E58`, started
at 07:09:41 São Paulo with 100000 rows, pages of 10000, 500 measured iterations,
two warmups and a 30-second request timeout. This run used the temporary
module-static socket mitigation. TCP completed all 500 measured traversals:
5000 calls and 50000000 rows, averaging 7747.32 ms per traversal. HTTP completed
135 measured traversals/1350 calls/13500000 rows. Its measured iteration 136
failed on the first request after 30020.8344 ms, with zero rows/pages read and
`QUERY_FAILED`. The complete benchmark is **FAILED**.

The duration is consistent with the configured deadline, but that older report
does not include HTTP status or a service code. It does not establish a SQL
failure or the source of the delay. There is no new terminal-component fatal
error in this retry. The preserved record is
`tmp/protheus-benchmark-large-static-20261016-93a0cc16.log`, SHA-256
`AC62382489B97B9CC00B41C1010A8AC5D9C60A6A3D24BEBDB444A403C4FCC986`.

The current TCP client owns one lazily created `TSocketClient` per
`HBBridgeClient`, reusing the native component while opening/closing a TCP
connection for every request. It exposes explicit idempotent `Close()`;
the measurement core closes its owned client. This replaces the temporary
static mitigation and the earlier component-per-call allocation. The
[focused lifecycle test](../hbbridge.client.lifecycle.test/README.md) exercises
6000 small Health requests instead of repeating the large SQL workload.
Its runtime acceptance is separate; component reuse does not establish native
allocator/terminal-registry leak freedom. New reports retain safe failure
phase/iteration/page, HTTP status and service-code diagnostics where available.

## Four client routes and two server-only scopes

The visual form can select Protheus StartJob/REST 2.0 and hbBridge TCP/HTTP,
using the same fixture, dataset checks and SELECT plus COUNT per page.
StartJob includes worker/environment startup per page; it is not TCP traffic.
FWWebEx supplies the selected `cEmpAnt`/`cFilAnt`. The job prepares its own
environment with `RpcSetEnv()` and releases owned resources. `FWGetTopInfo()`
provides DBAccess configuration. REST keeps its framework-prepared environment.

Reuse the existing HTTPS REST 2.0 listener with `Security=1`; see the
[configuration fragment](../../../../../config/hbbridge.benchmark.rest.md).
Private `[hbBridge]` keys: `BenchmarkProtheusURL` (e.g.
`https://localhost:4323/rest`), `BenchmarkProtheusCredentialSection`
(`FWWEBEX_PROTHEUS`), `BenchmarkAddonModule`, `BenchmarkAddonTimeoutSeconds`.
The referenced `UserName`/`Password` section supplies Basic credentials;
these never reach HTML/reports. No additional benchmark bearer is required.

Build the optional HRB with `scripts/build-hbbridge-benchmark-addon.ps1` and
check it with `scripts/test-hbbridge-benchmark-addon.ps1`. Install
`addons/examples/hbbridgebenchmarkaddon.hrb` under the updated server's
`addonRoot`. Its native call-owned context invokes `RPCRDD.Query` locally;
only measurements/checks return. The separate panel distinguishes server
traversal average from one complete TCP call including HRB loading, warmups
and all iterations. Those timing scopes are not interchangeable.

Opt into the comparison on CLI, retaining the original two-route default:

```text
-run=U_HBBridgeBenchmarkCLI -env=PROTHEUS --profile=MSSQL/pData --rows=1000 --page-size=100 --iterations=5 --warmup=2 --timeout=30 --compare-protheus=1 --with-addon=1 --company=99 --branch=01
```

The pending indicator animates and shows browser elapsed time until a matching
response/error. It does not claim a server progress percentage or cancel a
synchronous job. Chromium checks cover correlation, send failures, four routes,
separate addon results, partial failure, exports and large sample collections.
Runtime evidence is recorded in [acceptance](../../../../../docs/acceptance.md).

## Acceptance on 2026-10-19

The three supplied visual runs passed all four client routes and the server
addon: 1000 rows, page size 100, 5 measured + 2 warmup traversals, concurrency
one. All 105 samples passed; 684 export-audit checks passed. Mean client times
across 15 measured samples: TCP 990.62 ms, HTTP 1123.13 ms, StartJob 25899.95 ms,
Protheus REST 1221.15 ms. Addon server-only mean is 825 ms; complete RPCs cover
all seven traversals and must not be divided by five. An additional whole-package
comparison includes warmups on both sides; see
[methodology](../../../../../docs/benchmarking.md#accepted-visual-comparison-and-whole-packages-on-2026-10-19)
and [acceptance](../../../../../docs/acceptance.md#v01-v02-benchmark-acceptance-on-2026-10-19).

The two-route CLI also passed manual run 7482F7E8 on 2026-10-19: ten rows,
one page/traversal, zero warmups, TCP 94.799800 ms and HTTP 124.020300 ms (200).
[CLI evidence and timeout context](../../../../../docs/acceptance.md#m08-manual-cli-validation-on-2026-10-19).
Earlier isolated StartJob CLI initialization failures are separate. The large
100000-row/500-iteration outcome retains the reported excessive-workload and
inadequate-timeout context. D03/M09 were still open then; their later closure
and the current package remain recorded in WIP.
