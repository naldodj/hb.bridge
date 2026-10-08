# Documentation

[Português (Brasil)](README.pt-BR.md)

hbBridge brings Harbour, C and Zig capabilities to Protheus and native Harbour
clients. [The main README](../README.md) separates current implementation from
the intended architecture; [TODO](../TODO.md) tracks delivery and acceptance.

| Guide | Scope |
| --- | --- |
| [Active work package](../WIP.md) | Current scope, next task, decisions, completion evidence and renewal; first package is real MSSQL acceptance. |
| [Architecture](architecture.md) | Generic executor boundary, caller-resolved ERP context and multiple explicit database profiles. |
| [Milestone 1](milestone1.md) | Shared registry, embedded NETIO, host lifecycle/configuration/admin. |
| [Milestone 2](milestone2-framing.md) | HBBRIDGE/1, incremental server gzip, complete TLPP reads and runtime capacities. |
| [Milestone 3](milestone3-sql.md) | SQLMIX, SQLite/MSSQL profiles, named dataset and database-side pages. |
| [Dataset](dataset.md) | Field/header access, automatic sequential paging and pending UTF-8/FLOAT integrity corrections. |
| [Configuration](configuration.md) | Server INI/JSON/CLI, AppServer client section and sanitized metadata. |
| [HTTP and web administration](http.md) | Native hbhttpd, shared HTTP/JSON services, authenticated status panel and optional TLS. |
| [TLPP HTTP example](../examples/http/README.md) | FWRest client, AppServer settings, bearer, generic RPC and paginated SQL dataset. |
| [Acceptance](acceptance.md) | Operator/environment evidence, historical builds and pending scenarios. |
| [VF IO/TRPC](harbour-vfio-trpc.md) | Native file API and selective upstream design reuse. |
| [Transports/sessions/security](transports-sessions-security.md) | Persistence/context, TLS/JWT, gRPC restrictions and optional AMQP. |
| [Reorganization](reorganization.md) | Source responsibility map and before/after evidence. |
| [Standards](standards.md) | Four spaces, lowercase filenames, PascalCase functions/methods/namespaces/classes, maps and commit gates. |
| [Dependencies](dependencies.md) | Managed hb_compile/Harbour/toolchain bootstrap. |
| [Evolution review](evolution.md) | THREAD STATIC, optional Zig HTTP, upstream dependency resolution and tables for Protheus presentation. |
| [Credentials](credentials.md) | Portable protection of SQL, NETIO, admin and HTTP secrets on server and clients; implementation pending. |
| [Licensing](licensing.md) | Proposed original-code license and unresolved provenance. |

Every guide has an English canonical file and a Portuguese `.pt-BR` counterpart.

## Implemented product contract

[HBBridgeClient](../src/tlpp/hbbridgeclient.tlpp) sends JSON `service`/`params`
to the Protheus endpoint, default bind `0.0.0.0:1512` (loopback client:
`127.0.0.1`). NETIO shares the same dispatcher.
Health uses the Zig library, Echo returns parameters, ADDON.Execute compiles/
loads modules with `module`/`params`.

~~~text
HBBRIDGE/1|JSON|<JSON-byte-length>\n<JSON-payload>
~~~

The entire frame is gzip-compressed. JSON identifies representation; inner
length counts expanded JSON only. Client/server use this one version, with
one connection per call and server EOF after response.
[Shared constants](../includes/hbbridge.h) are not capability negotiation.

| Direction | Compression | Decompression |
| --- | --- | --- |
| Protheus → Harbour | GzStrComp. | Incremental C zlib. |
| Harbour → Protheus | Incremental C gzip. | GzStrDecomp. |

No temporary files/GzCompress/GzDecomp file API is used.
There is no application 16 MiB, eight-digit or 128-byte-header ceiling.
Canonical decimal length is compared to actual body.
Payload/wire defaults zero; read buffer 65,536; server phase budget 30 seconds,
zero disables its deadline. Runtime socket/zlib/string capacities remain.
The read buffer is not the total message limit.

Server deadlines/uptime use `HBBridgeMonotonicMs()`; TLPP uses static
`HBBridge.Client.HBBridgeTime` and normalized `TimeCounter()`.
[Issue #12](https://github.com/naldodj/totvs-protheus-open-issues/issues/12)
reproduces Unix seconds versus Windows milliseconds.
The operator confirmed Windows raw 1097.692700 / normalized 1097.773500 ms
after Sleep(1000), result OK. Linux/extended wrap behavior remains pending.
TOTVS whole-string gzip still depends on MAXSTRINGSIZE/memory; decompression
does not expose an allocation bound. JSON is fully materialized; logical
blocks, handshake, negotiated none/gzip and failure acceptance remain pending.

## Native Harbour integration

One process embeds hbnetio RPC/files and the Protheus adapter.
Harbour uses NETIO, not the Protheus frame.
The core handles native values, versioned registry, types and channel
permissions. `HBBridge.Call` exposes registered services; Service.List shares
discovery metadata. SQL uses SQLMIX plus sddsqlt3/sddodbc.

NETIO performs serialization; explicit hb_Serialize/hb_Deserialize with
HB_SERIALIZE_COMPRESS can carry binary blocks when required.
Native tests preserve dates, timestamps and binary data.
NETIO timeout zero maps to native -1; passwords are at most 64 bytes,
8,192 files per connection and some RPC/stream units have uint32 lengths.
See [NETIO notes](../src/hb/transports/netio/README.md).

SQLite Protheus acceptance passed 29 checks on 2026-10-04.
Configuration acceptance passed 13, including activeAppServerIni, with
Health/ADDON/Echo. Those historical reports did not prove MSSQL or post-refactor
compilation. The [acceptance record](acceptance.md) includes the later
2026-10-08 MSSQL/SQLite TCP and HTTP runs and their remaining limitations.

## Syslog and further documentation

[The Syslog module](../src/hb/telemetry/hbbridgesyslog.hb) is linked and can send
UDP to 127.0.0.1:514; active host/RPC flow does not call its open/write/close
functions. Integration and collector acceptance remain work.
Protocol, addon API and deployment guides will expand as behavior stabilizes.
