# Concurrent profile isolation through Protheus

[Português](README.pt-BR.md) · [Test catalog](../../../../../tests/README.md) · [Acceptance](../../../../../docs/acceptance.md)

`HBBridge.Test.HBBridgeConcurrencyTest` defaults to four `StartJob` workers in
one AppServer process: two use the production TCP client and two use the
production HTTP client. Every worker constructs and releases its own client,
dataset and JSON objects. Only serialized configuration and string key names
cross the job boundary.

The parent waits for all four READY signals before releasing their GO gates.
Each worker executes two rounds through explicitly supplied MSSQL and SQLite
aliases, with opposite starting orders. Constant SELECTs include distinct
worker/step IDs and markers. `SERVERPROPERTY('ProductVersion')` and
`sqlite_version()` identify the database execution; the raw result must also
declare the expected `mssql` or `sqlite` driver. The result schemas contain
`MSSQL_ONLY` or `SQLITE_ONLY`, respectively.

Each step checks alias switching, cleared previous fields, two pages and their
COUNT totals, exact rows, defensive row/header snapshots, invalid SQL, an
unknown alias and immediate recovery. No ERP tables or SQL Server settings
are modified. The native SQL lifecycle mutex remains enabled; this test does
not require parallel SQL execution.

## Run against an isolated host

The native M07 launcher accepts an existing working MSSQL alias from a private
configuration and creates an isolated SQLite profile:

```powershell
./scripts/test-hbbridge-mssql.ps1 -Config C:/tmp/hbBridge.ini -Profile MSSQL/pData -Concurrency -Serve
```

The server prints its loopback TCP and HTTP ports after native validation.
Use those endpoints, the explicit working MSSQL alias, `m07/sqlite`, and the
fixture-only HTTP token `m07-http-test-only`. The native `m07/mssql-clone`
profile is exercised by the native suite; this Protheus suite requires the
two different database drivers.

Compile the complete `src/tlpp` tree, including both `.tlpp` files in this
directory. The public entry is:

```tlpp
U_HBBridgeConcurrencyTest(cMSSQLProfile, cSQLiteProfile, cHost, nPort, cURL, cToken, ;
    nTimeoutSeconds, nWorkers, nBudgetSeconds, nLaunchDelayMs, nLaunchStepMs, nLaunchMaxMs)
```

For example, with the fixture's printed ports:

```tlpp
U_HBBridgeConcurrencyTest("MSSQL/pData", "m07/sqlite", "127.0.0.1", nTCPPort, ;
    "http://127.0.0.1:" + cHTTPPort, "m07-http-test-only", 30)
```

Both aliases are required, distinct and explicit. Omitted transport arguments
read the active AppServer `[hbBridge]` Host, Port, HTTPURL and HTTPToken keys.
The optional timeout defaults to 30 seconds; it is converted to milliseconds
for TCP and passed as seconds to HTTP. No demo SQL profile is selected.

## AppServer command line

Use the installation's licensed RPO/environment and a private CLI INI as
described in the [failure test guide](../hbbridge.failure.test/README.md).
Run from the AppServer directory in `cmd.exe`, substituting the printed ports:

```bat
appserver.exe -ini="hbm07.ini" -run=U_HBBridgeConcurrencyCLI -env=PROTHEUS --mssql-profile=MSSQL/pData --sqlite-profile=m07/sqlite --host=127.0.0.1 --port=<tcp-port> --url=http://127.0.0.1:<http-port> --token=m07-http-test-only --timeout=30 --workers=4 --budget-seconds=120 --launch-delay-ms=300 --launch-step-ms=50 --launch-max-ms=5000
```

The native CLI entry borrows `Variadic:vArgs`. Recognized flags must be unique
and use `--name=value`. Numeric flags require canonical decimal integers;
launch pacing also accepts `0`. Fractions, exponents, signs, leading zeros
such as `00`, and numeric suffixes are rejected. The suite never prints
arguments, tokens, SQL, response bodies or
exception descriptions. Exit 0 requires all checks; exit 1 means failed
configuration, prerequisites, worker collection or assertions.

## Expected report and lifecycle scope

A complete successful run reports **417 checks, zero failures**: **83 checks
per TCP worker**, **111 per HTTP worker**, and **29 parent checks**. Each
worker issues 28 RPC calls, for 112 total. Page calls execute their own COUNT
statement. The parent requires four distinct AppServer thread IDs, distinct
from its own thread, and overlapping worker execution intervals.

Each run uses UUID-scoped per-worker ready/result/gate keys through the native
`PutGlbValue`/`GetGlbValue` APIs. There is one writer for each ready/result key
and one parent writer for the gates. The worker releases its client, dataset
and JSON objects before publishing its JSON report. The parent copies the
report before acknowledging it. ABORT or a missing gate stops further calls;
both parent and worker remove their keys, including late publications. The
public worker wrapper clears READY last, after the Worker method returns.
The parent waits for all workers' final key cleanup before returning.

The existing normalized monotonic clock measures an independent
`nBudgetSeconds` test budget (default 120 seconds), including initialization,
worker launch sleeps, readiness, collection and normal final cleanup.
`--budget-seconds` sets the same value in CLI mode. A regressing clock or missing
worker fails the suite.
Completed reports wait at least 150 seconds or the collection budget plus
10 seconds for acknowledgment. These are harness budgets, not product limits.
On collection failure the coordinator signals ABORT, waits separately for
worker cleanup (request timeout plus 10 seconds), then clears its keys. Workers
check ABORT between calls and stop without logging skipped calls as response
failures. Already executing network/SQL calls retain their native timeouts;
this is no server-side cancellation or native join guarantee.

