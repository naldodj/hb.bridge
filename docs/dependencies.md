# Managed build dependencies

[Português](dependencies.pt-BR.md)

hbBridge resolves its own build environment. PowerShell 7 and Git are the
bootstrap prerequisites; Windows/Linux runtime packages and the licensed
TOTVS SDK remain external prerequisites where applicable. There is no default
dependency on a developer's `C:\GitHub\hb_compile` installation or global Zig.

```powershell
./scripts/bootstrap.ps1
./scripts/build-hbbridge.ps1
./scripts/test-hbbridge.ps1
./scripts/commit-check.ps1
```

## Manifest and directories

[config/dependencies.json](../config/dependencies.json) pins the hb_compile
and Harbour Git revisions, Zig version, official archive URLs/checksums and
required Harbour contribs. Bootstrap checks out those revisions in managed
directories; revision/origin mismatches are errors rather than an invitation
to overwrite changes. Compatibility preparation may modify the managed source;
local edits are preserved. Existing developer checkouts are untouched.

| Location | Purpose |
| --- | --- |
| `.deps/hb_compile/` | Project-owned checkout of the build orchestrator. |
| `.deps/harbour/` | Project-owned pinned Harbour source. |
| `.deps/tools/zig/` | Pinned Zig archive/executable, SHA256 verified. |
| `.deps/hb_compile/out/zig/` | Windows Harbour tools, includes and libraries. |
| `.deps/hb_compile/out/linux-zig/` | Linux Harbour installation built with Zig (default). |
| `.deps/hb_compile/out/linux/` | Linux Harbour installation built with GCC. |
| `.deps/http/` | Isolated hbhttpd/hbtcpio preparation and checked patch/build receipt. |
| `.deps/odbc/` | Isolated SDDODBC preparation and checked patch/build receipt. |
| `.deps/sqlite/` | Isolated SDDSQLite3 typed-reader preparation and checked patch/build receipt. |
| `.hbcommit/` | Maintenance sources; uses the same compiled `hbrun`. |
| `out/` | Generated product/addons; rebuilt from maintained sources/scripts. |
| `tmp/` | Fully disposable work directories and logs; never a prerequisite. |
| `scripts/`, `tests/` | Versioned reusable automation, fixtures and probes. |
| `docs/validation/` | Sanitized historical summaries and reproduction commands. |

The Linux Zig profile stores its HTTP, ODBC and SQLite stages and receipts
under a `linux-zig/` subdirectory of each preparation root.

`.deps/`, build outputs and local identity configuration are ignored by Git.
No duplicate `bin/harbour` runtime is distributed. A successful Harbour build
writes `hbbridge-toolchain.json` with manifest hash, platform, compiler and
revisions. Bootstrap reuses a complete toolchain for the selected profile.
`-ForceBuild` rebuilds that profile. `-SkipHarbourBuild` downloads and checks out
dependencies. Updating a pin is an explicit maintenance change and requires
rebuilding, running regressions and updating provenance/license notes.

## hb_compile integration

