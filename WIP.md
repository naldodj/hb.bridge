# Active hbBridge work package

[Português](WIP.pt-BR.md) · [Roadmap](TODO.md) · [Acceptance](docs/acceptance.md)

WIP records the current package, its next action and completion evidence.
Resume its first unfinished task instead of repeating the project-wide
analysis. TODO retains the complete roadmap; README describes the product;
acceptance records verified results; ChangeLog and Git preserve history.

## Package 001: real MSSQL acceptance

| Item | Current value |
| --- | --- |
| ID | `001-mssql-acceptance` |
| Opened / updated | 2026-10-07 / 2026-10-19 |
| Status | D02/M06/M07/M08 retain their recorded acceptance. V01/V02 completed on 2026-10-19 for the demonstrated visual/AppServer scope and separately recorded focused checks. D03 is next; final M09 checks and package closure remain pending. |
| Goal | Accept the existing RPCRDD.Query/dataset against an identified real MSSQL database through Harbour, Protheus TCP and Protheus HTTP. |
| Product reference | Published code `50e1c65`; checkout at package opening `bce52d2` includes the clone badge update. |
| Next task | D03: reproduce and correct UTF-8/raw-FLOAT integrity across Harbour, TCP/HTTP and Protheus. Keep caller-defined business scale/CAST. Then complete M09; package 001 stays open. |

### Decisions already made

- Keep the single implementation and existing Query/page contract. Use
  SQLMIX/RDDSQL with SDDODBC; correct defects revealed by this acceptance.
- Protheus resolves tenant/company/branch/xFilial, table names and business
  rules. hbBridge executes explicit SQL/parameters. Begin with constant SELECTs
  and an isolated read fixture; leave production ERP tables unchanged.
- Profiles remain opaque aliases selected explicitly per call. `MSSQL/pData`
  is an example, not a mandatory profile or business-context resolver.
- Use a private complete ODBC string or the structured MSSQL configuration
  keys, with explicit SQL/integrated authentication. Portable encrypted credentials/CLI remain a later package;
  their implementation is not a prerequisite for this acceptance.
- Clarified on 2026-10-07: SQL credentials are stable; automatic
  database password rotation is outside the selected scope. OpenBao KV storage
  needs no dynamic MSSQL plugin. Vault token renewal is a separate lifecycle.
- Preserve the shared SQL lifecycle mutex. Verify isolation/cleanup under
  concurrent calls; this package does not promise parallel SQL execution.
- Adapt connection ownership to `HBBridgeSQLPool` logical leases while keeping
  one native RDDSQL connection lifetime per call. Physical reuse belongs to
  the native ODBC Driver Manager; it remains opt-in and requires separate proof.
  SQLite `:memory:` retains a fresh database for each lease.
- Keep existing runtime capacities and configurable policies. Add no fixed
  proof-of-concept payload ceiling or new transport implementation.
- Reprioritized on 2026-10-13: defer optional Protheus metadata addons and
  automatic decimal/CAST rewriting. Keep caller SQL CAST and resume independent
  M06 failure/recovery work. D03 UTF-8/FLOAT remains open; package completion
  still requires its integrity evidence, not an assumed fix from CAST.

### Verified starting point

- Harbour suite: **487 checks, zero failures, no skips**, repeated 2026-10-07.
- Manual AppServer SQLite acceptance: **29 dataset/page checks**, repeated 2026-10-07,
  thread 27136, profile `sqlite_demo`.
- Revised client configuration: **16 checks**, 2026-10-07, thread 30596.
- Manual AppServer TCP: clock, Health, ADDON and both exact 200000-byte Echo calls
  passed, 2026-10-07, thread 27084.
- Manual AppServer TLPP HTTP acceptance: **13 checks**, repeated 2026-10-07,
  threads 27296 and 25456 after the reported recompilation.
  Its SQL profile/backend was not supplied; it does not certify MSSQL.
- Native THREAD STATIC probe: **31 assertions**; worker state differs from
  request state. The shared SQL mutex remains intentional.
- See [acceptance](docs/acceptance.md) for logs, exact scope and runtime details.

