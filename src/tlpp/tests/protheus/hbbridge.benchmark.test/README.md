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
tree. The test requires an existing hbBridge process with the selected MSSQL
profile and TCP/HTTP listeners. No service restart or configuration edit is
performed by the benchmark.

## Visual benchmark

Run `U_HBBridgeBenchmark()` in the Protheus UI with FWWebEx and
`FWWebEx.Tools.FWExampleTools` installed in the RPO. The page follows the
[HTTP table example](../hbbridge.http.table.test/README.md) and uses the same
measurement core as the command-line benchmark. It does not require a chart
library: the average and iteration charts use SVG, with exact values in tables.
FWWebEx is an optional dependency of the visual consumer, not of the core.

The form has five numeric fields: rows per iteration, rows per page, measured
iterations, warmup iterations and timeout per request in seconds. Profile,
TCP destination, HTTP URL and HTTP token are selected on the AppServer; the
browser cannot supply SQL, credentials or a different destination/profile.
`U_HBBridgeBenchmark()` reads the active `[hbBridge]` section, including
`SQLProfile`. Explicit trusted parameters can be supplied from TLPP:

```tlpp
HBBridge.Examples.HBBridgeBenchmarkExample():Show("MSSQL/pData", ;
    "127.0.0.1", 1512, "http://127.0.0.1:8080", cToken, 30)
```

The page displays complete/partial status, TCP and HTTP averages, measured
row/call counts, min/max statistics, per-iteration latency and separate warmup
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
regression, without SQL/HTTP execution. Visual and lifecycle additions require
their own compilation/runtime acceptance; previous M08 results below retain
their original scope. M09 and D03 remain pending in the active WIP.

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

Each scenario runs at concurrency **1**, first TCP and then HTTP. Each performs
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
