# SX9 relationship metadata for JOIN examples

[Português](sx9-relationships.pt-BR.md) · [Dictionary metadata](sx3-metadata.md) · [WIP](../WIP.md)

SX9 can inform the Protheus-side JOIN examples. It is a dictionary of
relationships, not a foreign-key constraint enforced by hbBridge or a complete
SQL query. Protheus continues to resolve physical tables, company/branch,
sharing, predicates, parameter values and presentation metadata. The server
receives explicit SQL and bindings.

## Read-only local observation on 2026-10-29

Only catalog/dictionary rows were read through the existing local MSSQL
profile. No employee, dependent or cost-center business values were read and
no tables, settings or credentials were changed.

The requested pairs were found in `dbo.SX9990`; `dbo.SX9` also exists but
returned no rows for those pairs. This is a local observation, not a naming
rule. Production dictionary access must use the prepared Protheus context.

| Domain | X9_IDENT | Counter-domain | Domain expression | Counter-domain expression | Declared cardinality |
| --- | --- | --- | --- | --- | --- |
| SRA | 106 | SRB | RA_MAT | RB_MAT | 1:N |
| CTT | 293 | SRA | CTT_CUSTO | RA_CC | 1:N |

Both records contain `X9_ENABLE=S`, `X9_USEFIL=S`, empty `X9_CONDSQL`,
`X9_VINFIL=2` and `X9_CHVFOR=2`. Preserve the latter codes as reported metadata;
this review does not assign new meanings to them. Cardinality is declared
dictionary metadata, not measured uniqueness of the business data.

From an SRA-rooted query, the first relation is outgoing, whereas the CTT
relation is incoming: one cost center can correspond to several employees,
so the SRA-to-CTT traversal reverses the stored 1:N direction to N:1. A reader
that filters only `X9_DOM='SRA'` misses this cost-center relationship.

The matching `SX2990` definitions report `SRA990`, `SRB990` and `CTT990`,
with `X2_MODO/X2_MODOUN/X2_MODOEMP=E/E/E`, branch width 2 and unit/company
widths 0. These values describe this inspected dictionary only. Resolve each
alias through Protheus at execution time rather than hardcoding the suffix,
equating branch fields blindly or guessing sharing from returned rows.

The official [TOTVS relationship/sharing explanation](https://tdn-homolog.totvs.com/pages/releaseview.action?pageId=844959467)
identifies domain/counter-domain and cardinality fields and explains sharing
at company, business-unit and branch levels. An official
[SX9 relationship example](https://tdn-homolog.totvs.com/display/public/PROT/DT%2BGCPA600%2BRelacionamento%2BSX9)
also records expression pairs, `X9_IDENT`, enable and branch-use flags.

## Reusing the existing SX9Tools example

The supplied `dna.tech.sx9.tools.tlpp` is a useful access-pattern reference:
it seeks the SX9 domain and reads the original expressions. Its deletion,
update and executable-codeblock functionality is outside this read-only
presentation requirement and should not be imported into hbBridge.

Adaptations required for a relationship snapshot:

- Include both outgoing and incoming relations, retaining their original
  direction and a separate traversal direction.
- Preserve `X9_IDENT` from SX9. The supplied reader currently assigns
  `cX9_EXPCDOM` to its `X9_IDENT` property; that is not the relationship ID.
- Record cardinality, enabled/deleted state, branch-use flags and conditional
  expressions alongside both table names and expressions.
- Preserve the caller's workarea and SX9 index/record state. Use verified
  native indexes where appropriate; do not assume an index ordinal blindly.
- Prefer a keyed `JSONObject` snapshot, using the domain/identifier/
  counter-domain tuple as identity. Do not compile dictionary text into
  executable macros merely to inspect or describe a relationship.

A proposed `HBBridge.Protheus.HBBridgeSX9Metadata` helper would serve that
snapshot. It is not implemented by this review. It must remain independent
of SQL connection ownership and of the generic Harbour service registry.

## Turning a candidate relationship into explicit SQL

For the two simple expression pairs observed here, field equality is a
reasonable starting point: `SRA.RA_MAT=SRB.RB_MAT` and
`SRA.RA_CC=CTT.CTT_CUSTO`. The Protheus example still resolves branch predicates
for each alias, applies logical deletion and chooses INNER or LEFT JOIN.
SX9 alone does not select the desired JOIN type or guarantee a matching row.

Expression text is not necessarily a list of column names. Compound keys,
AdvPL functions, literals and contextual conditions need explicit handling.
Do not split arbitrary expressions at `+` and silently translate them to
SQL equality or concatenation. Start with validated simple-field pairs;
retain unsupported expressions for caller resolution. Treat `X9_CONDSQL`
with the same care instead of executing unexamined dictionary fragments.

The existing `U_HBBridgeBrowseDataTestSRAWithCast` illustrates a relevant
correction for the future example: it declares LEFT JOIN but tests
`CTT.D_E_L_E_T_=' '` in WHERE. That rejects unmatched rows and behaves like an
inner join for them. Put the right-side deletion condition in ON when LEFT
JOIN semantics are intended. Resolve CTT sharing through Protheus rather
than the current CASE over each returned `CTT_FILIAL` value. No source was
changed as part of this analysis.

For SRA/SRB, joined rows can multiply according to the relationship.
Use unique projected aliases and a deterministic order including the
joined-side identity; count joined rows unless the caller explicitly requests
an employee-level aggregate. Preserve LEFT JOIN NULL in the dataset and
choose any native-presentation replacement explicitly in Protheus. Continue
to obtain field type, size and decimals from SX3 for each projected origin.

The next implementation remains the bounded selected-field/JOIN examples
recorded in WIP, not an automatic SQL parser or server-side ERP rule engine.
