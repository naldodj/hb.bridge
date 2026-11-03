# Active hbBridge work package

[Português](WIP.pt-BR.md) · [Roadmap](TODO.md) · [Acceptance](docs/acceptance.md)

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

## Next package

No next package has been selected. Select a bounded objective and its completion
criteria from the [roadmap](TODO.md) before starting new implementation. A
read-only SX9 relationship snapshot is a candidate for discussion, not an
implemented feature or an automatic SQL generator; see the
[SX9 review](docs/sx9-relationships.md).
