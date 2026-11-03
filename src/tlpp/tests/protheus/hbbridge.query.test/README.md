# SQL diagnostics

[Português](README.pt-BR.md)

`U_HBBridgeTemporaryInsertTest()` creates its own `FWTemporaryTable`, obtains
its physical name through `GetRealName()` and sends an MSSQL `INSERT INTO ...
SELECT` with two constant rows to `RPCRDD.Query`. Before writing, it checks the
SQL Server and database identities through both DBAccess and hbBridge. The
default profile comes from the AppServer `[hbBridge] SQLProfile`, falling back
to `FWGetTopInfo()`; pass an explicit profile when its hbBridge alias differs.
The configured TCP endpoint and profile must be active.

The diagnostic reads the owned table independently through DBAccess and reports
the service response and observed rows separately. An error response can follow
a side effect: `RPCRDD.Query` expects a result set and is not a supported DML
contract. A timeout or connection failure can also leave the outcome uncertain;
do not automatically retry the write. The test never writes to ERP tables and
deletes the owned temporary table during cleanup. Whether another SQL session
can see the table, whether the insert succeeds and how it is committed are
observations for the actual installation, not assumptions.

Run `U_HBBridgeTemporaryInsertTest(profile, .T.)` for `RPCRDD.Execute`, or
`U_HBBridgeTemporaryInsertTest(profile, .T., .T.)` for the installed example
addon. CLI entries `U_HBBridgeTemporaryExecuteCLI` and
`U_HBBridgeTemporaryAddonCLI` use the configured profile. Build the HRB with
`scripts/build-hbbridge-temporary-addon.ps1` and place it under the addon root.
See the [execution contract](../../../../../docs/sql-execution.md).

On 2026-11-02, an isolated Windows AppServer and a separately started local
hbBridge used the `MSSQL/pData` profile. Both reported the same SQL Server and
database. `GetRealName()` returned a schema-qualified global temporary table;
the service returned `QUERY_FAILED`, while DBAccess independently read both
expected rows. The owned alias was closed after `Delete()`. This establishes
the observed effect for that run, not a general DML transaction contract or
proof that all temporary storage has been removed. An initial CLI run stopped
before creating the table because the inferred profile was unavailable.
