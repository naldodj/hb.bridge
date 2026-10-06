# Tests

[Português](README.pt-BR.md)

```powershell
./scripts/bootstrap.ps1
./scripts/test-hbbridge.ps1
```

The runner resolves managed Harbour/Zig, prepares isolated fixtures under
tmp/tests-<id>, compiles the shared product components through hbbridge.hbm,
records results.log and returns the suite exit code. It does not replace or
stop the installed product. Explicit HbCompileRoot/ZigPath overrides are
available; a standalone test target without fixtures may report SKIP, while
the runner prepares both. See [dependencies](../docs/dependencies.md).

## Automated Harbour coverage

- [Configuration](unit/hbbridgeconfigtest.prg): defaults, precedence, paths,
  invalid values and endpoint conflicts.
- [INI](unit/hbbridgeconfiginitest.prg): JSON equivalence, autoload, BOM/CRLF,
  strict numbers, punctuation/paths/errors, multiple profiles and alias case.
- [Clock](unit/hbbridgetimetest.prg): monotonic waits/concurrent advancement.
- [Contract](contract/hbbridgeservicestest.prg): registration/versions/channel
  permissions, types, independent metadata, handlers and JSON adaptation.
- [NETIO](integration/harbour/hbbridgenetiotest.prg): native arguments,
  core/discovery/addons, binary VF IO, separate admin, filters/credentials and
  stop/restart/rollback. Listeners choose free ports rather than installed ports.
- [HTTP](integration/harbour/hbbridgehttptest.prg): native hbhttpd routes,
  bearer/admin separation, shared Health/Echo/addon/SQL, NETIO equivalence,
  raw JSON body/errors, concurrent contexts, sanitized web status and
  shutdown/restart/startup rollback. HTTP acceptance is recorded separately;
  historical counts below predate this adapter.
- [Framing](integration/harbour/hbbridgeframingtest.prg): fragmented gzip,
  canonical lengths, CRC/truncation, optional budgets, deadlines, incremental
  codecs, exact 24-million-byte Echo and JSON/gzip beyond 16 MiB.
- [SQL](integration/harbour/hbbridgequerytest.prg): persistent SQLite, profiles,
  values/metadata, workarea/default-connection restoration, sanitized errors,
  16 concurrent calls, SQL pages/order/gaps/sentinel/full/partial/empty pages,
  representable ordinals, duplicate/reserved aliases, equivalent NETIO/TCP
  results and explicit case-sensitive slash profile selection.
