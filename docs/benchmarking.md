# MSSQL performance baseline

[Português](benchmarking.pt-BR.md) · [WIP](../WIP.md) · [Acceptance](acceptance.md)

M08 records a reproducible reference for the existing implementation. It
does not impose a speed threshold or determine a production capacity limit.
The SQL lifecycle mutex remains enabled. Start with one client; M07 retains
the separate concurrency and cleanup evidence.

## Common workload

Use the read-only `m08.constant.v1` fixture against an explicit configured
MSSQL profile. It generates numbered rows with an ASCII name and an explicitly
cast decimal amount, without reading or writing ERP tables. Every route uses
the same SQL, projection, ordering, row count and page size. The generator's
100000-row capacity is a fixture boundary, not a server payload limit.

Initial settings are 1000 rows, 100 rows per page, two warmup traversals and
five measured traversals, with concurrency one. Each traversal reads the
entire paged dataset and validates its rows, values and page totals. Each page
uses the existing Query contract, including its separate COUNT statement.
Warmup timings and request counts are retained separately and excluded from
the measured aggregate. Warmup excludes neither SQL execution nor network
traffic; it only separates their measurements.

Native routes run in separate child processes: direct Harbour service, TCP
and HTTP. The TLPP consumer measures the real Protheus TCP and HTTP clients.
Identify the implementation/language of the client when comparing results.
An in-process native client and an AppServer client have different process
boundaries and must retain their own measurements.

Run `off` and `driver` ODBC policies in fresh processes when comparing physical
pooling. Record the effective policy. The optional Windows driver policy
and its isolation acceptance remain documented in [SQL connections](sql-connections.md).
An existing external server's policy must be identified separately; a client
argument cannot change it.

## Time and memory

The timed interval covers a complete dataset traversal, including client
calls, server processing, paging and response validation. Setup, compilation,
server startup and warmup are outside that interval. Preserve individual
durations, minimum, maximum, arithmetic mean and total, along with rows,
pages and service-call counts. Request latency, SQL-only duration and complete
process runtime are different metrics.

Native timing uses `HBBridgeMonotonicMs()`. On Windows its `GetTickCount64`
source has coarse native tick resolution, commonly around 10–16 ms. A
fractional average derived from several intervals does not improve that
clock's resolution. TLPP uses the existing normalized `TimeCounter()` wrapper
and records the runtime/platform; this does not add clock-wrap acceptance.

Report OS process working set and Windows private bytes in bytes, identifying
the requested sampling interval, sample count and phase. CSV elapsed timestamps
record the actual spacing, including sampling overhead. A sampled maximum can miss a
short-lived peak. An OS lifetime peak includes setup and warmup and must stay
separate from a measured-phase sample maximum. Memory belongs to the whole
sampled process; it is not an allocation count for a query, client, ODBC,
Harbour, C or Zig component. Native TCP/HTTP fixtures include their isolated
server and client in the same process. AppServer and an external hbBridge
server require separate process observations.

An unavailable metric is reported as unavailable, not as zero. No undocumented
TLPP memory API is required. These measurements do not prove absence of leaks;
that requires repeated comparable workloads and a separate lifecycle analysis.

## Reproduction and evidence

The native runner resolves the managed toolchain and produces an isolated
artifact directory:

```powershell
./scripts/benchmark-hbbridge-mssql.ps1 -Config C:/tmp/hbBridge.ini -Profile MSSQL/pData -ODBCPooling off
./scripts/benchmark-hbbridge-mssql.ps1 -Config C:/tmp/hbBridge.ini -Profile MSSQL/pData -ODBCPooling driver
```

`-Rows`, `-PageSize`, `-Iterations` and `-Warmup` change the fixture counts;
`-Route local|tcp|http|all` selects native clients. `-SocketTimeoutMs` controls
the fixture's socket budget. `-SampleIntervalMs` requests sampling spacing;
`-ProcessTimeoutSeconds` bounds each owned child process, including setup and
cleanup. These harness controls do not change product capacities.

For an isolated AppServer destination, use `-Route http -ServeSeconds 600`.
After the native measurements, `endpoints.json` in the printed run's `http/`
directory contains the dynamic loopback ports, selected profile/backend,
pooling policy and public fixture-only token `m08-http-test-only`.
The host remains available for the requested seconds or until `m08.stop`
is created in that `http/` directory. The wrapper prints its final result
after shutdown. The `serving` memory phase is separate from native timing;
its samples can include external client traffic. No private INI is modified.

Use the [TLPP example](../src/tlpp/tests/protheus/hbbridge.benchmark.test/README.md)
for the AppServer entry and compilation instructions. Private credentials
remain in the server configuration; neither runner prints connection strings,
tokens, raw native errors or private INI contents.

Keep the generated JSON reports and sanitized logs. Identify the executable
and owned source hashes, pinned dependency revisions/patches, OS, architecture,
runtime, backend version, fixture SQL/hash, pooling policy and workload settings.
Installed driver inventory is not proof of the driver used by a connection;
report that distinction. Record other running work and power settings when
they can influence comparison. Never infer missing measurements from the
earlier M07 worker summaries.

