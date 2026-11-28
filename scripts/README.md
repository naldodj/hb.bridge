# Build, run and validation scripts

[Português](README.pt-BR.md)

## Credential feasibility probes

`python tests/probes/hbbridge.credential.atomic.probe.py <existing-directory>`
probes local replacement and a cooperative cross-process lock using only
synthetic files. On Windows, add `--protected` for a protected-DACL fixture.
The test reports observed security-metadata changes; it does not implement or
certify production file updates, extended ACL preservation or crash durability.

On Windows, compile the isolated metadata probe with the prepared Harbour
toolchain and run its Python fixtures on NTFS:

```powershell
$probe = Join-Path (Get-Location) 'tmp/hbbridge-credential-stream-probe'
hbmk2 tests/probes/hbbridge.credential.stream.probe.hbp -cflag=-DHBBRIDGE_PUBLISH_TEST "-o$probe"
python tests/probes/hbbridge.credential.stream.test.py "$probe.exe"
```

The test distinguishes unsupported metadata, a sharing conflict and a missing
SACL privilege. Add `--require-audit` to the Python command when running
as an identity already assigned `SeSecurityPrivilege`. This test uses a
disposable audit SACL and limits privilege activation to the probe thread.

`pwsh ./scripts/test-credentials-terminal.ps1` builds the standalone terminal
probe and verifies that redirected input is refused without a prompt. On Linux
it also runs synthetic pseudoterminal tests; `-Interactive` adds a manual test
using the printed synthetic value. On Windows, no-echo and terminal restoration
still require an interactive console test. This probe is not a product command.

Run `pwsh ./scripts/test-credentials-serialization.ps1` for Harbour binary
serialization and `pwsh ./scripts/test-credentials-crypto.ps1` for Zig 0.16
authenticated encryption and secure entropy. Both use synthetic data; they do
not implement credential storage. Pass `-CompileOnlyTarget x86_64-linux-gnu`
to the Zig probe to compile for Linux without executing it.
Run `pwsh ./scripts/test-credentials-abi.ps1` to compile and execute the
synthetic Harbour/C/Zig integration probe, including secure OS entropy from
the linked Zig library. For native checks, run all three scripts after
`pwsh ./scripts/bootstrap.ps1` on Windows or Linux. The ABI build in `tmp/`
is disposable.

`pwsh ./scripts/test-credentials-key-publication.ps1` builds a test-only hook,
interrupts synthetic key creation before publication and checks that the final
path stays absent and the staged key is private. It tests recovery after the
interrupted process exits, and simulates cleanup failure on a collision and,
on Unix, after publication. The synthetic files are removed when it finishes.

`pwsh ./scripts/test-credentials-permissions.ps1` checks that encryption and
decryption reject a synthetic key with broad permissions, then work again after
restoring restricted permissions. On Windows it also checks DACL inheritance.

`pwsh ./scripts/test-credentials-sql.ps1` exercises the protected SQL profile,
INI/JSON parsing, context binding, failure handling and redaction with synthetic
values and a nonexistent DSN. It does not connect to an actual database.
Add `-TerminalUpdate` to exercise the isolated interactive update fixture.
On Linux it uses Python 3 and a pseudoterminal with private fixtures under
`/tmp`. On Windows it verifies refusal before a prompt or file creation.

On Linux, the standalone publication and snapshot probe uses synthetic
files on the selected local filesystem. It needs Harbour, Python 3 and
the ability to set `nodump` on the fixture. From the repository root:

```sh
probe_dir=$(mktemp -d /tmp/hbbridge-publish-XXXXXXXX)
hbmk2 tests/probes/hbbridge.credential.publish.probe.hbp -cflag=-DHBBRIDGE_PUBLISH_TEST "-o$probe_dir/publish-probe" "-workdir=$probe_dir"
python3 tests/probes/hbbridge.credential.publish.test.py "$probe_dir/publish-probe" "$probe_dir"
```

