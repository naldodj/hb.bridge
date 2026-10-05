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

Original Milestone 1 calls used loopback1512/5000ms and Health/Echo/ADDON.
For current acceptance compile the whole src/tlpp tree and run
U_HBBridgeConnectionTest(cHost,nPort,nTimeout,nLargePayloadBytes).
Without arguments it reads active [hbBridge], falling back to
127.0.0.1/1512/30000ms and zero optional extra Echo.
Constructor budgets default0/0, chunk65536, positive TLPP timeout.
Historical tests do not certify renamed/new sources.

## AppServer acceptance on 2026-10-03

Local logs corroborated manual compilation and WebApp execution:

- **07:45:37 São Paulo:** 3 sources, 3 successes, 0 errors:
  hbbridgeconnectiontest.tlpp and the then-named hbbridgeclient.tlpp/
  hbbridgerpcdataset.tlpp. Evidence: tmp/console.log.
- **08:00:30, thread32748:** Health/ADDON/Echo success:true in
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
Payload/wire default0, read buffer65536, Harbour budget30000ms, zero disables
its deadline; NETIO zero maps to -1.
C gzip is incremental but JSON remains materialized.
Runtime metadata exposes string/socket long/zlib uInt/NETIO int capacities.
Protheus drains admitted workers; zero deadlines can prolong shutdown.
NETIO signals/closes its connections.

The later pre-SQL run passed **305 checks, zero failures/no skips**:
exact24,000,000-byte Echo, JSON/gzip over16MiB both ways, incremental compressor,
zero/positive policies, positive/no Harbour deadline and nine-digit declared
length without allocating100MB.
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
request gzip152,964 >default65536 buffer.
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

An isolated JSON product smoke returned ID10, rowCount1, hasNexttrue.
Historical binary path: tmp/marco3-product/hbbridge.exe.
Log: tmp/marco3-product-smoke.log.
SHA256: 8C90995602F336B1B5B395AD6AE36A4F2608079451E68A9BC142DE8EC9F6C17C.
The active canonical installation was not replaced.

### Failed SQL attempt at 00:27:04

Operator U_HBBridgeQueryTest, thread30460, returned
SERVICE_NOT_FOUND; Servico nao suportado.
This proves test entry/dispatcher response, not SQL execution.
A subsequent Service.List probe at127.0.0.1:1512 found six basic services, no
RPCRDD.Query: tmp/sql-service-discovery.json.
The canonical executable's help already supported SQL; active process CLI was
not accessible to the agent.

Registration requires nonempty sqlProfiles.
Guidance was to restart the current product with the SQLite configuration and
repeat the existing TLPP entry. Startup/test diagnostics were added.

The new diagnostic candidate printed RPCRDD.Query enabled; SQL profiles=1 and
returned ID10/one row/hasNexttrue on isolated ports.
Log: tmp/sql-registration-smoke.log.
SHA256: F2177CFA4AB76363EC2E773A39717057D0CA7CDA8F10B0FD03A13CB3DAC74490.
The canonical launcher also passed SQLite on isolated ports, with Port overriding
JSON, tmp/sql-launcher-smoke.log. These are server preparation, not AppServer
acceptance.

### SQLite acceptance at 00:40:06

Operator U_HBBridgeQueryTest, AppServer thread41228, PROTHEUS/sqlite_demo:
**29 checks true**. Accepted named/decimal values, navigation/EOF, close,
empty, SQL/profile errors/recovery, first/next/last pages, gaps, localEOF,
hidden ordinal and invalid page/order rejection.

Time is the operator's São Paulo log time. The agent did not execute the test.
Server hash and corresponding compile log were not supplied.
This covers SQLite/client revision used then, not MSSQL, expanded SQL types/
codepages or later client changes.

### INI configuration and Harbour baseline

Server INI/JSON now share validation, precedence defaults<onefile<CLI,
automatic adjacent hbbridge.ini and explicit replacement.
--config-info is sanitized and opens no listener/database.
Launchers forward Port/MaxWorkers only when explicit; the SQL INI launcher
uses the product parser.

**412 Harbour checks, zero failures/no skips**:
tmp/tests-236f1241c1174cf4b193c22f6eedb6e0/results.log.
Added to383:26INI cases and3 strict invalid driver/order-direction rejections.
Coverage: equivalent INI/JSON, precedence, relative paths, BOM/CRLF,
password/ODBC punctuation, automatic loading and malformed-file rejection.

AppServer [hbBridge] reading followed the00:40:06 test and received its own later
operator acceptance below. HBBridgeConfig selects GetSrvIniName/GetPvProfString.
No-argument clients/tests now read the seven template keys.
Client and Harbour config files must be aligned separately; a WebApp URL without
arguments may select values different from launcher output.

An updated INI candidate passed all three INI metadata examples, CLI precedence
and a first-page launcher smoke (ID10/one row/hasNexttrue) using an isolated
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
| U_HBBridgeConfigTest | All13true: defaults/INI/precedence/invalid override, zero-negative-fraction budgets, port/timeout, native chunk and activeINI. |
| Connection-test clock | Unix=false, raw1097.692700, normalized1097.773500ms after Sleep1000, OK. |
| Health/ADDON/Echo | All passed; two identical200,000-byte results, varied requestgzip152,964. |
| U_HBBridgeQueryTest | sqlite_demo, all29true: fields/decimal/errors/recovery/empty/pages/EOF/close. |

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
codepages. The412Harbour checks are separate evidence.
Naming/dependency refactoring requires its own later validation; retain historical
artifact paths/hashes literally rather than implying new binaries share them.
