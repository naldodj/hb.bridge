# hbBridge package 003: delivered scope and deferred work

This package is archived in its delivered scope. The standalone monthly-report visual validation and historical reconciliation remain open and are deferred in the roadmap. Real SRE transfers were not available. See the [active work package](../../WIP.md).

[Português](package-003.pt-BR.md) · [Roadmap](../../TODO.md) · [Acceptance](../../docs/acceptance.md)

## Package 003: application addon and turnover drill-down

The examples are built together as one [addon bundle](../../docs/addon-bundle.md);
independent addons remain compatible. The bundle uses a per-call registry of
approved HRB-local symbols and `hb_ExecFromArray()` for dispatch.

- [x] Validate a controlled monthly SQLite fixture and addon aggregation using
  typed SQL, inherited permissions and explicit failure handling: native
  integration passed 826 checks, including 29 turnover checks. The bundle also
  passed 94 benchmark-addon checks.
- [x] Validate the controlled MSSQL fixture through direct TCP/HTTP and the
  Protheus clients in an isolated AppServer: three constant rows passed on
  both transports. See the [sanitized evidence](../../docs/validation/turnover.fixture.windows.json).
- [x] Visually validate the new grids and navigation through period, company,
  branch, cost center, job and employee, including Back, on TCP and HTTP.
  The source passed direct MSSQL and isolated AppServer UTF-8 checks.
  See the [sanitized evidence](../../docs/validation/turnover.fixture.windows.json).
- [x] Visually validate the updated three-month dashboard simulation and its
  drill-down and Back over TCP and HTTP. Validation confirmed for periods
  202609, 202610 and 202611; see [sanitized evidence](../../docs/validation/turnover.fixture.windows.json).
- [ ] Build a new turnover example using the supplied queries as data sources,
  adapting their execution and output to hbBridge. Define and validate its
  measures and drill-down without requiring an identical legacy implementation.
  The [source analysis](../../docs/turnover-reconciliation.md) records the registered
  SQL, JSON mappings and dashboard behavior as references.
  Native integration on 2026-11-05 passed 834 checks, including eight new
  checks for the isolated date fixture.
- [x] Add the optional `turnoverReport` example action for already-aggregated
  company-month results. Native integration passed 843 checks. An isolated
  Windows/MSSQL test executed the registered company query into an owned global
  temporary table, compared all measures in ten monthly addon results with the
  source and confirmed table release. The historical 202301–202310 interval
  also passed the same comparison. See the [example](../../examples/turnover/README.md).
- [ ] Visually validate the separate caller-supplied monthly report over TCP
  and HTTP with a Protheus-owned populated temporary table. With only the monthly
  SELECT supplied, the view has no branch details;
  deeper drill-down requires the ready-to-run GEP entry.
  The updated TLPP source compiled in an isolated AppServer; its report markup
  and JavaScript checks passed, including preservation of decimal text.
- [x] Observe the ready-to-run GEP company example in a prepared Protheus
  session over TCP and HTTP. It obtains the latest SRD period by default,
  resolves the registered ZZ/ZX query and owns the result temporary table.
  Its SQL planning passed ten controlled AppServer checks and a separate
  AppServer check against the registered SQL. The latest non-deleted SRD period
  in the development database was 202310. An isolated `RPCSetEnv` attempt
  could not prepare the company environment. Prepared-session reports displayed
  monthly measures for 202302 over TCP and 202303 over HTTP. These observations
  do not validate detailed drill-down or reconciliation of business measures.
