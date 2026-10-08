# hbBridge

[Português (Brasil)](README.pt-BR.md)

The [active work package](WIP.md) defines the next tasks, recorded decisions
and completion criteria. Package 001 covers real MSSQL acceptance;
[TODO](TODO.md) retains the full roadmap. WIP is renewed after package closure.

An extensible bridge that brings Harbour, C and Zig capabilities to TOTVS
Protheus (AdvPL/TLPP) and native Harbour clients. It extends applications with
RPC, data and file access, module execution and native processing, using the
Harbour ecosystem.

hbBridge is a **generic executor and extender**. Protheus resolves its business
rules, tenant ID, company/branch, `xFilial` and physical table names, then sends
prepared queries and explicit parameters. Addons may implement application
processing using those parameters; the core does not infer ERP context.
Profiles are arbitrary aliases selected per call, such as `mssql/pData`.
The client library has no fixed demo database. See
[architecture and multiple profiles](docs/architecture.md).

This document separates delivered behavior from the intended architecture.
[Milestone 1](docs/milestone1.md) embeds NETIO and a shared service core.
System services, negotiation, streams and other extensions remain in the
[roadmap](TODO.md), with implementation and acceptance tracked separately.

## Why Harbour, C and Zig?

### Harbour: familiar xBase programming

Harbour and AdvPL/TLPP share the syntax and programming conventions of the xBase
family. Protheus developers can read, write and maintain Harbour routines using
familiar functions, commands, control structures and data-access concepts.
Making programming easier is the central reason for choosing Harbour.

That familiarity guides services and addons. The runtime, `hbnetio`, native
RDDs and contribs extend the same foundation. Similar syntax helps adapt
routines; Protheus-specific APIs still require explicit adaptation.

### C: native interoperability

C connects Harbour to native extensions. Harbour's C API exposes functions to
xBase, converts arguments and returns values. The C ABI also connects functions
exported by Zig. The [C bridge](src/c/hbbridgezig.c) uses `HB_FUNC`,
`hb_parc` and `hb_retc` to call the
[Zig library](src/zig/runtime/hbbridgeruntime.zig).
The internal path is **Harbour ↔ C ↔ Zig**, within the server process.

### Zig: C interoperability and modern native development