Actual runs and remaining limitations belong in [acceptance](acceptance.md).

## Visual AppServer consumer and failure follow-up

`U_HBBridgeBenchmark()` opens the optional FWWebEx form with five numeric
workload settings. It invokes `HBBridgeBenchmarkTest.Measure()` through a
correlated server controller; the CLI uses the same measurement core.
Profile and endpoint credentials come from trusted TLPP/INI configuration.
The page plots measured averages and individual traversals, keeps warmups
separate, and exports JSON and standalone result HTML without a chart CDN.
See the [example guide](../src/tlpp/tests/protheus/hbbridge.benchmark.test/README.md).

Execution is synchronous. Timeout applies to each client request, not the
whole benchmark. Waiting on or closing the page is not native cancellation.
Failed scenarios retain samples and partial statistics; failed samples must
not become zero-latency points or successful iterations.

## Route selection and measured statistics

The AppServer benchmark can execute any nonempty subset of `tcp`, `http`,
`protheusStartJob`, `protheusRest` and `hbbridgeAddon`. Selection controls actual
execution, client construction and dependency validation; it is not a chart
filter. Selected routes retain that fixed order, with concurrency one. A
skipped route has no successful measurement and must not be counted as passed.
The additive `routeSelectionVersion=1`, `selectedRoutes` boolean map and
`routeStates` fields record selection and `skipped`, `notStarted`, `completed`
or `failed` outcomes. Existing calls without route selection retain their
TCP/HTTP baseline and optional comparison/addon behavior.

CLI accepts `--routes=http` or a comma-separated list such as
`--routes=tcp,http`. Use the exact route names above. Empty selections, unknown
names and duplicate routes are rejected before execution. Explicit `--routes`
is sufficient to select Protheus/addon routes and replaces the legacy selection
defaults. Without it, `--compare-protheus=1` and `--with-addon=1` keep their
previous behavior. An addon-only run
uses its TCP RPC and addon configuration; it does not execute HTTP or the
client-side Query traversal. A Protheus-only selection does not require an
hbBridge TCP/HTTP destination. Each selected route validates its own inputs.

The visual form exposes only capabilities enabled by trusted TLPP configuration.
It provides individual selection and presets, without allowing browser changes
to the profile, destinations, module, ERP context or credentials. Disabled
capabilities cannot be enabled by editing a browser request. The console,
rendered results and JSON retain the selection so an isolated test cannot be
mistaken for a successful full comparison.

Per-route derived statistics use successful measured traversal samples only:
`sampleCount`, `medianMs`, nearest-rank `p95Ms`, population `stdDevMs`, `cvPct`,
`throughputRowsSec` and `throughputCallsSec`. `statisticsMethod` records the
method. Warmup and failed samples remain visible separately. Median averages
the two central values for even counts; P95 selects sorted rank
`Ceiling(0.95 * count)`. Standard deviation divides by the measured sample
count; CV divides that deviation by the mean and multiplies by 100. A metric
with no valid denominator is unavailable rather than zero. End-to-end row/call
throughput divides validated measured rows/calls by their summed traversal
time; it does not measure raw database or network throughput.

`HBBridgeBenchmarkStats.Apply()` verifies the existing completed count,
row/call totals and duration aggregates against those samples before adding
statistics. Floating-point duration comparisons use absolute/relative
`1e-9` tolerance. Inconsistent existing totals fail explicitly instead of
being silently repaired. A route's failure does not prevent independent
selected routes from retaining their own execution outcome.

Five measured samples provide only a small observation: nearest-rank P95 then
equals the observed maximum and is not a production tail-latency estimate.
Partial successful-sample statistics do not make a failed route comparable.
Compare successful complete client routes with the same workload and timing
scope. Addon server traversal statistics remain separate from complete addon
RPC duration and from client traversal bars. Browser rendering time and payload
size are not collected by this harness and are not inferred from elapsed time.

New reports include the failed phase/iteration and per-sample `serviceCode`,
`httpStatus` and `failedPage`. TCP has no HTTP status; absent page/status data
does not identify a cause. Native exception text, SQL and credentials are
excluded. Preserve the compact console failure line and complete summary.
A 30-second failure in an old report without these fields is evidence of
elapsed time, not proof of a SQL timeout.