### Explicit preparatory change: Harbour source extension

On 2026-10-07 adoption of native `.hb` was authorized for all project-owned
Harbour sources. This bounded organization change precedes M01 and does not
replace package 001, reset its progress or certify MSSQL.

- [x] **P01 — Migrate sources and references.** Rename the 26 Harbour sources
  in `src/hb/`, `tests/` and `addons/`; update HBP/HBM, test scripts and the
  TCP/HTTP TLPP sample addon paths. Preserve upstream files and `.prg` addon support.
- [x] **P02 — Validate and record the convention.** Compile the product and
  run Harbour regressions, commit validators and local documentation links.
  Record the results and the TLPP recompilation/runtime acceptance status.

Evidence: 487 Harbour checks, zero failures/no skips; isolated product build
and help/configuration smoke checks; all three commit gates for 141 files;
61 documents' local links and whitespace passed. Logs/details are in
[acceptance](docs/acceptance.md#native-harbour-source-extension-on-2026-10-07).
Recompilation was reported, followed by passing manual AppServer TCP,
SQLite, revised configuration and HTTP runs. Evidence:
`tmp/protheus-http-hb-operator-20261007.log` and
`tmp/protheus-suite-hb-operator-20261007.log`; see [acceptance](docs/acceptance.md).
The preparatory TLPP regression is accepted for the exercised cases. Resume M01;
do not redo the completed extension migration or infer MSSQL acceptance.

<a id="preparatory-http-table-example-operator-acceptance"></a>

### Preparatory HTTP table example: manual validation

- [x] **F01 — Accept the FWWebEx HTTP table example.** Validation was confirmed
  as OK on 2026-10-13, with six screenshots of the constant fixture and SX5.
  Visible results cover 5/10-row displays, global search, a Description equality
  filter, filtered/unfiltered totals and literal text rendering. See the
  [example evidence](src/tlpp/tests/protheus/hbbridge.http.table.test/README.md)
  and [acceptance](docs/acceptance.md#fwwebex-http-table-validation-confirmed-on-2026-10-13).
  This requested preparation is complete for the demonstrated views. D02/D03
  retain their specific mock execution and data-integrity acceptance tasks.

- [x] **F02 — Correct and accept the HTTP table regression.** Manual execution
  of `U_HBBridgeHTTPTableTest` on 2026-10-13 at 17:46:56 São Paulo, thread 27708,
  passed **71 checks, zero failures**, including NUL boundaries/input preservation,
  recovery and totals. All 19 queued mock responses were consumed without
  unexpected calls. This closes the earlier 62-check run's three failures;
  see the [record](docs/acceptance.md#http-table-regression-validation-on-2026-10-13).
  Dataset/helper execution has subsequent acceptance in D02; D03 still tracks integrity.

### Work in order

The analysis was expanded on 2026-10-08 after the accepted HTTP runs:
dataset header access/automatic page traversal, encoding/collation and logical
field sizes/decimals. A constant probe revealed a raw FLOAT JSON precision
defect, and source inspection found a TCP codepage inconsistency. These are
new acceptance findings, not reasons to repeat the completed inventory.

- [x] **D01 — Review the consumer interface.** Inspect the supplied local
  FileRead/FileNavigator examples; adopt explicit `MoreToRead()` and metadata
  methods while preserving page-local `Eof()`/`Skip()`. Current canonical
  metadata API is `Header()`; `DSStruct()` was removed afterwards.
- [x] **D02 — Accept the TLPP dataset extension.** Compile and exercise
  header/field/row copies, column order, automatic traversal, repeated checks,
  empty/closed state and page failure/recovery. The new mock tests use no ERP data.
  Confirmed manual AppServer validation on 2026-10-13, São Paulo:
  `U_HBBridgeDataSetTest`, 17:56:23, thread 32332, **67 checks/31 mock calls**;
  `U_HBBridgeHelperTest`, 17:56:45, thread 28300, **12 checks**. All checks true,
  both reports OK. See [scope/evidence](docs/acceptance.md#dataset-and-helper-validation-on-2026-10-13).
  This accepts the mock/interface contract; native text/numeric integrity remains D03.
- [ ] **D03 — Correct text and numeric integrity.** First prove that the
  driver/RDD delivers the database's intended text to native Harbour before
  JSON serialization, using known fixture values and explicit source metadata.
  Then verify UTF-8 execution and text requests/responses in both directions
  between Protheus and hbBridge over TCP/HTTP, client conversion and binary handling;
  fix the reproduced fractional FLOAT JSON loss and define lossless decimal/
  native versus caller-supplied logical metadata without implicit ERP lookups.
  See [findings and contract](docs/dataset.md). Do not count old ASCII/DECIMAL
  fixture results as acceptance of these newly identified cases.
  The 2026-10-13 presentation observations retain the working HTTP example
  and further desktop validation. Clarified on 2026-10-19: `DecodeUTF8()` remains
  an expected consumer conversion when Protheus requires another codepage;
  removing it is not an acceptance criterion. A UI repair does not prove the
  database read. See the [staged checks](docs/dataset.md#d03-source-integrity-priority-on-2026-10-19).
  Separate generic FLOAT preservation from
  caller-selected DECIMAL business scale; CAST is an available projection,
  not a prerequisite for generic FLOAT transport. Explicit logical metadata
  remains a proposed extension. See the [analysis](docs/dataset.md#business-scale-and-raw-float-analysis-on-2026-10-13).
  Metadata addons and an optional TLPP/Zig SQL projection rewriter are deferred;
  their [evaluation](docs/dataset.md#deferred-metadata-addon-and-sql-rewriting)
  does not add an API/dependency or block independent M06 cases.
- [x] **S01 — Expand credential design.** Cover SQL, NETIO/admin and HTTP on
  hbBridge and local AppServer client secrets, external per-installation keys,
  portable providers and separately verified TLPP support. Encryption is still
  unimplemented; [credential scope](docs/credentials.md) records the remaining
  work. Stable SQL passwords/manual updates remain the selected policy.

- [x] **M01 — Identify the target.** Record the actual SQL alias, database,
  endpoint, MSSQL version, ODBC driver/version/architecture, authentication
  method and hbBridge process identity. Verify access to a private config.
  Keep passwords, tokens and complete credential-bearing strings outside Git/WIP.
- [x] **M02 — Prepare reproducible acceptance.** Use the existing
  [SQL launcher](examples/sql/README.md) and private INI/JSON. Establish a
  dedicated opt-in real-MSSQL test route, separate from the default SQLite
  suite. A missing required connector/config is a prerequisite failure,
  never a successful MSSQL test. Identify the backend in the recorded result.
- [x] **M03 — Accept Harbour SQL.** Run constant SELECTs and a reproducible
  fixture for named columns, supported numeric/decimal values, nulls, dates
  and accented/Unicode text. Define expected representations before assertions;
  record runtime/type restrictions rather than silently converting values.
- [x] **M04 — Accept Protheus TCP.** Run the existing
  [U_HBBridgeQueryTest](src/tlpp/tests/protheus/hbbridge.query.test/hbbridge.query.test.tlpp) against
  the explicit MSSQL alias, including all 29 checks. Add necessary backend
  cases to the shared product/tests without a second query implementation.
- [x] **M05 — Accept Protheus HTTP.** Run
  [U_HBBridgeHTTPTest](src/tlpp/tests/protheus/hbbridge.http.test/hbbridge.http.test.tlpp) with the
  same explicit MSSQL alias and the common dataset. Check the actual selected
  profile/backend, values and pages; a generic HTTP success alone is insufficient.
- [x] **M06 — Verify failures and recovery.** Accepted on 2026-10-14:
  invalid SQL, unknown profile, a reserved loopback port without a listener,
  one-second native MSSQL statement timeout, exact safe errors and subsequent
  recovery. Native local/NETIO/TCP/HTTP: **46 checks**; automated AppServer
  RPO CLI: **38 TCP / 51 HTTP checks**, each with 21 calls; **zero failures**,
  exit 0. Default regression: **636 checks**; repeated native MSSQL: **92**.
  Manual AppServer validation at 14:30:50 São Paulo, thread 13796, also passed
  all **38 TCP / 51 HTTP checks**, resolving the earlier seven failures per
  transport. [Manual scope/evidence](docs/acceptance.md#manual-protheus-failure-recovery-on-2026-10-14).
  Compiled all 30 TLPP sources with zero source errors. See
  [scope, artifacts and limitations](docs/acceptance.md#sql-native-timeouts-and-appserver-recovery-on-2026-10-14)
  and the [test guide](src/tlpp/tests/protheus/hbbridge.failure.test/README.md).
  Optional login/statement timeouts belong to each MSSQL profile; zero disables
  the native setting, omission preserves the driver default. Each statement,
  including COUNT, has its own timeout. This does not impose a shared request
  deadline or implement cancellation after client timeout/disconnect.
- [x] **M07 — Verify concurrency and release.** Baseline accepted on 2026-10-14;
  the additional load follow-up was accepted on 2026-10-15 for the Windows
  native and exercised manual summary scopes below. Preserve the intervening
  140-worker failure evidence:
  native **458 checks, 8 workers/192 calls**, local/NETIO/TCP/HTTP and three
  aliases; AppServer CLI **417 checks, 4 jobs/112 calls**, two TCP/two HTTP
  jobs alternating MSSQL/SQLite. Zero failures; caller areas/default connection,
  native handle reuse, profile/schema/value isolation, failure recovery and
  owned cleanup verified. Keep the SQL mutex; this does not certify parallel
  database execution or physical ODBC/heap leak freedom.
  [Evidence](docs/acceptance.md#sql-concurrency-and-release-on-2026-10-14).
  Additional manual logs report 40/100 workers with zero failures; only two
  use TCP when load increases. On 2026-10-15, independent collection/drain
  controls passed 417 checks with four workers and drained a controlled
  one-second abort. With a 300-second budget, all 140 reports/3920 calls
  returned: **16329 checks, 857 failures**, including status-0 native refusal
  diagnostics. All 32 TLPP sources compiled without source errors; the vendor
  compiler subsequently exited **0xC0000409**, recorded separately from compilation.
  The earlier native regression passed **656 checks, zero failures** with configurable
  HTTP listen backlog; both backlog 10 and the OS default failed at 140 workers.
  This is not an accepted backlog fix.
  The supplied 22 KB attachment contains a pool proposal plus DBAccess ODBC error
  10048, not a successful test log. Large TIME_WAIT counts and two Windows
  Tcpip 4227 events record host port pressure without identifying one process
  or proving the sole cause of HTTP failures.
  The proposal was adapted to `HBBridgeSQLPool`: hash-based logical leases
  carry unique ID, profile, owning thread and native connection. Forged,
  stale, duplicate and foreign-thread returns are rejected; acquisition has
  no retry loop and shutdown refuses active leases. Reconfiguring ODBC policy
  preserves the facade instance. Logical connections retain their per-call
  lifetime and SQLite memory databases remain fresh. An isolated product
  build, **266 lease/configuration checks** and the full **712-check native
  regression** passed with zero failures.
  Physical Driver Manager policy is `off` by default. `driver` is an opt-in
  Windows ODBC 3.8 path; Linux remains `off` until separate acceptance.
  The first MSSQL physical-reuse attempt opened
  13 distinct physical connections for 13 logical leases. Retaining the
  process ODBC environment subsequently demonstrated warm reuse and cleanup
  of settings, temporary tables, transactions and database selection on the
  same physical connection. Final isolated acceptance passed **61 checks/0**
  in each separate `driver` and `off` process. After two cold warm-up leases
  used two physical connections, all 13 measured `driver` leases reused one
  physical TCP connection; `off` used 13. The pooled native eight-worker/
  192-call suite passed **458 checks/0**, including isolation and release.
  Linux, integrated authentication and an optional second-database pooling
  profile were not exercised. The manual summaries do not identify this native
  adaptation or establish it as the cause of their successful load runs.
  A 125-worker success was reported without a fully reviewed log. The complete
  130-worker log is now reviewed: all 130 reports/3640 calls, **15159 checks/
  41 failures**. Thirteen HTTP refusals in step 4 caused 33 worker assertions
  plus eight parent zero-failure checks; the TCP workers passed. No THREAD
  ERROR appears. The refusals occurred within 460 ms, not a test-budget expiry.
  Later supplied summaries for **5/15/20/30/150/500 workers** report all jobs
  collected and **83934 checks, zero failures**; the 500-worker run reports
  **58449/0**. This accepts the exercised paced-load summary scope. Individual
  worker traces, actual elapsed times and binary/pool identity are absent;
  the summaries do not independently prove those properties or resolve cause.
  Launch pacing is now explicit in arguments 10–12/CLI: defaults 300/50/5000 ms
  preserve the supplied ramp and `GetEnvServer()`. Planned sleeps are 431450 ms
  for 130 workers and 481450 ms for 140; `0/0/0` supplies a burst control.
  The budget includes launch and impossible sleep plans are rejected before
  `StartJob`; the all-READY/GO barrier still releases workload together.
  The later summaries contain these explicit pacing fields, recording manual
  execution of that reporting revision. No new compiler receipt is supplied;
  the earlier 32-source compiler result precedes configurable pacing.
  [Native ODBC evidence](docs/acceptance.md#odbc-physical-reuse-on-2026-10-15),
  [historical follow-up](docs/acceptance.md#sql-concurrency-follow-up-on-2026-10-15)
  and [manual paced-load evidence](docs/acceptance.md#manual-protheus-concurrency-on-2026-10-15)
  retain their separate scopes. M08 has subsequent acceptance below; final M09 gates remain pending.
- [x] **M08 — Record a performance baseline.** Completed on 2026-10-16 with
  common read-only `m08.constant.v1`: 1000 rows, pages of 100, two warmup and
  five measured complete traversals, concurrency one. Native direct/TCP/HTTP
  in separate processes under off/driver policies passed 43366 benchmark
  checks, zero failures; measured-phase OS working/private samples exist for
  all six routes. Real AppServer TCP and HTTP passed five measured traversals
  each, 50 calls/5000 rows per route, plus separate warmups, exit 0. External
  client/server memory samples cover the combined AppServer lifecycle and
  retain that scope. All 34 TLPP sources compiled with zero source errors;
  vendor compiler finalization returned 0xC0000409; services restored and real
  execution passed separately. No speed threshold, route ranking, Linux,
  leak or D03 integrity acceptance follows. [Methodology](docs/benchmarking.md)
  and [results/artifacts](docs/acceptance.md#m08-performance-baseline-on-2026-10-16).
  Additional manual summary at 04:53:47 São Paulo passed all five measured
  traversals and two warmups per route, means 1039.60 ms TCP/1122.12 ms HTTP.
  Keep its unmeasured memory and unspecified pool/build/exit scope separate.
  [Manual evidence](docs/acceptance.md#m08-manual-protheus-validation-on-2026-10-16).
- [x] **V01 — Add the requested visual benchmark and verify client lifetime.**
  Completed for the demonstrated Windows/AppServer scope on 2026-10-19.
  Three manual paired JSON/HTML exports record successful form execution;
  controller 61 checks, REST contract 43 checks and Chromium 3 tests/46 checks
  have separate automated evidence. The client lifecycle run passed 6000
  Health calls and 17 checks with independent clients, recovery and Close.
  Compilation recorded 45 source successes; final compiler exit 0xC0000409 is
  retained separately. The old 100000-row/500-iteration HTTP failure at sample
  136 retains its recorded workload/deadline outcome; the later clarification
  reports excessive parameters and an inadequately sized timeout.
  See [acceptance](docs/acceptance.md#v01-v02-benchmark-acceptance-on-2026-10-19).
- [x] **V02 — Compare execution placement.** Completed for the three manual
  visual runs on 2026-10-19: hbBridge TCP/HTTP, Protheus StartJob/REST and the
  server-only HRB all passed. Fixture: 1000 rows, pages of 100, five measured
  traversals and two warmups per route/run, concurrency one. All 75 measured
  and 30 warmup samples passed; export audit passed 684 checks. Keep addon
  server time, whole-RPC time and the additional warmup-inclusive package
  comparison separate. Real REST checks passed 401/401/200/400/200 for absent,
  incorrect and valid credentials, invalid parameters and recovery. Earlier
  isolated StartJob CLI initialization receipts retain their failures; the
  manual TCP/HTTP CLI run 7482F7E8 passed separately (ten rows, one traversal,
  zero warmups). These are distinct from the successful visual comparisons.
  Executed binary/backend/configuration identity is not inferred from exports.
  [Evidence and limits](docs/acceptance.md#v01-v02-benchmark-acceptance-on-2026-10-19).
- [ ] **M09 — Complete regressions and documentation.** Run checks appropriate
  to any changed implementation, compile changed TLPP and obtain AppServer
  acceptance. Run all three commit validators; update EN/PT instructions,
  TODO, ChangeLog and acceptance with sanitized evidence and artifact versions.

### Completion criteria

Close this package only when M01–M09 are checked with attributable evidence:
identified real MSSQL/backend/configuration, successful Harbour/TCP/HTTP calls,
values/pages, failure recovery, resource isolation/release and relevant
regressions. Checkbox completion must distinguish implemented code, local
automated checks and manual AppServer runs. Record concrete limitations and
follow-ups without claiming HTTPS, Linux, other drivers or unsupported types
from this Windows acceptance.
Any change to required scope/criteria must be recorded explicitly before closing.

### Current prerequisites and resume note

Read-only local inventory identified a running default `MSSQLSERVER` instance
listening on TCP 1433. The 64-bit `pData` ODBC DSN names `(local)` and database
`pData`.
Microsoft ODBC Driver 18 for SQL Server is installed, product version
**18.6.2.1**, x64; Driver 17 is also present. The console identity is
`DNA-TECH-01\marin`; service identities remain separate acceptance work.

A private INI was selected for local completion; no ready connection was supplied.
`C:/tmp/hbBridge.ini` initially contained only `sqlite_demo` as an SQL profile.
On 2026-10-08 a commented `MSSQL/pData` template was appended with a private
backup and byte-for-byte preservation of existing settings. It uses the
installed `pData` DSN, explicit `Authentication=sql` and empty `Username`/
`Password` fields for local completion and uncommenting. Its explicit
local `Encrypt=optional` policy follows that development DSN; deployed TLS
settings require their own certificate configuration. No SQL credential was
read from DBAccess, changed in ODBC or stored in the repository.

The profile was enabled and credentials were filled locally during this work.
Its structured configuration validated without displaying values. A read-only
`System.Data.Odbc` probe using those private credentials and SQL authentication
connected to **SQL Server 16.0.1200.5**, database **pData**, on 2026-10-08.
M01 is complete. No credential was changed or copied into the repository.

The dedicated native route compiled. Four controlled missing-argument/config/
profile/wrong-backend cases all returned prerequisite exit 2, without opening
a SQL connection. M02 is complete. The opt-in route is
`scripts/test-hbbridge-mssql.ps1 -Config C:/tmp/hbBridge.ini -Profile MSSQL/pData`;
it builds shared components independently of the installed host and reports
missing prerequisites with exit 2. Its first real native connection returned
`CONNECTION_FAILED`: a comparison probe reproduced Driver Manager `IM002`
for `DSN={pData}` and connected with unbraced `DSN=pData`. That serialization
was corrected while retaining credential escaping. The corrected serializer
connected natively. Native fixtures then exposed SDDODBC's handling of
`SQL_NO_TOTAL` during VARCHAR-to-Unicode conversion and a binary field-flag
error. A checked staged connector patch preserves variable data, empty/null
values and UTF-16 chunks without changing the pinned source checkout.
The connector patch also combines UTF-16 surrogate pairs into valid UTF-8,
including pairs crossing chunks. On 2026-10-08 the native fixture passed
**92 checks, zero failures/no skips**, including long VARCHAR/NVARCHAR/binary,
embedded NUL, null/empty, supplementary Unicode, dates/timestamps, pagination,
failure recovery, caller resource restoration and four isolated worker results.
Evidence: `tmp/mssql-tests-b3d676f0daaf470a97af605a98a9681c/results.log` and
`tmp/mssql-native-normalized-20261008.log`. M03 is complete for this Windows target.
The core baseline read 1000 constant rows in three executions: 31/32/31 ms,
total 94 ms, concurrency 1, including connect/materialize/disconnect; memory
was not measured. At this point M06/M07 had partial evidence. M06 has subsequent native-timeout
and AppServer acceptance on 2026-10-14; M07 broader profile isolation has
subsequent acceptance recorded below.
M08 has subsequent TCP/HTTP and memory acceptance on 2026-10-16, recorded above.
The default regression passed **566 checks, zero failures/no skips**:
`tmp/tests-f84004277a8d4cc2905131f706a1e181/results.log`.

Manual AppServer TCP runs were reported on 2026-10-08, São Paulo time:
`U_HBBridgeQueryTestMSSQL`, 10:06:10, thread 660, profile `MSSQL/pData`, and
`U_HBBridgeQueryTestSQLite`, 10:06:43, thread 3192, profile `sqlite_demo`.
Both reports contain all 29 checks true. Those wrappers were added
to the existing TLPP test; their defaults remain test-only, without changing
the product's optional SQL alias. Evidence:
`tmp/protheus-mssql-sqlite-operator-20261008.log`. M04 is accepted for those
cases; no new compiler log or server artifact hash was supplied.

Manual AppServer HTTP runs were also reported on 2026-10-08, São Paulo time:
`U_HBBridgeHTTPTestMSSQL`, program 10:33:32, thread 25976, body 10:33:33–34,
and `U_HBBridgeHTTPTestSQLite`, program 10:34:06, thread 9916, body 10:34:07.
Both contain all 13 checks true/PASS and Health HTTP 200. The inspected
added wrappers default explicitly to `MSSQL/pData` and `sqlite_demo`,
respectively, and forward to the common HTTP test; library defaults are unchanged.
Evidence: `tmp/protheus-http-mssql-sqlite-operator-20261008.log`.
M05 is accepted for those cases. Reported elapsed 1 s/0 s has whole-second
resolution and does not replace M08 measurements. No compiler log, explicit
call arguments or server artifact hash was supplied. HTTPS, wider native type
transport and Linux remain separate acceptance tasks.

Progress/evidence: P01/P02/F01/F02/D02 and M01–M06 complete for the exercised cases.
M06's 2026-10-14 automated AppServer TCP/HTTP acceptance follows recompilation;
its native failure suite, default regression and repeated 92-check MSSQL route
passed. The repeated database probe reports SQL Server **16.0.1210.3**;
16.0.1200.5 remains the historical 2026-10-08 result.
The earlier normal-host run had seven failures per transport because its INI
lacked both fixture aliases; constant probes confirmed PROFILE_NOT_FOUND.
Subsequent manual execution at 14:30:50 São Paulo, thread 13796, passed all
38 TCP/51 HTTP checks and resolves that failed run within M06's test scope.
Native handshake diagnostics remain recorded without a verified cause or
resolution; neither a precise elapsed time nor a GUI launch route is inferred.
M07's 458 native and 417 AppServer CLI checks remain the historical accepted baseline.
The 2026-10-15 controlled 140-worker retry still failed after independent
collection/drain controls were validated. Connection reuse and port-pressure
analysis and acceptance of the adapted logical/physical connection lifecycle
subsequently completed M07 for the recorded Windows scope. The 130-worker
failures are reviewed; later paced-load summaries through 500 workers are
accepted within their summary scope. M08 time/memory reference completed on
2026-10-16. V01/V02 completed for the recorded scope on 2026-10-19. Resume
D03, then final M09 checks; preserve the SQL mutex and distinguish concurrent
requests from parallel database execution.
D03 integrity remains pending after
explicit reprioritization, with caller CAST retained.
Do not repeat accepted migrations, inventory or native/TCP/HTTP cases without
new evidence requiring it. M09, D03 and the package completion criteria remain.

The 2026-10-12 [SQL connection-reuse observation](docs/sql-connections.md)
was reprioritized into M07 on 2026-10-15. `HBBridgeSQLPool` now owns exclusive
logical leases under the existing lifecycle mutex. Native physical ODBC reuse
passed its Windows MSSQL acceptance, with policy `off` by default and opt-in
`driver`. Keep the accepted physical identity/session-cleanup proof separate
from manual load summaries and from future RPC persistence.

## Following packages: reserved direction

The 2026-10-12 [extension review](docs/extensions-review.md) records SQLRDD,
Duktape and CCHarbour as optional later packages, without adopting dependencies
or resetting this package. Current Protheus consumers are cataloged in the
[example guide](examples/protheus/README.md). Native review regression passed
583 checks with zero failures; remaining native browse/UI acceptance stays pending.
The HTTP table views/71-check mock and dataset/helper 67/12-check runs have
separate acceptance above. UTF-8/FLOAT and encrypted credentials remain pending.

| Order | Direction |
| --- | --- |
| 002 | Typed SQL parameters/metadata and native FWTemporaryTable/FWMBrowse presentation; separately scoped MSSQL materialization/release. |
| 003 | External dependencies through hb_compile, portable credential providers/management, optional OpenBao and HTTPS acceptance. |
| 004 | Negotiated compression/blocks, incremental consumption and real client capacities; RPC persistence/pool after measurements. |
| 005 | Native DBF/NETIO acceptance and a TLPP facade for Harbour VF IO. |
| 006 | Windows/Linux service operation, diagnostics, administration and reproducible packaging. |
| Later | Jobs/batches/progress/cancellation and useful native extensions. |

These are priorities, not completed specifications or tasks in package 001.
The supplied OpenBao RFC was reviewed on 2026-10-07 in
[credentials](docs/credentials.md#optional-openbao-provider-rfc-review-on-2026-10-07).
It remains a future optional provider for stable credentials. Automatic SQL
password rotation and dynamic database plugins are outside the initial package
003 scope. Manual updates remain available when needed; vault token renewal
does not change the SQL password. OpenBao does not block MSSQL package 001.
hbdebug can advance as an explicitly scoped parallel item; HBDAP and optional
Zig HTTP remain later work. Necessary fixes/dependencies for the current
package belong in its recorded scope, rather than silently opening another front.

### Future benchmark and compatibility references recorded on 2026-10-19

- [ ] Add C and Zig addon benchmark scenarios: hbBridge executes SQL and
  passes result JSON to the selected processor, which returns checks/metrics.
  Include a matched Harbour JSON control and separate SQL, serialization,
  parsing/processing, invocation and complete-RPC timings.
- [ ] Prepare PostgreSQL and Protheus 12.1.2610 validation using the supplied
  Docker environment as a reference. Connector/dialect, SDK, encoding and
  deployment acceptance are prerequisites, not delivered support.

[Design, reference environment and acceptance sequence](docs/benchmark-evolution.md).
These future tasks do not change the next action: D03, then final M09 checks.

## Updating and renewing WIP

1. At the start of package work, read AGENTS, this WIP and only the referenced
   context needed for the next task. Resume from recorded progress.
2. Update checkboxes, evidence, prerequisites and next action during the
   package. Intermediate commits/publication do not reset or replace WIP.
3. Reopen a decision when new evidence, a reproducible failure, a changed
   requirement/dependency or an explicit user instruction warrants it. Record
   the reason and impact; a new turn alone is not a reason to repeat analysis.
4. Once completion criteria pass, transfer the closure summary/evidence to
   acceptance and ChangeLog, reconcile TODO and record the closing revision
   when available. Preserve any unfinished item as an explicit follow-up.
5. Renew these same two WIP files for the next bounded package: ID/date,
   objective, reference, decisions, ordered tasks, criteria, prerequisites and
   next action. Git retains previous versions; avoid duplicating the full TODO.

Renewal is per **completed work package**, not per commit, publication or
arbitrary version bump. User instructions can reprioritize the active package;
update its scope/progress transparently instead of discarding unfinished work.
