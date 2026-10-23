# Build, run and validation scripts

[Português](README.pt-BR.md)

Requires PowerShell 7 and Git. The managed bootstrap resolves pinned copies
of hb_compile, Harbour and Zig. See [dependencies](../docs/dependencies.md).
No developer-specific checkout or global Zig is required.

```powershell
./scripts/bootstrap.ps1
./scripts/build-hbbridge.ps1
./scripts/test-hbbridge.ps1
```

Bootstrap verifies the Zig archive checksum and the Git revisions in
[dependencies.json](../config/dependencies.json). A completed receipt avoids
unnecessary rebuilds. `-ForceBuild` rebuilds Harbour; `-SkipHarbourBuild` only
resolves sources/Zig. Windows builds through hb_compile; Linux uses its
compatibility preparer plus native make/GCC. Linux requires PowerShell 7,
Git, make/GCC/binutils and unixODBC development headers. SQL Server ODBC
runtime drivers and licensed TOTVS resources are installed separately.

HTTP preparation is part of bootstrap: native hbhttpd/hbtcpio and the
checksum-verified project patch are built with `prepare-http.ps1`. Direct
HTTPS additionally needs an opted-in hbssl/OpenSSL SDK/runtime build.
See [HTTP services](../docs/http.md); `-hblib` denotes hbmk2 library mode.

`build-hbbridge.ps1` builds Zig and the product at `out/hbbridge.exe` on
Windows or `out/hbbridge` on Linux. It does not stop active servers. Use an
isolated output alongside a running installation:

```powershell
./scripts/build-hbbridge.ps1 -OutputDirectory tmp/candidate
```

`-HbCompileRoot` and `-ZigPath` are explicit advanced overrides. Managed
locations are the default. `toolchain.ps1` resolves hbrun/hbmk2/Zig/compiler
paths and checks the required Zig version; temporary environment changes
are restored after execution.

`test-hbbridge.ps1` builds isolated fixtures and the MT target using the same
components as the product. It records `tmp/tests-<id>/results.log` and
propagates the exit code. Coverage includes config/INI, registry, monotonic
clock, native NETIO/admin/VF IO, gzip/framing, SQL pagination/SQLite and MT.
Previous Windows run: 412 checks, zero failures, no skips. The managed
revision on 2026-10-04 passed **416 checks, zero failures, no skips**,
log tmp/tests-d1b829ff332c414f816a6e70748152d1/results.log. These historical
results predate the PascalCase/HTTP changes on 2026-10-06. See
[acceptance](../docs/acceptance.md) for later validation.

## Artifact cleanup

`tmp/` is fully disposable. Reusable sources/runners belong in `scripts/` and
`tests/`; sanitized results and recipes belong in [validation](../docs/validation/README.md).
Documentation paths, JSON manifests, log extensions and `*-current.txt` do not
silently retain temporary content. Outdated temporary inputs are never required.

```powershell
# Preview, without changing files (default age: seven days).
$report = ./scripts/clean-artifacts.ps1
$report.Candidates | Format-Table Path, Status, Bytes, Reason -AutoSize

# Preview the entire tmp tree, including recent entries.
./scripts/clean-artifacts.ps1 -Target tmp -MinAgeDays 0

# Apply the same cleanup explicitly.
./scripts/clean-artifacts.ps1 -Target tmp -MinAgeDays 0 -Apply

# Remove only generated out build caches, preserving product/addons.
./scripts/clean-artifacts.ps1 -Target out -MinAgeDays 0 -Apply
```

PowerShell 7 and working Git metadata are required; no compiler is needed.
Paths are based on the script's project. `-Target` accepts `all` (default),
`tmp` or `out`. The default `-MinAgeDays 7` protects recent trees, including
any newer descendant. Use 0 for immediate cleanup. All top-level tmp entries
are eligible, including unknown directories, RPO copies, logs, helpers and
manifests. `out` cleanup selects generated build directories/objects and keeps
the executable/debug files, benchmark addons and other deliverables outside builds.

