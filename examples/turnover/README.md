# Application-specific turnover example

[Português](README.pt-BR.md) · [Addon contract](../../docs/turnover-addon.md) · [Work package](../../WIP.md)

This optional example shows how a trusted application addon can process turnover
data. It is not a generic hbBridge business service. Protheus owns the company,
branch, authorization and physical table resolution; another application may
provide a different trusted query and context.

The bundled `turnoverReport` action calls `RPCRDD.QueryTyped` with the trusted
caller-supplied `profile`, `sql` and `bindings`. The SELECT must return exactly
one row per month with the following columns:

| SQL source | Result property |
| --- | --- |
| `PERIODO` | keyed period and `period` (`YYYYMM`) |
| `TTRFSAI`, `TTRFENT` | `transferOut`, `transferIn` |
| `TFUNIMES`, `TFUNADMMES`, `TFUNMES` | `initial`, `admissions`, `active` |
| `TFUNDEMMES`, `TFUNFMES` | `dismissals`, `final` |
| `TURNOVER`, `TURNMOVF` | `turnoverPercent`, `dismissalPercent` |

The action preserves the source measures, including exact decimal strings. It
does not sum different levels, recompute percentages or interpret SRE events.
Invalid values, missing fields and duplicate periods fail without partial data.
An optional `branchSql` and `branchBindings` pair provides the same measures
plus `RA_FILIAL`, one row per period and branch. The response includes
`branches` keyed by period and branch, and `branchRowCount`. Duplicate keys or
a branch period absent from the company result fail the entire action.
The existing `turnover` action remains a separate employee-month fixture.
Only authorized callers should supply SQL; bind data values and resolve and
validate table identifiers in trusted application code.

## FWWebEx presentation

After compiling `src/tlpp/tests/protheus/hbbridge.turnover.test`, the caller
can run the prepared Protheus/GEP example without writing another program:

```advpl
tlpp.Call("HBBridge.Examples.U_HBBridgeTurnoverRealTCP")
tlpp.Call("HBBridge.Examples.U_HBBridgeTurnoverRealHTTP")
```

Run each entry in a prepared Protheus company and branch. The example resolves
the active company and branch turnover models in `ZZ_`, reads their registered
execution batches from `ZX_`, resolves physical table names in Protheus, and verifies that DBAccess
and hbBridge use the same MSSQL server and database. It creates two owned
`FWTemporaryTable` objects, executes each adapted batch through
`RPCRDD.Execute`, displays the addon result and deletes both tables after the
modal closes. After selecting a month, select the current company to display its
branch rows. Protheus resolves the company branches using `FWAllFilial` and
`FWxFilial`; both queries use those physical branch keys. Selecting a branch requests the registered cost-center
model for that period and branch on demand. Selecting a cost center invokes the
registered job model for that period, branch and cost center. The page shows a
loading state and never automatically retries an uncertain execution. Selecting
one job loads its employee rows; the selected employee shows the source measures
and the current SRA name, admission and dismissal dates. Matching SRE transfer
records are shown separately, preserving their P/D fields and match flags; matching
is scoped to the selected period and assignment and may omit historical events.
The source model supplies the counts, which are not recalculated from this grid.
Historical reconciliation and visual validation with real matching events remain
pending. Rebuild the
installed addon bundle before running these entries. The source query must be
the trusted company and branch report shapes described below; a different shape fails
without automatic retry. Company, branch and SQL profile come from the current
Protheus context and configuration.

Without period arguments, the example finds the latest non-deleted `RD_PERIODO`
in the resolved SRD table and uses January through that month of its year. If
SRD has no valid period, provide a range explicitly. The optional arguments
are profile, start month and end month, for example:

```advpl
tlpp.Call("HBBridge.Examples.U_HBBridgeTurnoverRealTCP", "MSSQL/pData", "202301", "202310")
```

The selected SRD period is a default, not proof that every branch has movements
in every month. The current database must contain the GEP models and its
registered SQL; this is a specific application example, not a core hbBridge
dependency. No employee rows are written to project logs by the example.

Alternatively, an application that already owns a populated source table
can pass a trusted SELECT to `HBBridge.Examples.U_HBBridgeTurnoverReportTCP()`
or `HBBridge.Examples.U_HBBridgeTurnoverReportHTTP()`. The arguments are the
SELECT, an optional configured profile, typed-bindings `JSONObject`, branch
SELECT and company code, in that order. The last two are optional; the company
defaults to the prepared Protheus context. The optional branch SELECT currently
must be self-contained and return the branch columns listed above. The caller keeps its source table, connection and
application context alive while the modal page is open. Bindings are copied;
the viewer does not own the caller's object or temporary table.

