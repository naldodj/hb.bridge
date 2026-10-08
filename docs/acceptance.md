# Reference environment and acceptance

[Português (Brasil)](acceptance.pt-BR.md)

Acceptance of the earlier structural reorganization was confirmed.
This document identifies the development environment and separates historical
results, operator reports and agent-run regressions.
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
tmp/totvs-compile.log. An agent attempt received Access denied stopping the
elevated AppServer and ended before compilation. The successful run above was
performed by the operator.
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

### Operator RPC confirmation on 2026-10-03

The operator supplied:

~~~text
hbBridge Health Protheus OK: {"success":true,"message":"hbBridge Zig Engine Active"}
hbBridge ADDON.Execute Protheus OK: {"success":true,"addon_msg":"Executado via HRB Addon no hbBridge!"}
hbBridge Echo Protheus OK: 200000 bytes, conteudo identico.
hbBridge Echo fragmented Protheus OK: 200000 bytes, conteudo identico; gzip request=152964 bytes.
hbBridge RPC Protheus OK: todos os testes solicitados passaram.
~~~

These are verbatim operator logs; Portuguese output is intentionally preserved.
They confirm complete payload comparison and normal completion, with varied
request gzip 152,964 > default 65536-byte buffer.
The agent did not execute that round; execution time/arguments/binary hash
were not supplied.

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

Dataset/test implementation preceded an agent build attempt blocked during
TOTVS shutdown: tmp/marco3-totvs-build.log. No compilation/new AppServer execution
occurred in that attempt. Missing-DSN testing proved only sanitized ODBC errors,
not real MSSQL or DBAccess use.

An isolated JSON product smoke returned ID=10, rowCount=1, hasNext=true.
Historical binary path: tmp/marco3-product/hbbridge.exe.
Log: tmp/marco3-product-smoke.log.
SHA256: 8C90995602F336B1B5B395AD6AE36A4F2608079451E68A9BC142DE8EC9F6C17C.
The active canonical installation was not replaced.

### Failed SQL attempt at 00:27:04

Operator U_HBBridgeQueryTest, thread 30460, returned
SERVICE_NOT_FOUND; Servico nao suportado.
This proves test entry/dispatcher response, not SQL execution.
A subsequent Service.List probe at 127.0.0.1:1512 found six basic services, no
RPCRDD.Query: tmp/sql-service-discovery.json.
The canonical executable's help already supported SQL; active process CLI was
not accessible to the agent.

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

Operator U_HBBridgeQueryTest, AppServer thread 41228, PROTHEUS/sqlite_demo:
**29 checks true**. Accepted named/decimal values, navigation/EOF, close,
empty, SQL/profile errors/recovery, first/next/last pages, gaps, localEOF,
hidden ordinal and invalid page/order rejection.

Time is the operator's São Paulo log time. The agent did not execute the test.
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
operator acceptance below. HBBridgeConfig selects GetSrvIniName/GetPvProfString.
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
Agent compile was blocked before compiler during process stop:
tmp/ini-totvs-build.log. U_HBBridgeConfigTest was prepared and subsequently
accepted by the operator.

### Later operator configuration/clock/SQLite confirmation

Reported in the **2026-10-04 session**, after client-configuration changes.
This round was manual; the agent did not compile/execute those AppServer tests.

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
failures, no skips**. The agent executed it using the managed
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
`sqlite_demo` and `mssql/pData`, and sanitized secrets/connection strings.
Metadata inspection did not start listeners or query either database.

The final commit gate passed for **135 files**, including `check.hb`,
`commit.hb`, `3rdpatch.hb`, naming/indentation and documentation pairs.
Log: `tmp/commit-gate-20261007.log`. The staged-check pre-commit hook was
installed locally; no commit or publication was performed. Local documentation
links and `git diff --check` also passed.

Automatic external OpenSSL resolution, Zig HTTP and SQL materialization remain
design work. This candidate does not add HTTPS/Linux/MSSQL or AppServer
acceptance to the earlier records.

