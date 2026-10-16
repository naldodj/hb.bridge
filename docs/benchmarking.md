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
