# Reference environment and acceptance

[Português (Brasil)](acceptance.pt-BR.md)

Acceptance of the earlier structural reorganization was confirmed.
This document identifies the development environment and separates historical
results, reported manual AppServer runs and local automated regressions.
It does not certify other versions or subsequent changes automatically.

## Reference environment

| Component | Reported reference |
| --- | --- |
| OS | Windows 11 x64. |
| AppServer | 7.00.240223P-20260211, 24.3.1.5, debug symbols. |
| AppServer revisions | SVN 46783, Vader 3792. |
| AppServer port | 1234, independent of hbBridge listeners. |
| LIB | 20260706 — 20260703_152624. |
| LIB commit | 72adb06b99257e6165f7484ba26679818c037720. |
| Smartclient WebApp | 7.00.240223P-20260702, 10.2.1, HTML-10.2.1 WIN, remote 64-bit. |
| Broker Proxy | Disabled. |
| DBAccess | 20240224-20260522, 24.1.1.3, standalone MultiDB Windows x86_64. |
| DBAccess memory | Release/SmartHeap 11.6.1. |
| Database | MSSQL 16.0.1200.5 DEVELOPER. |
| Environment | PROTHEUS, development. |
| RPO/dictionary | 12.1.2510, dictionary in database. |
| Local files | SQLITE. |

| Build component | Reference |
| --- | --- |
| Compiled Harbour | 3.2.1dev (r2608271822), multithread VM. |
| Toolchain | Historical hb_compile/out/zig, hbmk2 -comp=zig. |
| Zig | 0.16.0. |
| Exercised platform | Windows x64. |
| Libraries | hbnetio, hbextern, rddsql, sddsqlt3/SQLite, sddodbc/ODBC, Harbour runtime/compiler, Zig library. |
| Inspected Harbour source | Local commit 8d94c31367104a57eb9ae6fa248cca2abb8db309. |

An inspected source checkout does **not** prove the compiled runtime came from
that commit; the runtime's available identifier is the revision above.
Distribution builds must record exact commits/options/contribs/dependencies.
The managed bootstrap is documented in [dependencies](dependencies.md).

Original Milestone 1 calls used loopback, port 1512, timeout 5000 ms and Health/Echo/ADDON.
For current acceptance compile the whole src/tlpp tree and run
U_HBBridgeConnectionTest(cHost,nPort,nTimeout,nLargePayloadBytes).
Without arguments it reads active [hbBridge], falling back to
127.0.0.1/1512/30000 ms and zero optional extra Echo.
Constructor budgets default 0/0, chunk 65536, positive TLPP timeout.
Historical tests do not certify renamed/new sources.

## AppServer acceptance on 2026-10-03

Local logs corroborated manual compilation and WebApp execution:

- **07:45:37 São Paulo:** 3 sources, 3 successes, 0 errors:
  hbbridgeconnectiontest.tlpp and the then-named thbbridgeclient.tlpp/
  trpcdataset.tlpp. Evidence: tmp/console.log.
- **08:00:30, thread 32748:** Health/ADDON/Echo success:true in
  C:\totvs\protheus1212410\protheusdata\logs\console.log.
- Full JSON comparison preserved message and **200,000 X characters**.

This accepted the Milestone 1 adapter/core, not fragmentation, low-compressibility
data, MAXSTRINGSIZE, future codecs or every planned service.

