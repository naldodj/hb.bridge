# Protheus TCP and HTTP performance baseline

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

## Visual benchmark

Run `U_HBBridgeBenchmark()` in the Protheus UI with FWWebEx and
`FWWebEx.Tools.FWExampleTools` installed in the RPO. The page follows the
[HTTP table example](../hbbridge.http.table.test/README.md) and uses the same
measurement core as the command-line benchmark. It does not require a chart
library: the average and iteration charts use SVG, with exact values in tables.
FWWebEx is an optional dependency of the visual consumer, not of the core.

The form has five numeric fields: rows per iteration, rows per page, measured
iterations, warmup iterations and timeout per request in seconds. Route controls
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
appserver.exe -ini="private-benchmark.ini" -run=U_HBBridgeBenchmarkCLI -env=PROTHEUS --profile=MSSQL/pData --rows=1000 --page-size=100 --iterations=5 --warmup=2 --timeout=30
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

The tested AppServer parser requires the private CLI INI beside its executable
and a basename in the quoted `-ini` argument; it rejects directory information.
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
after `jComparison`. Pass a `JSONObject` with all five boolean fields:

```tlpp
jRoutes := JSONObject():New()
jRoutes["tcp"] := .F.
jRoutes["http"] := .T.
jRoutes["protheusStartJob"] := .F.
jRoutes["protheusRest"] := .F.
jRoutes["hbbridgeAddon"] := .F.
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
TCP/HTTP, with optional Protheus/addon settings. A supplied map must be complete,
boolean, contain no unknown keys and select at least one route.

CLI supports explicit isolation without combining legacy comparison flags:

```text
--profile=MSSQL/pData --routes=http --rows=1000 --page-size=100 --iterations=5 --warmup=2 --timeout=30
--profile=MSSQL/pData --routes=protheusStartJob --company=99 --branch=01 --rows=1000 --page-size=100 --iterations=5 --warmup=2 --timeout=60
--profile=MSSQL/pData --routes=hbbridgeAddon --rows=1000 --page-size=100 --iterations=5 --warmup=2 --timeout=30
```

Append these arguments to the existing licensed AppServer CLI entry. Destinations,
REST credentials, addon module and complete addon RPC timeout remain private
server/TLPP settings. `--routes` uses the exact names `tcp`, `http`,
`protheusStartJob`, `protheusRest`, `hbbridgeAddon`; unknown, duplicate or empty
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
complete successful workloads; addon internal timing remains in its own panel.
See the [statistical method and timing scopes](../../../../../docs/benchmarking.md#route-selection-and-measured-statistics).

This maintenance requires fresh compilation and focused regression/real
AppServer checks. The 2026-10-19 acceptance below identifies the earlier version;
it does not automatically accept the new route/statistics controls.

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

## Four client routes and a server-only addon

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
