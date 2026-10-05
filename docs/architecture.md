# Generic execution and application responsibilities

[Português](architecture.pt-BR.md)

hbBridge extends Protheus with Harbour/C/Zig execution, data access, files,
addons and native processing. **Protheus owns its business rules.** The bridge
does not derive ERP context from a database name, a connection profile, an
RPC session or a table prefix. Other Harbour clients can use the same services.

| Protheus / calling application | hbBridge executor |
| --- | --- |
| Resolve tenant ID, company and branch. | Receive explicit context as opaque application data. |
| Resolve `xFilial`, table sharing and physical table names such as `RetSQLName` results. | Execute the fully prepared query against the selected profile. |
| Apply its dictionary, business validations, permissions, logical deletion, transactions and locks. | Enforce generic service/connection/resource permissions and return execution results. |
| Choose the connection alias and SQL dialect for its target. | Look up the configured alias, connect and execute; generic pagination may wrap the supplied query. |
| Supply business inputs to an addon. | Run that addon with supplied parameters; never silently infer an ERP company/branch. |

Future tenant authorization, session ownership and audit can validate explicit,
authenticated context. They must not invent `xFilial` predicates, infer table
sharing or map Protheus dictionaries. Tenant isolation is an executor security
concern; computing the ERP meaning of that tenant belongs to the application.
The current implementation does not yet provide that future tenant-aware
authorization/session model.

For SQL, the Protheus caller prepares the physical table identifiers and
business predicates before calling `RPCRDD.Query`. The current request uses
`alias`, `sql` and optional `page`; SQL bind parameters and a versioned context
envelope remain roadmap items. Prepared statement/bind support must distinguish
values from identifiers: a table name cannot be supplied as a value placeholder.
Never interpolate untrusted values merely because the bridge accepts SQL.

An addon may contain application-specific processing, but its business data
must arrive explicitly through parameters. The generic core has no dependency
on Protheus company databases or dictionaries. The `Echo` test's sample
`company="T1"` is just echoed data, not a configured company resolver.
Direct ODBC queries do not automatically execute DBAccess/business workflows.

## Multiple database profiles

Profiles are an arbitrary keyed map, not a single fixed database. Alias names
are opaque and case-sensitive, including `sqlite_demo`, `mssql/pData` or
`oracle/alias`. A slash in the name is not a filesystem path or routing rule;
the separate `driver` field selects a supported connector. In INI, a profile
such as `mssql/pData` lives in `[SQL/mssql/pData]`.

The TLPP library has **no `sqlite_demo` default**. `SQLProfile` in the AppServer
INI is optional, installation-specific and can be empty. The query test uses an
explicit argument first, that optional default second, and otherwise reports
`PROFILE_REQUIRED` before network I/O. Each dataset's `opensql(alias, sql)`
or `openpage(alias, ...)` chooses its own profile; two datasets can use different
profiles on the same client. Server profiles and credentials remain server-side.

```advpl
oSQLite:opensql("sqlite_demo", cSQLiteSql)
oMssql:opensql("mssql/pData", cResolvedProtheusSql)
```

Use [databases.ini](../config/examples/databases.ini) as a multiple-profile
configuration example. Only drivers `sqlite` and `mssql` are implemented in
the strict schema. An `oracle/alias` name is valid as an alias but does not
implement an Oracle driver; Oracle needs connector, dialect/type tests and
real acceptance before support can be advertised. SQLite examples explicitly
select their demo profile. Generic execution does not promise faster queries
without database plans/indexes and measurements of materialization/transport.
