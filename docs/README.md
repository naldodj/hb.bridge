# hbBridge documentation

[Português (Brasil)](README.pt-BR.md) · [Project](../README.md) · [Current work](../WIP.md)

Choose a guide by task. These English/Portuguese files are the maintained
technical documentation, versioned alongside the code. The Wiki presents this
index as a [navigation portal](https://github.com/naldodj/hb.bridge/wiki);
it does not maintain another copy of each guide.

## Start and configure

| Guide | Use it to |
| --- | --- |
| [Dependencies and bootstrap](dependencies.md) | Resolve hb_compile, Harbour, Zig, external drivers and platform prerequisites. |
| [Build, run and validation scripts](../scripts/README.md) | Compile the host/TLPP, start examples and reproduce isolated checks. |
| [Server and AppServer configuration](configuration.md) | Configure INI/JSON/CLI, listeners, timeouts, resource policies and client defaults. |
| [Credentials](credentials.md) | Understand current storage, deployment inputs and the planned portable protection model. |
| [Protheus examples](../examples/protheus/README.md) | Find client, dataset, query, browse and benchmark entry points. |
| [HTTP example](../examples/http/README.md) | Consume services from TLPP/FWRest with the configured HTTP credentials. |

## SQL, datasets and presentation

| Guide | Use it to |
| --- | --- |
| [SQL service and pagination](milestone3-sql.md) | Configure MSSQL/SQLite profiles and database-side pages. |
| [Dataset](dataset.md) | Read headers/fields/rows and traverse pages with explicit ownership. |
| [Typed SQL contract](typed-sql.md) | Supply typed parameters and distinguish source, wire and logical types, NULL and exact values. |
| [Connector capabilities](typed-sql-connectors.md) | Inspect supported native bindings and result metadata. |
| [Native Protheus presentation](native-presentation.md) | Convert current pages into owned native tables and browse them. |
| [SX3 metadata and selected fields](sx3-metadata.md) | Resolve dictionary definitions, SRA examples, aliases and original field names in Protheus. |
| [SX9 relationships](sx9-relationships.md) | Review SRA/SRB and CTT/SRA candidates for future explicit JOIN examples. |
| [SQL connection ownership and pooling](sql-connections.md) | Understand per-call ownership, physical reuse and future evaluation. |

## Architecture and transports

| Guide | Use it to |
| --- | --- |
| [Architecture](architecture.md) | Understand the generic executor, caller business rules, one host and separate adapters. |
| [Service core and embedded NETIO](milestone1.md) | Follow the registry, host lifecycle, administration and native Harbour gateway. |
| [Protheus TCP framing](milestone2-framing.md) | Understand HBBRIDGE/1, JSON/gzip, runtime capacities and planned transfer evolution. |
| [HTTP/REST and web administration](http.md) | Configure hbhttpd, routes, gzip, send budgets and optional TLS. |
| [Native NETIO transport](../src/hb/transports/netio/README.md) | Use native Harbour RPC/files and inspect upstream limits. |
| [Harbour VF IO and selective TRPC reuse](harbour-vfio-trpc.md) | Distinguish native file capabilities from planned TLPP facades. |
| [Transports, sessions and security](transports-sessions-security.md) | Review future persistence/context, TLS/JWT and optional adapters. |

## Develop, debug and measure

| Guide | Use it to |
| --- | --- |
| [Source standards and commit gates](standards.md) | Apply naming, indentation, maps, ownership and the three required checks. |
| [Source responsibility map](reorganization.md) | Find host, services, transports, clients, addons and reusable tests. |
| [Debugging](debugging.md) | Plan native hbdebug acceptance and future optional HBDAP/editor integration. |
| [Benchmarking](benchmarking.md) | Run measurements and compare the scope of client and server routes. |
| [Benchmark evolution](benchmark-evolution.md) | Review proposed native C/Zig processors and environment extensions. |
| [Visual benchmark](../src/tlpp/tests/protheus/hbbridge.benchmark.test/README.md) | Configure route selection, view charts and export results. |
| [Reusable tests](../tests/README.md) | Find native, contract and integration suites. |
| [Reproducible validation](validation/README.md) | Locate sanitized manifests and recreate runs from maintained sources. |

## Decisions, progress and contribution

| Guide | Use it to |
| --- | --- |
| [Active work package](../WIP.md) | Resume the next bounded task and its completion criteria. |
| [Roadmap](../TODO.md) | Review future delivery, prerequisites and acceptance criteria. |
| [Acceptance history](acceptance.md) | Check dated outcomes, identities, platform coverage and limitations. |
| [Evolution review](evolution.md) | Review worker state, optional HTTP engines, presentation and future in-memory results. |
| [Extension review](extensions-review.md) | Evaluate optional SQLRDD, Duktape and CCHarbour ideas. |
| [FWWebEx utility review](fwwebex-tools-review.md) | Review JSON clone, merge, flatten and timing candidates before reuse. |
| [Licensing and provenance](licensing.md) | Check the pending global license decision and existing source/dependency terms. |
| [Project and corporate support](support.md) | Contribute feedback or contact DNA Tech for specialist services. |

## Maintain this portal

Edit these versioned indexes and the relevant guide in both languages. Generate
the Wiki navigation with `pwsh ./scripts/prepare-wiki.ps1`; see the
[publication workflow](../scripts/README.md#wiki-portal).
Generated pages belong in disposable `out/`, while source guides remain here.
