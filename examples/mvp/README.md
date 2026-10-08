# Minimal hbBridge example

[Português](README.pt-BR.md)

This directory contains a launcher and instructions for the same
`out/hbbridge.exe` as the product. Clients/addons/implementation/tests are
shared; its name records the proof-of-concept origin preserved in Git history.
Defaults: Protheus `0.0.0.0:1512`, NETIO `0.0.0.0:2941`, 64 workers per listener.
Administration starts only with its own configured credential.

From the repository root, using PowerShell 7 and Git:

```powershell
./scripts/bootstrap.ps1
./scripts/build-hbbridge.ps1
./examples/mvp/run.ps1
```

`run.ps1` delegates to the [shared launcher](../../scripts/run-hbbridge.ps1)
and sets the working directory for `addons/`. It forwards only explicit
`-Port`, `-MaxWorkers`, `-Config`; defaults belong to the runtime and do not
override INI/JSON values. Without `-Config`, the product reads
`out/hbbridge.ini` if present, otherwise defaults. Precedence is defaults <
file < CLI; see [configuration](../../docs/configuration.md). Stop with Ctrl+Q.
Build refuses a running output; use `-OutputDirectory tmp/candidate` to build
alongside an active instance. See [scripts](../../scripts/README.md).

Compile all `src/tlpp/`, including [client](../../src/tlpp/hbbridgeclient.tlpp)
and [tests](../../src/tlpp/tests/protheus/hbbridgeconnectiontest.tlpp), in the
AppServer. Run `U_HBBridgeConnectionTest()` or explicit host/port/timeout.
Omitted arguments read `[hbBridge]` in the active AppServer INI, falling back
to `127.0.0.1:1512`. Merge the
[client template](../../config/examples/protheus-appserver.ini) separately from
the server INI. The test calls Health, Echo and ADDON.Execute with
`module="examples/hbbridgesampleaddon.hb"` and module params; the
[shared addon](../../addons/examples/hbbridgesampleaddon.hb) is enabled through
`__IS_THE_ADDONS_EXECUTION_ENABLED__`. Protheus uses HBBRIDGE/1, JSON and gzip.
hbBridge is generic; business/tenant/company/branch/table rules remain in
Protheus, and addons receive explicit application parameters.

For Query/pages, stop this server and use the [SQL example](../sql/README.md):

```powershell
./examples/sql/run.ps1
```

Without SQL profiles in the selected file or automatic INI, RPCRDD.Query is
not registered. This launcher can enable it with
`-Config config/examples/sqlite.ini` or its JSON equivalent. The SQL launcher
validates profiles and displays the Protheus invocation; tests run separately
in the AppServer. `sqlite_demo` is an example alias, never a library default.

[Milestone 1](../../docs/milestone1.md) includes native NETIO/VF IO tests;
[milestone 2](../../docs/milestone2-framing.md) repairs fragmented TCP and has
normal Health/ADDON/two Echo Protheus acceptance. Payload/wire caps are
optional and default off; chunks are buffers, not total message limits.
[Milestone 3](../../docs/milestone3-sql.md) implements SQLite/pages and ODBC
MSSQL for acceptance. Operator acceptance on 2026-10-04: 29 SQLite checks,
later 13 client configuration checks, Windows clock and normal RPC. Renamed
classes and revised optional-profile checks require renewed TLPP acceptance.
VF IO TLPP facade, OS service, negotiation and debugging remain in
[TODO](../../TODO.md). See [tests](../../tests/README.md).