Safety exclusions remain: Git-tracked files, symbolic links/junctions, visible
process paths and explicit `-KeepPath` paths. A linked root/ancestor aborts planning;
a link inside a candidate protects it. `-KeepPath` is a temporary operational
choice, not a durable storage contract. It accepts existing tmp/out paths.
The commit gate rejects versioned tmp/out files: move any such source to its
proper directory before committing.

`-Apply -WhatIf` previews without deletion or report creation. Optional
`-ReportPath` must name a new file in tmp/out; reports are also disposable.
Locked/changed/inaccessible entries produce `Failed` and retain remaining
content; inspect `$report.FailedCount` for automation. The script never stops
processes. Process discovery is best effort: run between builds/tests.
All deletion paths are checked; links are not traversed and only checked files
and empty directories are removed. Concurrent changes can abort planning or
leave a partially cleaned candidate. Byte counts are logical file lengths.

```powershell
./tests/unit/scripts/clean.artifacts.test.ps1
./scripts/check-doc-links.ps1
```

The closed cleanup fixtures include an absent tmp/out tree, complete tmp
disposability, non-retention by documentation/pointers, age, Git, links,
explicit keeps, locked files, reports and preview/WhatIf behavior.

Reusable validation helpers are maintained here: `check-doc-links.ps1`,
`test-harbour-thread-state.ps1` and `run-protheus-cli.ps1`. The last requires
explicit SDK/INI/program arguments and reports process results, not inferred
assertion success. See the [source-based recipes](../docs/validation/README.md).
The supplied INI must reside beside the supplied isolated SDK executable;
the tested AppServer rejects directory information in `-ini`. The launcher
omits that option for default `appserver.ini`, or passes another INI by its
basename as a separate argument. It does not copy an INI into or change a
running installation. See the
[TOTVS command-line reference](https://tdn.totvs.com/display/tec/Application%2BServer%2B-%2BCommand%2BLine).

## Commit validation

Before every commit:

```powershell
./scripts/commit-check.ps1
```

The managed `hbrun` executes `.hbcommit/check.hb`, `.hbcommit/commit.hb` and
`.hbcommit/3rdpatch.hb` in read-only validation mode. No second Harbour runtime
is distributed under `bin/harbour`. Preserve upstream notices. Correct failed
checks before committing; validation does not prepare the index. Hook options
are available in the script's parameter block; unrelated existing hooks are
not overwritten. [Standards](../docs/standards.md) define naming and doc pairs.

## TOTVS compilation

The proprietary SDK is external. Configure its directories explicitly:

```powershell
$env:HBBRIDGE_TOTVS_APPSERVER_DIR = '<your-appserver-directory>'
$env:HBBRIDGE_TOTVS_INCLUDES = '<your-totvs-includes>'
$env:HBBRIDGE_TOTVS_ENV = 'PROTHEUS'
./scripts/build-totvs.cmd
```

Arguments are AppServer directory, semicolon-separated include directories
and environment (default PROTHEUS). Project includes are added automatically.
Optional `HBBRIDGE_TOTVS_STOP_SCRIPT` and `HBBRIDGE_TOTVS_START_SCRIPT` use
installation-specific service scripts; no fixed installation or elevated-process
stop is assumed. A failed configured stop aborts compilation. Startup is
attempted after the compiler and preserves its failure status. The log is
`tmp/totvs-compile.log`. Compile the entire `src/tlpp/` tree including tests.
`prepare-totvs-sources.ps1` writes an explicit recursive list of regular
`.tlpp` files. TOTVS requires a single semicolon-separated line with a trailing
separator; supplying dotted test directories as sources caused seven errors
and omitted their children in the 2026-10-12 review. The corrected list included
all 24 sources. In the documented local installation, use an elevated terminal
and `C:\totvs\stop-totvs.bat` / `C:\totvs\start-totvs.bat`, ensuring startup
after failures. Quote semicolon-separated include arguments in PowerShell.
Renamed classes require a new compile; previous acceptance does not cover
their newly published names.

## Start the product and examples

[run-hbbridge.ps1](run-hbbridge.ps1) resolves `-Config` against the project
root and sets the addon's working directory. Only explicit `-Port` and
`-MaxWorkers` override INI/JSON values:

```powershell
./scripts/run-hbbridge.ps1 -Config config/examples/hbbridge.ini
./examples/mvp/run.ps1
./examples/sql/run.ps1 -Config config/examples/sqlite.ini
./examples/sql/run.ps1 -Config config/examples/mssql.ini -Profile mssql_demo
```

Stop the previous instance with Ctrl+Q before reusing its ports. Without
`-Config`, the executable looks for `hbbridge.ini` beside itself, then uses
defaults if absent. Invalid existing configuration prevents startup. Query is
not registered when SQL profiles are empty. The SQL launcher validates the
profile and displays a Protheus call; tests run separately in the AppServer.
It does not edit AppServer configuration. `--config-info` returns sanitized
host/port/workers/profile metadata without secrets, paths, listeners or DB access:

```powershell
./out/hbbridge.exe --config-info "-config=config/examples/sqlite.ini"
```

Quote native PowerShell `-config=...ini` arguments as shown. See
[configuration](../docs/configuration.md) for precedence and relative paths.
Align the [AppServer template](../config/examples/protheus-appserver.ini)
separately or supply explicit test arguments.

| Setting | CLI | Default / meaning |
| --- | --- | --- |
| protheusMaxPayloadBytes | -maxpayloadbytes= | 0, no application cap |
| protheusMaxWireBytes | -maxwirebytes= | 0, no application cap |
| protheusReadChunkBytes | -readchunkbytes= | 65536, read buffer, not message cap |
| protheusTimeoutMs | -iotimeout= | 30000 ms; 0 disables server deadline |
| netioTimeout | -netiotimeout= | 0 maps to native -1 |
| maxWorkers | -maxworkers= | 64 per listener, configurable |

Technical capacities reported by `HBBridgeRuntimeLimits()` are validated
separately. TLPP has a positive default timeout and AppServer limits including
MAXSTRINGSIZE; logical block transfer/negotiation remain pending.

The manual AppServer report recorded on 2026-10-04 confirmed INI's 13 checks,
Windows clock, normal RPC and SQLite's 29 checks. Earlier failed TOTVS stopping
attempts remain historical; no later compiler log was supplied. Forced socket
failures/partial sends, nondefault destinations, MSSQL and Linux remain pending.
The [credentials proposal](../docs/credentials.md) covers portable storage;
encrypted credential management is not implemented yet.

## Opt-in SQL concurrency test

`test-hbbridge-mssql.ps1 -Config C:/tmp/hbBridge.ini -Profile MSSQL/pData -Concurrency`
builds and runs the isolated eight-worker M07 suite. `-Concurrency`, `-Failures`
and `-Pooling` are mutually exclusive; `-Serve` is available for concurrency
or failures. In concurrency
mode it prints test endpoints/profiles, hosts for up to 600 seconds, and stops
on `m07.stop` in its run directory or Esc/Ctrl+Q. Final resource checks follow
host shutdown. See the [test guide](../tests/README.md#mssql-concurrency-and-resource-release-m07)
and [Protheus consumer](../src/tlpp/tests/protheus/hbbridge.concurrency.test/README.md).

`-Pooling -ODBCPooling off` and `-Pooling -ODBCPooling driver` run the physical
reuse/session-isolation test in separate processes; `-Pooling` defaults to
`driver`. Optional `-OtherProfile` must name another configured MSSQL database.
`-Concurrency -ODBCPooling driver` exercises all native routes with pooling.
`-HTTPListenBacklog <positive integer>` selects the isolated concurrency host's
queue request. These overrides do not modify private INIs. See
[pooling acceptance](../docs/acceptance.md#odbc-physical-reuse-on-2026-10-15).

## MSSQL time and memory baseline

`benchmark-hbbridge-mssql.ps1 -Config C:/tmp/hbBridge.ini -Profile MSSQL/pData`
builds the read-only M08 fixture and runs separate sequential child processes
for local Harbour, TCP and HTTP. Default counts are 1000 rows, pages of 100,
two warmups and five measured complete traversals; concurrency is one.
`-ODBCPooling off|driver` selects the native process policy; default is `off`.
The runner writes `benchmark.json`, per-route `result.json`, sanitized logs
and timestamped OS memory samples in its isolated `tmp/mssql-benchmark-*` run.
Use [the methodology](../docs/benchmarking.md) for measurement scope and the
optional `-Route http -ServeSeconds 600` host for the
[AppServer consumer](../src/tlpp/tests/protheus/hbbridge.benchmark.test/README.md).

## Optional Protheus comparison and benchmark addon

The [visual benchmark](../src/tlpp/tests/protheus/hbbridge.benchmark.test/README.md#four-client-routes-and-two-server-only-scopes)
compares hbBridge TCP/HTTP with Protheus StartJob/REST and separate Harbour
addon/Protheus single-job server scopes. All use the fixed paged fixture.
Per-page StartJob includes worker/environment
preparation per page; it does not simulate TCP network traffic. The addon runs
complete traversals inside hbBridge and returns statistics only. Its internal
measurements exclude transport and HRB loading; the enclosing single
`ADDON.Execute` call has a separate elapsed time.

Build and test the addon with the managed toolchain:

```powershell
./scripts/build-hbbridge-benchmark-addon.ps1
./scripts/test-hbbridge-benchmark-addon.ps1
```

The build writes `addons/examples/hbbridgebenchmarkaddon.hrb`; `-Output` selects
another target. The test builds isolated HRBs and a native fixture, checks SQL
identity across TLPP/addon/test sources and exercises mocked dispatch, errors,
reload and cleanup. Its log is `tmp/benchmark-addon-tests-<id>/results.log`.
It requires the managed ODBC/Zig build dependencies, but no live MSSQL credentials.
These checks do not establish AppServer or real MSSQL acceptance.

To keep a freshly built isolated addon fixture available for an actual TLPP
client, run it in a separate terminal:

```powershell
./scripts/test-hbbridge-benchmark-addon.ps1 -Serve -ServeSeconds 1800 `
    -Config C:/tmp/hbbridge.ini -Profile MSSQL/pData
```

`-Config` and `-Profile` are optional together and require `-Serve`. With them,
the host loads only that explicitly selected MSSQL profile into its built-in
registry. It prints its ephemeral loopback TCP port, profile/backend and
module `hbbridgebenchmarkaddon.hrb`; it never edits private INI or an existing
service. Without the pair, serve mode uses the SQL mock. The owned server exits
at `-ServeSeconds` (1..3600) or when `stop.request` appears in its printed run
directory. Setup/compilation are separate from serving and sample timing.

This minimal fixture leaves ODBC physical pooling **off**; it does not apply
other runtime settings from the private configuration or reproduce a running
server's pooling policy. It is a correctness/reproduction host, not a matched
performance deployment. Use the
[client/module and 255/500-run recipe](../src/tlpp/tests/protheus/hbbridge.benchmark.test/README.md#reproduce-the-addon-host-with-an-explicit-mssql-profile).

Merge the [REST configuration fragment](../config/hbbridge.benchmark.rest.md)
into the existing deployment: reuse one REST 2.0 listener with `Security=1`,
its TLS configuration and deployment-owned company/branch preparation.
`BenchmarkProtheusURL` includes `/rest`; `BenchmarkProtheusCredentialSection`
selects an existing server-side `UserName`/`Password` section. Protheus validates
HTTP Basic credentials before the endpoint. No extra listener or benchmark
bearer token is required. Browser input cannot supply SQL, ERP context or
credentials; the trusted AppServer context and configuration supply them.
`BenchmarkAddonModule` selects the installed HRB and
`BenchmarkAddonTimeoutSeconds` budgets legacy calls. Explicit new timeout
policy supplies the effective complete-call budget instead. Current automated
checks and remaining manual acceptance are recorded in [WIP](../WIP.md),
separately from the historical M08 baseline.
