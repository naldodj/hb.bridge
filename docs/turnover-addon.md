# Turnover addon example

[Português](turnover-addon.pt-BR.md) · [Work package](../WIP.md)

This experimental addon illustrates application-specific business logic executed
by the generic `ADDON.Execute` service. The calling application supplies an
opaque SQL profile, a trusted SELECT statement and typed bindings; it resolves
company, branch, physical names, authorization and the source data. Only install
trusted addons and expose SQL access to authorized callers. Query execution uses
`RPCRDD.QueryTyped` with the caller's permissions.

The first fixture supplies one row per employee, month and assignment with the
columns `PERIOD`, `COMPANY`, `BRANCH`, `COST_CENTER`, `JOB`, `EMPLOYEE`,
`ACTIVE`, `ADMISSION` and `DISMISSAL`. Period (`YYYYMM`), company and employee
are nonempty text. Branch, cost center and job may be empty for shared or
unassigned values. The last three fields are integers restricted to 0 or 1,
with ACTIVE equal to 1. A repeated employee in the same complete hierarchy is
rejected. NULL and malformed dimensions or indicators fail without substitution.

Optionally, `DETAILS_JSON` is a text column containing an object with
`employeeName`, `admissionDate`, `dismissalDate` and `transfers`. Dates use
`YYYY-MM-DD` or `null`; `transfers` is `null` when the source does not supply
movement evidence, or an object of keyed events. Each event has `date`,
`direction` (`in` or `out`), `fromBranch`, `toBranch`, `fromCostCenter` and
`toCostCenter`. An empty object states that the supplied coverage contains no
events. Invalid details fail without partial results.

The grid shows source admission and dismissal indicators alongside their dates.
Transfer events are counted by event month and aggregated at each level; if any
employee in a group lacks movement history, its total is shown as not supplied.
Transfers are reported separately and **do not enter the experimental formula**
below. Dates, events and indicators come from the source; no automatic
reconciliation or inference of Protheus rules is performed.
For each node, `initial = active - admissions`; turnover is
`round((admissions + dismissals) * 50 / initial, 2)` and dismissal percentage is
`round(dismissals * 50 / initial, 2)`. Both are zero when initial is zero. The
result is a keyed JSON tree ordered by levels period, company, branch, cost
center, job and employee. Counters across periods count employee-months, not
distinct employees. This formula is a bounded example: historical transfers,
multiple assignments, employee eligibility, period interpretation and exact
parity with the existing Protheus reports remain to be specified and validated.
It must not be used as a validated payroll or HR report.

The query and full result are materialized in memory; there is no streaming or
transaction snapshot across calls. Error results do not contain partial totals.
The controlled FWWebEx page includes a bar chart, a grid at each level and
employee date and movement details at the leaf. The client preserves wire UTF-8;
the page converts the JSON text before FWWebEx encodes the resulting HTML.
`U_HBBridgeTurnoverMarkupTest` checks this round trip in an isolated AppServer. A real ERP SQL source, temporary-table output and performance comparisons
remain unimplemented. Those are tracked in the work package.

## Controlled AppServer fixture

1. Build the installed addon with `./scripts/build-hbbridge-addons.ps1`.
   The default output is `addons/examples/hbbridgeaddons.hrb`. If the
   running server uses a different `AddonRoot`, pass `-Output` with the
   corresponding `examples/hbbridgeaddons.hrb` path.
2. Compile the maintained TLPP source under `src/tlpp/tests/protheus/hbbridge.turnover.test`.
3. Run `U_HBBridgeTurnoverTCP()` and `U_HBBridgeTurnoverHTTP()` in a Protheus
   environment whose active DBAccess alias corresponds to a configured MSSQL
   hbBridge profile. Each entry accepts an explicit profile if needed. They use
   only three SQL constants, not ERP tables, and report counts and percentages.

The controlled fixture passed MSSQL over TCP and HTTP through both direct
clients and TLPP in an isolated AppServer. The
[sanitized evidence](validation/turnover.fixture.windows.json) excludes ERP data.
Two screenshots show the TCP and HTTP fixtures at job level with metrics, bars
and employee buttons. An HTTP screenshot and confirmation of the same TCP
test establish selection of employee `001`, with its metrics and the end of
drill-down. Back was confirmed separately for both entries; real-data
behavior remains to validate. For isolated CLI execution, pass an explicit
`--profile=MSSQL/pData` and `--transport=TCP` or `--transport=HTTP` to
`-run=U_HBBridgeTurnoverCLI`.

Visual validation of the new grids and navigation through period, company,
branch, cost center, job and employee, including Back, was confirmed over
TCP and HTTP using the controlled fixture. The visual entries are
U_HBBridgeTurnoverViewTCP() and
U_HBBridgeTurnoverViewHTTP(). They display the same controlled MSSQL fixture;
FWWebEx must be installed in the RPO to use these entries.
A Node.js check of the isolated page script is available through
`node tests/unit/hbbridge.turnover.page.test.js`; it does not replace visual
AppServer acceptance in other environments.
