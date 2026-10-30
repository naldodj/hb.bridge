# Active hbBridge work package

[Português](WIP.pt-BR.md) · [Roadmap](TODO.md) · [Acceptance](docs/acceptance.md)

Resume the next unfinished task in this bounded package. Intermediate commits
and publication do not reset it. Renew this pair only after its completion
criteria pass; record closure in acceptance and ChangeLog.

## Previous package: 001 completed on 2026-10-21

Real MSSQL acceptance completed M01–M09, D01–D03 and V01/V02 for the identified
Windows/AppServer scope. Final native checks: **752 / 92 / 73**, zero failures.
TLPP: **49 sources**, zero errors/exit 0, plus the latest JSON helper compiled
and accepted separately. Final real AppServer: **31 JSON / 80 TCP+HTTP checks**,
zero failures/exit 0. SQL mutex, per-call logical ownership and optional ODBC
physical pooling remain unchanged. No blanket Linux/HTTPS/BLOB JSON support
is inferred. See [closure, exact artifacts and limitations](docs/acceptance.md#package-001-m09-closure-on-2026-10-21).

## Package 002: typed SQL parameters, metadata and native presentation

| Item | Current value |
| --- | --- |
| ID | `002-typed-sql-presentation` |
| Opened / updated | 2026-10-21 / 2026-10-30 |
| Status | T01–T04 validated in their recorded scopes. T05a selected dictionary fields passed isolated checks and confirmed manual visual acceptance. T05b explicit JOIN examples and final package closure remain open. |
| Goal | Define explicit typed SQL values/result metadata and a caller-owned native Protheus presentation adapter using the accepted Query/dataset. |
| Reference | Base `8db2823`; package 001 validated working-tree artifacts are identified in its closure manifest. This is not a new release tag. |
| Next task | T05b: implement explicit SRA/SRB and SRA/CTT JOIN examples using the SX9 review, caller-resolved metadata and deterministic joined-row paging; retain explicit NULL/native-presentation policy. |

### Preparatory maintenance

- [x] 2026-10-30: shorten the root EN/PT READMEs to project purpose, the
  Harbour/C/Zig rationale, current capabilities, first run and guide navigation.
  Keep technical guides versioned under docs; preserve the detailed debugging,
  architecture, planned framing and corporate support material in paired
  guides. Replace the documentation indexes with matching task-oriented
  portals and retarget former README section links. Generate four bilingual
  Wiki navigation files from those indexes through `scripts/prepare-wiki.ps1`,
  with absolute repository targets and deterministic output. The generator
  does not publish or duplicate guide maintenance. This documentation work
  does not reset package 002 or close its pending live presentation acceptance.

- [x] 2026-10-30: implement T05a selected dictionary projections through
  `HBBridgePresentationTable.Project()` and the optional SRA selection. Reuse
  trusted expressions and dictionary CASTs; retain output/source mappings,
  the full inventory and explicit `notSelected` reasons. Require unique
  positions, aliases and origins without adding system columns implicitly.
  Validate business predicates before selection; require the projected record
  identity for deterministic paging. Add the selected SRA TCP/gzip HTTP browse
  entry over the existing search/filter/View path. Build invalid alias fixtures
  by JSONObject assignment instead of invalid TLPP literals or macros, and
  require actual rejection without unconditional passing assertions. Avoid
  adding an absent optional flag to the input snapshot by using HasProperty.
  The final 78-source compile and 730 checks across ten suites passed,
  including 142 SRA planning/selection/native SQLite checks. Retain the
  [sanitized evidence](docs/validation/selected.presentation.windows.json).
  Manual visual acceptance was subsequently confirmed on 2026-10-30;
  [its reported scope](docs/acceptance.md#selected-sra-visual-acceptance-on-2026-10-30)
  remains separate from automated source identities. T05b and T05 closure remain open.

- [x] 2026-10-29: review the supplied SX9Tools and seven FWWebEx utilities.
  Read-only local dictionary inspection found SRA to SRB (`RA_MAT/RB_MAT`,
  1:N) and the incoming CTT to SRA relation (`CTT_CUSTO/RA_CC`, 1:N).
  Record bidirectional metadata, branch/sharing resolution and explicit JOIN
  constraints in the [SX9 analysis](docs/sx9-relationships.md). Record the
  [utility review](docs/fwwebex-tools-review.md): a narrow defensive JSON
  clone is the first reuse candidate, subject to correctness regressions and
  measurement. Reuse the existing clock for optional timing phases; defer
  merge/flatten until a concrete contract exists and avoid generic resource
  cloning. This analysis adds no runtime APIs or new core dependency and does
  not close T05 or change its next interactive acceptance task.

- [x] 2026-10-29: resolve the remaining source-mapping, MsMGet, shared-builder
  and stale SRA-test findings. Source lookup consistently rejects ambiguous
  origins and finds a unique origin despite an unknown homonymous projection.
  Keep dictionary identity in MsMGet `aFields`/`M->`, including `RA_BITMAP`,
  while captions follow the projection. Share pure Build/Plan paths with the
  live examples, reject empty projections and missing filter/order fields,
  and reject invalid browse search options without changing the current order.
  Compile 78 TLPP sources, zero errors; isolated checks passed: schema 76,
  page conversion 31, SRA/SX5 planning 66, local RDDs 100, source mapping 36,
  typed/ordinary datasets 77/67, SDK 5, TOPCONN/FWBulk 122 and browse callbacks
  74. The ordinary dataset returned -4 after all 67 checks and APPLICATION END,
  accepted by the existing runner policy; other suites returned 0. Final
  MsMGet dictionary-variable adjustment compiled separately, zero errors.
  Preserve the separate interactive View scope and
  [sanitized identities/results](docs/validation/presentation.review.windows.json).

- [x] 2026-10-29: document immediate cleanup of copied/generated TLPP in tmp,
  including failure paths, and translation of Portuguese source comments to
  English during reviews/edits. Staged commit validation now removes its
  source snapshot in `finally`; the selection regression removes its fixtures.
  Translation in three reviewed TLPP sources preserved executable code and
  string literals. Selection/cleanup passed 57 checks; actual staged validation
  passed all three tools with an empty staged selection, unchanged index and
  zero remaining temporary TLPP copies. Documentation links passed for 104
  documents. This maintenance does not close T05.

- [x] 2026-10-29: keep `projectionFields` optional in version-1 logical
  schemas. Accept existing two-member schemas and validate supplied maps:
  existing projection keys, nonempty NUL-free source strings; empty/partial
  maps and repeated origins remain valid. Preserve the caller's values and
  metadata during conversion and transfer the builder's map to its schema.
  Focused isolated AppServer validation compiled nine sources with zero errors
  and passed 76 schema/conversion plus 31 page-conversion checks, exit 0.
  This scope does not close the remaining SRA tests, origin-lookup, builder
  validation or interactive presentation work.

- [x] 2026-10-27: add reusable SX3 metadata and the SRA/standalone SX3 examples.
  Record the complete field inventory and explicit native-value exclusions;
  keep dictionary CASTs and branch/table resolution in Protheus. Preserve
  source/projection/native name directions, empty compact dates and SQL NULL.
  Compile 73 TLPP sources, zero errors; isolated AppServer checks passed:
  conversion 54, page conversion 31, SRA planning 49, typed/ordinary datasets
  77/67, SDK 5, native storage 89 and browse callbacks 59. Page conversion
  validates invariant metadata once and retains every value check; column
  positions are resolved before paint. The 100-column/100-row, three-round
  local comparison averaged 8842.354 ms per-row versus 1936.071 ms per-page
  conversion, excluding SQL, transport, native DDL and UI. This precedes the
  requested storage/index revision and is not a complete SRA speedup.
  Default commit checks now select changed/new files; staged snapshots, full
  policy invalidation and all three mandatory tools remain. Git selection
  passed 41 isolated checks without index changes. See the
  [sanitized evidence](docs/validation/sra.presentation.windows.json).

- [x] 2026-10-27, validated 2026-10-29: review the added SQLITE_MEM/SQLITE_TMP storage paths and adopt
  one initial index after population, with additional indexes created on demand
  through the native adapter. Map FWSeek details to projections and actual index
  orders, preserve indexed aliases across refills and release owned resources.
  Retain explicit TOPCONN/FWBulk coverage; validate both local RDDs separately.
  Local RDDs passed 100 checks; TOPCONN/FWBulk passed 122 checks with a
  1025-row bulk write; browse callbacks passed 74 checks. SQLite connection-end
  resource lifetime remains the documented SDK behavior, not a confirmed leak.

- [x] 2026-10-21: review project-owned sources against AGENTS: group declarations by type,
  preserve initializer order and cache proven loop invariants. Correct the
  ignored-token parameter reference and add two helper regression checks.
  Native, real AppServer and repository checks passed; see the separate
  [source-review evidence](docs/acceptance.md#source-conventions-review-on-2026-10-21).
  This maintenance does not implement T01; T01 remains the next task.

- [x] 2026-10-22: add the requested [artifact cleanup script](scripts/README.md#artifact-cleanup)
  with preview/explicit apply, bounded paths and age. Align with fully disposable
  tmp: no retention by docs/manifests/current pointers. Version reusable runners,
  probes and sanitized [historical summaries](docs/validation/README.md).
  Validation: 22 isolated fixtures passed, including absent tmp/out; real-tree
  previews removed nothing. Versioned thread probe: 31 assertions passed.
  Register the minimal TLPP include convention;
  preserve the revised benchmark sources. Keep T01 planned.

- [x] 2026-10-22/23: implement and automatically validate the requested benchmark reliability/control
  maintenance before resuming T01: actual isolated route execution through
  compatible CLI/TLPP/visual selection, selected-only dependencies, explicit
  skipped/failed outcomes and measured-sample statistics. Keep endpoint/profile/
  module/authentication configuration trusted; distinguish client traversals
  from addon internal/RPC timings and Protheus internal/whole-job timings.
  Add opt-in `protheusServer` (one StartJob for all traversals), normalize old
  five-route maps and preserve old five/six-field request payloads. Estimate
  automatic whole-server timeouts from iterations/pages, with editable 900s
  ceiling, explicit manual overrides and report-owned effective policy.
  Compile and verify focused deterministic,
  browser and real AppServer scenarios before recording acceptance. This
  reprioritization does not implement the SQL/presentation contracts of T01.
  See the [benchmark guide](docs/benchmarking.md#route-selection-and-measured-statistics).
  Current evidence: isolated 54-source TLPP compile passed, zero errors/exit 0;
  actual isolated AppServer control/visual/REST/JSON checks passed 82/81/43/31. Real single-job
  MSSQL correctness smoke passed (10 rows, page 5, two measured + one warmup).
  Post-codec native full/addon: 752/93, including precision/ABI and exact
  TCP 254/255/256/500 with SQL mock/no sleeps. Final 54-source TLPP compile
  passed with zero errors/exit 0.
  Chromium core: 3 suites passed, 69 main DOM + 30 server/timeout/layout checks.
  Optional recorded-report preview also passed with page network requests blocked.
  2026-10-23: diagnose the supplied 255-iteration failure and actual TLPP-client
  500-iteration SQL-mock reproduction as addon-ABI JSON mean rounding under
  SET DECIMALS 2, not an iteration limit. All returned sample checks pass;
  only aggregate precision fails. The supplied complete call took 87.9255s
  against a 900s budget. Use existing HBBridgeJSONEncode/Decode at the addon/
  host ABI, retain strict validation and remove the pacing-only 1.5s sleeps.
  Rebuilt host/HRB precision checks and actual TLPP client passed 255 measured
  plus two warmups and 500 plus zero against the real TCP host/HRB with mock
  Query, preserving strict aggregates. Keep Windows fixture scope distinct
  from other platforms and real-backend acceptance.
  Real MSSQL255 also passed: actual TLPP/TCP/HRB, 1000 rows/page100, two
  warmups, strict aggregates, pooling off/no sleeps. A separate automated500
  attempt exhausted the owned launcher's budget and is inconclusive, without
  a passing AppServer result. User-provided FWWebEx1500 evidence follows below;
  it does not identify source/pooling. T01 remains planned.

- [x] 2026-10-23: review the provided five-route FWWebEx1500 JSON/HTML run;
  independent totals/mean/median/P95/population-SD checks match within 1e-9.
  Group Harbour addon and Protheus single-job internal metrics in aligned
  cards, shared charts and one table; move complete requests and benchmark
  duration into a separate totals section. Preserve immutable results,
  authoritative metrics, export safety and client/server scope separation.
  Final compile: 54 TLPP sources/zero errors; AppServer checks 82/81/43/31;
  Chromium 69+30 core observations and recorded-report preview passed.
  Native addon SET matrix: 93 checks across DECIMALS 2/18 × FIXED off/on,
  restoring caller state. Fixture serve mode now applies/prints private
  SQL/ODBCPooling; the historical 255/off run retains its own scope.
  Provided manual 1500-iteration run passed 1500+2 per selected route; compiled
  source/RPO identity and effective pooling are not supplied. Confirm the revised live
  FWWebEx layout after recompiling; do not infer comparative performance or
  all-platform acceptance. Package 002 T01 remains planned.

### Prioritized HTTP maintenance on 2026-10-23

New benchmark reports require a focused hbhttpd review before SQL integration.
The [T01 contract draft](docs/typed-sql.md) records the connector inventory;
it is not an implemented API or a completed T01. Keep the MEMIO idea in
[future work](docs/evolution.md#in-memory-results-between-requests).

- [x] H01: inspect the supplied benchmark reports and native send path; compare
  like workloads and distinguish socket wait budgets from elapsed delays.
- [x] H02: correct response sending and add tested HTTP compression negotiation
  where supported, using the existing managed hbhttpd/shared service core.
  Preserve UTF-8/NUL, partial-send handling, payload ownership and failure semantics.
- [x] H03: validate native HTTP identity/gzip and actual TLPP/FWRest support,
  including errors, large responses and timeouts. Record scope and EN/PT docs;
  do not infer a performance win from compressed size alone.

2026-10-24 evidence: native suite 777/0; send-fault probe 18/0; isolated
AppServer compiled 55 sources/zero errors and passed 14 FWRest/client checks,
exit 0. Actual MSSQL/AppServer encoding comparison alternated identity/gzip
twice, five measured + two warmups each, 10000 rows in one page, pooling off.
All 20 measured and eight warmup traversals passed. Combined means:
identity 1869.279 ms, gzip 910.453 ms. Independent wire check: 582624 versus
107099 bytes, identical decoded SHA-256. This short same-build comparison
measures encoding policy, not the isolated effect of every HTTP change or a
general production speedup. See [HTTP evidence](docs/http.md#http-review-on-2026-10-24)
and the [sanitized manifest](docs/validation/http.response.windows.json).

Final header maintenance caches `CR_LF + CR_LF` once per worker and passes
it to the parser; split Accept-Encoding fields retain all exclusions. Final
native regression/send: 777/18, zero failures. A later 56-source compile and
14 FWRest checks passed, followed by 12 successful direct phase probes.
Gzip expansion averaged 1.511 ms, JSON parsing 43.158 ms, native request
179.851 ms (including server/network). Separate codepage-cache microbenchmarks
preserved bytes and SET behavior but did not prove a stable speedup.

The current AppServer benchmark requires gzip on its HTTP route, independently
of `HTTPAcceptEncoding` in the INI, and records the effective request policy.
An identity fallback fails explicitly. The comparison above used the earlier
optional policy on the same server build, before this benchmark requirement.
Actual MSSQL/AppServer checks confirmed both outcomes despite INI identity:
gzip enabled passed two measured traversals plus one warmup (10000/page10000,
exit 0); compression off produced the expected `HTTP_COMPRESSION_REQUIRED` /
HTTP 406 rejection (exit 1), with no identity fallback.

### Decisions retained

- Keep one implementation and the accepted `RPCRDD.Query`/page/dataset behavior.
  Preserve UTF-8 wire ownership, NUL integrity and native numeric semantics.
- Protheus resolves ERP context, tenant/company/branch, physical tables,
  filters, logical schema and business scale. hbBridge executes explicit inputs.
  Aliases remain opaque; no demo profile is mandatory.
- Bind values and identifiers have different contracts. Validate identifiers
  from trusted caller metadata; SQL literal substitution is not native binding.
  Prove each connector's prepared/bind capability before claiming support.
- Preserve the SQL lifecycle mutex and lease cleanup. Parameter/result typing
  does not imply parallel SQL, persistent cursors or snapshots between pages.
- Caller CAST remains available. Exact large decimal digits can stay textual;
  source metadata, logical definitions and wire representation stay separate.
  Automatic SX3/TOP_FIELD lookups, metadata addons and SQL rewriting remain deferred.
- SQL NULL is a valid result and remains distinct from empty/zero/false in the
  service, transport and dataset. Protheus owns business substitution; only
  an explicit native-presentation conversion can reject an unrepresentable value.
- `GetNonBlobColumns()` keeps long text and excludes binary types. LOB readers
  and versioned binary/streaming transport remain future work; no API is added now.
- Reuse/review `HBBridgeBrowseData` before adding another presentation layer.
  Native arrays remain limited to required SDK/connector boundaries.

### Work in order

- [x] **T01 — Define the bounded contracts.** Inventory current APIs and
  identify already implemented presentation behavior. Specify typed bind
  values, NULL/empty distinctions, native/source versus caller logical schema,
  scale/range rules, compatibility/versioning and unsupported capabilities.
- [x] **T02 — Prove connector bindings.** Validate real MSSQL/SQLite prepared
  parameters with text/UTF-8/NUL, numeric/date, empty/NULL, errors and recovery.
  Unsupported types/capabilities return explicit errors. Add no unproved
  emulated binding or silent conversion.
- [x] **T03 — Integrate the accepted parameter/metadata contract.** Extend the
  common service and TLPP clients/dataset, preserving existing SQL/page calls,
  caller profile and defensive metadata snapshots. Test conversion/range errors.
- [x] **T04 — Complete native Protheus presentation.** Adapt the existing browse
  path to caller-resolved schema and owned FWTemporaryTable/native UI resources.
  Define text decode-once, NULL/type/scale policies, page traversal and cleanup
  after success, failure and UI close. Preserve existing examples and ownership.
- [x] **T05a — Demonstrate selected dictionary fields.** Add an explicit
  projection example with caller-selected columns, aliases and per-output
  logical schema/source mappings. The Project API and selected SRA example are
  implemented and passed isolated planning/native-storage checks. Manual visual
  validation was confirmed on 2026-10-30; no per-transport logs or compiled
  identities were supplied for that run. Preserve that scope separately from
  the automated fixture; see the [selection guide](docs/sx3-metadata.md#selected-fields-and-join-queries).
- [ ] **T05b — Demonstrate explicit JOIN results.** Add INNER/LEFT JOIN examples
  with unique output aliases, caller-resolved metadata and business predicates,
  deterministic paging at the joined-row granularity and explicit NULL/native
  presentation policy. Validate duplicate origins through projected access;
  preserve dictionary-specific MsMGet identity without conflating repeated fields.
  Use the [SX9 review](docs/sx9-relationships.md) as relationship input:
  include incoming and outgoing candidates, resolve sharing in Protheus and
  keep right-side deletion predicates in ON for LEFT JOIN. A read-only SX9
  snapshot remains proposed; arbitrary dictionary expressions are not SQL.
  These requested examples are planned; generic SQL execution does not establish
  their native UI acceptance. See the [projection/JOIN plan](docs/sx3-metadata.md#selected-fields-and-join-queries).
- [ ] **T05 — Validate and close.** Run appropriate native and real AppServer
  TCP/HTTP/presentation checks, failure recovery and resource release. Run the
  three commit gates; update EN/PT docs and attributable artifacts.

### Completion criteria and prerequisites

T04 continuation on 2026-10-25 adds `HBBridgePresentationSchema` and
`HBBridgeNativeTable`. The native browse is now a local static function in
the interactive example; a generic public native browse API is deferred.
The existing `HBBridgeBrowseData.Browse` API remains available.
The adapter converts an owned current-page snapshot,
checks actual native definitions/readback and never fetches another page or
closes the borrowed dataset/client. NULL is rejected only at this explicit
native destination. Caller schema, generated field names, UTF-8 conversion,
numeric roundtrip, empty/failing pages and ownership are covered by maintained
AppServer tests. SDK observation separates numeric formatting from stored
native values; no SET override or DEC_CREATE substitution is introduced.
`FWGetTopInfo()` and explicit caught-object release are now source conventions.
Final isolated AppServer compilation passed all 64 sources, zero errors/exit 0.
Conversion passed 32 checks, actual FWTemporaryTable storage/ownership 34,
typed dataset regression 77 and ordinary dataset regression 67, zero failures.
The SDK probe passed five assertions and records formatting separately from
native numeric equality. All 64 compiled source hashes still match the tree.
See the [guide](docs/native-presentation.md) and
[sanitized manifest](docs/validation/native.presentation.windows.json).
`U_HBBridgeNativeBrowse()` is compiled for manual visual validation; interactive
native browse activation/dismissal and combined backend execution remain in T05.
The captured-error convention was verified in all 42 `catch xError` blocks,
including older benchmark/lifecycle handlers. All three repository validators
passed for 313 files; links passed for 102 documents, without tmp/out dependencies.

T05 visual feedback on 2026-10-25 confirms the first native example opened,
but rejects the close-to-next-page prompt and reports Flag/Day/Float column
misalignment. That observation does not accept paging, seek, filtering or
close behavior. Revise the local example to keep those actions in one window,
preserve caller ownership and use FWBulk for native inserts when supported.
Recompile/retest the revised sources and record fresh identities separately
from the earlier T04 manifest; manual visual acceptance is still required.

2026-10-26 revision: keep `BrowseNative` local to the example and the existing
public `Browse` unchanged. Navigation/search/filters stay in one open dialog;
page refill retains its physical table, alias, workarea and indexes. Use
FWBulk when supported, with optional full storage verification. Keep Flag as
logical data and index a private text shadow through `SearchFieldName()` /
`IndexOrder()`; Day/Float retain independent bindings.

The synthetic interactive fixture accepts `U_HBBridgeNativeBrowse(10000,100)`
and defaults to 1000 rows, 13 per page. The table load accepts
`U_HBBridgePresentationTableTest(10000)` or CLI `--native-rows=10000`, default
1025. Neither reads ERP data. Seven visible projections include zero-padded
`ID_CODE` C(10) for native character ordering, preserving the exact-text `ID`.
Review corrected `Result()` repeating code 42 and added row-code checks plus
index order from 9 to 10. Search/filter applies across the source before paging;
this does not implement or test SQL rewriting.

Supplied manual AppServer output on 2026-10-26 passed 50 browse checks and
56 native table checks, with 1025 bulk-written rows crossing the 1024-row buffer and
seven valid indexes. Those logs do not identify executable/RPO hashes and the
headless browse checks do not establish interactive acceptance. Keep this
observation separate from the subsequent isolated rerun and historical T04.

The subsequent isolated run compiled 66 sources/zero errors and passed
59 browse, 62 native-table, 32 conversion, five SDK, 77 typed and 67 ordinary
dataset checks with zero assertion failures. The main storage fixture used
10,000 bulk-written rows with independent full readback, including matching
ID_CODE/ID; all compiled source hashes remained unchanged. See the
[revision manifest](docs/validation/native.presentation.revision.windows.json)
for identities/exit codes. Interactive widget behavior and combined actual
AppServer-to-hbBridge typed backend acceptance remain open in T05.
All three commit validators passed for 316 files; links passed for 102
documents, with no tmp/out dependencies or index changes.

2026-10-26 real SELECT continuation after `6945aa5`: add
`U_HBBridgeNativeBrowseSX5(cProfile,cTransport,nPageSize)`, default TCP, 100 per page,
over the same local dialog. Protheus resolves RetSQLName/xFilial/TamSX3 and
the five-column schema, immutable branch/deleted bindings and RECNO tie-breaker.
An example-owned SQL source supplies SQL/bindings/order and parameterized
typed criteria; filter fields come from the current schema. No automatic ERP
resolution moves into hbBridge and no generic public BrowseNative is promoted.

Fresh isolated MSSQL hosting plus actual TCP/gzip HTTP/AppServer/native storage
passed **83 real integration checks**. A SELECT over five constant VALUES rows
exercises seven projections, independent native value checks, paging/totals,
Unicode input/output, exact decimal metadata, bound numeric/logical/date/text
filters, literal quote/wildcard input, failures/recovery and cleanup. This
executes real SQL without reading/updating ERP tables. TLPP inputs retain the
caller encoding; clients encode the complete JSON once. Results stay UTF-8
until explicit presentation conversion. The new Unicode search assertion
prevents double encoding of individual input bindings.

The final isolated run compiled **69 sources**, zero errors, and retained
32/77/67/5/62/59 conversion/dataset/SDK/native table/browse checks with zero
assertion failures, plus the 83 real checks. All compiled hashes matched after
execution. Native backend/transport regression passed **133 checks**; the
owned serving fixture stopped both listeners with no active leases. See the
[real SQL presentation manifest](docs/validation/native.presentation.sql.windows.json).
The automated SELECT and interactive SX5 query have distinct acceptance:
the latter still needs manual visual execution in the prepared Protheus
environment. Existing deployment INI/RPOs and services were not replaced.
All three validators passed for 320 files and links for 102 documents; the
index was not changed during this continuation.

2026-10-26 subsequent visual acceptance: supplied screenshots confirm the
real SX5 browse displayed over TCP/HTTP and its current-record View displayed
successfully. This manual observation supplies no compiled hashes and does
not independently establish every filter/failure/cleanup path.

The requested next example expands T05 to SRA and a reusable
`HBBridge.Protheus.HBBridgeSX3Metadata:Read()` snapshot. Protheus retains
dictionary/table/branch resolution. Combine FWSX3Util metadata and the physical
MSSQL catalog to select every supported physical dictionary field and available
system field; report explicit reasons for virtual, memo/binary, long-text,
missing and unsupported fields rather than silently truncating them. Keep the
full metadata inventory even when values are excluded. Numeric CASTs are
explicit caller-side example definitions, not a general SQL parser or automatic
server-side SX3 processing. LOB transport remains future work. See the
[SX3/SRA guide](docs/sx3-metadata.md). This extension requires its own compile,
regressions and interactive acceptance before closing T05; prior source hashes
and counts remain historical evidence.

2026-10-24 continuation after published HTTP commit `98054b45`: the
[T01 specification](docs/typed-sql.md) fixes request/result versions,
column-stable wire types, source/RDD/logical metadata, NULL/empty behavior,
reserved failures and presentation ownership. Both language versions contain
three syntactically validated JSON examples. This T01 observation is historical;
T03 implementation follows below.
The standalone `scripts/test-harbour-sqlite-bind.ps1` passed 252 checks/zero
failures on Windows x64, SQLite 3.53.4. Explicit-length UTF-8/NUL, NULL,
marker discovery, declared/empty/all-NULL metadata, reset/recovery and exact
canonical signed int64 endpoints were proved. Exact fixed DECIMAL remains
unsupported; native NUMERIC affinity demonstrably loses digits or scale.
`scripts/test-harbour-mssql-bind.ps1` passed 75 checks/zero failures against
SQL Server 16.00.1210, ODBC 18.07.0001: Unicode/NUL, NULL by type, safe integer
and int64 bounds, DECIMAL(38,8), native DATE/BIT/FLOAT, declared nullable columns,
empty/all-NULL metadata, independent page/count bindings, class-specific
errors/recovery and statement/connection cleanup. This is a session-local
temporary table proof, not service/AppServer acceptance.
Record raw FLOAT precision 53/radix 2 and native zero decimal `.00000000`;
version 2 adds precisionRadix and requires exact lexical zero normalization.
The [selected connector design](docs/typed-sql-connectors.md) extends tagged
internal RDDI_EXECUTE hashes on existing SDD-owned connections, with no raw
handle export, second login or ABI change. Its shared-hash/dispatch behavior
was proved during T03. See the
[sanitized native evidence](docs/validation/sql.bind.windows.json).
T02 is complete in this standalone Windows scope; T04/T05 remain pending.
These continuation changes are not part of the published HTTP commit.

2026-10-25 T03: `RPCRDD.QueryTyped` shares the accepted Query page plan, SQL
mutex, lease, totals and cleanup; tagged native SDD readers retain NULL and
column-stable exact values without an extra connection or raw handle export.
The integration passed 133 Windows checks, zero failures, against real SQLite
and MSSQL, including TCP/gzip HTTP/REST. Strict versioned TLPP methods preserve
binding/metadata snapshots with no unbound fallback. An isolated AppServer
compiled 57 sources with zero errors and passed 77 typed mock checks plus
67 legacy checks, including stricter composed-key validation. Full native
regression passed 777 checks, zero failures. The legacy 67-check manual result supplied
on 2026-10-25 confirms navigation but does not identify a new RPO.
The [integration manifest](docs/validation/typed.sql.windows.json) records final
identities and counts. These checks do not close T04 or infer real
AppServer-to-backend typed/presentation acceptance; that remains in T05.
All three commit checks passed without index changes; 98 documentation files
passed link validation. No commit or publication is included in this continuation.

Each implemented capability requires native connector evidence and real
AppServer acceptance in its recorded scope. Compile changed TLPP, keep old
Query/page compatibility, preserve typed values and release all owned resources.
Capture source/binary/RPO/configuration identities without secrets. Unsupported
capabilities remain explicit. Do not accept a mock alone as a backend/UI test.

Use managed dependencies, a private explicit SQL profile and the licensed
AppServer SDK/runtime. Prefer isolated builds/RPOs; do not overwrite running
artifacts. Read the [dataset contract](docs/dataset.md), [native presentation
review](docs/evolution.md) and [SQL contract](docs/milestone3-sql.md) for T01.

### Following work kept separate

MSSQL server-side `RPCRDD.Materialize`/Release needs its own design/acceptance;
it is not implied by a client-owned temporary table. Later packages retain
explicit immutable MEMIO result reuse with authorized handles, freshness,
memory/expiry and reader ownership; see [the feasibility review](docs/evolution.md#in-memory-results-between-requests).
They also retain
portable encrypted credentials/OpenBao/TLS, negotiated blocks/streams and LOB
readers, DBF/NETIO/VF, services/Linux/administration and debugging integration.
C/Zig addon benchmark processors and PostgreSQL/Protheus 12.1.2610 remain
[recorded future work](docs/benchmark-evolution.md). The complete roadmap is
in TODO. Do not start these fronts while T01–T05 remain unfinished without an
explicit reprioritization or necessary dependency/fix.
