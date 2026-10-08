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
| Opened / updated | 2026-10-07 |
| Status | MSSQL planned; the explicitly authorized .hb preparatory migration is complete. No MSSQL run recorded yet. |
| Goal | Accept the existing RPCRDD.Query/dataset against an identified real MSSQL database through Harbour, Protheus TCP and Protheus HTTP. |
| Product reference | Published code `50e1c65`; checkout at package opening `bce52d2` includes the clone badge update. |
| Next task | M01: record the target profile, ODBC environment and authentication method without storing secrets here. |

### Decisions already made

- Keep the single implementation and existing Query/page contract. Use
  SQLMIX/RDDSQL with SDDODBC; correct defects revealed by this acceptance.
- Protheus resolves tenant/company/branch/xFilial, table names and business
  rules. hbBridge executes explicit SQL/parameters. Begin with constant SELECTs
  and an isolated read fixture; leave production ERP tables unchanged.
- Profiles remain opaque aliases selected explicitly per call. `mssql/pData`
  is an example, not a mandatory profile or business-context resolver.
- Use the currently supported private ODBC connection string or integrated
  authentication. Portable encrypted credentials/CLI remain a later package;
  their implementation is not a prerequisite for this acceptance.
- The owner clarified on 2026-10-07 that SQL credentials are stable; automatic
  database password rotation is outside the selected scope. OpenBao KV storage
  needs no dynamic MSSQL plugin. Vault token renewal is a separate lifecycle.
- Preserve the shared SQL lifecycle mutex. Verify isolation/cleanup under
  concurrent calls; this package does not promise parallel SQL execution.
- Keep existing runtime capacities and configurable policies. Add no fixed
  proof-of-concept payload ceiling or new transport implementation.

### Verified starting point

- Harbour suite: **487 checks, zero failures, no skips**, repeated 2026-10-07.
- Operator SQLite acceptance: **29 dataset/page checks**, repeated 2026-10-07,
  thread 27136, profile `sqlite_demo`.
- Revised client configuration: **16 checks**, 2026-10-07, thread 30596.
- Operator TCP: clock, Health, ADDON and both exact 200000-byte Echo calls
  passed, 2026-10-07, thread 27084.
- Operator TLPP HTTP acceptance: **13 checks**, repeated 2026-10-07,
  threads 27296 and 25456 after the reported recompilation.
  Its SQL profile/backend was not supplied; it does not certify MSSQL.
- Native THREAD STATIC probe: **31 assertions**; worker state differs from
  request state. The shared SQL mutex remains intentional.
- See [acceptance](docs/acceptance.md) for logs, exact scope and runtime details.

### Explicit preparatory change: Harbour source extension

On 2026-10-07 the owner authorized adopting native `.hb` for all project-owned
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
The operator reported recompilation and subsequently supplied passing TCP,
SQLite, revised configuration and HTTP runs. Evidence:
`tmp/protheus-http-hb-operator-20261007.log` and
`tmp/protheus-suite-hb-operator-20261007.log`; see [acceptance](docs/acceptance.md).
The preparatory TLPP regression is accepted for the exercised cases. Resume M01;
do not redo the completed extension migration or infer MSSQL acceptance.

### Work in order

- [ ] **M01 — Identify the target.** Record the actual SQL alias, database,
  endpoint, MSSQL version, ODBC driver/version/architecture, authentication
  method and hbBridge process identity. Verify access to a private config.
  Keep passwords, tokens and complete credential-bearing strings outside Git/WIP.
- [ ] **M02 — Prepare reproducible acceptance.** Use the existing
  [SQL launcher](examples/sql/README.md) and private INI/JSON. Establish a
  dedicated opt-in real-MSSQL test route, separate from the default SQLite
  suite. A missing required connector/config is a prerequisite failure,
  never a successful MSSQL test. Identify the backend in the recorded result.
- [ ] **M03 — Accept Harbour SQL.** Run constant SELECTs and a reproducible
  fixture for named columns, supported numeric/decimal values, nulls, dates
  and accented/Unicode text. Define expected representations before assertions;
  record runtime/type restrictions rather than silently converting values.
