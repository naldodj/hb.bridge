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
| `.deps/hb_compile/out/linux/` | Linux native Harbour installation. |
| `.deps/http/` | Isolated hbhttpd/hbtcpio preparation and checked patch/build receipt. |
| `.hbcommit/` | Maintenance sources; uses the same compiled `hbrun`. |
| `out/` | Product executable; `tmp/` holds isolated builds and logs. |

`.deps/`, build outputs and local identity configuration are ignored by Git.
No duplicate `bin/harbour` runtime is distributed. A successful Harbour build
writes `hbbridge-toolchain.json` with manifest hash/platform/revisions; an
unchanged complete toolchain is reused. `-ForceBuild` rebuilds it.
`-SkipHarbourBuild` downloads/checks out dependencies only, leaving a full
Harbour build required. Updating a pin is an explicit maintenance change and
requires rebuilding, running regressions and updating provenance/license notes.

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
HTTP framing/Content-Length. The
pinned Harbour checkout remains intact. `-hblib` is hbmk2's library build
mode, rather than a separate contrib dependency.
[Git attributes](../.gitattributes) force LF for `config/patches/*.patch`,
keeping manifest checksums stable across Windows/Linux clones.

Plain HTTP requires no OpenSSL SDK. Direct HTTPS is an optional build with
`HB_HTTP_TLS=1`, **hbssl**, the target OpenSSL SDK/runtime and
`HB_WITH_OPENSSL` selecting its include directory. A TLS-enabled configuration
requires the linked library, certificate and private key; availability of the
Harbour source alone is insufficient. HTTPS and Linux acceptance remain
separate. See [HTTP configuration/routes](http.md).
Leave HB_HTTP_TLS unset for the default HTTP build; other nonempty values fail.

The pinned native PowerShell hb_compile runner targets Windows. On Linux,
hbBridge invokes its Harbour compatibility preparer and builds the same pinned
source using native GNU make/GCC, installing into the managed Linux prefix.
Install PowerShell 7, Git, make, GCC/binutils and unixODBC development headers
first. The bootstrap reports missing prerequisites; it does not silently change
the host's package manager. The product's Zig static library uses managed Zig,
and hbmk2 uses the compiler selected for that platform. Linux execution must
be homologated separately; a Windows build is not evidence of Linux success.

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

Protheus compilation requires the operator's licensed AppServer, includes,
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