`StartJob(...,.F.)` returns NIL and exposes no join handle. Report publication
proves explicit TLPP resource release; it does not prove native thread
termination, cancellation, or server workarea/connection restoration. The
native M07 suite records server restoration and release separately.

The supported primitives are documented in [TOTVS StartJob](https://tdn.totvs.com/display/tec/StartJob),
the [official worker example](https://tdn-homolog.totvs.com/display/tec/Exemplo%2Bde%2BFila)
and [TOTVS editor snippets](https://github.com/totvs/advpl-vscode/blob/master/snippets/advpl.json).
Confirmed AppServer CLI acceptance on 2026-10-14: 417 checks, zero failures,
112 calls, exit 0 and clean completion after all four worker acknowledgments.
[Evidence](../../../../../docs/acceptance.md#sql-concurrency-and-release-on-2026-10-14).
That execution preceded the configurable launch pacing described below; it
does not certify execution of the current pacing revision.

## Reproduce worker launch pacing

Arguments 10, 11 and 12 are `nLaunchDelayMs`, `nLaunchStepMs` and
`nLaunchMaxMs`. Their CLI equivalents are `--launch-delay-ms`,
`--launch-step-ms` and `--launch-max-ms`. Each accepts an integer from
0 through the native `Sleep` argument capacity, 2147483647 milliseconds.
Defaults preserve the launch ramp: 300, 50 and 5000 milliseconds.

After launching worker `i`, the parent sleeps
`Min(nLaunchDelayMs + i * nLaunchStepMs, nLaunchMaxMs)`, including after the
last launch. All workers must still report READY before any GO is released.
Pacing separates job creation; the barrier releases SQL/HTTP work together.
It does not reduce the number of simultaneous worker requests or establish
a fix for physical connection churn. Jobs use the current `GetEnvServer()`.

Before launching any job, the parent calculates the sum of the clamped ramp
without a per-worker loop. Planned sleeps equal to or above the total budget
are rejected. Requested pacing and the exact accepted sleep sum are logged;
a rejected sum is reported as at least the budget, without overflowing numeric
arithmetic. The estimate excludes `StartJob` and scheduling overhead, which
also consume the budget. Launch stops if that budget expires; an executing
native `StartJob` call cannot be interrupted by this check.

| Workers | Planned sleeps with defaults |
| --- | --- |
| 4 | 1700 ms |
| 130 | 431450 ms |
| 140 | 481450 ms |

Set all three pacing arguments to zero for a burst control. To reproduce the
default ramp with 140 workers, reserve enough time for more than its 481450 ms
of sleeps, plus startup, queries and cleanup, for example:

```tlpp
U_HBBridgeConcurrencyTest("MSSQL/pData", "m07/sqlite", "127.0.0.1", 1512, ;
    "http://127.0.0.1:8080", cToken, 30, 140, 900, 300, 50, 5000)
```

This revision still requires compilation and runtime validation. The values
describe a reproducible harness configuration, not accepted product capacity.

## Increasing load

Pass worker count as argument 8 and the total test budget in seconds as
argument 9. No constant edit/recompile is needed after compiling this version:

```tlpp
U_HBBridgeConcurrencyTest("MSSQL/pData", "m07/sqlite", "127.0.0.1", 1512, ;
    "http://127.0.0.1:8080", cToken, 30, 140, 300, 0, 0, 0)
```

The equivalent CLI options are `--timeout=30 --workers=140 --budget-seconds=300
--launch-delay-ms=0 --launch-step-ms=0 --launch-max-ms=0`.
The two timeouts have different purposes: 30 seconds per network call, 300
seconds for the whole run, including launch. Keeping the default ramp with
this 300-second budget is rejected before launch. Increasing only the request timeout to
150 seconds leaves an omitted collection budget at 120 seconds and can end
the test while calls are still running. The default workload remains 4 jobs;
at least 4 are required for the two-TCP/two-HTTP baseline coverage.

The first two workers use TCP; all others use HTTP. Each emits up to 28 calls,
with 83 TCP or 111 HTTP assertions. Parent checks are `6 * workers + 5` and
are counted from actual JSON keys. Complete runs with 4/40/100/140 jobs report
417/4629/11649/16329 checks respectively. The old summary undercounted parent
assertions when the compile-time constant was increased.

Manual 4/40/100-job logs report zero failures. The older 140-job run failed
833 HTTP step-4 assertions plus 136 parent zero-failure checks. The newer
2026-10-15 run used request timeout 150 but collection budget 120; it collected
83 reports and failed 894 checks. These are failed stress runs, not a proved
product capacity limit or successful 140-job acceptance.

Stage/pending-job diagnostics distinguish launch, readiness, collection and
release. Failed final operations report HTTP status, a recognized code and
elapsed time without tokens, SQL or raw exception text. `[General] MaxWorkers`
in hbBridge governs listener capacity separately from AppServer jobs. SQL
lifecycle synchronization remains unchanged. See the
[acceptance follow-up](../../../../../docs/acceptance.md#sql-concurrency-follow-up-on-2026-10-15).