- [ ] **M04 — Accept Protheus TCP.** Run the existing
  [U_HBBridgeQueryTest](src/tlpp/tests/protheus/hbbridgequerytest.tlpp) against
  the explicit MSSQL alias, including all 29 checks. Add necessary backend
  cases to the shared product/tests without a second query implementation.
- [ ] **M05 — Accept Protheus HTTP.** Run
  [U_HBBridgeHTTPTest](src/tlpp/tests/protheus/hbbridgehttptest.tlpp) with the
  same explicit MSSQL alias and the common dataset. Check the actual selected
  profile/backend, values and pages; a generic HTTP success alone is insufficient.
- [ ] **M06 — Verify failures and recovery.** Invalid SQL, unknown profile,
  controlled unavailable connection, applicable native timeout, sanitized
  errors and a successful subsequent query. Document any noninterruptible
  driver call; do not equate client timeout/disconnect with server cancellation.
- [ ] **M07 — Verify concurrency and release.** Interleave queries/profiles
  and verify workarea/connection restoration, no result leakage and cleanup
  after success/failure. Preserve the current synchronization contract.
- [ ] **M08 — Record a performance baseline.** Identify SQL, fixture/volume,
  execution count and concurrency; record elapsed time and available memory
  measurements separately for Harbour, TCP and HTTP. This is a reference,
  not a speed guarantee or a new performance threshold.
- [ ] **M09 — Complete regressions and documentation.** Run checks appropriate
  to any changed implementation, compile changed TLPP and obtain AppServer
  acceptance. Run all three commit validators; update EN/PT instructions,
  TODO, ChangeLog and acceptance with sanitized evidence and artifact versions.

### Completion criteria

Close this package only when M01–M09 are checked with attributable evidence:
identified real MSSQL/backend/configuration, successful Harbour/TCP/HTTP calls,
values/pages, failure recovery, resource isolation/release and relevant
regressions. Checkbox completion must distinguish implemented code, agent runs
and operator runs. Record concrete limitations and follow-ups without claiming
HTTPS, Linux, other drivers or unsupported types from this Windows acceptance.
Any change to required scope/criteria must be recorded explicitly before closing.

### Current prerequisites and resume note

Target-specific endpoint/database/ODBC/authentication/private configuration
have not been confirmed for this package. This is a pending prerequisite,
not evidence of a failed connection. The reported Protheus environment uses
MSSQL, but its DBAccess configuration is not an hbBridge connection profile.
While environment details are pending, prepare independent acceptance tasks.

Progress/evidence: P01/P02 complete; MSSQL tasks remain pending. Next action is
M01. Record subsequent progress/evidence here in both languages; do not restart
M01 once its information is recorded and valid.

## Following packages: reserved direction

| Order | Direction |
| --- | --- |
| 002 | Typed SQL parameters/metadata and native FWTemporaryTable/FWMBrowse presentation; separately scoped MSSQL materialization/release. |
| 003 | External dependencies through hb_compile, portable credential providers/management, optional OpenBao and HTTPS acceptance. |
| 004 | Negotiated compression/blocks, incremental consumption and real client capacities; persistence/pool after measurements. |
| 005 | Native DBF/NETIO acceptance and a TLPP facade for Harbour VF IO. |
| 006 | Windows/Linux service operation, diagnostics, administration and reproducible packaging. |
| Later | Jobs/batches/progress/cancellation and useful native extensions. |

These are priorities, not completed specifications or tasks in package 001.
The operator's OpenBao RFC was reviewed on 2026-10-07 in
[credentials](docs/credentials.md#optional-openbao-provider-rfc-review-on-2026-10-07).
It remains a future optional provider for stable credentials. Automatic SQL
password rotation and dynamic database plugins are outside the initial package
003 scope. Manual updates remain available when needed; vault token renewal
does not change the SQL password. OpenBao does not block MSSQL package 001.
hbdebug can advance as an explicitly scoped parallel item; HBDAP and optional
Zig HTTP remain later work. Necessary fixes/dependencies for the current
package belong in its recorded scope, rather than silently opening another front.

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