[build-totvs.cmd](../scripts/build-totvs.cmd) uses the project source root and
tmp/totvs-compile.log. A local build attempt received Access denied stopping the
elevated AppServer and ended before compilation. The successful run above was
manual.
[WebApp test](https://localhost:4321/webapp/?p=U_HBBridgeConnectionTest&e=PROTHEUS).

MSSQL/SQLite identify SQL integration targets. AppServer version does not
establish actual MAXSTRINGSIZE; measure effective capacity/codepages.

## Milestone 2 history and current contract

Earlier framing baseline: **196 checks, zero failures/no skips**, gzip above
65,535 both ways, fragmentation, CRC/truncation/policies/slow clients,
alternative-format rejection and old addon-alias removal.
That count predates ceiling removal/incremental compression.

The product now requires HBBRIDGE/1 and ADDON.Execute.
Payload/wire default 0, read buffer 65536, Harbour budget 30000 ms, zero disables
its deadline; NETIO zero maps to -1.
C gzip is incremental but JSON remains materialized.
Runtime metadata exposes string/socket long/zlib uInt/NETIO int capacities.
Protheus drains admitted workers; zero deadlines can prolong shutdown.
NETIO signals/closes its connections.

The later pre-SQL run passed **305 checks, zero failures/no skips**:
exact 24,000,000-byte Echo, JSON/gzip over 16 MiB both ways, incremental compressor,
zero/positive policies, positive/no Harbour deadline and nine-digit declared
length without allocating 100 MB.
Log: tmp/tests-1156a4ae33964edc925ff65e09748ddb/results.log.
Compressed-output/zlib guards and isolated build/help/invalid config passed.
29 clock checks covered repeated reads/waits/eight threads.
GetTickCount64 was exercised; POSIX CLOCK_MONOTONIC compiled without runtime
acceptance.

<a id="operator-rpc-confirmation-on-2026-10-03"></a>

### Manual RPC confirmation on 2026-10-03

Reported manual AppServer output:

~~~text
hbBridge Health Protheus OK: {"success":true,"message":"hbBridge Zig Engine Active"}
hbBridge ADDON.Execute Protheus OK: {"success":true,"addon_msg":"Executado via HRB Addon no hbBridge!"}
hbBridge Echo Protheus OK: 200000 bytes, conteudo identico.
hbBridge Echo fragmented Protheus OK: 200000 bytes, conteudo identico; gzip request=152964 bytes.
hbBridge RPC Protheus OK: todos os testes solicitados passaram.
~~~

These are verbatim manual AppServer logs; Portuguese output is intentionally
preserved.
They confirm complete payload comparison and normal completion, with varied
request gzip 152,964 > default 65536-byte buffer.
That round was not repeated during local validation; execution time/arguments/
binary hash were not supplied.

Clock values were absent from that earlier report and supplied later.
The current static HBBridgeTime uses TimeCounter and validates normalized
Sleep(1000) scale, detecting future unit changes.
[Issue #12](https://github.com/naldodj/totvs-protheus-open-issues/issues/12).
Precision/regression/wrap and Linux need acceptance.
An optional larger Echo must use measured MAXSTRINGSIZE.
Normal EOF was accepted; timeout/GetError/failure and forced partial-positive
Send still need identified runs.

## Milestone 3 SQL/pages on 2026-10-04

Initial complete SQL regression: **383 checks, zero failures/no skips**,
tmp/tests-245a7d7044724d3db678f1e6052194b7/results.log.
Linked SQLite reported **3.53.4** via sqlite_version().

An isolated persistent SQLite file exercised named results/metadata, empty/errors,
NULL expressions, previous area/connection restoration and 16 concurrent calls.
ROW_NUMBER/BETWEEN pages were produced in SQL, with compound/descending order,
gapped IDs, first/last/empty pages, sentinel/hidden ordinal and arithmetic limits.
NETIO/TCP returned equal simple/paged results.

Dataset/test implementation preceded a local build attempt blocked during
TOTVS shutdown: tmp/marco3-totvs-build.log. No compilation/new AppServer execution
occurred in that attempt. Missing-DSN testing proved only sanitized ODBC errors,
not real MSSQL or DBAccess use.

An isolated JSON product smoke returned ID=10, rowCount=1, hasNext=true.
Historical binary path: tmp/marco3-product/hbbridge.exe.
Log: tmp/marco3-product-smoke.log.
SHA256: 8C90995602F336B1B5B395AD6AE36A4F2608079451E68A9BC142DE8EC9F6C17C.
The active canonical installation was not replaced.

### Failed SQL attempt at 00:27:04

The reported manual U_HBBridgeQueryTest run, thread 30460, returned
SERVICE_NOT_FOUND; Servico nao suportado.
This proves test entry/dispatcher response, not SQL execution.
A subsequent Service.List probe at 127.0.0.1:1512 found six basic services, no
RPCRDD.Query: tmp/sql-service-discovery.json.
The canonical executable's help already supported SQL; active process CLI was
not accessible during local inspection.

Registration requires nonempty sqlProfiles.
Guidance was to restart the current product with the SQLite configuration and
repeat the existing TLPP entry. Startup/test diagnostics were added.

The new diagnostic candidate printed RPCRDD.Query enabled; SQL profiles=1 and
returned ID=10/one row/hasNext=true on isolated ports.
Log: tmp/sql-registration-smoke.log.
SHA256: F2177CFA4AB76363EC2E773A39717057D0CA7CDA8F10B0FD03A13CB3DAC74490.
The canonical launcher also passed SQLite on isolated ports, with Port overriding
JSON, tmp/sql-launcher-smoke.log. These are server preparation, not AppServer
acceptance.

### SQLite acceptance at 00:40:06

Reported manual U_HBBridgeQueryTest run, AppServer thread 41228, PROTHEUS/sqlite_demo:
**29 checks true**. Accepted named/decimal values, navigation/EOF, close,
empty, SQL/profile errors/recovery, first/next/last pages, gaps, localEOF,
hidden ordinal and invalid page/order rejection.

Time is the reported São Paulo log time. The test was manual and was not
repeated during local validation.
Server hash and corresponding compile log were not supplied.
This covers SQLite/client revision used then, not MSSQL, expanded SQL types/
codepages or later client changes.

### INI configuration and Harbour baseline

Server INI/JSON now share validation, precedence defaults < one file < CLI,
automatic adjacent hbbridge.ini and explicit replacement.
--config-info is sanitized and opens no listener/database.
Launchers forward Port/MaxWorkers only when explicit; the SQL INI launcher
uses the product parser.

**412 Harbour checks, zero failures/no skips**:
tmp/tests-236f1241c1174cf4b193c22f6eedb6e0/results.log.
Added to 383: 26 INI cases and 3 strict invalid driver/order-direction rejections.
Coverage: equivalent INI/JSON, precedence, relative paths, BOM/CRLF,
password/ODBC punctuation, automatic loading and malformed-file rejection.

AppServer [hbBridge] reading followed the 00:40:06 test and received its own later
manual acceptance below. HBBridgeConfig selects GetSrvIniName/GetPvProfString.
No-argument clients/tests now read the seven template keys.
Client and Harbour config files must be aligned separately; a WebApp URL without
arguments may select values different from launcher output.

An updated INI candidate passed all three INI metadata examples, CLI precedence
and a first-page launcher smoke (ID=10/one row/hasNext=true) using an isolated
copy/canonical layout.
Log: tmp/ini-launcher-smoke.log.
SHA256: F51BE0E77B64CAA94B0C12016E24BB49153035A1B2EE680A24FCE26ADBE9CF5B.
MSSQL metadata validation is not an ODBC/DSN/database query.

The local AppServer section was appended preserving prior bytes, with tmp backup.
A local build attempt was blocked before compiler during process stop:
tmp/ini-totvs-build.log. U_HBBridgeConfigTest was prepared and subsequently
accepted in a reported manual AppServer run.

<a id="later-operator-configurationclocksqlite-confirmation"></a>

### Later manual configuration/clock/SQLite confirmation

Reported in the **2026-10-04 session**, after client-configuration changes.
This round was manual; those AppServer tests were not compiled or executed
during local validation.

| Entry | Report |
| --- | --- |
| U_HBBridgeConfigTest | All 13 true: defaults/INI/precedence/invalid override, zero-negative-fraction budgets, port/timeout, native chunk and activeINI. |
| Connection-test clock | Unix=false, raw 1097.692700, normalized 1097.773500 ms after Sleep(1000), OK. |
| Health/ADDON/Echo | All passed; two identical 200,000-byte results, varied request gzip 152,964 bytes. |
| U_HBBridgeQueryTest | sqlite_demo, all 29 true: fields/decimal/errors/recovery/empty/pages/EOF/close. |

Exact configuration and SQL reports:

~~~text
hbBridge client configuration checks: {"missingSectionDefaults":true,"iniValues":true,"wildcardIsNotDestination":true,"invalidIniNumber":true,"explicitOverridesInvalidIni":true,"explicitZeroDisablesBudget":true,"invalidExplicitPort":true,"invalidTimeout":true,"nativeChunkCapacity":true,"negativeBudget":true,"fractionalBudget":true,"budgetBeyondSocketChunk":true,"activeAppServerIni":true}
hbBridge client configuration Protheus OK
hbBridge clock: Unix=false; TimeCounter delta=1097.692700; normalized=1097.773500 ms after Sleep(1000); result=OK
hbBridge RPC Protheus OK: todos os testes solicitados passaram.
hbBridge RPCRDD.Query checks: {"rowCount":true,"firstId":true,"firstName":true,"decimal":true,"missingField":true,"secondId":true,"secondName":true,"eof":true,"close":true,"empty":true,"emptyState":true,"invalidSql":true,"invalidSqlCode":true,"unknownProfile":true,"unknownProfileCode":true,"afterFailure":true,"afterFailureValue":true,"firstPage":true,"firstPageState":true,"hiddenOrdinal":true,"pageEof":true,"nextPage":true,"lastPageState":true,"noNextPage":true,"emptyPage":true,"invalidPage":true,"invalidPageCode":true,"invalidOrder":true,"pageClose":true}
hbBridge RPCRDD.Query Protheus OK; profile=sqlite_demo
~~~

This resolves execution acceptance of the new client configuration.
Time/thread/arguments/effectiveHostPort/hashes/build log were not supplied.
activeAppServerIni proves valid reading, not a nondefault destination.
Windows clock scale/advance was accepted; Linux/precision/realwrap/system-clock
changes remain open.

Remaining: real MSSQL, nondefault no-argument destinations/profiles, socket
timeouts/failures, forced positive partial sends and expanded types/volume/
codepages. The 412 Harbour checks are separate evidence.
Naming/dependency refactoring requires its own later validation; retain historical
artifact paths/hashes literally rather than implying new binaries share them.

## Managed dependency and profile revision on 2026-10-04

The project's own bootstrap compiled the pinned Harbour source and hbrun
through its managed hb_compile/Zig environment. Git pins were hb_compile
`2cb6f3ef59c297025a2c49c4cfa8c7639f3a1455` and Harbour
`6deac9cf3ad977ae829e5bca543d553b92dd4b6d`; Zig was 0.16.0.

The isolated Windows Harbour suite passed **416 checks, zero failures,
no skips**, log `tmp/tests-d1b829ff332c414f816a6e70748152d1/results.log`.
Compared with 412, two INI and two SQL cases verify multiple profiles,
slash/case preservation and explicit case-sensitive selection.

The candidate product build passed at `tmp/managed-product/hbbridge.exe`,
SHA256 `5443466A05A5206D7E6E1BC53F86DB604059EEF8F687A0C1B22973CFB7A76B18`,
build log `tmp/managed-product-build.log`. Sanitized profile metadata checks
did not query MSSQL. The active canonical installation was not replaced.

This validation predates the PascalCase and HTTP changes requested on
2026-10-06. Renamed TLPP classes/namespaces and the revised 16-check config
test were not compiled or accepted in Protheus. HTTP, direct HTTPS, real
MSSQL, Linux and later changes need separately recorded validation.

## PascalCase and native HTTP validation on 2026-10-06

The final targeted Windows Harbour/Zig HTTP run passed **65 checks, zero
failures, no skips**. It ran locally using the managed
toolchain. Log: `tmp/http-tests-f3476462dfbb4fe6b64d63b0de1c1149/results.log`;
wrapper log: `tmp/http-target-test.log`; dependency preparation log:
`tmp/http-prepare.log`. These logs contain the final run, replacing the
earlier 45- and 57-check targeted iterations.

The run exercised native hbhttpd alongside NETIO/TCP: authenticated Zig
Health, a 220 KB Echo, equivalent native NETIO results, SQLite alias
`memory/HTTP`, ADDON.Execute, service discovery, bearer/admin separation,
structured JSON service errors, Transfer-Encoding and duplicate/nondecimal
Content-Length rejection, eight concurrent contexts, shutdown during a
continuously incomplete header, same-port restart and startup rollback.
Administration is a read-only shared status panel; missing admin credentials
disable it. Caller ERP fields remain uninterpreted parameters.

UTF8EX-worker tests also passed byte-exact Content-Length, raw accents/CJK/
supplementary characters, BMP escapes, mixed-case surrogate pairs and object
keys, escaped backslash/quote preservation, invalid UTF-8/trailing-content
rejection, SQLite Unicode and native Unicode service execution. Orphan or
reversed surrogates returned `INVALID_JSON`/400 before dispatch. Surrogate
normalization is scoped to the HTTP adapter, without changing global hbjson
or the other transports.

Plain HTTP linked managed hbhttpd/hbtcpio, using the project patch SHA256
`ab6de8a46ec4aa3b01493db5ad5c90dd005f1b76ed61f8d38c6356602a3f3d1c`.
The targeted test executable's SHA256 was
`65661E1F56C02217D58E7C1F40FB6EF48E71D4BD144A43A9B8C379702E877EF5`.
Direct hbssl/OpenSSL TLS was not linked or exercised. HTTP request parsing/
timeouts remain native and do not inherit Protheus TCP budgets. See
[HTTP behavior and dependencies](http.md).

The complete Windows run on 2026-10-06 passed **487 checks, zero failures,
no skips**, including these HTTP cases and existing TCP/NETIO/SQL/addon
regressions. Log: `tmp/tests-f15616d6765e4c9c8103ca2992797c2d/results.log`;
wrapper: `tmp/full-tests-http-final.log`.
This HTTP run does not compile or accept the renamed TLPP sources in the
AppServer, prove real MSSQL/ODBC Unicode/HTTPS/Linux or implement administrative
mutations.

### Native HRB state semantics and counterprobe

The isolated native ownership test passed with **12 simultaneously loaded
FORCELOCAL HRBs**, a synchronization barrier, matching `owner=id` and
`counter=counterBefore+1`. Log: `tmp/addon-native-semantics.log`. Sequential
reload reused an initialized STATIC frame: the recorded counters continued
from 2 through 5 rather than resetting to one. The loader/runtime was not
changed to force resets.

A deliberately shared HRB handle across 12 threads was rejected in **11 of
12 responses**, log `tmp/addon-native-counterprobe.log`. This confirms that
the assertions detect shared state, while respecting Harbour's native frame
recycling. The fixture adds six checks to the full suite; the complete result
is recorded separately. Addons must initialize per-execution business state
from explicit parameters/locals; FORCELOCAL alone does not provide a reset.

## Thread state and candidate build on 2026-10-07

The native THREAD STATIC probe passed **31 assertions**, exit 0:
`tmp/thread-static-probe.log`. Twelve threads shared one HRB while retaining
private owners/counters; repeated calls and four HRB reloads in one persistent
thread retained values. This is separate evidence from the 487-check suite.
Native hbhttpd already uses thread statics and per-request resets. The audit
retained intentional shared SQL/test mutexes. See [the review](evolution.md).

The current checksum-verified HTTP preparation passed with patch SHA256
`52F937F65EDD03110C6DBC19A86C2D6E4A8031D04A6D686DE0B5AFC3D304CC1B`,
log `tmp/http-prepare-20261007.log`. The resulting patched `core.prg` is
identical to the source used by the prior full suite; that historical patch
hash and logs above remain recorded literally.

The isolated product build passed at `tmp/http-product-20261007/hbbridge.exe`,
SHA256 `D9E891155C7F36723F7E480E543F2FE0502D83DA9BFC22CC347CDC0C18C090EF`.
Build log: `tmp/http-product-build-20261007.log`; configuration checks:
`tmp/http-product-config-20261007.log`. The executable preserved default HTTP
disabled/empty SQL profiles, explicit wildcard bind/port overrides, aliases
`sqlite_demo` and `MSSQL/pData`, and sanitized secrets/connection strings.
Metadata inspection did not start listeners or query either database.

The final commit gate passed for **135 files**, including `check.hb`,
`commit.hb`, `3rdpatch.hb`, naming/indentation and documentation pairs.
Log: `tmp/commit-gate-20261007.log`. The staged-check pre-commit hook was
installed locally; no commit or publication was performed. Local documentation
links and `git diff --check` also passed.

Automatic external OpenSSL resolution, Zig HTTP and SQL materialization remain
design work. This candidate does not add HTTPS/Linux/MSSQL or AppServer
acceptance to the earlier records.

<a id="tlpp-http-operator-acceptance-on-2026-10-07"></a>

## TLPP HTTP manual acceptance on 2026-10-07

The accent comparison and FWRest unauthorized handling were adjusted,
followed by a reported manual `U_HBBridgeHTTPTest` run in **PROTHEUS**,
thread **25672**.
Program start: **15:16:12 São Paulo**; test **15:16:14–15:16:15**, elapsed
**00:00:01**. The reported RPO stack contained `tttm120.rpo`, `tlpp.rpo` and
`custom.rpo`. The report shows Health's Zig message and HTTP **200**.
The supplied transcript is preserved at `tmp/protheus-http-operator-20261007.log`.

All **13 checks** passed: `healthGet`, `healthPost`, `servicesGet`, `echo`,
`addon`, `unknownService`, `adminForbidden`, `unauthorized`, `afterFailure`,
`queryFirstPage`, `queryFirstValue`, `queryNextPage`, `queryLastValue`.
The Echo compares 200000 X bytes and an accent field, converting only that
field with DecodeUTF8. The query uses the existing dataset and constant SQL
with two IDs, exercising HTTP pagination without ERP table inference.

For this FWRest behavior, `cInternalError` contains Unauthorized while the
reported HTTP code may be zero. The client normalizes it to HTTP 401 and
local code UNAUTHORIZED. It preserves the JSON service errors for tested
403/404 responses; the 401 fallback is not the server's original JSON body.
The property is a framework compatibility dependency; another LIB needs
its own acceptance. A subsequent defensive initialization also handles a
native 401 with an empty internal reason, without changing the tested path.
That alternate branch has not been exercised on another LIB.

This is reported manual AppServer runtime acceptance, without a local test run
or a supplied compiler-success log. An earlier local build attempt returned
-1073740791; its log identified an include-directory value as the environment. It did
not establish successful compilation. The reported manual run supersedes that
execution gap for the exercised HTTP sources; logs remain at
`tmp/totvs-http-build-run.log` and `tmp/totvs-compile.log`.

The report does not identify the SQL alias/backend, client URL/token/settings
or server executable hash. It therefore does not add real MSSQL, HTTPS,
Linux, full Unicode, alternative configuration or the 16-check client config
test to this acceptance. See [the example](../examples/http/README.md).

The final local working-tree gate passed **139 files** with `check.hb`,
`commit.hb`, `3rdpatch.hb` and project conventions; log:
`tmp/commit-gate-tlpp-http-20261007.log`. Working-tree/index whitespace and
all local links across 59 documents passed. The existing staged snapshot
was preserved; these validations did not create a commit or publication.

## Native Harbour source extension on 2026-10-07

Adoption of `.hb` was authorized for project-owned Harbour sources. All **26** files
under `src/hb/`, `tests/` and `addons/` were renamed, and product/test HBP/HBM,
fixture scripts, sample addon paths and current documentation were updated.
Comparison against HEAD confirmed preserved Harbour implementation bodies,
apart from migrated filenames and the sample addon's descriptive test label.
Upstream sources and the loader's `.prg`/`.hrb` compatibility were preserved.

The Windows Harbour regression passed **487 checks, zero failures, no skips**
using `.hb` sources and the runtime-compiled `.hb` sample addon. Logs:
`tmp/tests-1c63707aa3ab435082fe50a415a0a834/results.log` and
`tmp/hb-extension-tests-20261007.log`.

The isolated product build passed at
`tmp/hb-extension-product-20261007/hbbridge.exe`, SHA256
`E8A06659FB8E6D319392747753D008877962C2240F1FB232D38021133C6D07CF`.
Build log: `tmp/hb-extension-product-build-20261007.log`. Help and configuration
metadata smoke checks passed without starting listeners; log:
`tmp/hb-extension-product-smoke-20261007.log`.

The convention scanner now includes `.hb` for class filenames, PascalCase
and four-space indentation. PowerShell parsing, eight focused positive/negative
convention cases and xBase Git attributes passed.

The two TLPP test source changes only replace the sample addon path with
`examples/hbbridgesampleaddon.hb`. They were not recompiled or executed in the
AppServer during the local migration work. Subsequent manual recompilation
and runtime reports below supersede that pending regression status. Earlier
RPO acceptance used the `.prg` sample path. Package 001 MSSQL milestones remain pending.

The full working-tree gate passed **141 files** with `check.hb`, `commit.hb`,
`3rdpatch.hb` and project conventions; log:
`tmp/hb-extension-commit-gate-20261007.log`. Local links across **61 documents**
and `git diff --check` passed. The index was preserved; no commit was created.

<a id="post-migration-protheus-operator-acceptance-on-2026-10-07"></a>

## Post-migration Protheus manual acceptance on 2026-10-07

Recompilation after the `.hb` migration was confirmed, with manual AppServer
HTTP output reported in chat, followed by Query/configuration/TCP/HTTP output in
`F:/tmp/hbridge.news.txt`. The supplied reports are preserved in
`tmp/protheus-http-hb-operator-20261007.log` and
`tmp/protheus-suite-hb-operator-20261007.log`; the original attachment copy,
including its separate OpenBao RFC, is `tmp/hbridge-news-20261007.txt`.

All times below are São Paulo on 2026-10-07. The reports show `marin` on
`DNA-TECH-01` with the same `tttm120.rpo`, `tlpp.rpo` and `custom.rpo` stack.

| Program | Reported execution | Result |
| --- | --- | --- |
| `U_HBBridgeHTTPTest` | Program 16:10:40, thread 27296; test 16:10:44–16:10:45 | All 13 checks true/PASS, Health HTTP 200; elapsed 1 s. |
| `U_HBBridgeQueryTest` | Program 16:13:33, thread 27136 | All 29 dataset/page checks true; profile `sqlite_demo`. |
| `U_HBBridgeConfigTest` | Program 16:14:06, thread 30596 | All 16 checks true, including `explicitProfile`, `noForcedProfile` and `invalidProfile`. |
| `U_HBBridgeConnectionTest` | Program 16:14:31, thread 27084 | Clock, Health, ADDON and both exact 200000-byte Echo calls passed; fragmented request gzip 152964 bytes. |
| `U_HBBridgeHTTPTest` | Program 16:15:02, thread 25456; test 16:15:03–16:15:04 | All 13 checks true/PASS, Health HTTP 200; elapsed 1 s. |

The clock reported `Unix=false`, TimeCounter delta **1089.987500** and
normalized **1090.088100 ms** after Sleep(1000), result OK. The revised
configuration test covers the optional SQL alias without forcing a demo
profile. Both HTTP runs include addon execution, rejected credentials,
forbidden/unknown services, recovery and first/next/last-page values.

These are reported manual AppServer executions, without local AppServer test
runs or a supplied compiler-success log. They supersede the pending
renamed-TLPP/16-check configuration regression status for the exercised cases.
The addon sources
now default to `.hb`; the reports do not echo the actual module argument,
connection arguments or server executable hash. Query explicitly identifies
SQLite; HTTP does not identify its SQL backend, so its results do not certify
MSSQL. Nondefault endpoints, other platforms, clock adjustment/wrap and forced
socket failures retain their separate acceptance tasks.

The updated EN/PT acceptance and OpenBao design documentation passed all three
commit validators for **141 files**; log:
`tmp/operator-acceptance-openbao-gate-20261007.log`. Local links across **61
documents** and whitespace passed. This documentation update did not rerun
the native suite or access an OpenBao/MSSQL server.

<a id="protheus-tcp-mssql-and-sqlite-operator-acceptance-on-2026-10-08"></a>

## Protheus TCP MSSQL and SQLite manual acceptance on 2026-10-08

Manual AppServer runtime output from the two Query wrappers was reported. The
transcript is preserved at `tmp/protheus-mssql-sqlite-operator-20261008.log`.
Times below are São Paulo on 2026-10-08; the log identifies `marin` on
`DNA-TECH-01` and the `tttm120.rpo`, `tlpp.rpo`, `custom.rpo` stack.

| Program | Reported start / thread | Result |
| --- | --- | --- |
| `U_HBBridgeQueryTestMSSQL` | 10:06:10 / 660 | All 29 checks true; `Protheus OK; profile=MSSQL/pData`. |
| `U_HBBridgeQueryTestSQLite` | 10:06:43 / 3192 | All 29 checks true; `Protheus OK; profile=sqlite_demo`. |

The checks cover named fields and decimals, missing fields, EOF/close, empty
results, invalid SQL, unknown profiles, subsequent recovery, first/next/last/
empty pages, hidden ordinals, invalid page/order and page cleanup. This records
manual AppServer runtime acceptance of the existing TCP dataset/page contract with
the explicit MSSQL alias, plus the repeated SQLite regression. The report
contains no compiler-success log or artifact hashes; these AppServer calls
were not repeated during local validation. Native extended fixtures retain
their separate evidence.

HTTP acceptance with the MSSQL profile subsequently passed on 2026-10-08;
see the [identified HTTP wrapper runs](#protheus-http-mssql-and-sqlite-operator-acceptance-on-2026-10-08).
Earlier HTTP reports without an identified SQL backend retain their historical
scope.

## Native MSSQL acceptance on 2026-10-08

The locally executed opt-in Harbour acceptance passed **92 checks, zero failures,
no skips** against the real SQL Server database. Evidence:
`tmp/mssql-tests-b3d676f0daaf470a97af605a98a9681c/results.log` and
`tmp/mssql-native-normalized-20261008.log`.

| Component | Exercised value |
| --- | --- |
| Platform | Windows x64. |
| SQL alias / database | `MSSQL/pData` / `pData`. |
| SQL Server | `16.0.1200.5`. |
| ODBC driver | Microsoft ODBC Driver 18, `18.6.2.1`, x64. |
| Authentication | SQL login from the private server configuration; no credentials in the evidence. |
| Harbour source | Pinned commit `6deac9cf3ad977ae829e5bca543d553b92dd4b6d`, multithread build. |
| Zig / codepage | `0.16.0` / `UTF8EX`. |

The executable was built from the shared product core. It verified constant
connection/version/database probes, named fields, numeric/decimal values,
NULL versus empty text, native date/timestamp and bit values, accented/CJK
text and exact Unicode bytes. Extended fixtures verified 12000-byte VARCHAR
and binary data, 12000-character NVARCHAR, embedded NULs, chunk boundaries,
an emoji encoded as a UTF-16 surrogate pair, and empty/NULL binary values.
The tests also passed invalid SQL/unknown-profile recovery and sanitized
errors, ordered pages with gaps/tie breakers, hidden ordinals, caller
workarea/default-connection restoration, explicit connection release and
four concurrent calls with isolated values under the existing SQL mutex.

This run includes the staged [SDDODBC patch](../config/patches/sddodbc.patch)
for `SQL_NO_TOTAL` variable-length fetching, binary field flags and UTF-16
surrogate conversion to UTF-8. Patch SHA256:
`F0DDE4C85F89D2A72B27040E65EB556E9E0D59838E064FB0FC2254650DA637E6`.
The managed receipt records library SHA256
`B64952AF699A354762AD0C78DFE9BDDEED2DA12973EF652A5B9C8365E8602B5E`.
Acceptance executable SHA256:
`6FA1AAFA04DE72C496290F456F7CB00068BC36EFC9E8EBB9AC0A6774D3DF0F69`.
Preparation patches a disposable copy and preserves the pinned checkout;
see [dependencies](dependencies.md). The run used read-only constant fixtures,
with no ERP-table writes or host restart.

The native baseline executed the deterministic 1000-row fixture three times,
concurrency **1**, in **31, 32 and 31 ms**, total **94 ms**. Each measurement
includes connection, query/result materialization and disconnection. Memory
was **not measured**; the measurements are a reference without a speed
threshold and do not measure TCP or HTTP performance.

The full default Harbour regression passed **566 checks, zero failures/no
skips**, including the 79 added configuration assertions. Evidence:
`tmp/tests-f84004277a8d4cc2905131f706a1e181/results.log` and
`tmp/mssql-full-regression-20261008.log`. The isolated product build passed at
`out/mssql/hbbridge.exe`, SHA256
`1F157D4099E7F954652C2AF645E4EB80DB971078D6522CC3AFF6D5DAC5715ADB`;
log: `tmp/mssql-product-final-20261008.log`. Sanitized configuration metadata
accepted the private MSSQL/SQLite profiles and equivalent public MSSQL INI/JSON
without connecting: `tmp/mssql-config-final-smoke-20261008.log`.
All three commit validators and project conventions passed **146 files**:
`tmp/mssql-commit-gate-20261008.log`. Local links across 61 documents and
whitespace passed. No commit or publication was performed.

This supplies the native SQL value/type evidence for M03 alongside the separate
manual AppServer TCP result above. The [manual AppServer HTTP runs below](#protheus-http-mssql-and-sqlite-operator-acceptance-on-2026-10-08)
accept M05 for the 13 exercised cases. Controlled unavailable-connection/
native-timeout cases (M06), broader profile/resource
isolation (M07), transport/memory baselines (M08) and remaining AppServer/final
package evidence (M09) retain their pending work; package 001 is not complete.

<a id="protheus-http-mssql-and-sqlite-operator-acceptance-on-2026-10-08"></a>

## Protheus HTTP MSSQL and SQLite manual acceptance on 2026-10-08

Manual AppServer runtime output from both HTTP test wrappers was reported. Evidence:
`tmp/protheus-http-mssql-sqlite-operator-20261008.log`. The report identifies
`marin` on `DNA-TECH-01` and the same `tttm120.rpo`, `tlpp.rpo`, `custom.rpo`
stack. Times below are São Paulo on 2026-10-08.

| Program / default SQL profile | Reported execution | Result |
| --- | --- | --- |
| `U_HBBridgeHTTPTestMSSQL` / `MSSQL/pData` | Program 10:33:32, thread 25976; test 10:33:33–10:33:34 | All 13 checks true/PASS, Health HTTP 200; elapsed 00:00:01. |
| `U_HBBridgeHTTPTestSQLite` / `sqlite_demo` | Program 10:34:06, thread 9916; test 10:34:07–10:34:07 | All 13 checks true/PASS, Health HTTP 200; elapsed 00:00:00. |

The supplied [HTTP wrappers](../src/tlpp/tests/protheus/hbbridge.http.test/hbbridge.http.test.tlpp)
default the SQL alias explicitly and forward to the common test. They retain
the existing URL/token/timeout resolution for omitted transport arguments.
Both runs passed `healthGet`, `healthPost`, `servicesGet`, `echo`, `addon`,
`unknownService`, `adminForbidden`, `unauthorized`, `afterFailure`,
`queryFirstPage`, `queryFirstValue`, `queryNextPage` and `queryLastValue`.
This accepts M05 for those 13 exercised cases with `MSSQL/pData`, including
the common dataset's HTTP page values, and repeats the SQLite HTTP regression.

These are reported manual AppServer executions, without a supplied
compiler-success log or artifact hashes; these HTTP calls were not repeated
during local validation. The reported elapsed times have one-second resolution
and are not performance
benchmarks. They establish neither HTTPS/Linux acceptance nor expanded SQL
type/Unicode coverage beyond the exercised HTTP fixture. Earlier HTTP reports
without an identified backend remain historical evidence. Controlled failures
and native timeout, broader isolation, transport/memory baselines and remaining
final package evidence continue under M06–M09.

The paired documentation alignment passed all three commit validators and
project conventions for **146 files**, local links across **61 documents**
and whitespace checks. Gate log:
`tmp/http-mssql-sqlite-commit-gate-20261008.log`. Native build/regression
results above were not rerun for this documentation update.

## Dataset extension and integrity findings on 2026-10-08

Easier field access and sequential page traversal were requested after
the accepted runs above. The TLPP dataset now includes `MoreToRead()`,
`Header()`, its compatibility alias `DSStruct()`, `FieldInfo()`, `FieldCount()`,
`FieldName()` and `GetRow()`. `Eof()`/`Skip()` retain page-local behavior;
`MoreToRead()` fetches the next page at EOF and preserves a failed request's
error. Header, field and row access return independent JSON copies. See
[dataset behavior and proposed contract](dataset.md).

The new isolated [U_HBBridgeDataSetTest](../src/tlpp/tests/protheus/hbbridge.dataset.test/hbbridge.dataset.test.tlpp)
uses a mock client, without SQL, credentials, network calls or ERP data.
Its expected successful report is **45 checks and 17 mock calls**, covering
metadata ordering/copies, automatic traversal, repeated checks, closed/empty
state, invalid metadata and failure/recovery. A local compilation attempt ran
with `scripts/build-totvs.cmd` on 2026-10-08 at 16:31:40 São Paulo, thread
36788. It returned exit 1, `COMPILEERROR-300 Failed to open repository`:
`custom.rpo` was in use by one user. The compiler reported total/success/errors
`0/0/0`, so it did not compile these sources. Log: `tmp/totvs-compile.log`.
No stop/start scripts were configured, and the active AppServer was not stopped.
The new runtime test remains unexecuted; prior manual AppServer reports do not accept
these methods. D02 in [WIP](../WIP.md) tracks that acceptance.

A separate local read-only constant MSSQL probe reproduced a numeric
serialization defect: `CAST(123.4567 AS FLOAT)` retained its fractional value
natively but emitted `123` in JSON. `DECIMAL(15,4)` emitted `123.4567`, and
`DECIMAL(16,2)` emitted `123.46`. Evidence:
`tmp/numeric-probe-20261008.log`. The 92 native checks did not exercise a raw
fractional FLOAT JSON round trip; their earlier success remains bounded to
their fixtures and does not certify arbitrary numeric precision.

Source inspection also found that the TCP adapter uses the pinned Harbour
default `EN`/CP437 without the HTTP worker's `UTF8EX` selection, and its JSON
path lacks explicit UTF-8 conversion. Existing ASCII TCP reports do not
certify accented/Unicode values or TCP/HTTP parity. An `OemToAnsi()` display
workaround is not proof of the SQL column's encoding. These text/numeric
corrections remain unimplemented and are tracked under D03 before M06 resumes.

Current RDD header width/decimals are not SX3/TOP_FIELD business definitions.
Protheus must supply its logical field rules and explicit SQL; hbBridge must
not discover ERP tables, branches or salary rules implicitly. The linked
dataset analysis distinguishes source, logical and wire metadata as future
contract work, not currently accepted extra service parameters.

The dataset/security documentation and source conventions passed all three
commit validators for **150 files**, local links across **63 documents** and
whitespace checks. Gate log: `tmp/dataset-commit-gate-20261008.log`.
TLPP preprocessor outputs are ignored as generated build artifacts. No full
native regression was repeated for the TLPP/navigation and documentation work.

## Source, examples and extension review on 2026-10-12

Reviewed commits through `344c86b`, including dotted module names,
client-side browse/filter/SQL helpers and grouped Protheus tests. Updated
current paths/API examples while retaining the earlier acceptance records.
`Header()` is canonical; configure `SetAliasProfile()` before SQL-only
`OpenSQL()`/`OpenPage()`. The new [consumer guide](../examples/protheus/README.md)
distinguishes fixtures from local ERP/UI examples.

Corrections cover partial-open SQL area ownership, public diagnostic redaction
and JSON encoding, total validation/profile lifetime, browse row ownership,
typed/escaped seek/filter expressions, callback updates and compilation errors
in helpers/examples. The original area selection was valid: `dbSelectArea(0)`
selects a free area, not the saved caller area. Preserve the already corrected
real row count, constant-time page calculation and MSSQL `COUNT_BIG`.

Native regression: **583 checks, zero failures**,
`tmp/tests-79526806a38f44a6a2a34c8e0feb2202/results.log`;
wrapper `tmp/review-harbour-final-20261012.log`. The first run's single failure
was a contradictory INI fixture asserting both presence and absence of the
same alias; the negative check now uses a different case. The added checks
exercise safe error details/JSON, exact totals and caller area restoration.
No new MSSQL connection, Protheus HTTP, Linux or UI runtime claim follows.

The directory compiler initially interpreted seven dotted test folders as
files and reported 19 inputs/12 successes/7 errors. The corrected launcher
generates a recursive file list in the documented single-line, semicolon-
terminated TOTVS format. Final compilation: **24 sources, 24 successes,
zero errors**, `custom.rpo` updated 2026-10-12 16:18:59 São Paulo, thread 3112.
Log: `tmp/review-totvs-accepted-20261012-build.log`. Admin stop/start used the
supplied scripts; startup returned zero. The compiler process still exited
with **0xC0000409 after the completed build**; a clean process exit is not
claimed. Earlier partial attempts are not acceptance of the whole source tree.

The new dataset mock expects **67 checks/31 calls**; the helper test expects
**12 checks**. They were compiled, not executed in this review. Interactive
SRA/SX5 browse/filter/seek, field types and cleanup require manual AppServer
acceptance.
The query fixture runs constant SELECTs by default; its fifth argument
explicitly enables the supplied ERP examples. No personnel rows were read by
this review.

The [brainstorming review](extensions-review.md) records SQLRDD, Duktape and
CCHarbour as future candidates with primary-source references. No engine,
external model, DBAccess adapter or new dependency was installed. UTF-8/FLOAT,
credential encryption and the remaining package criteria stay pending in WIP.

All three validators passed for **170 files**; local links across **67
documents** and whitespace passed. Log:
`tmp/review-commit-gate-final-20261012.log`. Restart readiness was independently
verified on local ports **5555, 7890, 1234 and 4321**. The existing staged index
was preserved; this review did not commit or publish.

## FWWebEx HTTP table: validation confirmed on 2026-10-13

Validation of the interactive HTTP table example was confirmed as OK, with
six screenshots in the [example README](../src/tlpp/tests/protheus/hbbridge.http.table.test/README.md).
The artifacts were inspected locally; they record a reported manual AppServer run.

| Visible scenario | Recorded result |
| --- | --- |
| SX5 unfiltered | 11,764 entries; displays of 5 and 10 rows with pagination controls. |
| SX5 global search | `TIPOS DE IMPOSTOS`: 1 entry, filtered from 11,764. |
| SX5 field equality | Description `TIPOS DE IMPOSTOS`: 1 entry, filtered from 11,764. |
| Constant fixture | 10 displayed rows out of 12; `O'Brien`, `100%_done` and `<b>literal text</b>` rendered as text. |
| Fixture global search | `Harbour`: 1 entry, filtered from 12. |

The SX5 descriptions also display accented text in these samples. This does
not close the broader UTF-8/FLOAT correction in WIP D03. Protheus resolves
the SX5 profile/table/branch context; hbBridge remains the generic executor.

This accepts preparatory WIP F01 for the demonstrated views. The HTTP table
mock has separate acceptance below. Dataset 67 checks/31 calls and helpers
12 checks have subsequent validation in the next record. The table example does not exercise
the automatic traversal/copy/failure cases required by D02. The screenshots
do not identify the actual profile/backend, execution time, compiler build or
server artifact; no new claim for those attributes or M06–M09 follows.

## HTTP table regression validation on 2026-10-13

Confirmed manual execution of `U_HBBridgeHTTPTableTest` at **17:46:56 São Paulo**
(20:46:56 UTC), AppServer thread **27708**: **71 checks, all PASS, zero failures**;
final report `hbBridge HTTP table checks: 71; OK`.
The received result is summarized in `tmp/http-table-manual-20261013-174656.summary.txt`.

The earlier run at 08:16:18, thread 36400, reported 62 checks with three failures:
`rejectNulFilter`, `successAfterServiceFailure` and `missingTotalsAreVisible`.
Filter validation now reads the original values before any JSON round-trip;
the borrowed input is preserved. The mock uses a separate response cursor,
so an unexpected call cannot skip a future fixture or mask later results.

The accepted run covers NUL rejection at the beginning, middle and end and
as the only byte for filters/search, input-byte preservation, query recovery,
totals/errors, and the existing page/filter/order/projection checks.
`noUnexpectedMockCalls` and `allQueuedResponsesConsumed` both pass; the fixture
contains **19 queued responses**.

Additional log lines report handshake error 10054 on thread 13968; the test
still completes with 71 PASS. This record diagnoses neither that connection
nor TLS behavior. This is a mock-contract run, without live HTTP or SQL calls.
F02 is complete. D02 has subsequent dataset/helper validation below;
D03 UTF-8/FLOAT remains pending.

## Dataset and helper validation on 2026-10-13

Confirmed manual AppServer validation, São Paulo time:

| Entry | Start / thread | Result |
| --- | --- | --- |
| `U_HBBridgeDataSetTest` | 17:56:23 / 32332 | All 67 checks true; 31 mock calls; `Protheus OK`. |
| `U_HBBridgeHelperTest` | 17:56:45 / 28300 | All 12 checks true; `Protheus OK`. |

Summary: `tmp/dataset-helper-manual-20261013.summary.txt`. These are received
manual results, not new local test execution or a fresh compiler-success log.

The dataset run accepts field/header/row copies and column order, page-local
EOF/Skip, automatic `MoreToRead()` traversal, idempotence, empty/closed states,
page failure/recovery, metadata and totals validation, previous-page navigation
and profile/result lifetime. The historical `dsStructDefensiveAlias` check name
exercises `Header()`/`FieldInfo()` copies; no `DSStruct()` method was restored.
Helpers accept SQL field qualification without modifying literals/comments,
replacement behavior and the prepared typed filter expressions.

D02 is complete. These mock/helper results perform no live SQL or HTTP calls;
D03 still requires native UTF-8/FLOAT corrections and acceptance. A separate
handshake error 10054 appears on thread 34420; the helper result remains OK.
The connection/TLS condition is not diagnosed by these tests. Resume D03,
then M06–M09; package 001 remains open.

## SQL transport failures and recovery on 2026-10-13

After the explicit deferral of metadata addons/automatic decimal policies,
M06 was resumed independently. Optional SQL CAST rewriting remains a recorded
proposal; caller CAST is retained, and D03 UTF-8/FLOAT is not accepted or closed.

The isolated Windows Harbour runner passed **615 checks, zero failures, no
skips**, adding **32 assertions** to the earlier 583-check regression:

- Invalid SQL, unknown profile, missing SQLite database and missing synthetic
  ODBC DSN, through native NETIO, TCP/JSON and both HTTP RPC/REST routes.
- Exact four-field English error envelopes, without partial datasets, SQL,
  paths or synthetic connection credentials. HTTP errors keep status 500.
- Successful constant SELECT immediately after each failure, including reuse
  of the same native NETIO connection; HTTP RPC/REST recover on their own routes.
- Defensive recovery-result checks report malformed responses as failures.

Final log: `tmp/tests-fa36c9bc67ca4f0089f3b49edc2642b7/results.log`;
build wrapper: `tmp/review-m06-final-20261013.log`, exit 0. Run date is
2026-10-13 São Paulo / 2026-10-14 UTC. A preliminary revision passed 611 checks;
the final run adds immediate HTTP RPC recovery and response-shape guards.

Fixtures use private test directories, ephemeral local listeners and fictitious
credentials. No real MSSQL connection, installed service or AppServer execution
is part of this run. Missing DSN proves a Driver Manager connection failure,
not a live SQL Server outage. At this revision, M06 remained open for controlled
real-MSSQL and AppServer cases, and managed SDDODBC set no login/statement
timeout or cancellation API. Socket budgets did not establish SQL cancellation.
The following [2026-10-14 record](#sql-native-timeouts-and-appserver-recovery-on-2026-10-14)
adds native timeouts and real AppServer acceptance; mid-fetch disconnect remains
a separate follow-up.

<a id="sql-native-timeouts-and-appserver-recovery-on-2026-10-14"></a>

## Native SQL timeouts and AppServer recovery on 2026-10-14

M06 is accepted for invalid SQL, unknown profile, controlled unavailable
connection, applicable native timeout, sanitized errors and immediate successful
recovery through the selected Windows routes. D03 UTF-8/raw FLOAT remains open;
metadata addons and automatic SQL CAST rewriting stay deferred. Package 001
continues with M07 resource/concurrency verification.

| Execution | Result / evidence |
| --- | --- |
| Isolated default Harbour regression | **636 checks, zero failures**, exit 0; `tmp/tests-12c300f8399948e3bb3c20ee13eacc2d/results.log`, wrapper `tmp/review-m06-regression-20261014.log`. |
| Opt-in real-MSSQL controlled failures | **46 checks, zero failures/no skips**, exit 0; `tmp/mssql-tests-e22aaf15b69e44ad806a5316060438ec/results.log`, wrapper `tmp/review-m06-mssql-verified-20261014.log`. |
| Existing real-MSSQL acceptance rerun | **92 checks, zero failures/no skips**, exit 0; `tmp/mssql-tests-c49ac62b333d4c9d8e94aabf5134cb1b/results.log`. |
| Complete TLPP recompilation | AppServer compiler report: **30 sources, 30 successes, zero errors**, 08:23:38 São Paulo, thread **32272**; `tmp/totvs-compile.log`. |
| Local AppServer CLI TCP | **38 checks, zero failures**, exit 0, 08:28:56–08:29:12 São Paulo, thread **29120**; `tmp/m06-protheus-tcp-clean-output-20261014.log`. |
| Local AppServer CLI HTTP | **51 checks, zero failures**, exit 0, 08:28:13–08:28:29 São Paulo, thread **21392**; `tmp/m06-protheus-http-output-20261014.log`. |

The live TLPP runs use `-run=U_HBBridgeFailureCLI -env=PROTHEUS` with explicit
transport/profile arguments against an isolated Harbour fixture. They execute
the actual AppServer/RPO client classes and **21 service calls per transport**,
including dataset calls. This is local CLI execution, separate from the earlier
reported manual WebApp runs. AppServer identifies **24.3.1.5**, build
**7.00.240223P-20260211**, x64. See the
[failure-test guide](../src/tlpp/tests/protheus/hbbridge.failure.test/README.md)
for the reproducible entry points.

The existing 92-check rerun identifies SQL Server **16.0.1210.3**, database
**pData**, Harbour `UTF8EX`, on the private `MSSQL/pData` profile. The SQL Server
version differs from the historical 2026-10-08 report (`16.0.1200.5`); both
dated observations are retained. The selected connector is **Microsoft ODBC
Driver 18 for SQL Server**, x64; the installed driver identified during the
package is **18.6.2.1**. Credentials remain in the private configuration and
are absent from the repository and the acceptance output.

### Controlled failure fixture and observed behavior

- A constant `SELECT 77 AS RECOVERY_ID` establishes the working real-MSSQL
  connection before failure assertions. Each failed service/dataset call is
  followed by a successful constant query.
- `m06/refused` uses a loopback ephemeral TCP port kept reserved by a bound
  socket without listening, explicit Driver 18, fictitious credentials and
  one-second native login/query settings. This proves controlled connection
  refusal without stopping SQL Server or changing an existing DSN/credential;
  it is not a test of an actual SQL Server outage or a stalled login expiry.
- `m06/query-timeout` clones the working profile with a one-second native
  query timeout. The SQL batch uses `WAITFOR DELAY '00:00:04'` before the
  constant SELECT; a client budget of at least seven seconds distinguishes
  the native SQL limit from transport timeout.
- A direct native statement with explicit query timeout `0` completes the
  bounded four-second control. With timeout `1`, native ODBC reports `HYT00`
  and finishes before that control. Local/NETIO/TCP/HTTP assertions confirm
  the timed failure and subsequent recovery. Both live TLPP transports also
  accept the native deadline check (at least 500 ms and below 4000 ms).
- Exact four-field English envelopes preserve fixed service errors and safe
  numeric diagnostics. They omit SQL, credentials, data paths and partial
  headers/rows/totals. HTTP failures return 500; recovered queries return 200.
  Failed datasets clear prior results/metadata/page state and stop
  `MoreToRead()`; reopening returns the constant value again. The live test
  does not count/mock client calls to prove absence of retries; that assertion
  retains the prior 67-check dataset mock evidence.

### Native settings and artifact provenance

MSSQL profile `LoginTimeoutSeconds`/`QueryTimeoutSeconds` (JSON
`loginTimeoutSeconds`/`queryTimeoutSeconds`) are optional. Omission preserves
the driver default; explicit zero disables the corresponding native timeout.
The additional 21 default-regression checks accept omission/zero/native maxima
and reject invalid types, fractions, negatives and overflow in both config
forms. See [the exact ranges and configuration](configuration.md#native-mssql-timeouts).

The checksum-verified [managed SDDODBC patch](../config/patches/sddodbc.patch)
sets and reads back explicit ODBC attributes: login before connection and again
after connection; query before each statement. Failed settings/readback or
driver-substituted values fail and release their handles. This includes the
query-open/native-execute paths; page retrieval and its separate count each
receive their own query timeout. The pinned Harbour checkout remains intact.
The managed receipt at the first accepted run identifies Harbour revision
`6deac9cf3ad977ae829e5bca543d553b92dd4b6d`, patch SHA256
`90B2B1EA3C6C895B677C3ACC42AD256C58734DD7ECE3D1C381E7BE6FE812F5F1`
and library SHA256
`01871BF984468CE83230901302FB8CE2B2CEE9B053839A99667222E554164FBB`.
The accepted 46-check executable SHA256 is
`FB89E787D12991D70717900646C55F3D12D085158264F674F3BE06F274FFED17`.
Build staging and receipt details are in [dependencies](dependencies.md).

The driver applies each native statement timeout. Connection, SQL mutex wait,
separate statements, materialization, JSON and network transfer do not share
one request deadline. A client timeout/disconnect alone does not demonstrate
SQL cancellation; an explicit hbBridge cancellation API and mid-fetch
disconnect acceptance remain future work. The shared SQL lifecycle mutex is
preserved. These Windows loopback results add no GUI, HTTPS, Linux, other-driver
or raw FLOAT fix acceptance.

### Reported normal-host run and fixture prerequisites

The supplied log records `U_HBBridgeTCPAndHTTPFailureTest` on 2026-10-14
at 12:06:05 São Paulo, thread 4728: TCP **38 checks / seven failures** and
HTTP **51 checks / seven failures**. A separate CLI run, thread 42740, also
reports TCP 38/seven. These runs are not accepted. They target the regular
host on ports 1512/8080 rather than the isolated failure runner. The private
INI contains only `sqlite_demo` and `MSSQL/pData`; constant HTTP probes for
`m06/refused` and `m06/query-timeout` each returned **500 / PROFILE_NOT_FOUND**.
A missing alias cannot exercise refused connection or native query timeout;
the seven failed assertions follow from that prerequisite mismatch.
Sanitized evidence: `tmp/protheus-failure-reported-20261014.log`; the original
log remains outside Git and its HTTP token is redacted from the local copy.

Repeat using `-Failures -Serve`, its explicit driver and printed TCP/HTTP
endpoints. The fixture creates both aliases in memory and reserves the refused
port without listening. Do not copy real SQL credentials into extra demo
profiles or assume that the regular host has these test-only aliases.
The [test guide](../src/tlpp/tests/protheus/hbbridge.failure.test/README.md)
records the full command. The revised test logs a fixed prerequisite diagnostic
when a required fixture alias is missing. The combined entry is preserved;
parameter reflection/dumps were removed so the HTTP token is not printed.

After these source adjustments, all **30 TLPP sources compiled with zero
source errors** on 2026-10-14 at 13:09:29, thread 24144. Updated CLI runs passed:
TCP **38/zero**, 13:10:46–13:11:02, thread 41452, and HTTP **51/zero**,
13:11:59–13:12:14, thread 10404; both exit 0. Evidence:
`tmp/m06-protheus-tcp-updated-output-20261014.log` and
`tmp/m06-protheus-http-updated-output-20261014.log`.
The compiler process itself exits **0xC0000409 after the completed build
report**, as in the earlier build; successful source compilation and subsequent
RPO execution do not certify a clean compiler-process exit. The configured
TOTVS restart completed with exit 0 and port 4321 available.

The final commit gate passes **186 files** through all three validators.
The SDDODBC patch's empty context markers were normalized to satisfy the
whitespace check. Applying the normalized patch succeeds; the generated C
source equals the tested authoring source after newline normalization.
The final managed receipt has patch SHA256
`4E8F24D6482A93585AD021DD7EEC9631C472A4BDA225240206F83C5302C4B9BE`
and library SHA256
`68D9B00215ED11AA8DEEFD4F59C252E181B03659ABED06E35C4805FC45A85651`.
Earlier hashes above identify the artifacts used in the first accepted run.

<a id="manual-protheus-failure-recovery-on-2026-10-14"></a>

## Manual Protheus failure/recovery validation on 2026-10-14

Confirmed manual AppServer execution of `U_HBBridgeTCPAndHTTPFailureTest`
on **2026-10-14 at 14:30:50 São Paulo**, thread **13796**. The supplied log
contains **38 TCP PASS checks and 51 HTTP PASS checks**, matching both
`failures=0; OK` summaries. This accepts the manual execution of the listed
M06 cases and resolves the earlier normal-host run's seven failures per
transport. The earlier unsuccessful runs remain historical evidence.

Accepted checks cover invalid SQL, an unknown profile, an unavailable
connection, native query timeout, safe failure envelopes, no partial result,
service recovery, dataset clearing/stopping/reopening and diagnostic filtering.
HTTP also verifies error/recovery statuses. Both `queryTimeoutNativeDeadline`
checks pass. The live run does not count wire requests; the earlier 67-check
dataset mock retains the separate absence-of-retries evidence.

Evidence: `tmp/protheus-failure-manual-20261014-143050.log`, copied byte-for-byte from the supplied log.
The excerpt contains no credential values; its native diagnostics and local
runtime context are preserved in the ignored local artifact. Nine native
error-10054 lines and one additional SSL `onSend` diagnostic are recorded.
Their cause, connection association and resolution are not established;
all 89 hbBridge assertions still report PASS. This does not certify a clean
TLS handshake or HTTPS transport.

No end-program timestamp, precise elapsed time, launch route, explicit call
arguments, server artifact hash or new compiler result is supplied. Do not
infer M07 concurrency, M08 performance or broad UTF-8/FLOAT integrity from this
run. The next WIP task remains **M07**, and D03 integrity remains pending.

<a id="sql-concurrency-and-release-on-2026-10-14"></a>

## SQL concurrency and resource release on 2026-10-14

M07 acceptance passed on Windows against the private working `MSSQL/pData`
profile and isolated SQLite fixtures. SQL Server had previously been identified
as 16.0.1210.3; the managed SDDODBC dependency and SQL lifecycle mutex were
retained. Only constant MSSQL SELECTs and the test-owned SQLite file were used.
No product synchronization, pooling, credentials or ERP rules were changed.

| Execution | Workers / calls | Checks / failures |
| --- | --- | --- |
| Native local, NETIO, TCP and HTTP | 8 / 192 | 458 / 0, no skips |
| AppServer CLI TCP and HTTP | 4 / 112 | 417 / 0 |

The native suite synchronizes eight workers, two per route, through three
rounds over the working alias, `m07/mssql-clone` and `m07/sqlite`. Separate
schemas, driver names and worker/round values expose cross-profile leakage.
Checks cover unpaged reads, first/final/empty pages and independent COUNT,
invalid SQL, ambiguous columns, unknown profiles and recovery. Each caller's
workareas/default connection remain unchanged and its fixture stays readable.
Retained caller connections disconnect after worker joins; the first free
RDDSQL connection slots are reusable before/after the batch. NETIO endpoint
ownership is released after all borrowed worker references. The isolated host
stops with listeners stopped and zero active workers.

The initial native run had one fixture failure among 457 checks: it expected
each borrowed NETIO pointer to own an endpoint disconnection. The parent now
holds one endpoint reference, releases it after joins and verifies the endpoint
cache is empty. The corrected 458-check run exited 0. Evidence:
`tmp/mssql-tests-e914432a7e5d49cc99b76cbb948605a1/results.log` and
`tmp/review-m07-concurrency-final-20261014.log`. Repeated isolated hosts also
passed all 458 checks, including final cleanup, before process exit 0.

AppServer `U_HBBridgeConcurrencyCLI` launches two TCP and two HTTP StartJobs.
Each owns its client/dataset/JSON, alternates MSSQL/SQLite over four steps,
and issues 28 calls. Actual backend/schema proofs, exact pages/totals,
defensive snapshots, failures/recovery and clearing old state passed. Four
distinct worker threads were recorded: 9712, 16572, 27392 and 24384; the parent
collector was thread 24480. Publication follows object release; the parent
acknowledges reports and waits for final shared-key cleanup. `StartJob` has
no native join handle, so this records logical completion, not native join.

Compilation at **18:15:58 São Paulo**, compiler thread 17484, reported
**32 sources, 32 successes, zero errors**. Its process subsequently returned
`0xC0000409` (-1073740791), retained separately from source compilation.
The later test CLI exited **0**, reported 417 checks/zero failures at
**18:18:12**, and ended at **18:18:24**, without THREAD ERROR or shutdown
exception. Stop/start scripts exited 0 and the normal AppServer listener
returned. The isolated CLI INI was removed; regular private INIs were unchanged.
Evidence: `tmp/totvs-m07-baseline-compile-20261014.log`,
`tmp/m07-totvs-build-result-20261014.json`,
`tmp/m07-protheus-concurrency-final-output-20261014.log` and
`tmp/m07-protheus-concurrency-final-20261014.log`.

The preceding CLI run reported 416 checks/zero assertion failures but then
raised `Application Server is Shutting Down` while a worker awaited the
collection acknowledgment. It was not accepted as a clean lifecycle run.
The final worker-wrapper marker and parent completion barrier resolve that
reproduced harness race; the successful 417-check repetition is the acceptance.

### Additional manual load and diagnostic follow-up

The supplied `HBBridgeConcurrencyTest.txt` contains complete reports for
4, 40 and 100 workers, zero failures and 112, 1120 and 2800 calls respectively.
The 100-worker run has unique reported thread IDs and per-worker elapsed
values from approximately 31.94 to 49.72 seconds. These include waiting and
whole worker execution, not per-query latency or M08 memory measurements.
Evidence copy: `tmp/protheus-concurrency-manual-20261014.txt`.

Increasing the test constant retains two TCP jobs; the other jobs use HTTP
(38 and 98 respectively). These are not balanced transport load tests. The
older summary fixed its parent check count at 29, so its printed 4413/11073
checks undercount the actual parent assertions (6 per worker plus 5 shared).
The report now counts actual parent JSON keys. For unchanged transport
assignment, complete 40/100-worker runs would report 4629/11649 checks.
New stage/pending-worker diagnostics distinguish launch/readiness, report
collection and release, without logging tokens or raw exception descriptions.
Their subsequent compilation/runtime validation and the supplied failed
140-worker logs are recorded below. No product capacity limit is inferred.

Native handle reuse and logical disconnection do not prove physical ODBC
session closure or freedom from heap/network leaks. The shared mutex remains:
concurrent callers can queue while SQL lifecycles execute serially. Linux,
HTTPS, cancellation, pooling and D03 UTF-8/FLOAT retain their own acceptance.
The exercised isolation/lifecycle baseline remains accepted; the additional
load reopens M07 before M08 performance/memory work. See the
[Protheus guide](../src/tlpp/tests/protheus/hbbridge.concurrency.test/README.md)
and [connection-reuse analysis](sql-connections.md).

<a id="sql-concurrency-follow-up-on-2026-10-15"></a>

## Concurrent HTTP follow-up on 2026-10-15

Additional load reopens M07 after the accepted native eight-worker and
AppServer four-worker baseline. The baseline is preserved; it does not certify
140 concurrent callers. The supplied previous 140-worker log, parent thread
2680 on 2026-10-14, contains all 140 reports/3920 calls: 833 failed HTTP
assertions, all in step 4, plus 136 parent zero-failure checks, totaling 969.
Both TCP workers pass all 83 checks; all SQL read/page/schema/value checks
preceding the final error/recovery operations pass. The printed 15513 check
count uses the older fixed parent count and is not the actual total.
Evidence: `tmp/protheus-concurrency-manual-140-20261014.log`.

The later supplied log starts 2026-10-15 **07:33:53.921 São Paulo**, collector
thread 34240, with **140 workers (2 TCP/138 HTTP), request timeout 150 seconds
and collection budget 120000 ms**. READY passes at 07:33:55.906; collection
ends at **07:35:53.971**, reporting **10002 checks, 894 failures, 83 collected
workers, FAILED**. Some jobs log afterwards. There is no THREAD ERROR in this
supplied excerpt. It is not successful 140-worker acceptance.
Evidence: `tmp/protheus-concurrency-manual-latest-20261015.log`.

There are 336 response-mismatch records, all step 4: 204 report HTTP status 0
and UNRECOGNIZED code. The other 132 retain status 200/500. Timings range
0.0223–34.0541 ms. Some operations after ABORT never issue a request, so their
retained status/code is stale and their sub-millisecond timing is not HTTP
latency. Earlier nonzero fast failures before the collection deadline remain
unexplained; increasing the request timeout alone has not resolved them.

The local 2026-10-14 diagnostic CLI repetition also failed: 113 collected
reports, 13332 checks/937 failures and 27 subsequent worker shutdown errors.
The four-worker diagnostic repetition passed 417 checks and exited 0.
Evidence: `tmp/m07-protheus-diagnostics-140-output-20261014.log` and
`tmp/m07-protheus-diagnostics-4-output-20261014.log`. These are separate runs;
a passing four-worker result must not be attributed to the 140-worker case.

The harness now accepts worker count as argument 8 (`--workers`) and an
independent collection budget in seconds as argument 9 (`--budget-seconds`).
Defaults remain 4 and 120. It marks pending jobs before launch, checks ABORT
after each transport call, stops without interpreting skipped calls, and
waits separately for worker cleanup before removing keys. The drain budget
is request timeout plus 10 seconds; it neither cancels native SQL nor supplies
a native StartJob join.

The latest controls compiled on 2026-10-15: **32 sources, 32 successes, zero
errors**. The compiler process again returned `0xC0000409` after its completed
report; stop/start exited 0. Runtime acceptance is distinct:

| Controlled CLI run | Result |
| --- | --- |
| 4 workers, normal budget | 417 checks / 0 failures, exit 0 |
| 4 workers, deliberately insufficient 1-second collection budget | Expected failure, 29 checks / 27 failures, cleanup drained, exit 1 without THREAD ERROR |
| 140 workers, request 30 seconds / collection 300 seconds | All 140 reports, 16329 checks / 857 failures, exit 1 without THREAD ERROR |

Evidence: `tmp/m07-protheus-budget-4-output-20261015.log`,
`tmp/m07-protheus-abort-4-output-20261015.log` and
`tmp/m07-protheus-budget-140-output-20261015.log`. The harness cleanup fix
does not resolve the transport failure. An isolated HTTP backlog comparison
also failed both requests: backlog 10 produced 1433 failures, and the native
`SOMAXCONN` request produced 1010, each among 16329 checks/all 140 reports.
These are separate runs, not a controlled proof that backlog changes improve
capacity. Both isolated native hosts passed all 458 checks including shutdown.
Evidence: `tmp/m07-protheus-backlog10-140-output-20261015.log`,
`tmp/m07-protheus-somax-140-output-20261015.log` and their native host logs.
Default Harbour regression after backlog configuration: **656 checks / 0**,
exit 0, `tmp/m07-backlog-regression-final-20261015.log`.

The current supplied file is a pool design sketch with a DBAccess ODBC
**10048/08001** login failure, not another successful test report. Local
Windows System events **Tcpip 4227** at **07:35:03 and 08:41:55 São Paulo**
report failure to allocate a recently reused outgoing local endpoint. A
snapshot also counted 15264 `TIME_WAIT` connections; the configured IPv4
dynamic range is 49152–65535. This establishes host port-reuse pressure;
it does not attribute every failure or consumed port to hbBridge or DBAccess.
Evidence: `tmp/protheus-concurrency-pool-proposal-20261015.txt` and
`tmp/m07-port-pressure-events-20261015.json`. No OS TCP setting was changed.
The attached call's final arguments `150*10,120,150*10` mean 1500-second
request timeout, 120 workers and 1500-second collection budget. A longer
deadline does not reduce physical connection creation.

M07 remains open. The next measured adaptation is physical ODBC connection
reuse with the SQL mutex and logical caller ownership retained; HTTP/TCP
reuse is separate. See the [design review](sql-connections.md).

<a id="manual-protheus-concurrency-130-on-2026-10-15"></a>

## Detailed manual 130-worker run on 2026-10-15

The separately supplied `HBBridgeConcurrencyTest_130.txt` was reviewed and
preserved as `tmp/protheus-concurrency-manual-130-20261015.log`, SHA-256
`A507584F449BD08395DE6C94351529F2238EA72AD98CE6A707CD615061FD6C38`.
It contains all **130 worker reports**, **130 distinct worker thread IDs**
and **3640 reported RPC calls**: two TCP workers/56 calls and 128 HTTP
workers/3584 calls. The total **15159 checks** comprises 14374 worker and
785 parent checks. The run failed **41 checks**.

Those 41 failures represent **13 refused HTTP requests**, all in step 4:

| Operation | Refused requests | Failed worker assertions |
| --- | --- | --- |
| Unknown-profile request | 7 | 21: unknownProfile, unknownClears, unknownHTTPStatus |
| Recovery after unknown profile | 6 | 12: recoveryAfterUnknown, unknownRecoveryHTTPStatus |
| Parent zeroFailures aggregation | No additional requests | 8, one per affected worker |

Affected HTTP workers were 9, 13, 29, 41, 58, 75, 97 and 126. Both TCP
workers and the other 120 HTTP workers reported zero failures. All 13 response
diagnostics have status **0**, code **NATIVE_REFUSED_DIAGNOSTIC**, and measured
call durations **5.7892–34.1813 ms**. The seven unknown-profile requests should
return PROFILE_NOT_FOUND/HTTP 500 before SQL connection acquisition; these
refusals are transport failures, not evidence of unsupported services or
incorrect business SQL. The six subsequent recovery requests expected HTTP 200.
The eight parent failures summarize the same workers; they are not eight
additional failed requests or checks after the final summary.

The launch record is **17:59:38.935 São Paulo**; all workers are READY at
**18:07:36.699**, and the final summary is **18:09:41.514**. Launch to readiness
took **477764 ms**, readiness to summary **124815 ms**. All refusals occurred
between **18:09:03.526 and 18:09:03.986**, a **460 ms** interval. Request timeout
was **2100 seconds**, with a **2100000 ms** total budget; neither explains the
fast refusals. If the launch ramp was 300/50/5000 ms, its 431450 ms of planned
sleeps would leave 46314 ms of launch/readiness overhead, but this older log
does not record the requested pacing fields.

No THREAD ERROR, parent runtime error, pending/drain diagnostic, DBAccess
error or SQL connection-close error appears in this log. It does not contain
a binary hash, pooling policy or native adaptation identity. The refusal
diagnostic does not establish its underlying host/network cause. Preserve
this failed run independently of the later successful summaries below.

<a id="manual-protheus-concurrency-on-2026-10-15"></a>

## Manual Protheus paced concurrency on 2026-10-15

The later supplied `HBBridgeConcurrencyTest.txt` contains the caller example
and six launch/final-summary pairs. Its original bytes were preserved as
`tmp/protheus-concurrency-manual-current-20261015-f067c9d9.log`, SHA-256
`F067C9D9747FF12AC0FADC6D799C9EE16440FF1AD9026984CB804171E65FBE1E`.
Every summary reports all expected jobs collected and **zero failures**:

| Workers collected/expected | Checks / failures | Request timeout / total budget, seconds | Planned launch sleeps, ms |
| --- | --- | --- | --- |
| 5 / 5 | 534 / 0 | 100 / 100 | 2250 |
| 15 / 15 | 1704 / 0 | 200 / 200 | 10500 |
| 20 / 20 | 2289 / 0 | 250 / 250 | 16500 |
| 30 / 30 | 3459 / 0 | 350 / 350 | 32250 |
| 150 / 150 | 17499 / 0 | 1550 / 1550 | 531450 |
| 500 / 500 | 58449 / 0 | 5050 / 5050 | 2281450 |

The six summaries total **83934 checks, zero failures**, over **720 jobs
across separate runs**. Every check count agrees with `117 * workers - 51`.
Each run assigns two workers to TCP and the rest to HTTP; the largest has
two TCP/498 HTTP workers. Under the 28-call test contract, the summaries imply
**20160 RPC calls**, including 14000 for the 500-worker run; individual call
counts are not present in this excerpt.

All six launch records explicitly select **300/50/5000 ms** pacing. The
500-worker plan includes **2281450 ms (38 minutes 1.45 seconds)** of sleeps
within its **5050-second** budget. These are planned sleeps and configured
budgets, not actual elapsed-time measurements. Job creation is paced; the
existing all-READY/GO barrier still releases worker requests together.

Manual acceptance is recorded for the exercised paced-load summary scope,
including the successful 150- and 500-worker runs. The excerpt contains no
individual worker reports, thread IDs, READY timestamps or final process
exit evidence, so those details cannot be independently audited from it.
There are no mismatch, failed-check or THREAD ERROR lines in the supplied
text; absence from this summary excerpt is not a full thread-termination trace.
The explicit launch fields establish execution of the revised reporting path,
without supplying a new compiler receipt or identifying the server binary,
ODBC policy or SQL-pool implementation. Do not attribute these results to
the native physical-reuse adaptation without that evidence.

The earlier 130/140-worker failures remain separate historical evidence;
the later summaries do not identify which change removed those refusals.
M07 manual paced-load follow-up is accepted within the scope above. The
separate native acceptance below completes M07 for its recorded Windows
scope; M08 measurement and D03 UTF-8/FLOAT remain open.

<a id="odbc-physical-reuse-on-2026-10-15"></a>

## Native ODBC physical reuse on 2026-10-15

The adapted `HBBridgeSQLPool` retains exclusive logical ownership under the
existing SQL lifecycle mutex. Native RDDSQL connections still connect and
disconnect per call; physical MSSQL reuse belongs to the ODBC Driver Manager.
Policy remains **off by default**. The opt-in `driver` route is gated to the
verified Windows ODBC 3.8 path; Linux pooling remains outside this acceptance.

The first pooling attempt used 13 physical connections for 13 leases because
the ODBC environment lifetime did not retain the warm pool. Retaining a
process environment corrected that lifecycle. Cold acquisition and steady
reuse are recorded separately; the final acceptance does not hide the cold
connections or average them into a performance claim:

| Isolated native process | Cold warm-up | Subsequent measured leases | Checks / failures | Exit |
| --- | --- | --- | --- | --- |
| `driver` | 2 leases, 2 physical connections | 13 leases, 1 physical TCP connection | 61 / 0 | 0 |
| `off` | 2 warm-up leases recorded separately | 13 leases, 13 physical connections | 61 / 0 | 0 |

Physical identity is verified with SQL Server connection ID, client TCP port
and connection creation time, rather than SPID alone. Test-owned mutations
to settings/context, a local temporary table, an open transaction and `USE`
database selection were observed before disconnect. The next driver lease
after each mutation returned to the original clean state **on the same physical connection**.
Invalid SQL/recovery, caller workarea/default connection zero and nonzero,
an active caller's exclusive connection, one-second statement timeout and
subsequent longer-timeout recovery also passed. All test-owned logical leases
were released; the native retained environment closed successfully and its
retained-state flag cleared.

Evidence: `tmp/m07-mssql-pooling-driver-accepted-20261015.log` and
`tmp/mssql-tests-bb7664a7b9314a9492a88d8f098c5aff/results.log`;
the separate off control is `tmp/m07-mssql-pooling-off-accepted-20261015.log`.
The isolated native concurrency fixture was then repeated with
`-ODBCPooling driver`: **8 workers, 192 calls, 458 checks, zero failures,
no skips, exit 0**, through local/NETIO/TCP/HTTP. It verifies profile/schema/
value isolation, failure recovery, caller state and owned release under the
retained SQL mutex. Evidence:
`tmp/m07-mssql-pool-concurrency-20261015.log` and
`tmp/mssql-tests-ea4ca5c6a2774bad8b2367822ef4cfd3/results.log`.

This accepts physical reuse and the exercised native lifecycle for Windows
with SQL authentication. Linux, integrated authentication and an optional
second configured MSSQL database/profile were not exercised. The tested `USE`
reset is not acceptance of that second-profile case. These native results
remain separate from the manual 500-worker summaries, which do not identify
their server binary or pooling policy. No attribution of those successful
manual runs, speed gain, maximum worker count or parallel SQL guarantee follows.

M07 is complete within the native Windows and manual paced-summary scopes
recorded above. Resume M08 time/memory measurements; final M09 validation and
D03 UTF-8/FLOAT remain open, so package 001 is not closed.

<a id="m08-performance-baseline-on-2026-10-16"></a>

## M08 performance baseline on 2026-10-16

Recorded the common read-only fixture `m08.constant.v1` against explicit
profile `MSSQL/pData`, database `pData`, SQL Server **16.0.1210.3**. It generates
1000 rows with ID/name/`DECIMAL(15,2)` quarter amounts, pages of 100 ordered
by ascending ID. No ERP tables are read or changed. Native and TLPP SQL
match byte for byte: 537 ASCII bytes, SHA256
`A5F3569517A2A638BEDAFED9D4CA348ADCA9C737C90213A18147B8D4078BDCC5`.
See [methodology/reproduction](benchmarking.md).

Each route uses one client, two complete warmup traversals and five measured
complete traversals. Each measured traversal validates all 1000 rows and ten
pages, including field order, values, totals and final-page state. Each page
uses one Query call and the product's separate SELECT/COUNT statements.
Per route: 20 warmup calls/2000 rows and 50 measured calls/5000 rows. Warmup
samples remain visible and excluded from statistics. A setup identity query
precedes native warmup; no cold-connection or cold-database-cache claim follows.

### Native clients and OS memory

Separate sequential processes measured direct Harbour dispatch, native TCP
and native HTTP under each explicit pooling policy. All six routes returned
success and exit 0: **43366 benchmark assertions, zero failures**, covering
warmup/measured values, owned shutdown, zero active leases and caller workarea/
default-connection restoration. These are benchmark assertions, separate from
the earlier 712-check product regression.

| Policy | Native client | Mean ms / complete traversal | Min–max ms | Measured sampled peak working/private MiB | Measured memory samples |
| --- | --- | --- | --- | --- | --- |
| off | Harbour direct | 2881.20 | 2344–3546 | 21.35 / 4.93 | 180 |
| off | TCP | 2300.00 | 1938–2687 | 18.04 / 6.03 | 151 |
| off | HTTP | 2496.80 | 1891–3203 | 18.52 / 6.51 | 156 |
| driver | Harbour direct | 1159.40 | 985–1344 | 23.37 / 5.00 | 78 |
| driver | TCP | 1531.40 | 1235–1875 | 19.89 / 6.12 | 94 |
| driver | HTTP | 1303.00 | 969–1718 | 20.50 / 6.61 | 87 |

All six reports have `memory.available=true` and measured-phase samples.
Memory is the whole route process, including client and isolated server for
TCP/HTTP, not a per-query allocation. Working set/private bytes are OS process
counters; lifetime high-water observations remain separate in JSON. Requested
sample spacing is 50 ms plus collection overhead; CSV timestamps record actual
spacing. MiB is bytes divided by 1048576. Native timings use coarse Windows
`GetTickCount64` ticks; fractional means are derived aggregate values.

Artifacts:

- off: `tmp/mssql-benchmark-65e82528313e404e8395b801db49c2c7/benchmark.json`,
  per-route `result.json`/`results.log`/`memory.csv`;
  launcher log `tmp/m08-native-baseline-off-20261016.log`.
- driver: `tmp/mssql-benchmark-458ec3e6699b4508aae6df881d16e31d/benchmark.json`,
  corresponding per-route artifacts;
  launcher log `tmp/m08-native-baseline-driver-20261016.log`.
- Executable SHA256 off:
  `6E992FA6FCD4C85315E5269B0E759457B9EEBA452390933099D2674E194225FD`;
  driver: `4F10EC0BF5F7DF8028832CA94ECF3F7482335F153B8932E4FFE468F374DD235B`.
  Reports also identify owned sources, dependency manifest/revisions,
  Zig 0.16.0 and managed ODBC patch/library hashes.

### Real Protheus clients

The complete TLPP tree compiled **34 sources, zero source errors**, including
the new benchmark class and entry. The vendor compiler subsequently returned
**0xC0000409** during finalization, separate from source compilation. Stop/start
scripts returned 0 and normal services were restored. Receipts:
`tmp/m08-totvs-build-result-20261016.json`,
`tmp/totvs-m08-compile-20261016.log` and
`tmp/m08-totvs-lifecycle-20261016.log`.
An invalid `--rows=0` CLI invocation returned exit 1 with the expected harness
validation message, confirming the compiled entry rejects that input.

Actual `U_HBBridgeBenchmarkCLI` execution through the licensed AppServer passed
both production clients/dataset, with **exit 0** and complete successful JSON.
The selected isolated hbBridge used explicit policy `driver` and its identified
native executable above. Its preliminary fixture request is separate from
AppServer measurements. The host's final cleanup checks passed with exit 0.

| TLPP client | Measured traversals | Mean ms / complete traversal | Min–max ms | Measured calls / rows |
| --- | --- | --- | --- | --- |
| TCP | 5 | 1118.14 | 991.05–1263.63 | 50 / 5000 |
| HTTP | 5 | 1491.91 | 1299.71–1641.31 | 50 / 5000 |

Both routes additionally passed two warmup traversals each. Timing includes
dataset navigation/value checks and Close, using normalized `TimeCounter()`.
TCP precedes HTTP. The complete harness took about 19.016 s; process runtime
including initialization/finalization was about 33.232 s. These intervals are
distinct from the means above. The in-test memory field stays `UNAVAILABLE`;
an external sampler supplied whole-process memory:

| Observed process during the combined TCP/HTTP lifecycle | Samples | Sampled peak working MiB | Sampled peak private MiB |
| --- | --- | --- | --- |
| Isolated AppServer client | 405 | 297.98 | 310.72 |
| Separate isolated hbBridge server | 405 | 20.88 | 6.91 |

These external samples include client initialization/cleanup and both routes;
they are not measured-phase or per-route memory figures. Process snapshots do
not establish a leak or allocate shared runtime memory to a thread.
Artifacts: `tmp/m08-protheus-benchmark-c05255b72a8b48b68ef794b9329f7366/benchmark.json`,
`protheus.log`, `memory.csv` and `server/result.json`/`results.log`.
Sampler source is preserved at `tmp/run-m08-protheus-benchmark-20261016.ps1`
and identified by hash in that receipt. The private CLI INI is outside Git,
beside AppServer; its parser requires a basename in `-ini`. The active
`appserver.ini` and private hbBridge SQL configuration were not edited.

Class SHA256: `1A9C40240C0B8D36300DAA13518EA595F947DE8595BD75C7B4350D76C210B487`;
entry SHA256: `C5A355E64DA8442079C3B35151C4363AD6268287F659AAD5AD25F344575BD533`.
The RPO reports 31489542 bytes, last updated 04:33:17 São Paulo; its hash was
unavailable due to the running runtime's file lock. This limitation is explicit;
successful invocation and source compiler receipts identify the exercised entry.

### Scope and follow-up

Reference runs used the same shared Windows x64 workstation, 12 logical CPUs,
Balanced power scheme, regular AppServer/DBAccess/hbBridge also present. Other
machine activity and shared SQL caches were uncontrolled. Preparatory trials
overlapped service compilation/restart and are preserved separately, excluded
from the tables. No agent compilation ran during these selected measurements.
Installed Driver 18 inventory reports binary version `2018.0187.0001.01`;
effective connection-driver version remains `NOT_OBSERVED` by this harness.

The short `-Route http -Rows 17 -PageSize 7 -Iterations 1 -Warmup 0
-ServeSeconds 1` smoke also passed, exercising a partial final page,
zero warmup, endpoint publication and owned host shutdown:
`tmp/mssql-benchmark-f00628fbfb824bb7bee7e3a65bc9170a/benchmark.json` and
`tmp/m08-benchmark-serve-smoke-20261016.log`.

M08 is complete for this identified Windows/reference workload. The figures
are not a statistically isolated pooling comparison, speed guarantee,
production capacity, parallel-SQL or memory-leak acceptance. No Linux, HTTPS,
ERP business-volume or D03 UTF-8/raw-FLOAT acceptance is inferred. Resume M09
final checks/documentation; D03 remains required before closing package 001.

M08 tooling validation: all three mandatory validators passed 205 files;
local links exist across 81 documents, PowerShell syntax and whitespace
checks passed. Receipt: `tmp/m08-commit-check-20261016.log`. These checks do
not close M09's remaining package regression/integrity requirements.

<a id="m08-manual-protheus-validation-on-2026-10-16"></a>

## Additional manual M08 Protheus validation on 2026-10-16

Manual validation recorded from the supplied summary and final
`hbBridge benchmark Protheus OK` line. Run ID
`614056ED784ECE4AB68EAAE1EE863D89`, start **04:53:47 São Paulo**, fixture
`m08.constant.v1`, explicit alias `MSSQL/pData`, Windows normalization
(`serverUnix=false`). Workload: 1000 rows, pages of 100, one client,
two warmup and five measured complete traversals per transport, TCP then HTTP.

| Transport | Measured traversals | Mean ms / complete traversal | Min–max ms | Measured calls / rows |
| --- | --- | --- | --- | --- |
| TCP | 5 | 1039.60 | 770.08–1257.06 | 50 / 5000 |
| HTTP | 5 | 1122.12 | 951.03–1388.17 | 50 / 5000 |

Every measured and warmup sample reports success, 1000 rows, ten pages and
ten calls. Recalculation confirms totals/min/max/means within floating-point
rounding. Both transports together measured **100 calls / 10000 rows**,
excluding **40 warmup calls / 4000 rows**. The measured intervals sum to
10808.610 ms; complete harness duration is **14887.055 ms**. The remaining
4078.445 ms includes warmup and other work outside measured intervals;
it is not solely warmup time.

Evidence: `tmp/protheus-benchmark-manual-20261016-614056ed.log`, SHA256
`921B63D9F26D08B4294F938BD265739E3010B62F679CE55551DD33372A0D1DD7`.
This is a separate manual summary, not another locally automated execution.
Memory remains `UNAVAILABLE` in this report. Effective destination, server
binary/backend version, physical pooling policy, compilation receipt and
process exit code were not supplied; they are not inherited from the previous
automated run or its external memory samples. No causal optimization or
capacity comparison follows. This adds manual evidence to accepted M08;
M09 and D03 remain open.

<a id="m08-large-protheus-follow-up-on-2026-10-16"></a>

## Large manual benchmark follow-up on 2026-10-16

The supplied `C:/totvs/protheus1212410/protheusdata/logs/console_appserver_hbbridge.log`
contains run `93A0CC16D629E74FAA54843567C86E58`, started 07:09:41 São Paulo.
Fixture `m08.constant.v1`, `MSSQL/pData`: 100000 rows, pages of 10000,
500 measured iterations, two warmups, concurrency one, TCP then HTTP,
30-second request timeout. The overall result is **FAILED**.

| Transport | Successful measured iterations | Calls / rows in successful measurements | Mean ms / traversal |
| --- | --- | --- | --- |
| TCP | 500 / 500 | 5000 / 50000000 | 7747.32 |
| HTTP | 135 / 500 | 1350 / 13500000 | 22312.04 |

Both transports completed two warmups. HTTP measured sample **136** failed
on its first call: `QUERY_FAILED`, 30020.834 ms, zero completed pages/rows.
That attempted call is retained in the failed sample and excluded from the
successful aggregate. Harness duration was 6967715.110 ms. The failure duration
is close to the configured 30-second request deadline; the old summary lacks
service code/HTTP status and does not establish a transport, server or SQL cause.
Memory/pool/build identity cannot be inherited from the smaller baseline.
The [2026-10-19 clarification](#m08-manual-cli-validation-on-2026-10-19) records excessive workload
parameters and an inadequately sized timeout as operational context.

The earlier terminal-component fatal error was supplied separately at
06:45:23, before the interim module-static socket change. The retry no longer
reported that fatal error, but its HTTP failure remains distinct. The owned
client now reuses one native component per instance and exposes `Close()`;
connections still close after each response. The focused
[lifecycle test](../src/tlpp/tests/protheus/hbbridge.client.lifecycle.test/README.md)
and safe service-code/status/page diagnostics support follow-up without
claiming the complete large workload has passed.

Sanitized summary/final line: `tmp/protheus-benchmark-large-static-20261016-93a0cc16.log`;
SHA256 `AC62382489B97B9CC00B41C1010A8AC5D9C60A6A3D24BEBDB444A403C4FCC986`.
The supplied interim source is preserved at
`tmp/hbbridge.client.user-static-20261016.tlpp`. V01 tracks this requested
follow-up and visual consumer; M09 and D03 remain open.

<a id="v01-v02-benchmark-acceptance-on-2026-10-19"></a>

## V01/V02 benchmark acceptance on 2026-10-19

V01/V02 are complete for the demonstrated Windows/AppServer workflow. Three
manual visual runs supplied paired JSON/HTML exports on 2026-10-19. All four
client routes (hbBridge TCP/HTTP, Protheus StartJob/REST) and the server-only
Harbour addon passed. These manual results are separate from focused automated
tests, earlier failed CLI comparisons and the historical larger workload.
D03 UTF-8/raw-FLOAT integrity, final M09 checks and package 001 remain open.

### Manual run scope and arithmetic

Each route/run traversed the constant `m08.constant.v1` fixture: explicit alias
`MSSQL/pData`, environment reported as `PROTHEUS_NGROK`, 1000 rows, pages of
100, five measured traversals and two warmups, concurrency one. All 75 measured
and 30 warmup samples passed; each sample reports 1000 rows, ten pages/calls
and no failure. The 75000 measured row visits repeatedly traverse the fixture;
they are not distinct business records. Warmups are excluded from these means.

| Reported local start | Run ID | Mean ms: TCP / HTTP / StartJob / Protheus REST |
| --- | --- | --- |
| 20261019/06:50:35 | `3FF23D3FFFA5984889F09C1DFAFF2459` | 835.00 / 1178.44 / 24876.41 / 1170.96 |
| 20261019/07:03:57 | `B7D7F6E890176D45BB3DC912EC61E8BA` | 1151.27 / 1090.36 / 27085.53 / 1189.93 |
| 20261019/07:09:26 | `E3D8EB828C914C48926D2633219F0724` | 985.58 / 1100.60 / 25737.92 / 1302.56 |

Across 15 measured samples per route, means are **990.62 ms TCP, 1123.13 ms
HTTP, 25899.95 ms StartJob and 1221.15 ms Protheus REST**. Addon server-only
mean is **825.00 ms**, with a different scope. TCP time is descriptively 18.88%
lower than REST overall; HTTP 8.03% lower. HTTP was 0.64% slower than REST in
the first run; TCP lost to HTTP in one run. Fixed order and the small sample
do not establish statistical significance or general performance superiority.

The export audit passed **684 consistency checks**, including all measured
HTML chart values and means, JSON completion/status/page/row counts and
recalculated sums/means/minima/maxima. Largest arithmetic difference is
4.95e-10 ms from floating-point rounding. Reconstructing complete harness time
from all client samples plus the one addon RPC leaves 8.59-14.06 ms per run
outside those intervals, consistent with harness preparation/cleanup.

StartJob starts a synchronous worker per page, including environment/connection
preparation and cleanup; REST uses its prepared worker. The StartJob/TCP ratio
does not isolate SQL-engine or language performance. Addon `rpcCalls=10` per
sample and `measuredCalls=50` per run are local dispatches. `networkCalls=1`
covers the complete seven-traversal package and returns metrics, zero dataset
rows. Whole-call times are 5884.622 / 5598.375 / 6194.857 ms; those include HRB
loading, warmups, measured traversals and response transport.

An additional package comparison includes warmups on both sides: three whole
addon RPCs total **17.677854 s**, versus **20.638174 s TCP, 23.892302 s HTTP
and 26.260709 s Protheus REST** for the sum of the same 21 client traversal
intervals. Addon time is 32.68% lower than REST in that sum. It returns metrics
instead of client-side pages; execution placement and payload differ. Client
intervals omit inter-iteration harness bookkeeping, while addon calls include
their internal orchestration. This is separate from the measured-only means.
Whole-call minus addon server-run time is 4.375-9.622 ms (under 0.17% observed);
it combines HRB/serialization/transport and clock quantization, not isolated
network time. The Windows addon clock has system-tick granularity.

### Focused evidence and network acceptance

| Validation method | Result and scope | Local evidence |
| --- | --- | --- |
| AppServer CLI lifecycle | 6000 actual Health calls, 17 checks/0, exit 0; reused per-instance native component, independent clients, refusal/recovery/Close; no SQL or leak measurement. | `tmp/comparison-protheus-0d6eed2eb4554737acfe9a05f902d8da/validation.json`, `results.lifecycle`. |
| AppServer CLI controller | 61 checks/OK, exit 0; deterministic request validation/ownership, no SQL. | `tmp/comparison-protheus-e95c292052a44a1f943d84bcc16a7fe7/controller.log`. |
| AppServer CLI REST contract | 43 checks/OK, exit 0; eight mock page calls, authentication/header/status/error contracts and rejected-input workarea preservation. | Same run's `rest-contract.log`. |
| Chromium template | Three tests, 46 checks/0; request lifecycle/spinner, charts, correlation, standalone exports and large collections; comparison fixtures are simulated. | `tmp/benchmark-browser-validation-20261018.log`, `tmp/benchmark-browser-35740/result.json`. |
| Native addon | 47 checks/0; fake query registry, permissions, old one-argument ABI, no database/listener; runner also checks fixture identity at three row counts. | `tmp/benchmark-addon-tests-51e2a7520b2048648bf2a1517db70c17/results.log`. |
| Native product regression | 712 checks/0; separate historical regression after optional addon context. | `tmp/tests-78d22ed883da4f57b2d5aabb7f2bf91c/results.log`. |
| Actual existing Protheus REST listener | Repeated 2026-10-19: absent/incorrect/valid credentials 401/401/200; authenticated invalid fixture 400; recovery 200. Successful pages have seven rows, total 17, first ID 1. | `tmp/v01-v02-acceptance-20261019/rest-network.json`. |

The REST probe reused `https://localhost:4323/rest`, HTTPV11/REST 2.0,
Security=1 and the existing private credential section. No extra listener,
service restart or configuration change was required for closure. The probe
bypassed certificate verification only for that local HTTPS request; it does
not accept certificate validation or other TLS deployments. Private credentials
are absent from receipts. The prior INI consolidation backup remains private:
`appserver.ini.benchmark-backup-20261018-162739.bak` beside the active INI.

The last worker-connect compilation recorded **45 successful sources, zero
source errors**. Its process finalization remained **0xC0000409**; stop/start
scripts returned zero. Evidence:
`tmp/comparison-worker-connect-build-output-20261018.log` and
`tmp/comparison-worker-connect-totvs-build-result-20261018.json`. No product
source changed in this documentation closure; recompilation was not repeated.

### Provenance and remaining limits

Original exports remain in `C:/Users/marin/Downloads/hbbridge-benchmark`.
Verified copies and the 684-check audit are retained in
`tmp/v01-v02-acceptance-20261019/`; `closure.json` records the current 12-file
TLPP source snapshot and separates manual/local outcomes. Those hashes match
the latest focused source snapshot; they do not identify the binaries/RPO
executed in the supplied manual runs. SHA256 of each original export:

| File | SHA256 |
| --- | --- |
| `hbbridge-benchmark-3FF23D3FFFA5984889F09C1DFAFF2459.json` | `7cee8cbfd3b12bb9f9998a968f72f65f4aa01fbf984af536b4a013e3743821e9` |
| `hbbridge-benchmark-3FF23D3FFFA5984889F09C1DFAFF2459.html` | `8531b39b2d3270cfb5a75cb28c57bfc2f5253302b3c2b37625ecc79182710c1c` |
| `hbbridge-benchmark-B7D7F6E890176D45BB3DC912EC61E8BA.json` | `f292597a78b8323232353470b71d311c28c957a3d8fd2ab39a2990e2f9957588` |
| `hbbridge-benchmark-B7D7F6E890176D45BB3DC912EC61E8BA.html` | `f0d314994c5da523ea1945cf5e5831abc9b1ea17c3cf6261cd040fa56d9007c3` |
| `hbbridge-benchmark-E3D8EB828C914C48926D2633219F0724.json` | `daee9ca75807cb2a9d5abd3005ca6d0234a99b48da2e5e2d4a505e8e4343da6e` |
| `hbbridge-benchmark-E3D8EB828C914C48926D2633219F0724.html` | `c148285e5b2e3fd1af403a1039cfd7408be7a86a17c9e456e15920616deff5fe` |

Earlier aggregate automated receipts remain failed: `e95c2920...` recorded
StartJob `ENVIRONMENT_FAILED`; `ea7029a0...` recorded `CONNECTION_FAILED`.
Use their passing individual controller/REST/lifecycle evidence only. An
intermediate REST test process failed before its entrypoint with APPMAP/file
sharing, not an assertion failure; the subsequent 43-check run passed. Later
manual success accepts its demonstrated environment without changing those
isolated StartJob CLI outcomes. The later two-route CLI passed separately;
the larger HTTP sample-136 outcome has workload/timeout context recorded
[below](#m08-manual-cli-validation-on-2026-10-19), without a generic CLI defect claim.

Exports do not attest the same physical backend, builds, driver, pooling,
hardware, endpoints/TLS/topology or background load. The environment name does
not establish a tunnel and `startedLocal` has no timezone offset. Memory is
UNAVAILABLE and CPU unmeasured. `transportOrder` omits addon although code runs
it last; timing fields retain their declared scopes. ASCII/explicit DECIMAL
CAST success does not accept D03 Unicode/binary/raw-FLOAT cases. Next: D03,
then M09 final package validation; the earlier isolated StartJob CLI
environment preparation remains a separate record, not a general CLI failure.

Documentation closure checks passed on 2026-10-19: all three required
validators (`check.hb`, `commit.hb`, read-only `3rdpatch.hb`) accepted 227 files;
local links exist across 85 documents and whitespace checks passed. Receipt:
`tmp/v01-v02-acceptance-20261019/commit-check.log`. These gates cover this
closure and do not complete pending D03/final M09 package work.

<a id="m08-manual-cli-validation-on-2026-10-19"></a>

## Additional manual TCP/HTTP CLI validation on 2026-10-19

The supplied fragment records run `7482F7E82956EC4E961CEEE6C3A82222` at
2026-10-19T08:13:33.576000-03:00, prefix 35364, with overall success and final
`hbBridge benchmark Protheus OK`. This is manual CLI evidence, not another
automated execution. Fixture `m08.constant.v1`, alias `MSSQL/pData`: ten rows,
page size ten, one measured traversal per transport, zero warmups, concurrency
one. `protheusComparison=false` and `addonComparison=false`.

| Route | Elapsed ms | Completed pages / calls / rows | Result |
| --- | --- | --- | --- |
| hbBridge TCP | 94.799800 | 1 / 1 / 10 | Success, no service error. |
| hbBridge HTTP | 124.020300 | 1 / 1 / 10 | Success, HTTP 200. |

Each one-sample total/minimum/maximum/mean equals that sample. The two timed
traversals sum to 218.820100 ms; complete run 232.731400 ms leaves 13.911300 ms
outside sample intervals. This confirms the two-route CLI workflow for its
reported parameters, without accepting expanded StartJob/REST/addon CLI or
replacing the separate 1000-row benchmark statistics. Invocation, timeout,
executed binary/RPO identity and process exit code were not supplied; memory
is UNAVAILABLE. Archived summary/review:
`tmp/v01-v02-acceptance-20261019/cli-manual-20261019-7482f7e8.json` and
`cli-manual-20261019-7482f7e8-review.json`. The archive hash identifies this
preserved fragment, not an original complete console log.

Operational clarification recorded on 2026-10-19: the earlier 100000-row,
500-iteration CLI workload used excessive values without an adequately sized
request timeout. The earlier invocation had a 30-second request budget; the
clarification concerns its suitability, not absence of a numeric setting.
Keep HTTP sample 136's FAILED result as that workload/deadline outcome, with
workload/budget sizing as its operational context; it does not demonstrate a
generic CLI defect. No independent rerun or isolated cause measurement is
inferred. Earlier isolated StartJob CLI `ENVIRONMENT_FAILED`/`CONNECTION_FAILED`
initialization attempts are a different configuration-specific record.
V01/V02 remain complete; D03 is next and M09/package 001 remain open.

<a id="d03-integrity-on-2026-10-21"></a>

## D03 UTF-8, numeric and NUL integrity on 2026-10-21

D03 is accepted for the identified Windows x64 / SQL Server 16.0.1200.5 /
Microsoft ODBC Driver 18 target and read-only `d03.mssql.constants.v1`
fixture. Native retrieval, serialization and the Protheus consumer have
separate evidence; a UI conversion alone does not prove a correct database
read. M09/package 001 remain open.

Native checks completed on 2026-10-19, all without failures:

| Scope | Checks | Artifact |
| --- | --- | --- |
| Default regression, including JSON codec | 752 | `tmp/d03-native-final.log`; `tmp/tests-5733f80fe0ec4a30a4310adc37247e8c/` |
| Real MSSQL native/TCP/HTTP integrity | 73 | `tmp/d03-mssql-integrity-fixed.log`; `tmp/mssql-tests-d6d74b0b70be4cf8b4a6a0b0e8b56545/` |
| Existing real MSSQL regression | 92 | `tmp/d03-mssql-regression.log`; `tmp/mssql-tests-7c3c29255b1341dd988561123160de10/` |
| Independent `System.Data.Odbc`, without Harbour/JSON | 7 | `tmp/d03-odbc-reference.json` |
| Zig binary64 formatting/parsing | 2 | `src/zig/runtime/hbbridge.number.zig` unit checks |

The managed ODBC patch corrects supplementary Unicode in UTF-8 SQL input as
well as outgoing UTF-16 chunks. Before the input correction the 73-check run
had five failures: `tmp/d03-mssql-integrity.log`. No pinned upstream checkout
was modified. The shared numeric codec preserves fractional native FLOAT
and binary64 round trips; Protheus `N` comparisons use tolerances within 15
significant digits. CAST defines caller business scale; exact large decimal
values use explicit SQL text projection. SX3/TOP_FIELD are never inferred.

The final automated real AppServer CLI run on 2026-10-21 passed **80 checks,
zero failures, client/server exit 0**, against the isolated MSSQL host through
production TCP/HTTP clients and the common dataset. Receipt:
`tmp/d03-protheus-9c3d1606250449c9a659f92f92c5c6e6/validation.json`;
`protheus.log` contains all keyed checks. Native host SHA-256:
`96A7AC7B0D29C2016B15CAC4D8DCD18E5FA4CE075AF1BA28DE4719A5E8BE5CA1`.
The earlier 80-check run also passed in
`tmp/d03-protheus-4c82aad9154f4bfe8ae533f6c947ac48/`.
Coverage includes accented VARCHAR, euro, Unicode outside CP1252, surrogate
chunk boundaries, long text, FLOAT fractions/magnitudes, explicit DECIMAL
scales, exact decimal text, NUL/empty/null, EOF, HTTP status and defensive
row/page copies. Clients encode CP1252 fixture inputs once; received values
stay UTF-8 and consumer text uses `DecodeUTF8()` once when needed.

A standalone `JSONObject` probe confirmed a separate AppServer defect:
assigned `A + Chr(0) + B` remains `410042`; `ToJSON()` emits `{"text":"A"}`;
`FromJSON('{"text":"A\u0000B"}')` returns Nil and yields `4142` (AB).
The round trip yields `41` (A), without SQL or transport. Exact reproduction
and build 7.00.240223P / 24.3.1.5 / SVN 46783 are published in
[issue #14](https://github.com/naldodj/totvs-protheus-open-issues/issues/14).
Probe: `tmp/d03-local-7baba9a141dc4c2cae22a80db76779af/protheus.log`.

`HBBridge.Client.HBBridgeJSON` now preserves real NUL string escapes without
recoding UTF-8 or changing native scalar/numeric handling. Both clients and
dataset snapshots use it. Truncated/removed NUL remains a failed assertion;
no fallback changes the expected value to A or AB. Closed AppServer checks
passed **31/zero failures, exit 0**, including NUL positions/density, literal
escapes, Unicode keys, empty containers and failure clearing:
`tmp/d03-local-334459cffda64ccd89f8760b27c8d266/protheus.log`.

The private RPO compiled all ten selected sources with **zero source errors,
process exit 0**: `tmp/d03-protheus-rpo/compile.log`. Installed services/RPO
were not replaced or restarted for these final runs. An intermediate compile
reported an empty/corrupt source despite exit 0; the subsequent complete
compile passed. AppServer mock regressions also passed: dataset **67/31
calls** (`tmp/d03-local-bfc974373fdc40f78e6143d7500834bc/`), helpers **12**
(`tmp/d03-local-11b6fb42fcb94c788f9bdc0c52b1cede/`), HTTP table **71**
(`tmp/d03-local-496df9338ec545c8bd713748a2829dab/`). The two procedure entries
returned process -4 without a numeric CLI return; acceptance uses their
complete successful assertion summaries, not a fabricated exit 0.

Native binary bytes remain exact. Version-1 JSON explicitly refuses SQL
binary columns with `BINARY_JSON_UNSUPPORTED`; explicit SQL hexadecimal text
projection is tested. This does not implement automatic BLOB JSON support.
The Protheus projection helper excludes binary base types, retains long text,
orders columns, escapes the supplied table literal and removes the hardcoded
dbo assumption. The revised SRA browse compiles; its UI/business-data run was
not repeated here. Earlier manual accent/no-CAST/DecodeUTF8 observations keep
their manual scope. Linux, other drivers/codepages, arbitrary-precision JSON,
automatic ERP scale and a versioned binary representation require separate
implementation/acceptance.

Final D03 documentation/source gates passed on 2026-10-21: all three required
validators accepted **242 files**, local links exist across **89 documents**,
and whitespace checks passed. Receipt: `tmp/d03-final-commit-check.log`.
These checks do not close M09/package 001.
