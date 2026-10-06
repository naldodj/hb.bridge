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
operator-configured service scripts; no fixed installation or elevated-process
stop is assumed. A failed configured stop aborts compilation. Startup is
attempted after the compiler and preserves its failure status. The log is
`tmp/totvs-compile.log`. Compile the entire `src/tlpp/` tree including tests.
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

The operator accepted INI's 13 checks, Windows clock, normal RPC and SQLite's
29 checks in the report recorded on 2026-10-04. Earlier failed TOTVS stopping
attempts remain historical; no later compiler log was supplied. Forced socket
failures/partial sends, nondefault destinations, MSSQL and Linux remain pending.
The [credentials proposal](../docs/credentials.md) covers portable storage;
encrypted credential management is not implemented yet.