The standalone `tests/probes/hbbridge.credential.ini.probe.hbp` can be built
with Harbour's `hbmk2` on Windows or Linux without SQL or Zig dependencies. It
checks the in-memory INI update planner with synthetic values; it neither writes
configuration files nor authenticates an encrypted envelope.

For the cross-platform provider fixture, create an empty directory and run
`pwsh ./scripts/test-credentials-portability.ps1 -Mode Create -FixtureDirectory <path>`
on the source platform. Transfer only the two **synthetic** files into a private
directory on the destination, set its key permissions for the destination
identity, and run the same script with `-Mode Verify`. Repeat in the opposite
direction. The caller owns and removes the fixture files; this is a test, not a
credential migration utility. Bootstrap the managed toolchain on each platform.

`pwsh ./scripts/test-hbbridge-mssql-credential.ps1 -Config <private.ini> -Profile <alias>`
tests a structured plaintext SQL-authentication profile against MSSQL. It creates
an encrypted temporary JSON profile and a private key, runs `SELECT 1` through
the normal query path, and removes both files. It never writes the plaintext
password to the fixture or prints it. The original configuration is unchanged.
Pass `-TestExecutable <hbbridge-executable>` to also exercise the local
`--credential-test` command with the temporary protected profile, verify that
its captured output does not contain the password or envelope, and test key
creation and refusal to overwrite a synthetic key.

## Wiki portal

The root READMEs present the project and first run. Technical guides stay in
`docs/`, versioned with the implementation. The two documentation indexes are
the authored source of the Wiki navigation; do not maintain guide copies there.

```powershell
pwsh ./scripts/prepare-wiki.ps1
```

This deterministic local generator writes `Home.md`, `Home.pt-BR.md`,
`_Sidebar.md` and `_Footer.md` to disposable `out/wiki`. Relative guide links
become repository links, retaining fragments; language links select the Wiki
home page for that language. `-OutputDirectory out/wiki-preview` selects another
preview location under `out/`. No repository is cloned, committed or published.

