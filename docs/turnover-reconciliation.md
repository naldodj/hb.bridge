# Turnover: historical-rule reconciliation

[Português](turnover-reconciliation.pt-BR.md) · [Example](turnover-addon.md) · [Work package](../WIP.md)

The objective is a new hbBridge example that uses the supplied turnover queries
as data sources and adapts their outputs to a new dashboard and drill-down.
The historical implementation is a reference, not an identical behavior
requirement. Define the meaning of the new measures and validate them against
the chosen source; claim legacy equivalence only if independently established.

The current experimental addon accepts one employee-month per row and builds a
complete hierarchy in memory. The supplied queries instead return already
calculated measures at different levels and, in the general reports, use a SQL
batch that materializes a result table. They cannot be passed unchanged to the
existing `turnover` action as a typed SELECT. A new application-specific addon
contract should consume the chosen result shape without adding the same
aggregate at several levels, and retrieve the selected level and its details
when needed. Protheus supplies resolved table identifiers and authorized context;
the addon can own trusted SQL templates and calculation rules. Bind filter values
and validate identifiers; do not evaluate stored Protheus macro expressions in
the Harbour process. Adapt batch output deliberately to the execution and table
ownership contract, then compare JSON output with a caller-owned temporary table
where appropriate. No performance advantage is assumed before measurement.

This is a source-code comparison of the five historical SQL backups supplied for
the company, branch, cost-center, job and employee reports. They are an input
to reconciliation, not proof that their contents match the currently deployed
customization. Each backup is byte-identical to its corresponding SQL file in
the supplied GEP project. The application resolves physical table names, company, branch,
permissions and report filters. The generic hbBridge core does not infer them;
a trusted addon may implement the application's own rules.

## Rules observed and current coverage

| Subject | Historical SQL backups | Current addon example |
| --- | --- | --- |
| Month eligibility | An admission month is no later than the period; a blank dismissal or a dismissal month no earlier than the period is required. A nonblank dismissal must not precede admission. | The caller supplies `ACTIVE=1`; the addon does not reconstruct eligibility. A synthetic SQLite test exercises these month boundaries. |
| Admission and dismissal | Count the respective SRA dates in the month. Employees admitted and dismissed in the same month may contribute to both. | Each input row supplies a 0/1 indicator. A controlled test covers both events in one month and an employee dismissed before the next month. |
| Measures | `initial = active - admissions`; `final = active - dismissals`; turnover is `(admissions + dismissals) / 2 / initial * 100`, rounded to two decimals; dismissal movement is `dismissals / 2 / initial * 100`. Both rates are zero for a zero initial count. | Initial and both rates use the same arithmetic on supplied rows. The example does not expose the historical final count. Equal formulas do not establish equal input populations. |
| Transfers | The backups count SRE records separately by month and employee identity, with distinct source/destination matching criteria. They resolve several displayed dimensions from the earliest or latest matching movement in the same month. | The caller supplies dated events with explicit `in`/`out` directions; missing evidence stays unknown. The addon sums events per supplied row. It does not infer SRE direction, ownership or historical assignment. |
| Job | The backups use the latest matching SR7 date within the month, with SRA as fallback. | The source supplies the job for each row. |
| Dimensions and identity | Historical subqueries use company, branch, employee and unique-code criteria; the output groups differ between reports. CTT and SRJ are inner joins with branch-sharing conditions. | The hierarchy is period/company/branch/cost center/job/employee. The caller must supply an unambiguous employee key and dimensions. A repeated key in the same complete path is rejected. |

The controlled test uses invented dates, an isolated SQLite table and a
deliberately simplified monthly source. It checks hand-calculated results,
not execution of the original SQL, SQL Server behavior, transfer reconstruction
or equivalence to the deployed application. Totals above the period node sum
employee-months; they are not distinct headcounts or automatically meaningful
cross-period turnover rates.

## Cases to define and validate

- Compare against the actual deployed report and its parameter/table resolution;
  backup table spellings are not a portable contract. Preserve authorization and
  avoid copying real employee data into fixtures, logs or the repository.
- Validate month generation and inclusive date boundaries. In these backups the
  generated sequence uses `TOP (DATEDIFF(MONTH, minimum, GETDATE()))`; its end
  behavior, including the current month, must be checked against the application.
- Resolve SRE source/destination semantics with controlled one-way, return and
  multiple movements, same-day ties and cross-company/branch cases. The backup
  labels `TTRFSAI` and `TTRFENT` must not be mapped to `out`/`in` by name alone.
  Determine where an event belongs at each aggregation level and avoid counting
  it twice when it appears in more than one supplied assignment.
- Check SR7 changes, missing or duplicated CTT/SRJ matches, sharing modes,
  deleted records and rehires. In the inspected backups, admission and dismissal
  subqueries do not explicitly filter logical deletion, and the dismissal
  subquery groups by branch without an explicit branch equality predicate.
  Establish intended behavior before reproducing or changing it.
- Define unique employee and assignment identity across transfers. The existing
  0/1 row contract cannot represent arbitrary SQL counts greater than one, and
  the current path cannot distinguish identical employee keys in one assignment.
- Validate each level, source indicators, movements and rounded totals with
  controlled inputs and an authorized Protheus environment. Comparing the
  historical implementation on the same input can explain differences, but is
  required only for an explicit claim of equivalence. Record sanitized results
  and transport scope.

The example is not yet a validated HR or payroll report.

## Result delivery options