- [x] Probe the original Protheus REST with real company and employee models:
  seven sanitized checks passed, including company pagination and employee
  fields. This validates the original service, not hbBridge integration.
  See the [diagnostic](../../docs/turnover-addon.md#original-protheus-rest-diagnostic).
- [x] Observe the controlled TCP and HTTP FWWebEx pages at the job level: the
  supplied screenshots show the metrics, bars and two employee buttons.
  See the [sanitized evidence](../../docs/validation/turnover.fixture.windows.json).
- [x] Validate employee `001` selection on both visual entries: HTTP screenshot
  and confirmation of the same TCP test, with metrics and drill-down end.
- [x] Validate Back on both visual entries, as confirmed separately.
  This controlled fixture does not establish real-data acceptance.
  Do not expose personal details in evidence.
- [x] Validate the JOIN CLI entry in a prepared Protheus environment: 24 checks
  passed over TCP and 24 over HTTP, with 60 rows and two pages per JOIN.
  `RPCSetEnv` previously failed in the isolated environment.
  See the [sanitized evidence](../../docs/validation/join.cli.windows.json).
- [x] Evaluate caller-owned temporary-table output through `RPCRDD.Execute`;
  compare approaches and record their limits and evidence in the
  [reconciliation review](../../docs/turnover-reconciliation.md#result-delivery-options).
  Addon-written turnover output and performance comparisons remain future work.

The addon can own business rules; the core remains generic. The initial contract,
formula and pending limitations are in [the example](../../docs/turnover-addon.md).

- [x] Validate the real branch drill-down visually over TCP and HTTP in the
  prepared Protheus session. In this environment `FWAllFilial()` returned the
  branches; passing `cEmpAnt` returned an empty array. The
  company and branch registered batches populate separate caller-owned tables;
  branch scope is the current company, resolved by Protheus framework functions.
  An isolated MSSQL diagnostic compared all measures for ten company months and
  twenty branch rows across two explicit branches with their
  respective sources.
- [x] Validate the real cost-center drill-down visually over TCP and HTTP in
  the prepared Protheus session.
  A request uses the selected period and company branch, executes the registered
  cost-center batch on demand and releases the Protheus-owned temporary table.
  An isolated MSSQL diagnostic matched 53 rows to their source. The page test
  verifies navigation, selection isolation and no automatic retry.
- [x] Validate the real job drill-down visually and Back over TCP and HTTP in
  the prepared Protheus session. It executes
  the registered job model on demand with the selected period, branch and cost
  center. An isolated MSSQL diagnostic matched four job rows to their source;
  the page rejects responses for a different cost center.
- [x] Validate the real employee drill-down and Back visually over TCP and HTTP
  in the prepared Protheus session.
  The registered employee model runs for the selected period, branch, cost
  center and job. A sanitized isolated MSSQL diagnostic matched one employee
  row and its current SRA attributes to the source.
- [x] Validate the SRE evidence presentation over TCP and HTTP with the
  development data. The available SRE990 table was empty; the validation does
  not demonstrate presentation of an actual transfer.
Visual acceptance of matching real SRE transfer events is deferred to the
[roadmap](../../TODO.md#native-presentation-and-shared-query-results); it is not a
completion criterion for this package. A synthetic MSSQL fixture passed both
match directions, identity and period isolation, and mixed collations. The
development SRE990 table was empty, so real-event presentation has not been
validated. The query preserves source P/D fields and may omit historical events;
counts remain the registered model's values. Historical rule reconciliation
and event completeness remain future work.

## Package 002 completed on 2026-11-03

Typed SQL, caller-owned native presentation, selected fields and explicit
SRA/SRB and SRA/CTT JOIN examples passed in the documented Windows/MSSQL scope.
Native integration: **789 checks, zero failures**. Isolated AppServer: **83 TLPP
sources**, **767 checks**, plus the SDK probe. The ordinary dataset exited -4
following 67 passing checks, as accepted by the runner. The real JOIN diagnostic
passed **24 checks per transport**; browse, search and Views were reported OK
on TCP and HTTP.

The tested ERP pages contained no unmatched row. A separate synthetic MSSQL
LEFT JOIN preserved an unmatched NULL over TCP. Other sharing configurations,
unmatched ERP rows and platforms remain outside the recorded acceptance.
Source identities and test scopes are in the [sanitized manifest](../../docs/validation/join.presentation.windows.json);
the [package 002 work history](../../docs/validation/package-002.md) preserves decisions
and earlier evidence. [Acceptance](../../docs/acceptance.md#join-browse-validation-on-2026-11-03)
and [ChangeLog](../../ChangeLog.txt) record closure.
