# SQL execution and caller-owned temporary tables

[Português](sql-execution.pt-BR.md) · [SQL queries](milestone3-sql.md)

`RPCRDD.Execute` submits SQL through the configured SQLite or MSSQL profile.
The caller owns the SQL and database permissions. It can be called through the
existing TCP, HTTP or native registry, including `HBBridgeDispatch()` from a
trusted addon. This is separate from the result-set contract of `RPCRDD.Query`.

```json
{"service":"RPCRDD.Execute","params":{"requestVersion":1,"alias":"MSSQL/pData","sql":"INSERT INTO [dbo].[##example] (TESTID, TESTTEXT) SELECT 1, 'example'"}}
```

On Protheus, `HBBridge.SQL.HBBridgeSQLExecutor():Execute(oClient, cProfile,
cSQL)` accepts an existing TCP or HTTP client and returns a JSONObject; the
caller owns both the client and the response. This method does not retry.

The response contains `success`, `resultVersion: 1`, `outcome`,
`affectedRows` and `connectionReleased` where a connection was attempted:

| Outcome | Meaning |
| --- | --- |
| `notStarted` | Validation, profile lookup or connection failed before SQL submission. |
| `completed` | The driver reported successful execution. Inspect `connectionReleased` separately. |
| `unknown` | The driver did not confirm the submitted operation. It may have had an effect. |

`affectedRows` is `null` when unavailable; SQLite's current RDDSQL driver
reports result rows rather than affected rows and is deliberately not used as a
count. MSSQL uses the ODBC count when available. A lost response or client
timeout also has an unknown outcome: do not retry automatically. Transport
errors without an outcome are marked `unknown` by the TLPP helper.

This version sends an unparameterized SQL string; it does not yet offer typed
bindings, an idempotency key, distributed transactions, transaction control
across calls or a result dataset. Do not concatenate untrusted values into SQL.
The database account, driver and SQL determine transaction behavior; successful
execution is not a general atomicity guarantee for batches or explicit
transactions. Never assume a failed call rolled back. Use least-privilege SQL
credentials and restrict access to the listener: TCP currently has no client
authentication, and the service accepts SQL under the configured account. SQL
text is not an authorization boundary.

## Protheus-owned target and addon example

1. Protheus creates and keeps its `FWTemporaryTable` alive, obtains
   `GetRealName()`, and passes the actual profile and target to the addon.
2. The trusted [example addon](../addons/examples/hbbridgetemporaryinsertaddon.hb)
   quotes the MSSQL identifier and executes its fixed synthetic `INSERT INTO
   ... SELECT` using the dispatcher. It expects `TESTID` and `TESTTEXT`.
3. Protheus reads the populated table with its own DBAccess connection and
   deletes its table after use. The addon does not create or own that table.

The addon also accepts `columns` and `select` from a trusted caller. The
SX5/SRA temporary-browse examples use that form; the SQL is not parsed or
parameterized. See the [browse examples](../src/tlpp/tests/protheus/hbbridge.presentation.test/README.md#caller-owned-temporary-browse).

Build the HRB with `./scripts/build-hbbridge-temporary-addon.ps1`, install it
under the configured addon root, then run the Protheus diagnostic documented
in [SQL diagnostics](../src/tlpp/tests/protheus/hbbridge.query.test/README.md).
The example does not resolve company, branch, dictionary or business rules.

On 2026-11-02, an isolated Windows AppServer and local hbBridge against the
same MSSQL server/database both confirmed two inserted rows through direct
TCP execution and through the addon; DBAccess independently read the rows.
The actual temporary name was schema-qualified and global, and the owner kept
it open for each call. Alias closure after `Delete()` was observed; physical
cleanup was not independently verified. Other installations must validate
visibility, privileges and lifetime. Avoiding transfer and repeated queries
may improve performance, but a benchmark is needed for a quantified comparison.

On 2026-11-02 at 22:09:42, a separate manual execution of
`U_HBBridgeTemporaryExecuteCLI` in the development AppServer reported
`MSSQL/pData`, the same server/database, `completed`, two affected rows and
two independently observed rows. The owned alias was closed. This report
validates the direct route; physical temporary-table removal was not
independently verified.

On 2026-11-03, a separate manual AppServer CLI log reported `ADDON.Execute`
with the same profile and server/database, `completed`, two affected rows,
two observed rows and a closed owned alias. The log reports application end
at 06:50:45; it does not provide source hashes or independently confirm
physical removal of the temporary table.

## MSSQL view integration test

Run `./scripts/test-hbbridge-mssql-view.ps1 -Config '<private-ini>' -Profile
'<alias>'` to create one uniquely named view in `dbo` using `RPCRDD.Execute`,
read synthetic rows with `RPCRDD.Query` and `RPCRDD.QueryTyped` (including an
integer binding), and drop the view with `RPCRDD.Execute`. The test verifies
absence after the drop. It requires CREATE VIEW and corresponding schema
permissions; the view is a real database object until removed, not a SQL
temporary table. If creation or cleanup has an uncertain outcome, the test
prints the unique object name for inspection. It never blindly drops a view
whose creation it could not confirm.

On 2026-11-02, this test passed against local MSSQL with the `MSSQL/pData`
profile: creation, both query contracts and removal/absence all passed. Calls
used the native in-process service registry; this particular test did not
exercise a network transport or a Protheus UI.