- **Addon JSON:** the controlled `turnover` example returns a complete hierarchy;
  `turnoverReport` returns already aggregated monthly measures. This is useful
  for an interactive page, but the query and result are materialized in memory.
- **Caller-owned temporary table:** the Protheus example creates and retains
  `FWTemporaryTable` objects. `RPCRDD.Execute` fills them from registered SQL;
  the addon reads company/branch results and selected details are queried on
  demand. The owner keeps the connection and tables alive and deletes them after
  use. Direct browse of a caller-owned SX5/SRA temporary table has also been
  validated, without paginated RPC transfer.
- **Addon-written results:** a trusted application addon may execute SQL and
  write to the caller's destination, with the same ownership and permissions.
  The temporary-insert addon was validated with two synthetic rows; no test has
  yet established that a turnover addon computes and writes its own output.

A Windows/MSSQL diagnostic populated owned temporary tables using registered
queries, compared the monthly addon JSON and selected detail rows against the
SQL results, and checked release. The real TCP/HTTP dashboard was visually
validated through employee and Back. See [example evidence](../examples/turnover/README.md)
and [SQL execution evidence](sql-execution.md). These comparisons validate the
specified paths and fields, not historical business-rule equivalence or a
performance advantage. Separate queries need not share a transaction snapshot.

The SQL profile must address a server and database where the destination is
visible to the hbBridge connection; visibility, isolation and permissions must
be validated per backend. The owner controls the trusted destination and schema.
`RPCRDD.Execute` lacks typed bindings and a lost response can mean an unknown
outcome; do not retry automatically or assume rollback. JSON, paging and temporary
tables should be compared with equivalent data, work and measurement scope
before selecting one for performance reasons.

## GEP application usage

The referenced `Turnover*.prg` files are Harbour/Nefele presentation and model
consumers. The company report passes period filters to `GetDataModel`; the
drill-down links continue through branch, cost center, job and employee. The
company and branch dashboards use their report data to build monthly series for
transfers, admissions, dismissals, initial and final headcounts, and the two
turnover rates. `GetDataModel` can use cached JSON or request a model; inspecting
these sources does not establish which data path is active in a deployment.

The corresponding SQL parameter mapping supplies `RetSQLName` expressions for
several physical tables, application parameters and temporary table names. This
is evidence of that application's resolution mechanism, not a requirement for
the hbBridge addon to adopt the same JSON model or hardcode table names.

The six GEP configuration files also describe ordered columns, labels, data
properties, formatting, search, ordering and fixed columns, plus model access
settings. They are presentation references; the new example need not read them.
Some entries in the inspected company and employee configurations repeat a
field or associate a displayed column with a different data property. Validate
the intended mapping against the query and model instead of copying it blindly.
Access settings in these files must not be copied into project documentation.

### Registered models and JSON production

A read-only inspection of the local development MSSQL database on 2026-11-05
found six active turnover models joined from `ZZ_` to `ZX_` by query code. The
five general models use SQL execution and the planned-versus-actual model uses
the other query mode. Their field mappings are configuration, not employee data.

The Protheus model endpoint resolves the model and reads the query and parameter
mapping from `ZX_`. `QueryToTmpTable` evaluates configured parameter expressions
in the Protheus environment. In the execution mode it runs the SQL, inspects its
result table, creates a `FWTemporaryTable`, populates it with `INSERT INTO ...
SELECT` and removes the intermediate result table. The endpoint pages over the
resulting alias; `AFXUtils:getJSON` uses ordered `ZZ_` entries to map source
fields or expressions to JSON properties. Each item is placed under
`table.items[].detail.items`. The GEP consumer can subsequently retrieve this
model response or cached JSON. This flow is based on the inspected source and
model configuration; no report execution was performed during this inspection.

For example, the registered company model maps `PERIODO` to `codPeriodo`,
`TTRFSAI` to `totalTransferenciasSaida`, `TTRFENT` to
`totalTransferenciasEntrada`, `TFUNIMES` to `totalFuncionariosInicioMes`, and
`TURNOVER` to `turnOverGeral`. In the employee model, configured expressions
locate SRA by `SRARECNO` for employee name and admission date; the dismissal
date is returned conditionally on the monthly dismissal count. These mappings
identify the legacy labels but do not by themselves prove that every movement
has been attributed to its correct source and destination group.

The five SQL texts stored in the development `ZX_` records differ from the
matching backups. Four differ in the normalized month expression and an SRA
placeholder; the employee query has additional month-expression differences.
The stored SQL uses the SRA placeholder present in its parameter mapping. These
observations are not a claim of semantic equivalence. Reconciliation must use
the applicable registered query and resolved configuration as well as the
application code, without executing raw stored expressions outside their trusted
Protheus context.

The dashboards also calculate a selected-period rate separately from the monthly
SQL rates. For nonempty data and a nonzero denominator, the inspected expression
is `((sum(admissions) + sum(dismissals)) / 2 / sum(initial) / numberOfRows) * 100`;
the dismissal rate substitutes `sum(dismissals)` for the numerator. They take
the initial headcount from the first returned row and the final headcount from
the last. The current addon's root instead applies its node formula to the sums
of employee-month indicators, without that extra division by row count. These
are distinct calculations; the supplied sources alone do not establish which
definition should be adopted for a new report or its zero-data behavior. Confirm
ordering, period coverage and the intended period formula before implementing
or comparing dashboard totals. Monthly series remain independently comparable.
