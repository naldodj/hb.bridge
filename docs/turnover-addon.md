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

The [historical-rule comparison](turnover-reconciliation.md) records the
observed SQL behavior, controlled monthly tests and unresolved differences.
The separate [`turnoverReport` example](../examples/turnover/README.md)
consumes already-aggregated monthly results without recalculating them.

## Original Protheus REST diagnostic

`scripts/test-turnover-protheus-rest.ps1` calls the existing Protheus model
service using the locally configured `FWWEBEX_PROTHEUS` Basic credentials and
an explicitly supplied application-token file. It requires an HTTPS loopback
URL, company, branch and a date range with at least two returned monthly rows.
The service may create and remove its own temporary tables. The script checks
company pagination and employee field availability; it reports only check
statuses and HTTP codes, not response rows or credentials. For a development
server with a self-signed certificate, pass `-SkipCertificateCheck` explicitly.

```powershell
pwsh -File scripts/test-turnover-protheus-rest.ps1 `
    -AppServerIni '<path to appserver.ini>' `
    -ApplicationTokenFile '<path to authentication.aut>' `
    -Company '<company>' -Branch '<branch>' `
    -StartPeriod 202501 -EndPeriod 202510 -SkipCertificateCheck
```

On 2026-11-05 the local Windows/MSSQL development run passed seven checks over
the original Protheus REST: two company pages, company fields, one employee
page, employee fields and the absence of an item-level error. This tests the
legacy service directly, not the new dashboard, an hbBridge addon or equality
with the historical SQL backup. Employee values were not recorded.

The query and full result are materialized in memory; there is no streaming or
transaction snapshot across calls. Error results do not contain partial totals.
The controlled FWWebEx page includes a bar chart, a grid at each level and
employee date and movement details at the leaf. The client preserves wire UTF-8;
the page converts the JSON text before FWWebEx encodes the resulting HTML.
`U_HBBridgeTurnoverMarkupTest` checks this round trip in an isolated AppServer. The separate registered-source example uses caller-owned temporary tables
filled through `RPCRDD.Execute`; see [turnoverReport](../examples/turnover/README.md).
This controlled addon does not write turnover output to a temporary table.
Performance comparisons remain pending.

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
A newer dashboard simulation adds a three-month synthetic fixture to these
visual entries, with monthly movement bars and initial/final headcount. Missing
transfer evidence remains unknown. Cross-month active totals are labeled as
employee-months and no overall period rate is asserted. The CLI entries retain
the original three-row fixture. The updated visual presentation was confirmed over TCP and HTTP for all three
periods, drill-down and Back; it does not consume the real turnover SQL.
A Node.js check of the isolated page script is available through
`node tests/unit/hbbridge.turnover.page.test.js`; it does not replace visual
AppServer acceptance in other environments.