## TLPP HTTP operator acceptance on 2026-10-07

The operator adjusted the accent comparison and FWRest unauthorized handling,
then reported `U_HBBridgeHTTPTest` running in **PROTHEUS**, thread **25672**.
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

This is operator runtime acceptance, not an agent-run test or a supplied
compiler-success log. An earlier agent build attempt returned -1073740791;
its log identified an include-directory value as the environment. It did
not establish successful compilation. The operator's run supersedes that
execution gap for the exercised HTTP sources; logs remain at
`tmp/totvs-http-build-run.log` and `tmp/totvs-compile.log`.

The report does not identify the SQL alias/backend, client URL/token/settings
or server executable hash. It therefore does not add real MSSQL, HTTPS,
Linux, full Unicode, alternative configuration or the 16-check client config
test to this acceptance. See [the example](../examples/http/README.md).

The agent's final working-tree gate passed **139 files** with `check.hb`,
`commit.hb`, `3rdpatch.hb` and project conventions; log:
`tmp/commit-gate-tlpp-http-20261007.log`. Working-tree/index whitespace and
all local links across 59 documents passed. The existing user-staged snapshot
was preserved; these validations did not create a commit or publication.

## Native Harbour source extension on 2026-10-07

The owner authorized `.hb` for project-owned Harbour sources. All **26** files
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
AppServer during the agent's migration run. Subsequent operator recompilation
and runtime reports below supersede that pending regression status. Earlier
RPO acceptance used the `.prg` sample path. Package 001 MSSQL milestones remain pending.

The full working-tree gate passed **141 files** with `check.hb`, `commit.hb`,
`3rdpatch.hb` and project conventions; log:
`tmp/hb-extension-commit-gate-20261007.log`. Local links across **61 documents**
and `git diff --check` passed. The index was preserved; no commit was created.

## Post-migration Protheus operator acceptance on 2026-10-07

The operator confirmed recompilation after the `.hb` migration and supplied
HTTP output in chat, followed by Query/configuration/TCP/HTTP output in
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

These are operator executions, not agent-run AppServer tests or a supplied
compiler-success log. They supersede the pending renamed-TLPP/16-check
configuration regression status for the exercised cases. The addon sources
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

## Protheus TCP MSSQL and SQLite operator acceptance on 2026-10-08

The operator supplied runtime output from the two Query wrappers. The
transcript is preserved at `tmp/protheus-mssql-sqlite-operator-20261008.log`.
Times below are São Paulo on 2026-10-08; the log identifies `marin` on
`DNA-TECH-01` and the `tttm120.rpo`, `tlpp.rpo`, `custom.rpo` stack.

| Program | Reported start / thread | Result |
| --- | --- | --- |
| `U_HBBridgeQueryTestMSSQL` | 10:06:10 / 660 | All 29 checks true; `Protheus OK; profile=mssql/pData`. |
| `U_HBBridgeQueryTestSQLite` | 10:06:43 / 3192 | All 29 checks true; `Protheus OK; profile=sqlite_demo`. |

The checks cover named fields and decimals, missing fields, EOF/close, empty
results, invalid SQL, unknown profiles, subsequent recovery, first/next/last/
empty pages, hidden ordinals, invalid page/order and page cleanup. This records
operator runtime acceptance of the existing TCP dataset/page contract with
the explicit MSSQL alias, plus the repeated SQLite regression. The report
contains no compiler-success log or artifact hashes; the agent did not run
these AppServer calls. Native extended fixtures retain their separate evidence.