- [MT](integration/harbour/hbbridgeservertest.prg): parallel/idle clients,
  invalid requests, worker settings, graceful shutdown, addon failure/isolation.
  The addon fixture holds 12 FORCELOCAL HRBs active behind a barrier and
  verifies owner/id plus counterBefore+1. Sequential reload may recycle
  STATIC values; a reset-to-one assertion would test an invalid assumption.
  A deliberate single-handle/12-thread counterprobe rejected 11 responses.
  Addons initialize per-call state explicitly; see
  [HRB semantics](../docs/milestone1.md#hrb-state-and-addon-ownership).

Prior Windows x64 run on 2026-10-04: **412 checks, zero failures, no skips**,
SQLite 3.53.4, log tmp/tests-236f1241c1174cf4b193c22f6eedb6e0/results.log.
That run included 383 previous checks, 26 INI checks and three strict SQL
rejections. New managed/renamed validation is recorded separately in
[acceptance](../docs/acceptance.md). The older 2026-10-01 MT baseline was
74 checks; the previous normalized 72-check baseline and fixture corrections
are in [reorganization](../docs/reorganization.md).

Managed-toolchain validation on 2026-10-04 passed **416 checks, zero failures,
no skips**, log tmp/tests-d1b829ff332c414f816a6e70748152d1/results.log.
It added two INI and two explicit SQL alias checks. This predates the
PascalCase/HTTP changes of 2026-10-06 and requires their separate validation.

## Protheus compilation and calls

Compile all src/tlpp, including tests/protheus. Public product APIs are
namespaced classes: HBBridgeClient, HBBridgeConfig, HBBridgeTime and
HBBridgeRPCDataSet. Existing procedure U_ entry points are retained; the
preprocessor also generates U_ from User Function, so no conversion is needed.
Renamed classes and optional-profile changes require a new compile/runtime
acceptance; prior RPO results do not cover this revision. The configurable
[build utility](../scripts/build-totvs.cmd) requires the licensed SDK.

[Client INI template](../config/examples/protheus-appserver.ini): host/port/
timeout/budgets/chunk and optional SQLProfile. Omitted transport arguments
fall back to 127.0.0.1:1512, 30000 ms; 0.0.0.0 is not a client destination.
**SQLProfile now defaults to empty**. Each Query/dataset selects an alias;
the query test reports PROFILE_REQUIRED before I/O if none is supplied or
configured. sqlite_demo is only an example. Aliases do not resolve company,
tenant, xFilial or physical table names; the caller prepares business inputs.

[U_HBBridgeConfigTest](../src/tlpp/tests/protheus/hbbridgeconfigtest.tlpp)
checks defaults/INI/overrides, destination/numbers, zero/negative/fractional
budgets, native chunk capacity, active INI and now explicit/empty/invalid
profile selection. Previous acceptance covered 13 checks; the revised test
adds three and requires a fresh run. Complement with no-argument Health/Query
against a configured nondefault destination.

[U_HBBridgeConnectionTest](../src/tlpp/tests/protheus/hbbridgeconnectiontest.tlpp)
checks TimeCounter after Sleep(1000), normalized units, nonregression and
deadline arithmetic. The reproduced Linux scale needs seconds × 1000
([issue 12](https://github.com/naldodj/totvs-protheus-open-issues/issues/12));
Windows uses milliseconds. A changed scale stops the test and reports raw data.
Then Health, Echo and ADDON.Execute use examples/hbbridgesampleaddon.prg with
__IS_THE_ADDONS_EXECUTION_ENABLED__. Echo compares all 200000 bytes, including
varied ASCII whose request gzip must exceed 65535 bytes. Logs summarize
integrity/size; Health still uses the demonstration Zig library.

The single active Protheus contract is HBBRIDGE/1, framed JSON and gzip.
TLPP uses GzStrComp/GzStrDecomp, C uses incremental codecs; the whole frame is
compressed but declared length counts uncompressed JSON. Constants live in
[hbbridge.h](../includes/hbbridge.h). Different signatures, unframed JSON and
non-gzip wrappers are rejected.

[U_HBBridgeQueryTest](../src/tlpp/tests/protheus/hbbridgequerytest.tlpp)
checks named fields/decimal/EOF/close, empty/invalid SQL, unknown profiles,
recovery and first/next/last/empty pages, hidden ordinals, gaps and invalid
order/page parameters. Run the [SQL example](../examples/sql/README.md), then
the separate Protheus call:

```advpl
U_HBBridgeQueryTest("sqlite_demo", "127.0.0.1", 1512, 30000)
U_HBBridgeQueryTest("mssql/pData", "127.0.0.1", 1512, 30000)
```

Use the [WebApp entry](https://localhost:4321/webapp/?p=U_HBBridgeQueryTest&e=PROTHEUS)
without arguments only with an appropriate optional SQLProfile configured.
The launcher does not edit the AppServer INI or execute tests. Config changes
alone need no TLPP recompile; source/class changes do. INI launchers use
sanitized --config-info from the updated executable. SERVICE_NOT_FOUND means
Query was not registered (usually no profiles); PROFILE_NOT_FOUND means
the service exists but the requested alias does not.

## Manual acceptance and remaining scenarios

Operator report 2026-10-03: normal Health/ADDON/two Echo calls passed with
200000 identical bytes; varied request gzip 152964 bytes. Earlier milestone1
logs recorded three compiled sources without errors and successful RPC.
Initial SQLite/page acceptance: 2026-10-04 00:40:06, thread 41228,
sqlite_demo, all 29 checks true.

Later report recorded in the 2026-10-04 session reconfirmed those 29 checks,
RPC and all 13 client configuration checks, including activeAppServerIni.
Windows clock: Unix=false, raw delta 1097.692700, normalized 1097.773500 ms
after Sleep(1000), result OK. This is operator execution, not the Harbour
runner. It supplied no execution time/thread/hash/arguments/compile log and
does not prove nondefault destination selection. Earlier agent stopping of
elevated TOTVS processes failed before compilation; manual acceptance superseded
that old execution gap, with history retained in the acceptance matrix.

Pending: renamed TLPP/16-check configuration test, real MSSQL, nondefault
host/port/profile, Linux, clock precision/adjustment/wrap, forced socket
timeout/connection failure/positive partial Send/Receive/GetError,
MAXSTRINGSIZE, null/nested/multibyte/non-ASCII values, larger/incompressible data
and Harbour codepage/revision compatibility. Persistent calls/pool/multiplex,
coalescence/disconnect/replay prevention, explicit-tenant session owner/TTL/
cleanup, TLS/JWT and optional gRPC/Smartlink/AMQP are roadmap work. Test technical
capacities separately from optional memory/worker/deadline policies.
