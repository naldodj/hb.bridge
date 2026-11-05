# Active hbBridge work package

[Português](WIP.pt-BR.md) · [Roadmap](TODO.md) · [Acceptance](docs/acceptance.md)

## Package 003: application addon and turnover drill-down

The examples are built together as one [addon bundle](docs/addon-bundle.md);
independent addons remain compatible. The bundle uses a per-call registry of
approved HRB-local symbols and `hb_ExecFromArray()` for dispatch.

- [x] Validate a controlled monthly SQLite fixture and addon aggregation using
  typed SQL, inherited permissions and explicit failure handling: native
  integration passed 826 checks, including 29 turnover checks. The bundle also
  passed 94 benchmark-addon checks.
- [x] Validate the controlled MSSQL fixture through direct TCP/HTTP and the
  Protheus clients in an isolated AppServer: three constant rows passed on
  both transports. See the [sanitized evidence](docs/validation/turnover.fixture.windows.json).
- [x] Visually validate the new grids and navigation through period, company,
  branch, cost center, job and employee, including Back, on TCP and HTTP.
  The source passed direct MSSQL and isolated AppServer UTF-8 checks.
  See the [sanitized evidence](docs/validation/turnover.fixture.windows.json).
- [ ] Define and reconcile the historical turnover rules with the existing
  Protheus implementation before asserting equivalence.
- [x] Observe the controlled TCP and HTTP FWWebEx pages at the job level: the
  supplied screenshots show the metrics, bars and two employee buttons.
  See the [sanitized evidence](docs/validation/turnover.fixture.windows.json).
- [x] Validate employee `001` selection on both visual entries: HTTP screenshot
  and confirmation of the same TCP test, with metrics and drill-down end.
- [x] Validate Back on both visual entries, as confirmed separately.
  This controlled fixture does not establish real-data acceptance.
  Do not expose personal details in evidence.
- [ ] Validate the JOIN CLI entry in a prepared Protheus environment; it compiled,
  but `RPCSetEnv` failed in the isolated environment before JOIN checks.
- [ ] Evaluate caller-owned temporary-table output through `RPCRDD.Execute`,
  compare the approaches and record meaningful limits and validation evidence.

The addon can own business rules; the core remains generic. The initial contract,
formula and pending limitations are in [the example](docs/turnover-addon.md).

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
Source identities and test scopes are in the [sanitized manifest](docs/validation/join.presentation.windows.json);
the [package 002 work history](docs/validation/package-002.md) preserves decisions
and earlier evidence. [Acceptance](docs/acceptance.md#join-browse-validation-on-2026-11-03)
and [ChangeLog](ChangeLog.txt) record closure.