HTTP acceptance with the MSSQL profile subsequently passed on 2026-10-08;
see the [identified HTTP wrapper runs](#protheus-http-mssql-and-sqlite-operator-acceptance-on-2026-10-08).
Earlier HTTP reports without an identified SQL backend retain their historical
scope.

## Native MSSQL acceptance on 2026-10-08

The agent-run opt-in Harbour acceptance passed **92 checks, zero failures,
no skips** against the real SQL Server database. Evidence:
`tmp/mssql-tests-b3d676f0daaf470a97af605a98a9681c/results.log` and
`tmp/mssql-native-normalized-20261008.log`.

| Component | Exercised value |
| --- | --- |
| Platform | Windows x64. |
| SQL alias / database | `mssql/pData` / `pData`. |
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
operator TCP result above. The [operator HTTP runs below](#protheus-http-mssql-and-sqlite-operator-acceptance-on-2026-10-08)
accept M05 for the 13 exercised cases. Controlled unavailable-connection/
native-timeout cases (M06), broader profile/resource
isolation (M07), transport/memory baselines (M08) and remaining AppServer/final
package evidence (M09) retain their pending work; package 001 is not complete.

## Protheus HTTP MSSQL and SQLite operator acceptance on 2026-10-08

The operator supplied runtime output from both HTTP test wrappers. Evidence:
`tmp/protheus-http-mssql-sqlite-operator-20261008.log`. The report identifies
`marin` on `DNA-TECH-01` and the same `tttm120.rpo`, `tlpp.rpo`, `custom.rpo`
stack. Times below are São Paulo on 2026-10-08.

| Program / default SQL profile | Reported execution | Result |
| --- | --- | --- |
| `U_HBBridgeHTTPTestMSSQL` / `mssql/pData` | Program 10:33:32, thread 25976; test 10:33:33–10:33:34 | All 13 checks true/PASS, Health HTTP 200; elapsed 00:00:01. |
| `U_HBBridgeHTTPTestSQLite` / `sqlite_demo` | Program 10:34:06, thread 9916; test 10:34:07–10:34:07 | All 13 checks true/PASS, Health HTTP 200; elapsed 00:00:00. |

The operator's [HTTP wrappers](../src/tlpp/tests/protheus/hbbridgehttptest.tlpp)
default the SQL alias explicitly and forward to the common test. They retain
the existing URL/token/timeout resolution for omitted transport arguments.
Both runs passed `healthGet`, `healthPost`, `servicesGet`, `echo`, `addon`,
`unknownService`, `adminForbidden`, `unauthorized`, `afterFailure`,
`queryFirstPage`, `queryFirstValue`, `queryNextPage` and `queryLastValue`.
This accepts M05 for those 13 exercised cases with `mssql/pData`, including
the common dataset's HTTP page values, and repeats the SQLite HTTP regression.

These are operator AppServer executions, without a supplied compiler-success
log or artifact hashes; the agent did not execute these HTTP calls. The
reported elapsed times have one-second resolution and are not performance
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

The owner requested easier field access and sequential page traversal after
the accepted runs above. The TLPP dataset now includes `MoreToRead()`,
`Header()`, its compatibility alias `DSStruct()`, `FieldInfo()`, `FieldCount()`,
`FieldName()` and `GetRow()`. `Eof()`/`Skip()` retain page-local behavior;
`MoreToRead()` fetches the next page at EOF and preserves a failed request's
error. Header, field and row access return independent JSON copies. See
[dataset behavior and proposed contract](dataset.md).

The new isolated [U_HBBridgeDataSetTest](../src/tlpp/tests/protheus/hbbridgedatasettest.tlpp)
uses a mock client, without SQL, credentials, network calls or ERP data.
Its expected successful report is **45 checks and 17 mock calls**, covering
metadata ordering/copies, automatic traversal, repeated checks, closed/empty
state, invalid metadata and failure/recovery. The agent attempted compilation
with `scripts/build-totvs.cmd` on 2026-10-08 at 16:31:40 São Paulo, thread
36788. It returned exit 1, `COMPILEERROR-300 Failed to open repository`:
`custom.rpo` was in use by one user. The compiler reported total/success/errors
`0/0/0`, so it did not compile these sources. Log: `tmp/totvs-compile.log`.
No stop/start scripts were configured, and the active AppServer was not stopped.
The new runtime test remains unexecuted; prior operator reports do not accept
these methods. D02 in [WIP](../WIP.md) tracks that acceptance.

A separate agent-run, read-only constant MSSQL probe reproduced a numeric
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