The TCP client reuses one native socket component per instance; connections
remain per request. Owned benchmark clients call `Close()` at completion.
The lifecycle regression sends 6000 Health requests on one client by default
and checks independence and recovery. Its result is separate from SQL
throughput, allocator/terminal-registry counters and the
[large manual run](acceptance.md#m08-large-protheus-follow-up-on-2026-10-16).

## Protheus comparison and execution inside an addon

The expanded visual example measures four complete client traversals:
hbBridge TCP, hbBridge HTTP, Protheus StartJob and Protheus native TLPP REST.
All use the constant MSSQL fixture, page SELECT plus COUNT, the same page
sizes and dataset value checks. StartJob executes a synchronous worker per
page and includes its startup; it is an in-process job, not a TCP transport.
TLPP REST uses its configured worker pool and DBAccess. Its endpoint accepts
only `{rows,pageNumber,pageSize}`, never caller SQL or database credentials.
Protheus uses its own environment database; the hbBridge alias does not select
or change that environment. Verify both target the same MSSQL database.

An additional addon scenario consumes every page inside hbBridge through the
same permission-checked `RPCRDD.Query` registry. It returns only checks and
measurements, with warmup samples separate. `hbbridgeAddon.samples.*.elapsedMs`
measures server traversal, SQL and hash/value validation; HRB loading and the
network are excluded. `hbbridgeAddon.callElapsedMs` measures one complete
client call, including HRB loading, all warmups/iterations and response transport.
The page presents these scopes separately. Different data transfer and client
work make the addon useful as an execution-placement comparison; its server
average is not a replacement for the four client elapsed-time bars.

Build/install the optional HRB using
`scripts/build-hbbridge-benchmark-addon.ps1`; the default output is
`addons/examples/hbbridgebenchmarkaddon.hrb`. Install it under the running
server's `addonRoot` and rebuild hbBridge for the optional native addon context.
No SQL credentials are sent to the addon: the host supplies its local registry
as the optional second native entry argument. Existing JSON-only addons keep
their first argument and result contract. The context is call-owned, must not
be retained, and is never part of JSON; nested service calls retain permissions.

The [private REST configuration](../config/hbbridge.benchmark.rest.md) includes
`BenchmarkProtheusURL`, `BenchmarkProtheusCredentialSection`, `BenchmarkAddonModule` and
`BenchmarkAddonTimeoutSeconds` under `[hbBridge]`. The visual example enables
all comparison capabilities; the form selects routes for each run. CLI opts in
with `--compare-protheus=1 --with-addon=1` or explicit `--routes`.
Omitting these flags preserves the two-route CLI baseline. REST 2.0 validates
Basic credentials from the private referenced `UserName`/`Password` section;
no additional benchmark bearer is used. Authorization and addon module remain
in trusted server configuration. The visual consumer captures `cEmpAnt` and
`cFilAnt` already selected in Protheus and passes them to StartJob. CLI uses
explicit `--company=99 --branch=01`, or private `BenchmarkProtheusCompany`/
`BenchmarkProtheusBranch` keys. Only the job prepares and clears its own
environment with `RpcSetEnv()`/`RpcClearEnv()`. `FWGetTopInfo()` supplies any
needed DBAccess configuration. REST keeps its framework-prepared session;
ERP context is never sent to the Harbour addon or inferred by hbBridge.

The addon timeout bounds its complete RPC rather than an individual SQL page;
set it for the requested total workload. StartJob checks elapsed time after
return and cannot be interrupted by this harness. A client timeout does not
prove the worker stopped. The browser spinner and elapsed indicator show that
a request is pending; they are not a server progress percentage or cancellation.

## Accepted visual comparison and whole packages on 2026-10-19

V01/V02 are complete for the recorded manual AppServer scope and focused
automated evidence. Three runs passed all five routes: 75 measured and 30
warmup samples; the paired JSON/HTML audit passed 684 checks. See
[results, hashes and limits](acceptance.md#v01-v02-benchmark-acceptance-on-2026-10-19).
D03/M09 were pending at that acceptance; their later package 001 closure and
the current package are recorded in [WIP](../WIP.md).

Use an additional whole-package comparison when the addon performs all work
and returns metrics: compare its complete RPC with the sum of the same seven
client traversal intervals, including two warmups on both sides. Across the
three runs, addon calls total 17.677854 s versus 26.260709 s REST Protheus
(32.68% less time). This differs from the 15-sample means excluding warmup.
The addon returns metrics; clients receive and validate pages. Client sums
exclude inter-iteration harness bookkeeping; addon calls include internal
orchestration. Each package replaces 70 external page calls with one RPC and
70 local dispatches. Whole-call minus server-run residual was 4.375-9.622 ms,
under 0.17% observed, including HRB/JSON/transport/clock effects. It is not an
isolated network timer or a prediction for returning the full dataset.

The manual two-route CLI passed separately with ten rows and no warmup.
[Scope and workload/timeout clarification](acceptance.md#m08-manual-cli-validation-on-2026-10-19)
distinguish it from isolated StartJob CLI initialization failures and the
large workload with an inadequately sized request budget.


## Future C/Zig processors and PostgreSQL/2610 reference

The two requested additional addon benchmarks keep SQL execution in hbBridge,
pass result JSON to C or Zig and return metrics. A matched Harbour JSON control
and separate SQL/serialization/parsing/processing/RPC intervals are planned.
The supplied Docker Protheus 12.1.2610/PostgreSQL environment is a future
compatibility reference, requiring its own connector, dialect, SDK, encoding
and deployment acceptance. See [design and plan](benchmark-evolution.md).
These remain future tasks; follow the current package and preparatory maintenance
in [WIP](../WIP.md).
