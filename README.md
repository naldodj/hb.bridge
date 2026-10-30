# hbBridge

[Português (Brasil)](README.pt-BR.md) · [Documentation](docs/README.md) · [Wiki](https://github.com/naldodj/hb.bridge/wiki) · [Current work](WIP.md)

[![Stars](https://img.shields.io/github/stars/naldodj/hb.bridge?style=social)](https://github.com/naldodj/hb.bridge)
![Clones](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/naldodj/hb.bridge/refs/heads/main/clone-badge.json)

**Extend TOTVS Protheus with Harbour, C and Zig.** hbBridge provides a shared
service host for AdvPL/TLPP, native Harbour and HTTP clients, with SQL access,
Harbour addons and native processing.

hbBridge is a **generic executor**. Protheus resolves its business rules,
tenant, company, branch, `xFilial` and physical table names, then supplies
explicit queries and parameters. Database profiles are caller-selected aliases;
the client library does not require a demo database.

## Why Harbour, C and Zig?

- **Harbour makes xBase programming familiar.** Its syntax and conventions
  resemble AdvPL/TLPP, making services and addons easier for Protheus developers
  to read and maintain. Harbour also supplies native RDDs, NETIO, serialization
  and contrib libraries. Protheus-specific APIs still require adaptation.
- **C provides native interoperability.** The Harbour C API connects xBase
  code to native libraries; the C ABI also connects Harbour extensions to Zig.
  The internal integration path is **Harbour ↔ C ↔ Zig**.
- **Zig modernizes native development.** C interoperability, explicit error
  handling, allocation/ownership and compile-time evaluation support native
  extensions. Zig also supplies the managed Harbour/C build toolchain and the
  shared numeric JSON codec.

See [architecture and extension boundaries](docs/architecture.md).

## Available today

| Capability | Current implementation |
| --- | --- |
| Shared services | Health, Echo, discovery, controlled core functions and addon execution. |
| Protheus TCP | TLPP client using the `HBBRIDGE/1` JSON/gzip contract. |
| Native Harbour | Embedded NETIO for registered RPC and native remote file access. |
| HTTP/REST | Optional hbhttpd listener, TLPP HTTP client, gzip and authenticated status panel. |
| SQL | MSSQL/ODBC and SQLite profiles, typed parameters/results and database-side pagination. |
| Protheus presentation | Dataset navigation, native tables/browse and caller-resolved SX3 metadata/examples. |
| Addons and measurements | Harbour source/HRB execution and reproducible CLI/visual benchmark examples. |

The project is under active development. [Acceptance records](docs/acceptance.md)
identify tested versions, platforms and limitations. System-service installation,
protected credential storage, general LOB transport and HBDAP integration remain
future work; see [WIP](WIP.md) and the [roadmap](TODO.md).

## First run

From the repository root, with PowerShell 7 and Git installed:

```powershell
pwsh ./scripts/bootstrap.ps1
pwsh ./scripts/build-hbbridge.ps1
pwsh ./scripts/run-hbbridge.ps1 -Config config/examples/hbbridge.ini
```

Bootstrap resolves the pinned `hb_compile`, Harbour and Zig dependencies.
The executable is generated in `out/`. External SQL drivers and the licensed
TOTVS SDK are separate prerequisites. See [dependencies](docs/dependencies.md)
and [build/run scripts](scripts/README.md) for Windows/Linux requirements.

The [sample INI](config/examples/hbbridge.ini) enables Protheus TCP and native
NETIO; HTTP is opt-in. Use a private configuration for your deployment's
addresses, credentials and SQL profiles. Configure clients through `[hbBridge]`
in the active AppServer INI, using the [client template](config/examples/protheus-appserver.ini)
and [configuration guide](docs/configuration.md).

Compile the maintained `src/tlpp/` tree with your TOTVS environment and run:

```advpl
U_HBBridgeConnectionTest()
```

This first test exercises Health, Echo and the supplied Harbour addon.
[Protheus examples](examples/protheus/README.md) explain compilation, HTTP,
SQL, native browses and the visual benchmark.

## Consume a service from TLPP

Inside a TLPP method, after configuring the client:

```advpl
local jParams := JSONObject():New() as json
local jResponse as json
local oClient := HBBridge.Client.HBBridgeClient():New() as object

jParams["message"] := "Hello from Protheus"
jResponse := oClient:CallService("Echo", jParams)
ConOut(jResponse:ToJSON())

oClient:Close()
FreeObj(@oClient)
FreeObj(@jParams)
FreeObj(@jResponse)
```

For HTTP, see the [FWRest/TLPP example](examples/http/README.md).
For SQL, choose a configured profile per call and use the
[dataset](docs/dataset.md), [typed SQL contract](docs/typed-sql.md) and
[native presentation examples](docs/native-presentation.md).

## Find the details

The [documentation index](docs/README.md) groups guides by task:

- [Configure listeners, profiles and clients](docs/configuration.md).
- [Understand HTTP, compression and administration](docs/http.md).
- [Use SX3 metadata and selected fields](docs/sx3-metadata.md).
- [Measure performance and interpret benchmark results](docs/benchmarking.md).
- [Debug Harbour and plan optional HBDAP integration](docs/debugging.md).
- [Reproduce validation](docs/validation/README.md).

Technical guides stay in `docs/` alongside the code. The Wiki portal is generated
from the documentation index; guides are maintained in one place.

## Contribute and get support

Follow the [source standards and commit gates](docs/standards.md).
[WIP](WIP.md) tracks the active package; [TODO](TODO.md) retains the wider roadmap.
Licensing is not yet formalized for the whole project; consult the
[licensing/provenance status](docs/licensing.md) and existing source notices.

Stars and contributions help the project. For DNA Tech corporate support,
Protheus architecture, database tuning and integrations, see
[support and contact details](docs/support.md).