Zig provides C interoperability, explicit errors, optional types, allocation
and resource ownership, and compile-time evaluation (`comptime`).
These features let native extensions evolve through the C ABI.
See the [official overview](https://ziglang.org/learn/overview/).

Zig has two roles: the Harbour/C toolchain (`hbmk2 -comp=zig`) and the language
for native extensions. The product links `hbbridge_zig` and exercises that
connection in `Health`. Its current response is demonstrative; functional
extensions will be introduced incrementally.

## Project direction

Project code focuses on service contracts, type conversion, configuration and
operation, reusing the native Harbour ecosystem:

- Serve Harbour through NETIO and Protheus through an interoperability adapter,
  sharing the same registered services.
- Reuse `hbnetio` RPC, remote files, multithreading, serialization and
  administration.
- Embed `hbhttpd` for HTTP/REST and hbBridge/NETIO web administration,
  reusing the shared service core and its permissions.
- Link core symbols with `HB_EXTERN`; authorize remote exposure separately.
- Reuse compilation of `.prg`/`.hb` and execution of `.hrb`.
- Start debugging with native `hbdebug`, adding optional HBDAP integration later.
- Prioritize MSSQL/ODBC and SQLite through `rddsql`/`SQLMIX`.
- Expose DBF RDD access over NETIO and VF IO (`hb_vf*`) for local/remote files.
- Extend database acceptance to PostgreSQL and MySQL/MariaDB as dependencies allow.
- Evolve logical blocks, negotiated compression and client-specific capacities.
- Support console and system-service operation with configurable addresses,
  ports, roots, concurrency and resource policies.
- Develop C/Zig extensions as the Harbour foundation stabilizes.

AppServer remains responsible for the Protheus environment. hbBridge extends
it through RPC and also serves Harbour applications, retaining xBase service
programming.

## Current implementation and acceptance

| Capability | Delivered state |
| --- | --- |
| TCP server | Multithreaded, configurable; default bind `0.0.0.0:1512`. Local clients use `127.0.0.1`. |
| Protheus client | `HBBridgeClient`, `HBBRIDGE/1`, JSON and memory gzip in both directions; one connection per call. AppServer `[hbBridge]` defaults with explicit argument overrides. Revised 16 configuration checks accepted by the operator on 2026-10-07, including explicit/empty/invalid profile selection. |
| Services | Shared versioned registry: `Health`, `Echo`, `ADDON.Execute`, `Core.Upper`, `Core.Version`, `Service.List`, `Admin.Status`, and `RPCRDD.Query` when SQL profiles exist. |
| Protheus RPC | Health, ADDON and two identical 200,000-byte Echo results accepted on 2026-10-03 and reconfirmed on 2026-10-04 and 2026-10-07; fragmented request gzip: 152,964 bytes. Windows clock test passed. |
| Addons | In-memory `.prg`/`.hb` compilation and `.hrb` execution through `ADDON.Execute`, receiving `module`/`params`. |
| NETIO | Embedded native listener `0.0.0.0:2941`, filtered RPC and Harbour serialization. `HB_EXTERN` enabled; registered services only. |
| HTTP/REST | Embedded `hbhttpd`, optional and disabled by default. JSON service calls and authenticated web status share the core; service/admin credentials are separate. Direct HTTPS requires an OpenSSL-enabled build and its own acceptance. |
| Protheus HTTP client | `HBBridgeHTTPClient` uses native FWRest, bearer authentication and the shared JSON contract. Operator accepted 13 checks on 2026-10-07, including SQL pagination; latest run: thread 25456, one second. HTTP SQL backend was not identified. |
| SQL | SQLMIX with SQLite/MSSQL-ODBC, named results and database-side pages. SQLite Protheus: 29 accepted checks on 2026-10-04, reconfirmed on 2026-10-07 with `profile=sqlite_demo`. Real MSSQL acceptance pending. |
| DBF | Native RDD access over NETIO planned; not integrated yet. |
| VF IO | Harbour `hb_vf*` with NETIO has binary read/write tests; TLPP facade pending. |
| C/Zig | C API/ABI bridge in Health; Zig library and toolchain required. |
| Limits | No application payload/wire ceiling by default; optional policies, buffers and deadlines. Runtime/API/AppServer/memory capacities still apply. Negotiation and logical blocks pending. |
| Operation | Coordinated console host, INI/JSON and CLI. Automatic adjacent `hbbridge.ini`; sanitized `--config-info`; admin `127.0.0.1:2940` when enabled. System services pending. |
| Syslog | UDP module exists but is not called in the active request lifecycle. |
| Debugging | Native hbdebug exists; product/addon debug profile and HBDAP integration pending. |

The latest complete Harbour run on 2026-10-06 passed **487 checks, zero failures,
no skips**, including HTTP, addon concurrency,
INI/JSON, real SQLite, pages, equivalent NETIO/TCP results, an exact
**24,000,000-byte Echo**, and JSON/gzip over 16 MiB in both directions.

The [evolution review](docs/evolution.md) records the 2026-10-07 proposals:
`THREAD STATIC` for worker-local state with explicit per-request initialization,
Zig as an optional HTTP adapter, external dependency resolution owned by
hb_compile and generic SQL result tables for native Protheus presentation.
The native thread-static probe passed 31 separate assertions. Zig HTTP,
automatic OpenSSL resolution and SQL materialization are still pending.

[Acceptance](docs/acceptance.md) records AppServer `24.3.1.5`, LIB `20260706`,
RPO/dictionary `12.1.2510`, and the Harbour/Zig reference build. The earlier
2026-10-04 operator report covered 13 configuration checks. On 2026-10-07,
after reported recompilation following the `.hb` migration, the operator
accepted renamed TLPP, all 16 revised configuration checks, clock/RPC,
29 paginated SQLite checks and 13 HTTP checks. Times/threads identify this
Windows regression; no compilation log, call arguments, effective destination
or artifact hashes were supplied. A nondefault destination, real MSSQL and
Linux still require their own acceptance.

## Intended architecture

~~~text
Protheus / AdvPL / TLPP    Harbour clients    HTTP clients / browser
          |                     |                      |
      HBBRIDGE/1            native NETIO        HTTP / REST / web admin
          |                     |                      |
 Protheus adapter          hbnetio adapter        hbhttpd adapter
          |                     |                      |
          +----------------- hbBridge ------------------+
                         |
             service/capability registry
          types / errors / context / authorization
                         |
        +----------------+------------------+
        |                |                  |
 Harbour/core      data and files       Harbour C API
 contribs/addons   SQL / DBF / VF IO          |
                                         C ABI ↔ Zig

Separate administration: 127.0.0.1:2940 when enabled
Hosting: console or service, sharing the same core
Build: Zig toolchain for Harbour/C + native Zig library
~~~

The host coordinates NETIO, Protheus and optional HTTP. Each adapter translates its
transport into the core; modules and queries need not understand the client's
protocol. Registry/configuration are shared, while each call owns its work
areas, connections, modules and other resources.

### One executable with internal modules

The reference deployment is **one hbBridge executable**, statically linking
`hbnetio` with `-lhbnetio`. Initialization, filtering, administration and
shutdown use `netio_Listen`, `netio_Accept`, `netio_RPCFilter` and
`netio_Server`. The host retains and joins its threads;
`netio_MTServer` detaches them. See the
[hbnetio APIs](https://github.com/harbour/core/blob/master/contrib/hbnetio/readme.txt).

A DLL can later enable independently updated extensions when its ABI/loading
lifecycle is justified. Separate processes can isolate specific workloads.
Neither is needed to embed NETIO. ODBC drivers/connectors remain dependencies.

`HBBRIDGE/1` belongs to Protheus; Harbour uses native NETIO. Changing a TLPP
client port to 2941 does not make it a NETIO client. Sharing a port would need
explicit multiplexing and interoperability tests.

### Networking, configuration and service operation

| Channel | Default bind | Port | Purpose |
| --- | --- | --- | --- |
| NETIO | `0.0.0.0` | `2941` | Harbour RPC and remote files. |
| Administration | `127.0.0.1` | `2940` | Management separate from application traffic. |
| Protheus | `0.0.0.0` | `1512` | `HBBRIDGE/1`, JSON/gzip. |
| HTTP/REST + web admin | `127.0.0.1` | `8080` | Optional `hbhttpd`, disabled until explicitly configured. |

NETIO/admin match `_NETIOSRV_IPV4_DEF`, `_NETIOSRV_PORT_DEF`,
`_NETIOMGM_IPV4_DEF` and `_NETIOMGM_PORT_DEF`.
`0.0.0.0` is a bind, not a client destination. Administration is disabled
without a password. See the
[upstream server](https://github.com/harbour/core/blob/master/contrib/hbnetio/utils/hbnetio/hbnetio.prg).

[INI](config/examples/hbbridge.ini) and [JSON](config/examples/hbbridge.json)
share schema/validation. Precedence is **defaults < one file < CLI**.
Without `-config`, look for `hbbridge.ini` beside the executable.
Paths from the file are file-relative; CLI paths remain working-directory-relative.
See [configuration](docs/configuration.md) and [Milestone 1](docs/milestone1.md).

| Setting | Default | CLI | Meaning |
| --- | --- | --- | --- |
| `protheusMaxPayloadBytes` | `0` | `-maxpayloadbytes=` | Optional expanded JSON ceiling; zero adds none. |
| `protheusMaxWireBytes` | `0` | `-maxwirebytes=` | Optional compressed-byte ceiling; zero adds none. |
| `protheusReadChunkBytes` | `65536` | `-readchunkbytes=` | I/O buffer bounded by socket/zlib APIs; not the message limit. |
| `protheusTimeoutMs` | `30000` | `-iotimeout=` | Per read/send phase budget; zero disables the Harbour deadline. |
| `netioTimeout` | `0` | `-netiotimeout=` | Zero maps to native `-1`; positive milliseconds. |
| `maxWorkers` | `64` | `-maxworkers=` | Operational concurrency per listener. |

Client defaults are in `[hbBridge]` of the active AppServer INI:
`Host`, `Port`, `TimeoutMs`, `MaxPayloadBytes`, `MaxWireBytes`,
`ReadChunkBytes`, `SQLProfile`.
[The template](config/examples/protheus-appserver.ini) documents them.
`HBBridgeConfig` uses `GetSrvIniName()`; `HBBridgeClient():New()` applies
explicit overrides afterward. No-argument tests use this section.
`SQLProfile` selects an alias; connections/credentials stay on hbBridge.

`HBBridgeRuntimeLimits()` reports string, C socket `long`, zlib `uInt`
chunk and NETIO `int` timeout capacities. The read buffer fits the smaller
socket/codec capacity; per-call capacities do not limit total logical volume.
Positive policies do not increase runtime capacity or memory. With a zero
server deadline, a client that neither completes nor disconnects can prolong
shutdown indefinitely.

Windows service operation will reuse the
[hbnetio/hbwin integration](https://github.com/harbour/core/blob/master/contrib/hbnetio/utils/hbnetio/_winsvc.prg).
Linux needs supervised operation. Startup, shutdown and recovery must share the
console core, use stable absolute paths and clean up cursors/streams/in-flight
calls. These system-service modes are not implemented.

### HTTP/REST and web administration

The optional `hbhttpd` listener serves the same registry as NETIO and Protheus.
GET `/api/v1/health` and `/api/v1/services` provide health/discovery; POST
`/api/v1/rpc` or `/api/v1/services/<service>` executes registered services with
JSON. Protheus continues to supply its resolved business inputs.

Configure `[HTTP]` in the server INI (or the equivalent JSON fields). Service
requests use a bearer credential from `HTTP.Password`; `/admin/` and
`/admin/status` use the separate `Admin.Password`, with username `admin`.
The web panel currently reports hbBridge and NETIO status; configuration,
session management and administrative mutations remain in the roadmap.

The managed build resolves `hbhttpd` and `hbtcpio`. `-hblib` is the `hbmk2`
library mode. `hbssl`/OpenSSL supports the optional direct TLS build path;
certificate/TLS/platform acceptance remains pending. A TLS reverse proxy is
another deployment option. See [HTTP setup and contracts](docs/http.md).

The [TLPP HTTP example](examples/http/README.md) uses
`HBBridge.Client.HBBridgeHTTPClient`, configured by `HTTPURL`, `HTTPToken`
and `HTTPTimeoutSeconds` in the active AppServer `[hbBridge]` section.
`U_HBBridgeHTTPTest()` covers GET Health/discovery, POST Health/Echo/addon,
401/403/404 errors, recovery and optional SQL pages through the existing
dataset. The earlier 2026-10-07 report used thread 25672. Later runs passed
all 13 checks: thread 27296 at 16:10:44–16:10:45 and thread 25456 at
16:15:03–16:15:04 (São Paulo), each in one second. Their HTTP SQL backend
was not identified; the separate TCP Query run explicitly used SQLite.

### Extensible capabilities

The registry describes names, versions, types, permissions, dependencies and
immediate execution. `Service.List` discovers channel-available services.
Batch/stream modes and optional dependency resolution evolve later.

| Intended capability | Foundation | Application |
| --- | --- | --- |
| xBase routines | Harbour core/contribs and PRG/HB/HRB addons. | Services familiar to Protheus developers. |
| Data processing | SQLMIX/connectors, DBF RDDs, NETIO. | Server-side queries/transforms, pages and aggregates. |
| Files/content | VF IO, NETIO, compression, ZIP. | Local/remote files and block transfers. |
| External integration | `hbcurl`, `hbexpat`, other contribs. | APIs/XML behind domain services. |
| HTTP services and web operation | `hbhttpd`, `hbtcpio`, optional `hbssl`/OpenSSL. | Shared REST services and authenticated administration. |
| Native processing | Harbour C API, C/Zig libraries. | Measured specialized transformations/calculations. |
| Long operations | Threads, NETIO streams, future job layer. | Submission, progress, results, cooperative cancellation. |

Contribs: [hbcurl](https://github.com/harbour/core/tree/master/contrib/hbcurl),
[hbexpat](https://github.com/harbour/core/tree/master/contrib/hbexpat),
[hbziparc](https://github.com/harbour/core/tree/master/contrib/hbziparc).

## Native RPC, HB_EXTERN and serialization

`HB_EXTERN` links symbols for runtime/module use; it does not authorize
arbitrary remote invocation. NETIO filtering admits the `HBBridge.Call`
gateway; the common registry controls exposure. Version, types and channel
permissions apply to both adapters.

Harbour clients receive native values. NETIO already serializes arguments and
results, so the bridge must not JSON-encode or serialize them twice. See
[NETIO client](https://github.com/harbour/core/blob/master/contrib/hbnetio/netiocli.c).

Explicit serialized blocks may use `hb_Serialize()`/`hb_Deserialize()`.
`HB_SERIALIZE_COMPRESS` is separate from NETIO connection compression; avoid
redundancy. References:
[serialization](https://github.com/harbour/core/blob/master/src/rtl/itemseri.c),
[options](https://github.com/harbour/core/blob/master/include/hbserial.ch).

Tests preserve dates, timestamps and binary bytes. Classes/symbols/special
references need their own rules; pointers do not become remote resources by
serialization. Cursors/jobs need owned identifiers, opening, expiry and closure.

NETIO capacities include 64-byte passwords, 8,192 open files per connection,
and `uint32` lengths in some RPC/stream units. These differ from Protheus
decimal frame length and total operation volume. See the
[embedded transport](src/hb/transports/netio/README.md).
Data/item streams will be evaluated for incremental results/progress; enabling
streams alone does not bound memory.

### Selective TRPC reuse

`contrib/xhb/trpc.prg` offers function-registration/description, executor,
progress and cancellation ideas. Its `XHBR` protocol is different and will not
be a mandatory third transport. The [review](docs/harbour-vfio-trpc.md) records
restrictions and extraction criteria. Analysis was static; no upstream TRPC
class was incorporated.

## Addons and data access

The upstream hbnetio utility's `-rpc=<file>` loads HRB or compiles PRG/HB,
dispatching through `HBNETIOSRV_RPCMAIN`.
See its [example](https://github.com/harbour/core/blob/master/contrib/hbnetio/utils/hbnetio/rpcdemo.hb).

hbBridge `ADDON.Execute` receives
`{"module":"examples/hbbridgesampleaddon.hb","params":{...}}`.
[The loader](src/hb/addons/hbbridgeaddon.hb) compiles in memory using
`hb_compileBuf`; HRB uses `hb_hrbLoad`/`hb_hrbDo`/`hb_hrbUnload`,
with symbols/statics isolated between simultaneously active HRBs. Harbour may
retain STATIC values when reusing an unloaded module; initialize per-call state
from explicit parameters. Modules resolve under `addonRoot`.
NETIO exposes the same service. Publishing, versions, trust and live updates
remain pending.

### SQL: RPCRDD.Query with database-side pages

| Database/interface | Harbour components |
| --- | --- |
| MSSQL/ODBC — priority | `sddodbc` + `rddsql`/`SQLMIX`; direct `hbodbc` when needed and installed ODBC driver. |
| SQLite — priority | `sddsqlt3` + SQLMIX; direct `hbsqlit3` when needed. |
| PostgreSQL — later | `sddpg` + SQLMIX; `hbpgsql` when needed. |
| MySQL/MariaDB — later | `sddmy` + SQLMIX; validate client/server versions. |

References: [rddsql](https://github.com/harbour/core/tree/master/contrib/rddsql),
[sddodbc](https://github.com/harbour/core/tree/master/contrib/sddodbc),
[sddsqlt3](https://github.com/harbour/core/tree/master/contrib/sddsqlt3),
[sddpg](https://github.com/harbour/core/tree/master/contrib/sddpg),
[sddmy](https://github.com/harbour/core/tree/master/contrib/sddmy).

Clients send `alias`/`sql`; credentials/paths stay on the server.
[SQLite](config/examples/sqlite.json) and [MSSQL](config/examples/mssql.json)
INI/JSON examples exist. SQLite was the first real regression; MSSQL requires
the actual driver's/DSN's acceptance. Only configured profiles advertise SQL.

Results are named hashes for `header`/`rows`, with `rowCount`,
`driver`/`resultVersion`. [HBBridgeRPCDataSet](src/tlpp/hbbridgerpcdataset.tlpp)
uses `JSONObject`, named-field access, navigation, closure and identified errors.
`U_HBBridgeQueryTest` passed at 00:40:06 on 2026-10-04 for `sqlite_demo`:
29 checks including decimals, empty results, errors/recovery, pages, EOF/closure.

~~~powershell
pwsh ./examples/sql/run.ps1
pwsh ./examples/sql/run.ps1 -Config config/examples/mssql.ini -Profile mssql_demo
~~~

The [SQL launcher](examples/sql/README.md) supports `-Config`, `-Profile`,
`-Port`, `-MaxWorkers` and uses the same product.

Optional `page = {number, size, orderBy}` uses `ROW_NUMBER()`/`BETWEEN`,
following the reviewed REST example. The database returns up to `size+1`
rows: the sentinel determines `hasNext`, and the response exposes at most
`size`. TLPP methods include `OpenPage`, `NextPage`, `HasNextPage`,
`PageNumber`, `PageSize`. Use a unique ordering tie-breaker. Each page is a
new query, not a snapshot.

No arbitrary row ceiling applies; ordinals must remain exact JSON/TLPP
integers. Pagination limits bridge rows but deep pages may still sort/scan
extensively. The [contract](docs/milestone3-sql.md) details order grammar,
types/nulls, errors and lifecycle. Bound parameters, cursors, transactions,
cancellation, SQL timeouts and incremental BLOBs remain pending.

### Portable SQL credentials

Current profiles accept connection strings; **encrypted password storage and
a credential utility are not implemented**. Integrated authentication uses
the hbBridge process identity; a DSN is not a credential vault.

The proposed Windows/Linux format keeps public connection settings and a
versioned encrypted password envelope in INI/JSON, with a separate key provider.
A protected external key file can serve both platforms; environment/vault
providers can be added. OS credential managers remain optional. A compiled
fixed key or a key beside the ciphertext is not the design.

A local utility and future UI should share the same core/format, prompt without
displaying passwords, and update/remove/test credentials. Protheus sends only
a profile alias. See [configuration](docs/configuration.md#portable-credential-storage)
and the [credential design](docs/credentials.md).

### DBF over NETIO and Harbour VF IO

Harbour `net:` paths redirect file I/O while preserving native RDD semantics.
DBF acceptance must cover indexes/memos, navigation, reads/writes, locks,
concurrency and closure. TLPP needs a facade; it does not speak NETIO.
DBF is a distinct data capability from SQL `RPCRDD.Query`.

File services will use `hb_vfOpen`, `hb_vfRead`/`hb_vfWrite`,
`hb_vfReadAt`/`hb_vfWriteAt`, `hb_vfSeek`, `hb_vfSize`,
`hb_vfClose`, plus provider directories/metadata/locks.
Harbour can use them directly for local/`net:` paths.
Proposed TLPP `Files.*` uses session-owned opaque IDs, blocks, byte counts,
EOF/errors and explicit closure. VF pointers/OS descriptors stay in their
process. C/Zig can use buffers or C `hb_file*`. Whole-file
`hb_vfLoad`/`hb_vfSave` only suits content within a measured budget.
See [VF IO/TRPC](docs/harbour-vfio-trpc.md).

## Current contract and compression

~~~json
{"service":"Echo","params":{"message":"Protheus connected to Harbour"}}
~~~

Before compression:

~~~text
HBBRIDGE/1|JSON|<JSON-byte-length>\n<JSON-payload>
~~~

Signature/codec/length are validated before dispatch.
[Shared constants](includes/hbbridge.h) identify the frame version; this is
not capability negotiation. The whole frame is gzip-compressed. Declared length
covers expanded JSON only and differs from socket length.
Canonical decimal length must match actual body length; there is no eight-digit
or 128-byte-header ceiling.

| Direction | Compression | Decompression |
| --- | --- | --- |
| Protheus → Harbour | TLPP `GzStrComp`. | Incremental C zlib. |
| Harbour → Protheus | Incremental C gzip. | TLPP `GzStrDecomp`. |

The [client](src/tlpp/hbbridgeclient.tlpp) and
[framing](src/hb/transports/protheus/hbbridgeframing.hb) use memory buffers,
without temporary files or `GzCompress`/`GzDecomp` file APIs.
The decoder/[compressor](src/c/hbbridgecompressor.c) preserve zlib state across
chunks, validate CRC/trailer and exact payload length. No fixed 16 MiB ceiling
remains.

Each call uses one gzip unit per direction and one connection. Harbour decodes
incrementally; TLPP collects bytes until EOF then calls `GzStrDecomp` once.
Both handle positive partial sends. Normal Protheus flow and low-compressibility
Echo were accepted. Timeout/failure and forced partial-send paths still need
AppServer acceptance.

Constructor: `New(cHost, nPort, nTimeout, nMaxPayloadBytes, nMaxWireBytes,
nReadChunkBytes)`. Arguments are optional; default positive client deadline:
30 seconds. Indefinite TOTVS waits remain unvalidated. Budgets default zero;
reads default 64 KiB.

`HBBridge.Client.HBBridgeTime` in
[hbbridgetime.tlpp](src/tlpp/hbbridgetime.tlpp) uses `TimeCounter()`,
adapted from `dna.tech.StopWatch.__GetCurrentTimeStamp()`.
It avoids `Date()`/`Seconds()` and an artificial one-day ceiling.
[Issue #12](https://github.com/naldodj/totvs-protheus-open-issues/issues/12)
reproduces Windows milliseconds versus fractional Linux seconds; Unix values
are multiplied by 1,000. A counter regression expires the budget.
The test checks scale/advance over `Sleep(1000)`, including detecting a future
runtime unit correction.

The 2026-10-04 Windows operator report recorded raw `1097.692700`, normalized
`1097.773500 ms`, result `OK`. The 2026-10-07 run at 16:14:31, thread 27084,
reconfirmed `OK`: raw `1089.987500`, normalized `1090.088100 ms`.
Full monotonic/wrap behavior and Linux remain pending. Harbour uses
`HBBridgeMonotonicMs()` for deadlines/uptime.

`GzStrComp`/`GzStrDecomp` require complete strings and actual AppServer
`MAXSTRINGSIZE`/memory. TOTVS exposes no expansion allocation budget; checking
afterward cannot bound allocation. `TSocketClient:Send` has no timeout argument,
so blocking sends can exceed the caller budget. JSON remains materialized on
both sides. Incremental gzip is not logical block streaming.
See [Milestone 2](docs/milestone2-framing.md).

## Contract and transfer evolution

Service semantics remain shared, with native values over NETIO and an
interoperable representation for Protheus. Service and transport versions differ.

### Negotiation and types

Start Protheus connections with a small known uncompressed capability exchange:
version, codec, compression, block size, transfer modes.
Harbour discovers services after NETIO's native handshake.
Peers advertise enforceable capacities; unknown AppServer limits require an
explicitly accepted deployment profile.

| Element | Required semantics |
| --- | --- |
| Call | ID, service/version, parameters, context, execution deadline. |
| Response | Correlation, success/result/metadata, error code/origin/retry semantics. |
| Types | Null/empty, logical, integer, decimal/currency, date/timestamp, text, binary, arrays/hashes and explicit conversions. |
| Text/numbers | Encoding, byte count, precision, timezone/date rules. |
| Resources | Session/cursor/stream/job IDs, expiry, closure, cooperative cancellation. |
| Results/versions | Versioned Health/Echo/ADDON/dataset behavior and identifiable incompatibility. |

Future framing identifies each block's call, version, codec/compression,
wire and expanded lengths. Validate the exact format with both peers before
implementation; `Receive` boundaries are not messages. A call ID alone does not
make retry safe: mutations require idempotency or previous-result lookup.

### Persistent connections and context

The [review](docs/transports-sessions-security.md) recommends framing first,
sequential connection reuse, then a bounded pool.
Concurrent use of one socket additionally needs correlation, one reader,
coordinated writes and flow control. Persistence reduces handshakes/ephemeral
ports but idle connections still consume resources.

Use native `hb_socketSetKeepAlive`/`hb_socketSetNoDelay`.
OS keepalive does not replace deadlines/heartbeats. Measure `TCP_NODELAY`;
reconnect with backoff/jitter without repeating mutations of unknown outcome.

Use **per-call isolation and explicit session state**: verified identity,
authorized opaque caller context, correlation/deadline. Protheus resolves
company/branch and ERP rules before the call. Clean work areas, transactions
and buffers even on failure. Cursor/transaction/VF handles need owners,
expiry and closure. IDs do not grant durability/process portability.
Resumption/load balancing require authentication and owner routing.
Jobs survive restart only when persisted.

### TLS, JWT and optional transports

| Proposal | Direction |
| --- | --- |
| Protheus TLS | Test `TSSLClient` ↔ `hbssl`/OpenSSL with certificate/hostname validation. |
| JWT | Optional authentication/authorization over protected transport, checking signature, issuer, audience, time and scope. |
| `tSktSslSrv`/`tSktSslConn` | Reserve for concrete inbound-Protheus requirements. |
| `tGrpc` | Investigate predefined Smartlink contract; arbitrary `.proto` support unproven. |
| `tAMQP` | Optional RabbitMQ AMQP 0.9.1 jobs/events, idempotency and recovery. |
| Zig transport | Reuse libraries through C ABI; measure before replacing Harbour baseline. |

References: [TSSLClient](https://tdn.totvs.com/display/tec/Classe+TSSLClient),
[tJWT](https://tdn.totvs.com/display/tec/tJWT),
[tGrpc](https://tdn.totvs.com/display/tec/tGrpc),
[tAMQP](https://tdn.totvs.com/display/tec/tAMQP),
[JWT RFC 8725](https://www.rfc-editor.org/rfc/rfc8725.html).

Signed JWT is not payload encryption. All adapters share catalog/context/errors.
RabbitMQ is optional. gRPC/AMQP/callbacks do not block SQL, VF IO or the Protheus
contract. Zig remains both toolchain and extension language.

### Logical volume, memory and compression

Pages/blocks/streams can exceed individual string/message capacity without
pretending memory is unlimited.
[MaxStringSize](https://tdn.totvs.com/pages/viewpage.action?pageId=161349793)
depends on AppServer build/config. Account for expansion, JSON/base64, temporary
buffers and copies in each block.

Separate technical peer limits, connection/process budgets and total operation
volume. Bound expanded/in-flight blocks; provide backpressure/deadlines/closure.
Concatenating all TLPP blocks into one string still hits `MAXSTRINGSIZE`.
Single-value services must declare their materialization requirement and fail
clearly when the peer cannot receive it.

Negotiate `none`/`gzip`, with optional measured automatic selection by
size, compression gain, CPU/latency. Small/already compressed data may remain
uncompressed. Each gzip block must decode independently and fit Protheus limits.
Test empty/binary data; distinguish gzip from zlib/raw DEFLATE.
References: [GzStrComp](https://tdn.totvs.com/display/tec/GzStrComp),
[GzStrDecomp](https://tdn.totvs.com/display/tec/GzStrDecomp).

Declared expanded length does not enforce allocation bounds.
Validate expansion/memory; APIs without bounded expansion may require trusted
blocks or `none`. NETIO uses its native compression, without Protheus headers.
Evaluate `HB_SERIALIZE_COMPRESS` separately to avoid duplication.
Measure local/remote, JSON/binary and different compression ratios.

## Source organization and standards

Reusable components live in `src/`, with one server/entry point.
[examples/mvp](examples/mvp/README.md) is a minimal launcher for the same
product/clients/addon; its name records its origin. Old proofs of concept remain
in Git history.

~~~text
hb.bridge/
|-- .hbcommit/                         # Harbour validation/commit tools
|-- src/hb/host/                       # Entry, configuration, lifecycle
|-- src/hb/core/                       # Versioned registry/Harbour values
|-- src/hb/transports/netio/            # Native RPC/files
|-- src/hb/transports/protheus/         # TCP adapter/HBBRIDGE framing
|-- src/hb/transports/http/             # Native hbhttpd REST/web adapter
|-- src/hb/services/                   # Builtins/discovery/SQL
|-- src/hb/addons/                     # Compilation/loading
|-- src/hb/telemetry/                  # Existing Syslog
|-- src/c/                            # Harbour API/gzip/C ABI
|-- src/zig/runtime/hbbridgeruntime.zig
|-- src/tlpp/hbbridgeclient.tlpp        # HBBridgeClient
|-- src/tlpp/hbbridgehttpclient.tlpp    # HBBridgeHTTPClient
|-- src/tlpp/hbbridgeconfig.tlpp        # HBBridgeConfig
|-- src/tlpp/hbbridgetime.tlpp          # HBBridgeTime
|-- src/tlpp/hbbridgerpcdataset.tlpp    # HBBridgeRPCDataSet
|-- src/tlpp/tests/protheus/            # U_ test entry points
|-- addons/examples/
|-- config/dependencies.json           # Managed dependency manifest
|-- config/patches/                    # Managed patches against pinned sources
|-- config/examples/                   # Server/client INI/JSON
|-- examples/{mvp,sql}/                # Product launchers
|-- tests/{unit,contract,integration}/
|-- docs/                             # English and pt-BR pairs
|-- scripts/                          # Bootstrap/build/run/tests
|-- hbbridge.hbp                       # Product entry/common components
|-- hbbridge.hbm                       # Components shared with tests
`-- build.zig                          # Zig library
~~~

[Reorganization](docs/reorganization.md) preserves historical paths/baselines.
The test build reuses `hbbridge.hbm` with its own entry. Protheus tests remain
under `src/tlpp/` for compilation together.

Own source uses **four spaces**, English identifiers and lowercase filenames.
**Functions, procedures, methods, namespaces and classes use PascalCase**,
explicitly chosen by the project owner:
`HBBridgeClient` ↔ `hbbridgeclient.tlpp`.
Project-owned Harbour sources use `.hb`, Protheus sources use `.tlpp`, and
compiled Harbour addons use `.hrb`. Related Harbour/TLPP/C/Zig modules share
the same basename convention; extensions identify the language.
Ordinary `.hbp` builds keep their existing workflow. `ADDON.Execute` still
accepts `.prg` sources for compatibility alongside `.hb` sources and `.hrb`
modules.
Standard repository filenames retain conventional spelling; docs have English
canonical files and `.pt-BR` counterparts.
Preserve vendor formatting/notices. See [standards](docs/standards.md).

Prefer Harbour hashes for named records/configuration/metadata.
TLPP uses [JSONObject](https://tdn.totvs.com/display/tec/Classe+JsonObject) for
JSON contracts and [THashMap](https://tdn.totvs.com/display/tec/Classe+THashMap) /
[HashMap functions](https://tdn-homolog.totvs.com/pages/viewpage.action?pageId=77300615)
for suitable internal maps. Arrays need a concrete API/contract requirement,
considering allocation/copy/lookup cost; a sequence alone is insufficient.

Public Protheus APIs are namespaced classes; stateless utilities use static
methods. Tests retain `U_` entries. `User Function Name` preprocesses to
`U_Name`; existing `procedure U_HBBridgeConnectionTest` needs no conversion.
File-local helpers may use `Static Function`. See [AGENTS](AGENTS.md).

Commits must pass `.hbcommit/check.hb`, `.hbcommit/commit.hb` and
`.hbcommit/3rdpatch.hb`. The managed Harbour build supplies `hbrun`;
there is no need for a separate `bin/harbour` runtime.
Preserve the tools' upstream licenses.

## Debugging: hbdebug first, optional HBDAP later

Use [native hbdebug](https://github.com/harbour/core/tree/master/src/debug) for
breakpoints, stepping, stack/variables in an explicit development-console
profile. Compile Harbour with `-b`, link the debugger and retain matching
sources, including in-memory PRG/HB and external HRB.
Current `hbbridge.hbm`/loader do not enable `-b`; installed hbdebug is not
accepted integration. `hbmk2 -debug` is for native C debug information.

Validate one controlled worker/call, pausing in a handler/addon, inspecting and
resuming until the response. Define terminal/GT, RPC timeout effects and resource
cleanup. Services must not require interactive debugging.

Private experimental **HBDAP**, locally `F:\GitHub\hbdap`, adapts Harbour
debugging to DAP. This is a development reference, not an installation dependency.
The optional VS Code **Harbour DAP** extension, locally
`F:\GitHub\hbdap-vscode-extension`, registers `harbour-dap`.
Intended flow: **VS Code → extension → HBDAP → hbdebug in hbBridge**.
Other DAP/CLI clients can use HBDAP.

VSIX packages editor integration; runtime/library/adapters are separate.
Pin compatible runtime patches/hooks, toolchain and revisions; validate real
handler/addon launch/attach and HRB load/unload. HBDAP's own tests do not prove
hbBridge worker control.

Keep debug traffic separate from RPC/admin, explicitly enabled and controlled.
Logs must not corrupt DAP framing. External development adapters preserve the
single-product-executable design. Test breakpoints, stepping, stack, variables
and disconnect. AdvPL/TLPP uses AppServer debugging; C/Zig uses native symbols.
Correlation helps trace boundaries without promising cross-runtime stepping.

## Independent build and dependencies

[scripts/bootstrap.ps1](scripts/bootstrap.ps1),
[scripts/toolchain.ps1](scripts/toolchain.ps1) and
[config/dependencies.json](config/dependencies.json) resolve a managed
`hb_compile` checkout and build hbBridge's own Harbour runtime/tools.
The product does not require a fixed `C:\GitHub\hb_compile` installation.

~~~powershell
pwsh ./scripts/bootstrap.ps1
pwsh ./scripts/build-hbbridge.ps1
pwsh ./scripts/test-hbbridge.ps1
~~~

See [dependencies](docs/dependencies.md) and [scripts](scripts/README.md) for
arguments/profiles/tool locations and external SDKs.
Zig runs `zig build` and `hbmk2 -comp=zig`; the managed `hbrun` also runs
commit gates. Protheus compilation requires a configured proprietary
AppServer/TLPP environment, not a downloadable Harbour dependency.

Use [the common launcher](scripts/run-hbbridge.ps1) or
[the minimal example](examples/mvp/run.ps1), compile TLPP and execute
`U_HBBridgeConnectionTest()`. It exercises Health/Echo and default-enabled
ADDON with `examples/hbbridgesampleaddon.hb`.
The launcher sets the working directory for `addons/examples/`.
See [test instructions](tests/README.md).

## Operation, licensing and contributions

[Syslog](src/hb/telemetry/hbbridgesyslog.hb) sends UDP to `127.0.0.1:514`
but is not integrated into lifecycle/RPC yet.
Broader identity/token policies, credential management, module trust and deployment policies
remain work. The next SQL acceptance is real MSSQL/ODBC; blocks, DBF, TLPP VF,
services, jobs/batches and functional C/Zig extensions follow incrementally.
Discover only delivered capabilities; metrics for correlation, latency,
wire/expanded bytes, memory/errors/resources guide concurrency/compression.

No global license is adopted. The [proposal](docs/licensing.md) recommends
MIT for original code, preserving dependency terms, after resolving loader,
clock and upstream commit-tool provenance.
Existing public-domain/third-party notices remain in force.

## ⭐ Support the project

[![Stars](https://img.shields.io/github/stars/naldodj/hb.bridge?style=social)](https://github.com/naldodj/hb.bridge)
![Clones](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/naldodj/hb.bridge/refs/heads/main/clone-badge.json)

## 💼 Corporate support and specialist consulting

**DNA Tech** offers corporate services for organizations using TOTVS Protheus:

- **Advanced support/architecture:** complex customization incidents and architectural guidance.
- **Database/routine tuning:** queries, locks and SQL Server/Oracle/PostgreSQL performance.
- **REST integration/modernization:** APIs, automation and migration to TL++.
- **Engagements:** monthly retainers with SLA or fixed-scope projects.

[LinkedIn](https://www.linkedin.com/in/naldodj/) •
[Email](mailto:marinaldo.jesus@gmail.com) • [BlackTDN](https://blacktdn.com.br)

<img width="1024" height="1024" alt="dna_tech_logo_black_panter" src="https://github.com/user-attachments/assets/9b39a407-31ca-4a86-a1df-f76790e2036a" />
