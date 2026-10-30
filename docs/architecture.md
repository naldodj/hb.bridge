# Generic execution and application responsibilities

[Português](architecture.pt-BR.md)

The [documentation index](README.md) provides task-oriented navigation.

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

## Shared core and transport adapters

```text
Protheus / AdvPL / TLPP    Harbour clients    HTTP clients / browser
          |                     |                      |
      HBBRIDGE/1            native NETIO        HTTP / REST / web admin
          |                     |                      |
 Protheus adapter          hbnetio adapter        hbhttpd adapter
          |                     |                      |
          +----------------- hbBridge ------------------+
                              |
                 shared service/capability registry
                 types / errors / call permissions
                              |
          +-------------------+-------------------+
          |                   |                   |
    Harbour core,        data and files       Harbour C API
    contribs/addons     SQL / native VF IO         |
                                              C ABI ↔ Zig
```

Each adapter translates its transport into the common core. Modules and queries
do not need to implement each client's wire protocol. The registry and host
configuration are shared; each call owns its context, work areas, connections
and modules. See the [registry and lifecycle](milestone1.md),
[HTTP adapter](http.md) and [native RPC/file boundary](harbour-vfio-trpc.md).

The reference deployment uses **one hbBridge executable**, currently operated
in console, with `hbnetio` statically linked through `-lhbnetio`.
The host coordinates initialization, filtering, administration and shutdown
through `netio_Listen`, `netio_Accept`, `netio_RPCFilter` and `netio_Server`,
retaining and joining its threads. The upstream `netio_MTServer` wrapper
detaches its threads. See the
[hbnetio APIs](https://github.com/harbour/core/blob/master/contrib/hbnetio/readme.txt).

A DLL may later support independently updated extensions when a stable ABI and
loading lifecycle justify it. A separate process may isolate a specific
workload. Neither is required to embed NETIO. Database connectors and installed
ODBC drivers remain dependencies of their selected profiles/builds.

`HBBRIDGE/1` belongs to the Protheus endpoint; Harbour clients use the separate
native NETIO endpoint. Changing a TLPP client's port from 1512 to 2941 does not
make it a NETIO client. Sharing a port would require explicit multiplexing and
interoperability acceptance. Binds such as `0.0.0.0` are listener addresses,
not client destinations; local clients use `127.0.0.1`. Defaults, separate
administration and optional HTTP settings are in [configuration](configuration.md).

## Console operation and future system services

Console operation is implemented. Windows system-service installation and
Linux supervised-service integration remain planned; they must reuse the same
host and resource lifecycle rather than create a second product implementation.
The [upstream hbnetio/hbwin service integration](https://github.com/harbour/core/blob/master/contrib/hbnetio/utils/hbnetio/_winsvc.prg)
is the Windows reference. Linux requires supervised startup, signals, shutdown
and recovery.

Use stable absolute installation paths and coordinate startup rollback,
admission shutdown and cleanup of in-flight work. Future cursor/stream
resources also need explicit owners and closure. Existing workers still need
their handlers/addons to return; the console host does not provide forced
execution cancellation. Service operation must not depend on interactive
debugging. See [debugging](debugging.md) and the [roadmap](../TODO.md).

## Multiple database profiles

Profiles are an arbitrary keyed map, not a single fixed database. Alias names
are opaque and case-sensitive, including `sqlite_demo`, `MSSQL/pData` or
`oracle/alias`. A slash in the name is not a filesystem path or routing rule;
the separate `driver` field selects a supported connector. In INI, a profile
such as `MSSQL/pData` lives in `[SQL/MSSQL/pData]`.

The TLPP library has **no `sqlite_demo` default**. `SQLProfile` in the AppServer
INI is optional, installation-specific and can be empty. The query test uses an
explicit argument first, that optional default second, and otherwise reports
`PROFILE_REQUIRED` before network I/O. Each dataset selects its profile with `SetAliasProfile(alias)` before
`OpenSQL(sql[, page])` or `OpenPage(sql, number, size, orderBy)`. Two datasets
can use different profiles on the same client. Server profiles and credentials remain server-side.

```advpl
oSQLite:SetAliasProfile("sqlite_demo")
oSQLite:OpenSQL(cSQLiteSql)
oMssql:SetAliasProfile("MSSQL/pData")
oMssql:OpenSQL(cResolvedProtheusSql)
```

Use [databases.ini](../config/examples/databases.ini) as a multiple-profile
configuration example. Only drivers `sqlite` and `mssql` are implemented in
the strict schema. An `oracle/alias` name is valid as an alias but does not
implement an Oracle driver; Oracle needs connector, dialect/type tests and
real acceptance before support can be advertised. SQLite examples explicitly
select their demo profile. Generic execution does not promise faster queries
without database plans/indexes and measurements of materialization/transport.

## Foundations for extensions

The following map records intended extension paths, not an assertion that all
listed capabilities are delivered. The registry exposes available services;
optional contribs require explicit dependency/build and acceptance decisions.

| Capability | Foundation and scope |
| --- | --- |
| xBase routines | Harbour core/contribs and PRG/HB/HRB addons; the existing addon service is described in [Milestone 1](milestone1.md). |
| Data processing | SQLMIX/connectors for implemented SQL queries/pages; DBF over NETIO remains a separate planned integration. |
| Files and content | Native VF IO/NETIO, compression and ZIP; the TLPP file-service facade and logical block transfers remain planned. |
| External integration | Optional `hbcurl`, `hbexpat` and other contribs behind application services; not a preinstalled universal API/XML service. |
| HTTP services and web operation | Existing `hbhttpd`/`hbtcpio` adapter and authenticated status; direct TLS uses optional `hbssl`/OpenSSL and separate acceptance. Administrative mutations remain planned. |
| Native processing | Harbour C API and C/Zig libraries; additional specialized transformations need measured implementations. |
| Long operations | Threads, native NETIO stream facilities and a future jobs layer with submission, progress, results and cooperative cancellation. |

References: [hbcurl](https://github.com/harbour/core/tree/master/contrib/hbcurl),
[hbexpat](https://github.com/harbour/core/tree/master/contrib/hbexpat),
[hbziparc](https://github.com/harbour/core/tree/master/contrib/hbziparc).
[Dependencies](dependencies.md), [evolution](evolution.md) and
[TODO](../TODO.md) retain the implementation boundaries and prerequisites.

## Telemetry status

The [Syslog module](../src/hb/telemetry/hbbridge.syslog.hb) is linked and can
send UDP to `127.0.0.1:514`. The active host/RPC flow does not call its
open/write/close functions. Lifecycle integration and collector acceptance
remain future work; linked code alone does not establish active telemetry.