The next dependency integration delegates selective external SDK resolution
to hb_compile, including its generated environment, target/runtime artifacts
and capability-aware cache receipts. The pinned Windows resolver already
supports OpenSSL; native Linux resolution needs an upstream capability or
an explicitly supported WSL/Docker route. This is pending implementation;
the current TLS SDK workflow below remains applicable. See
[the dependency review](evolution.md#one-dependency-resolver).

[hb_compile](https://github.com/DNATechByNaldoDJ/hb_compile) orchestrates Harbour
compilation and compatibility preparation. Windows uses its native Zig build
runner with project-owned source/install paths and a contrib whitelist:
NETIO, ZIP, SQLite, SQLRDD/SQLMIX and ODBC. Zig is obtained from the official
distribution using the manifest checksum. Unrelated GUI libraries and private
HBDAP repositories are not implicit build requirements.

HTTP adds native **hbhttpd** and **hbtcpio**. The bootstrap invokes
[prepare-http.ps1](../scripts/prepare-http.ps1) to build those contribs from
an isolated source copy. The manifest pins the checksum of
[hbhttpd.patch](../config/patches/hbhttpd.patch): raw request-body exposure,
configurable workers, listener readiness/coordinated stop and rejection
of unsupported Transfer-Encoding and duplicate/nondecimal Content-Length,
plus preservation of structured handler error bodies and byte-oriented
HTTP framing/Content-Length, configurable response send deadlines and bounded
partial/nonblocking sends. Incomplete responses close before access logging
or keep-alive reuse. The
pinned Harbour checkout remains intact. `-hblib` is hbmk2's library build
mode, rather than a separate contrib dependency.
[Git attributes](../.gitattributes) force LF for `config/patches/*.patch`,
keeping manifest checksums stable across Windows/Linux clones.

The patch also uses native C for selected request and response processing. It
remains a patch against the pinned upstream source because the affected code
includes private server internals; a standalone replacement would require
maintaining a fork of the server. Its parser rejects Content-Length values
outside the native signed integer range. Revalidate behavior and performance
when changing the pinned Harbour version.

`hbbridge.hbm` selects Harbour `-gc3` for project executable sources, generating
C operations instead of a compact p-code array. This can improve CPU-bound
work but may increase build time or executable size; measure each workload.
It does not change HRB addon generation or force a rebuild of Harbour and
contrib libraries. Bootstrap leaves caller-supplied compiler flags intact.

MSSQL acceptance identified an SDDODBC variable-length fetch defect when a
Unicode `SQLGetData` length probe returns `SQL_NO_TOTAL`. The managed
[sddodbc.patch](../config/patches/sddodbc.patch) corrects this connector path,
binary field flags and UTF-16 surrogate conversion for UTF-8 codepages,
preserving embedded NULs and empty/null values across chunks. It imposes no
payload ceiling. The same managed patch adds optional per-profile native
ODBC login/query timeouts, C validation against native integer capacity and
exact attribute readback. Explicit attributes that fail or change are rejected;
login is verified again after connection and every statement, including a
separate page count, receives its configured query timeout. Missing attributes
retain driver defaults and explicit zero disables them. See
[timeout configuration and scope](configuration.md#native-mssql-timeouts).
This changes the staged connector interface, not the pinned upstream checkout,
and does not fix the separately tracked D03 raw FLOAT fractional loss.
[prepare-odbc.ps1](../scripts/prepare-odbc.ps1)
checks the manifest's `harbour.odbcPatch` checksum and applies the reviewed
patch to an isolated `sddodbc` stage under `.deps/odbc/`, preserving the pinned
source checkout.
It builds only SDDODBC and installs its library/metadata into the selected
managed Harbour installation. Windows uses native ODBC libraries; Linux
requires unixODBC development headers and libraries.

The managed ODBC and SQLite patches also provide the tagged `RDDI_EXECUTE`
branch used by `RPCRDD.QueryTyped`, preserving the existing string/Query path.
Native readers execute on the current SDD-owned connection and share the
ordinary SQL lease/mutex; no second login or raw-handle export is introduced.
The [SQLite patch](../config/patches/sddsqlt3.patch) is pinned by
`harbour.sqlitePatch` and prepared by
[prepare-sqlite.ps1](../scripts/prepare-sqlite.ps1). ODBC preparation invokes
it before checking its own cache. Both patches copy the project-owned
[shared helpers](../src/c/hbbridge.sql.typed.h) and their respective
[ODBC](../src/c/hbbridge.odbc.typed.c)/
[SQLite](../src/c/hbbridge.sqlite.typed.c) reader into disposable staged sources.

Bootstrap prepares these connectors after Harbour, including when the base
toolchain is reused. Product builds and Harbour test launchers prepare them
before linking. Their receipts under `.deps/odbc/` and `.deps/sqlite/`
record the Harbour revision, patch SHA256, native helper source hashes,
platform/compiler and installed library SHA256. Changed helpers invalidate
cache reuse alongside patch/library changes.
`./scripts/prepare-odbc.ps1 -ForceBuild` rebuilds both staged connectors;
`./scripts/prepare-sqlite.ps1 -ForceBuild` rebuilds SQLite alone. Acceptance
remains separate from compilation: reviewed patches and successful builds do
not certify every driver, Linux or AppServer. See the
[typed connector integration and evidence](typed-sql-connectors.md).

Plain HTTP requires no OpenSSL SDK. Direct HTTPS is an optional build with
`HB_HTTP_TLS=1`, **hbssl**, the target OpenSSL SDK/runtime and
`HB_WITH_OPENSSL` selecting its include directory. A TLS-enabled configuration
requires the linked library, certificate and private key; availability of the
Harbour source alone is insufficient. HTTPS and Linux acceptance remain
separate. See [HTTP configuration/routes](http.md).
Leave HB_HTTP_TLS unset for the default HTTP build; other nonempty values fail.

## Linux compiler selection

The pinned PowerShell hb_compile runner handles the Windows Zig build. On
Linux, hbBridge invokes the same compatibility preparer and builds the pinned
Harbour source with GNU make and the selected compiler. The existing hb_compile
revision supplies both integration points.

Install PowerShell 7, Git, GNU make and unixODBC development files for Linux.
The GCC profile also needs GCC and binutils. The managed Zig 0.16.0 compiler
is the default and also builds the product's Zig static library in both
profiles. Harbour's `hbmk2` uses the selected profile for C compilation and
linking.

To bootstrap with GCC and select it for subsequent builds and tests, run
these commands from the repository root in the same PowerShell session.

```powershell
pwsh ./scripts/bootstrap.ps1 -Compiler gcc
$env:HBBRIDGE_HARBOUR_COMPILER = 'gcc'
pwsh ./scripts/build-hbbridge.ps1
pwsh ./scripts/test-hbbridge.ps1
```

Bootstrap also accepts `HBBRIDGE_HARBOUR_COMPILER`. Its explicit `-Compiler`
option takes precedence. Clear the variable with
`Remove-Item Env:HBBRIDGE_HARBOUR_COMPILER` to return to Zig for subsequent
commands. Windows uses Zig.

`scripts/toolchain.ps1` centralizes path/version resolution. Build/test/commit
scripts use its `hbrun`, `hbmk2`, Zig and compiler paths. `-HbCompileRoot` and
`-ZigPath` are explicit advanced overrides for a maintained external toolchain;
the default is always project-owned. Compiler/PATH changes are scoped to the
script and restored after execution. A product build does not stop servers:
use `-OutputDirectory tmp/candidate` to build alongside an active installation.

## Database and Protheus prerequisites

SQLite comes from the selected Harbour contribs. MSSQL uses SQLMIX/SDDODBC,
an ODBC driver manager and an SQL Server ODBC driver of the process architecture.
A driver/DSN and credentials are installation-specific, not Git-managed build
secrets. On Linux, unixODBC development files are required at build time and
runtime driver packages at deployment. Configure Windows identity or Linux
Kerberos for integrated authentication, or a private SQL login configuration.
See [credential design](credentials.md) and [SQL example](../examples/sql/README.md).

Protheus compilation requires a licensed AppServer, includes,
environment and RPO. [build-totvs.cmd](../scripts/build-totvs.cmd) accepts paths
and environment arguments or `HBBRIDGE_TOTVS_APPSERVER_DIR`,
`HBBRIDGE_TOTVS_INCLUDES`, `HBBRIDGE_TOTVS_ENV`. Optional stop/start script
paths are supplied explicitly. hbBridge does not download or assume a fixed
TOTVS installation. Compile `src/tlpp/` as a complete tree; renamed classes
need recompilation before the current client can be accepted.

Dependency licenses stay with their sources. Harbour linking exceptions do
not automatically apply to GPL maintenance utilities; Zig and zlib retain
their own terms. Global project licensing is still under
[provenance review](licensing.md).

## Potential upstream contributions

The managed patches are integration artifacts. Generic fixes should be
proposed separately: HTTP framing by byte length, ODBC binary flags and
variable-field/fetch-error handling. Additive `Ready`/worker/body APIs require
separate compatibility review. hbBridge-named timeout helpers, JSON integer
capacity and strict timeout readback are project policies; an upstream
timeout interface should be generic. The current Windows/MSSQL evidence
does not certify other drivers or platforms.

Unconditional `SO_REUSEADDR` needs a separate platform policy: Windows can
permit competing binds with indeterminate delivery. See [Microsoft's socket
semantics](https://learn.microsoft.com/en-us/windows/win32/winsock/using-so-reuseaddr-and-so-exclusiveaddruse).
Keep upstream formatting/notices and follow the [Harbour contribution process](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/README.md#how-to-participate).
This records candidates; no contribution has been submitted.
