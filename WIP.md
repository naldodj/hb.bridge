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
| Opened / updated | 2026-10-21 / 2026-10-24 |
| Status | T01 inventory/draft in progress; prioritized HTTP maintenance accepted in its Windows scope on 2026-10-24. |
| Goal | Define explicit typed SQL values/result metadata and a caller-owned native Protheus presentation adapter using the accepted Query/dataset. |
| Reference | Base `8db2823`; package 001 validated working-tree artifacts are identified in its closure manifest. This is not a new release tag. |
| Next task | Resume T01 draft review/remaining contract decisions; then T02 native binding proof. |

### Preparatory maintenance

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
- `GetNonBlobColumns()` keeps long text and excludes binary types. LOB readers
  and versioned binary/streaming transport remain future work; no API is added now.
- Reuse/review `HBBridgeBrowseData` before adding another presentation layer.
  Native arrays remain limited to required SDK/connector boundaries.

### Work in order

- [ ] **T01 — Define the bounded contracts.** Inventory current APIs and
  identify already implemented presentation behavior. Specify typed bind
  values, NULL/empty distinctions, native/source versus caller logical schema,
  scale/range rules, compatibility/versioning and unsupported capabilities.
- [ ] **T02 — Prove connector bindings.** Validate real MSSQL/SQLite prepared
  parameters with text/UTF-8/NUL, numeric/date, empty/NULL, errors and recovery.
  Unsupported types/capabilities return explicit errors. Add no unproved
  emulated binding or silent conversion.
- [ ] **T03 — Integrate the accepted parameter/metadata contract.** Extend the
  common service and TLPP clients/dataset, preserving existing SQL/page calls,
  caller profile and defensive metadata snapshots. Test conversion/range errors.
- [ ] **T04 — Complete native Protheus presentation.** Adapt the existing browse
  path to caller-resolved schema and owned FWTemporaryTable/FWMBrowse resources.
  Define text decode-once, NULL/type/scale policies, page traversal and cleanup
  after success, failure and UI close. Preserve existing examples and ownership.
- [ ] **T05 — Validate and close.** Run appropriate native and real AppServer
  TCP/HTTP/presentation checks, failure recovery and resource release. Run the
  three commit gates; update EN/PT docs and attributable artifacts.

### Completion criteria and prerequisites

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