Before publishing, commit/publish the referenced guides to `main` and pass
`scripts/check-doc-links.ps1` and all three `scripts/commit-check.ps1` gates.
The Wiki has its own Git repository. Enable it in repository settings and,
for the first publication, create its initial page in the GitHub UI as described
in the [GitHub instructions](https://docs.github.com/en/communities/documenting-your-project-with-wikis/adding-or-editing-wiki-pages).
After initialization, use a fresh Wiki checkout and copy only the generated
four pages into it:

```powershell
git clone https://github.com/naldodj/hb.bridge.wiki.git out/wiki-repository
Copy-Item -LiteralPath out/wiki/Home.md,out/wiki/Home.pt-BR.md,out/wiki/_Sidebar.md,out/wiki/_Footer.md -Destination out/wiki-repository
git -C out/wiki-repository diff --check
git -C out/wiki-repository add -- Home.md Home.pt-BR.md _Sidebar.md _Footer.md
git -C out/wiki-repository commit -m "Refresh hbBridge documentation navigation"
git -C out/wiki-repository push origin HEAD
```

Use an unused checkout path for each reproduction. Keep existing unrelated
Wiki pages. Edit the versioned indexes/guides for subsequent updates and
regenerate; no personal token or additional CI secret is required by the generator.

## Isolated native Protheus presentation

`test-protheus-presentation.ps1` receives explicit `-AppServerDirectory`,
`-IniFile`, `-RpoDirectory` and `-IncludeDirectory` prerequisites. Pass include
directories as a PowerShell array, for example `@('<totvs>', '<project>/includes')`.
It copies the licensed SDK/RPOs into a fresh disposable workspace, compiles all
current TLPP sources and runs conversion plus typed/ordinary dataset regressions.
`-NativeTables` also runs SDK observations, actual FWTemporaryTable storage/
cleanup and native example navigation/column callbacks without opening its
window, against the configured DBAccess endpoint. It does not activate
the native browse, replace deployment files or stop existing services. Sources and
RPOs are hashed; local `result.json` records exact outcomes without INI content.
See [the guide and manual UI fixture](../docs/native-presentation.md).

`-MeasureConversion` additionally compares strict row conversion against page
conversion over 100 columns × 100 rows, in three alternating rounds. The
reported local phase excludes fixture creation, SQL, transport, native storage,
UI and value comparison. Correctness checks never require a timing win.
The default suites include page conversion and SRA metadata planning.

`-NativeRows 10000` sets the main synthetic storage load (default 1025),
through `U_HBBridgePresentationTableCLI --native-rows=10000`. Small paging cases
retain two rows followed by one. The interactive example is separate:
`U_HBBridgeNativeBrowse(10000,100)` sets source size and page size; its defaults
are 1000/13. Both sources are generated fixtures, not ERP-table queries.

To add actual hbBridge SQL integration, first keep a fresh owned typed-SQL
fixture serving in one terminal:

```powershell
./scripts/test-hbbridge-typed-sql.ps1 -Config '<private-ini>' `
    -Profile '<mssql-alias>' -Serve -ServeSeconds 1200
```

Wait for the printed fresh `endpoints.json` path, then run in another terminal:

```powershell
./scripts/test-protheus-presentation.ps1 -AppServerDirectory '<sdk>' `
    -IniFile '<sdk-ini>' -RpoDirectory '<vendor-rpos>' `
    -IncludeDirectory @('<totvs-includes>', '<project>/includes') `
    -NativeTables -HBBridgeEndpointsFile '<fresh-endpoints.json>'
```

`-HBBridgeEndpointsFile` requires `-NativeTables` and adds
`U_HBBridgePresentationSQLTest`: actual MSSQL SELECT over five constant
`VALUES` rows, TCP and gzip HTTP, typed dataset and owned native temporary
table. It does not read/write ERP tables. The runner copies the fresh endpoint
configuration only into its newly owned INI; deployment INIs remain untouched.
The endpoint JSON contains a private temporary HTTP token: keep it local,
not in Git or published evidence. The serving fixture stops at its bounded
lifetime or on `stop.request` in that fresh run directory. Reproduce with a
fresh run rather than retaining tmp endpoints.

The interactive `U_HBBridgeNativeBrowseSX5('<profile>','TCP',100)` or HTTP variant
instead reads actual SX5 data in an already prepared Protheus company/branch
context. Its source definition resolves dictionary/table/branch in Protheus.
This manual UI step is separate from automated SQL constant-row acceptance;
see [the native guide](../docs/native-presentation.md#read-real-sx5-data-in-the-native-browse).

## HTTP response probes

HTTP response maintenance: `test-harbour-http-send.ps1` reproduces native
partial-send/deadline/stop checks without database credentials.
`test-protheus-http-gzip.ps1` uses an explicit external SDK/INI/includes and a
fresh private SDK/RPO to verify FWRest and the TLPP client; `-CompileAll` compiles
all project TLPP. It requires Python 3 only for the owned loopback fixture.
See the [probe guide](../src/tlpp/tests/protheus/hbbridge.http.test/README.md).

`profile-protheus-http.ps1` uses the same isolated SDK setup and an explicit
fresh M08 MSSQL `-EndpointsFile` to time FWRest, gzip expansion, JSON parsing
and direct row validation. Identity is diagnostic; benchmark HTTP still
requires gzip. `benchmark-harbour-json.ps1` compares scalar codepage lookup
with one lookup per document: eight alternating batches of 50 encodes and
three warmups by default. It verifies identical bytes under four SET
configurations; its serializer-only timings imply no HTTP speedup.

The 2026-10-24 Windows checks passed native send 18/0 and FWRest/client 14/0;
the isolated `-CompileAll` run compiled 55 sources with zero errors. See
[scope and identities](../docs/validation/http.response.windows.json).

Requires PowerShell 7 and Git. The managed bootstrap resolves pinned copies
of hb_compile, Harbour and Zig. See [dependencies](../docs/dependencies.md).
No developer-specific checkout or global Zig is required.

`./scripts/test-harbour-memio.ps1` builds/runs the standalone managed MEMIO
snapshot probe in a new disposable directory. The 2026-10-23 Windows run passed
22 assertions plus one fresh-process check; it does not accept an SQL/product
cache service or Linux. See [lifetime, scope and future work](../docs/evolution.md#in-memory-results-between-requests).

```powershell
./scripts/bootstrap.ps1
./scripts/build-hbbridge.ps1
./scripts/test-hbbridge.ps1
```

Use `./scripts/test-hbbridge.ps1 -CredentialTransport` to exercise protected
SQL credential failures over the native TCP and HTTP listeners on loopback.
The focused run uses synthetic data, checks the public error and subsequent
Echo on both transports, and scans the captured output for credential
markers. The fixture checks that the ODBC connection path remains unused.

Bootstrap verifies the Zig archive checksum and the Git revisions in
[dependencies.json](../config/dependencies.json). A completed receipt avoids
unnecessary rebuilds. `-ForceBuild` rebuilds the selected Harbour profile.
`-SkipHarbourBuild` resolves sources and Zig. Windows uses the hb_compile
runner. Linux uses its compatibility preparer and GNU make with managed Zig
by default. The Linux GCC profile is available through `-Compiler gcc` and
`HBBRIDGE_HARBOUR_COMPILER=gcc` for subsequent scripts. See the
[Linux compiler selection](../docs/dependencies.md#linux-compiler-selection)
for prerequisites and commands. SQL Server ODBC runtime drivers and licensed
TOTVS resources are installed separately.

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

Use `./scripts/build-hbbridge.ps1 -DebugSymbols` for a separate debug build in
`out/debug`. It passes `-debug` before the project file and enables Harbour debug
information with `-b`; normal builds retain the non-debug linker setting. Use
`-OutputDirectory` to select another location. On Windows keep the generated PDB
with its matching executable. Prebuilt dependencies and the Zig library are not
automatically rebuilt with the same debugging settings. For direct `hbmk2`
invocation, put `-debug -prgflag=-b` before `hbbridge.hbp`: project filters are
evaluated in input order. Use separate directories to avoid stale symbols.

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

The default checks modified/added files from the working tree and index, plus
nonignored new files. Use `-Staged` to validate only changed staged files using
their indexed content, or `-All` for a complete review (`-Staged -All` reviews
the complete index). Deleted/renamed documents include their surviving language
pair. Changes to validation rules, tools or dependency/configuration policy
automatically require a full review. Third-party validation remains global;
all three Harbour validators still run, including when the selection is empty.
Selection does not refresh or modify the index. The isolated regression is
`./scripts/test-commit-check-selection.ps1`.

Staged validation removes its copied source snapshot in `finally`, including
checkout/validation failures. The selection regression also removes its
generated fixtures. TLPP copies must not remain under `tmp/`: they confuse
the TOTVS extension's source resolution. Retained file lists/logs contain no
duplicate sources; Protheus compilation uses maintained source paths.

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

## Native SQL binding proofs (T02)

```powershell
./scripts/test-harbour-sqlite-bind.ps1
./scripts/test-harbour-mssql-bind.ps1 -Config '<private-ini>' -Profile '<alias>'
```

Both runners use managed Harbour dependencies and create disposable run
directories with build logs, sanitized results and source/binary receipts.
SQLite uses an in-memory database. The initial MSSQL proof is Windows-only,
requires a configured SQL Server ODBC driver and uses a session-local `#temp`
table, dropped before disconnect; it does not alter application tables.
Only the private configuration path and explicit alias are supplied on the
command line. Credentials and native diagnostic text are not recorded.

These are native prepare/bind/fetch/metadata/cleanup proofs. They do not expose
QueryTyped, validate SQLMIX integration, or establish AppServer acceptance.
Exact SQLite fixed DECIMAL remains unsupported. See the
[contract](../docs/typed-sql.md), [connector decision](../docs/typed-sql-connectors.md)
and [sanitized evidence](../docs/validation/sql.bind.windows.json).

## Managed typed SQL integration (T03)

```powershell
# SQLite native hook, shared service and TCP/gzip HTTP/REST.
./scripts/test-hbbridge-typed-sql.ps1

# Add the explicitly selected private MSSQL profile.
./scripts/test-hbbridge-typed-sql.ps1 -Config '<private-ini>' -Profile '<alias>'
```

The runner prepares the managed ODBC, SQLite and HTTP libraries, builds the
versioned fixture and runs an owned child process with a 120-second default
execution budget (`-TimeoutSeconds` accepts 10..600). `-Config` and `-Profile`
are optional together; they select a private existing INI/profile without
copying credentials into the report. SQLite uses a disposable file fixture; MSSQL
queries use explicit inputs without changing application tables.

`-Serve` runs the integration checks first, then retains fresh owned loopback
TCP/HTTP listeners for an external consumer. `-ServeSeconds` accepts 1..1800
and defaults to 120; it bounds the serving phase separately from the initial
`-TimeoutSeconds` test budget. Pass an explicit private MSSQL config/profile
for the AppServer presentation test. When ready, the runner prints the local
`endpoints.json` path; it includes profile, ports and a private HTTP token.
Do not export that file as acceptance evidence. Stop by creating `stop.request`
in its fresh run directory or allow the serving deadline to expire. The
fixture records `serve.result.json` and checks owned listeners/SQL leases
were released. See the [AppServer consumer commands](#isolated-native-protheus-presentation).

The Windows run on 2026-10-25 passed **133 checks, zero failures**: 111 native
SDD/shared-service checks and 22 TCP/gzip HTTP/REST checks across SQLite and
MSSQL. It verifies `RDDI_EXECUTE` shared-hash output, string/Query compatibility,
native bindings, NULL versus empty/missing, exact int64/decimal values,
UTF-8/NUL, fixed metadata, pagination/count, explicit rejections and recovery.
The real wire checks use Harbour consumers, not AppServer. Native Protheus
presentation, Linux and other driver combinations require separate acceptance.

Fresh `tmp/typed-sql-<id>/` output contains `build.log`, `console.log`,
`result.json` and a source/binary/dependency `receipt.json`. All are disposable;
reproduction uses maintained sources/scripts and managed dependencies. The
runner rejects inconsistent check totals, nonboolean/failing checks, missing
SQLite execution or a requested MSSQL profile that was not exercised.

`prepare-odbc.ps1` also invokes `prepare-sqlite.ps1` before cache reuse. Both
managed connector receipts fingerprint native helpers, patch and library;
helper changes trigger rebuilding. See [dependencies](../docs/dependencies.md)
and [connector scope](../docs/typed-sql-connectors.md). The T02 probes above
remain standalone evidence and do not replace these integration checks.

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
./scripts/build-hbbridge-addons.ps1
./scripts/test-hbbridge-benchmark-addon.ps1
```

The build writes `addons/examples/hbbridgeaddons.hrb`; `-Output` selects
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

With a private profile, the fixture configures the private `[SQL] ODBCPooling`
policy before connections and prints its effective `odbcPooling` ready field.
Without it, mock mode retains the off policy. Other runtime settings are not
implicitly reproduced. The earlier 255-iteration fixture used pooling off;
record the ready value of a new run instead of assuming equivalence to that
run or the normal deployment. This is a correctness/reproduction host, not a
matched performance deployment. Use the
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
