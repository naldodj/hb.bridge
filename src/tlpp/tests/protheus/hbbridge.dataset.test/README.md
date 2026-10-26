# Dataset regression tests

[Português](README.pt-BR.md) · [Dataset contract](../../../../../docs/dataset.md)

Compile this directory with the current `src/tlpp` client/dataset sources in a
dedicated AppServer test RPO, then run:

```advpl
U_HBBridgeDataSetTest()
U_HBBridgeTypedDataSetTest()
```

The ordinary suite checks version-1 metadata, totals, page boundaries, errors,
recovery and defensive snapshots. The typed suite uses the same mock client
and actual `JSONObject`/dataset implementation: strict request/result versions,
canonical bindings, NULL versus missing, UTF-8/NUL, exact integer/decimal strings,
source/wire metadata, immutable later-page inputs and no unbound fallback.
Both print named assertions and final counts. Typed returns numeric 0/1;
the older procedure can return CLI -4 despite its explicit successful summary.

These are deterministic client-contract tests; no SQL connection or browser is
used. Native backend and transport tests are reproduced by
`scripts/test-hbbridge-typed-sql.ps1`; real AppServer/backend and presentation
acceptance remain separate. The [integration manifest](../../../../../docs/validation/typed.sql.windows.json)
records the accepted source/RPO identities and scope.