For example, after the application has created and populated `oTemporary`
with the specified monthly columns, it can build a SELECT using the real name
from that owned object and call either entry. The source identifiers and SQL
must be application-controlled, not supplied by the browser. The page shows
the monthly measures and movement bars directly from the addon. Its period
selection does not invent employee, branch or cost-center detail: those require
subsequent source queries and are not implemented yet. A missing SELECT is
rejected rather than silently displaying the synthetic fixture.

```advpl
cSQL := "SELECT PERIODO,TTRFSAI,TTRFENT,TFUNIMES,TFUNADMMES,TFUNMES," + ;
    "TFUNDEMMES,TFUNFMES,TURNOVER,TURNMOVF FROM " + oTemporary:GetRealName()
tlpp.Call("HBBridge.Examples.U_HBBridgeTurnoverReportTCP", cSQL, cProfile, NIL)
// Call oTemporary:Delete() after the modal page returns.
```

The SQL profile must point to the same database and server as the owned table.
The caller remains responsible for populating and deleting it, including on
errors; use the HTTP entry to exercise the other transport.

## Local MSSQL diagnostic

The following optional Windows development test targets the specific registered
company-query shape examined in the GEP application. It is not a general SQL
parser. The caller supplies a trusted configuration, query record, resolved
physical table names, company, branch and a range containing at least two rows.
The profile must use an MSSQL DSN with a SQL login and HTTP enabled. It starts
an isolated hbBridge process, rewrites that known batch to populate a
test-owned global temporary table, calls `RPCRDD.Execute`, calls the example
addon, compares each returned monthly measure to that table, and checks the
temporary table is released. No employee records or credentials are printed.
The query runs with the configured SQL permissions and creates temporary tables;
use only a trusted query and an authorized development environment.

Build the managed executable and an isolated addon bundle before running:

```powershell
pwsh ./scripts/build-hbbridge.ps1 -OutputDirectory ./tmp/turnover-server
pwsh ./scripts/build-hbbridge-addons.ps1 -Output ./tmp/turnover-addon/hbbridgeaddons.hrb

& ./examples/turnover/test-mssql-report.ps1 `
    -Config '<private hbBridge.ini>' -Profile '<configured MSSQL profile>' `
    -Executable './tmp/turnover-server/hbbridge.exe' `
    -AddonRoot './tmp/turnover-addon' -QueryTable '<resolved ZX table>' -QueryCode '<company query code>' `
    -BranchQueryCode '<branch query code>' -CostQueryCode '<cost-center query code>' `
    -JobQueryCode '<job query code>' -EmployeeQueryCode '<employee query code>' `
    -Company '<company>' -Branch '<branch>' -Branches @('<branch 1>', '<branch 2>') -StartPeriod 202501 -EndPeriod 202510 `
    -TableMappings @{ SRA990='<resolved SRA>'; SRE990='<resolved SRE>'; SRJ990='<resolved SRJ>'; CTT990='<resolved CTT>'; SR7990='<resolved SR7>' }
```

The optional `-Branches` explicitly supplies company branch keys for the
diagnostic; without it the diagnostic uses `-Branch` only. The optional
`-BranchQueryCode` also compares the branch rows and checks both
owned tables are released.

The mapping keys identify placeholders in the inspected query, not fixed table
names in hbBridge. They are replaced with explicitly supplied identifiers. The
diagnostic does not execute stored Protheus macro expressions or verify all
branches, drill-down levels or business rules. Visual acceptance of the
caller-supplied report and implementation of deeper levels remain pending.

The optional `-CostQueryCode` also executes the cost-center model for the
start period and `-Branch`, then compares all returned dimensions and measures
with the owned temporary table. No employee records or values are logged.

The optional `-JobQueryCode` uses the first returned cost center for a filtered
job query and compares all dimensions and measures without printing its value.

The optional `-EmployeeQueryCode` filters by the first returned job and compares
source measures and current SRA attributes without printing personal data.

The employee diagnostic also tests matching SRE records and a controlled fixture
with both directions, unrelated records and mixed collations. Empty real results
do not validate actual transfer events.
