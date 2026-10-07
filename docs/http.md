# HTTP services and web administration

[Português](http.pt-BR.md)

hbBridge uses Harbour's **hbhttpd** inside the same executable as NETIO and
the Protheus TCP adapter. The [HTTP adapter](../src/hb/transports/http/hbbridgehttp.prg)
authenticates requests and invokes the existing versioned registry. HTTP
does not duplicate Health, addons or SQL executors and does not interpret
Protheus tenant/company/branch/xFilial/table rules; callers provide explicit
parameters. See [architecture](architecture.md).

## Enable HTTP

HTTP is disabled by default. Its configured bind is `127.0.0.1:8080`, with
no default password. Use a private installation INI based on
[hbbridge.ini](../config/examples/hbbridge.ini), then start the product with
`./scripts/run-hbbridge.ps1 -Config <private-configuration>`:

```ini
[HTTP]
Enabled=true
Host=127.0.0.1
Port=8080
Password=<service-secret>
TLS=false
Certificate=
PrivateKey=

[Admin]
Password=<different-admin-secret>
```

Replace the placeholders locally. `Enabled` and `TLS` accept `true`/`false`
in INI, logical values in JSON. JSON names are `httpEnabled`, `httpHost`,
`httpPort`, `httpPassword`, `httpTLS`, `httpCertificate`, `httpPrivateKey`.
CLI `-httphost=`/`-httpport=` override the bind; activation and secrets remain
file settings. Defaults < one file < CLI applies. Certificate/key paths
are relative to the configuration file. Port conflicts prevent startup;
partial startup rolls back the other listeners. The shared `maxWorkers`
setting controls hbhttpd's worker ceiling instead of its original fixed 50.

HTTP activation requires its own nonempty service secret. When administration
is enabled, the service and admin secrets must differ. Setting `adminPassword`
also enables the existing NETIO administration endpoint; web administration
uses that same explicit admin credential. `--config-info` exposes HTTP
enabled/bind/TLS metadata and excludes secrets and certificate/key paths.

## Routes and authorization

| Route | Method | Authorization | Body / result |
| --- | --- | --- | --- |
| `/api/v1/health` | GET | `Bearer <service-secret>` | Shared Health result. |
| `/api/v1/services` | GET | Service bearer | Permitted service discovery. |
| `/api/v1/rpc` | POST | Service bearer | JSON envelope: `service`, `params`, optional `version` (default 1). |
| `/api/v1/services/<service-name>` | POST | Service bearer | JSON body is the service's parameters; version 1. |
| `/admin` or `/admin/` | GET | Basic, user `admin` and admin secret | Read-only web status page. |
| `/admin/status` | GET | Admin Basic | Shared Admin.Status JSON. |

Send `Content-Type: application/json` for POST. Use uncompressed UTF-8
JSON with an HTTP `Content-Length` in bytes; the Protheus `HBBRIDGE/1` header/gzip
frame does not belong to HTTP. This first adapter does not implement HTTP
request gzip, response compression negotiation or chunked request decoding.
Transfer-Encoding requests are rejected before body parsing/dispatch.
Service names and JSON fields preserve their published case.
Authentication scheme names are case-insensitive; credential bytes remain
case-sensitive. The admin username is `admin`.

The HTTP boundary validates UTF-8 before dispatch. Raw supplementary
characters and JSON escaped surrogate pairs produce the same text, including
object keys. Normalization stays inside HTTP JSON strings and preserves
escaped backslashes/quotes; it does not modify Harbour's global JSON codec or
the TCP adapters. Orphan or reversed surrogate escapes return
`INVALID_JSON`/400 before execution. Invalid raw UTF-8 returns
`INVALID_UTF8`/400; a service returning invalid UTF-8 text receives
`INVALID_UTF8_RESULT`/500.

```json
{
    "service": "RPCRDD.Query",
    "params": {
        "alias": "mssql/pData",
        "sql": "SELECT 1 AS CALLER_VALUE"
    }
}
```

The profile must exist on the server; SQLProfile in the AppServer INI is
not involved in an HTTP request. Each request chooses its own opaque alias.
The same route can invoke Echo, ADDON.Execute or other registered data
services. Data credentials cannot invoke Admin.Status or access `/admin`;
missing admin credentials disable web administration. Unauthorized requests
return 401, disabled administration 403 and unsupported media 415. Wrong
GET/POST usage on an adapter route returns 405. The native hbhttpd parser
supports GET/POST; other verbs can return its native 501 before the adapter.
Service failures retain the common structured `success/error/code`
result with the adapter's corresponding HTTP status.
Malformed HTTP headers are rejected by hbhttpd before the adapter and may
return its native HTML error body; clients should inspect the response
Content-Type before decoding JSON.

The web page shows uptime, endpoint bind/running/active state and HTTP
request/rejection counters, including the embedded NETIO endpoints. It
does not yet manage users, credentials, files, SQL profiles, connections or
remote shutdown. Those actions need separate authorized contracts and tests.

## Protheus HTTP client

The [TLPP example](../examples/http/README.md) uses
`HBBridge.Client.HBBridgeHTTPClient` and `U_HBBridgeHTTPTest`, built with the
same `src/tlpp/` tree. FWRest issues GET/POST with the service bearer, while
`HBBridgeRPCDataSet` reuses its existing SQL page contract over HTTP.
The operator accepted 13 checks on 2026-10-07; see [acceptance](acceptance.md).

Request text follows the AppServer encoding and is converted with EncodeUTF8.
Parsed response strings retain UTF-8; the accent comparison converts that
specific field with DecodeUTF8. FWRest's observed unauthorized behavior uses
a compatibility fallback; it does not preserve the server's JSON body in
that case. Broader Unicode/other LIBs and HTTPS need their own acceptance.

## Dependencies and TLS

The managed bootstrap builds **hbhttpd** and **hbtcpio** from the pinned
Harbour source. hbhttpd owns HTTP parsing, sockets and its pool; hbtcpio
provides the native TCP VF IO extension for subsequent file/transport use.
`-hblib` is hbmk2's library build mode, not a separate Harbour contrib.
See [dependencies](dependencies.md).

[The reviewed hbhttpd patch](../config/patches/hbhttpd.patch) exposes the raw
request body as `REQUEST_BODY`, makes `MaxWorkers` configurable and rejects
unsupported Transfer-Encoding requests with HTTP 400 and connection closure.
It rejects duplicate/nondecimal Content-Length fields, reports listener
readiness after startup, enables address reuse and
checks stop requests in accept/header/body loops so lifecycle coordination
does not depend on idle clients completing their requests.
Nonempty handler error bodies are retained, preserving structured JSON
instead of replacing it with hbhttpd's default non-200 HTML page.
Native HTTP framing, Content-Length and access-log sizes use byte-oriented
Harbour operations. The adapter validates raw UTF-8, selects UTF8EX for each
JSON/service call and restores the worker's previous codepage in ALWAYS.
Configuration and credential bytes are not recoded. Unicode acceptance
belongs to the concrete test results below, independently of Protheus/MSSQL.
Its checksum is recorded in [dependencies.json](../config/dependencies.json).
Git retains LF for patch files so clone line endings preserve that checksum.
[prepare-http.ps1](../scripts/prepare-http.ps1) checks and applies it to an
isolated `.deps/http/` copy, preserving the pinned checkout, then writes a
dependency receipt. Original copyright/license notices remain intact.

Direct HTTPS is optional: build with `HB_HTTP_TLS=1`, provide the
**hbssl/OpenSSL** SDK/runtime for the target architecture, then configure
`TLS=true`, `Certificate` and `PrivateKey`. A build without linked hbssl rejects
TLS activation instead of silently serving plain HTTP. For example:

```powershell
$env:HB_HTTP_TLS = '1'
$env:HB_WITH_OPENSSL = '<openssl-include-directory>'
./scripts/bootstrap.ps1
./scripts/build-hbbridge.ps1 -OutputDirectory tmp/https-candidate
```

Certificate/hostname validation, supported TLS versions, renewal and client
integration still require real HTTPS acceptance. Leave HB_HTTP_TLS unset for
the default HTTP build; other nonempty values are rejected.
Basic and bearer credentials require a protected channel for remote
deployment; loopback HTTP supports
local development or a deliberately configured TLS reverse proxy.
TLS on HTTP does not automatically protect NETIO or the Protheus TCP listener.

## Validation and next steps

[HTTP integration tests](../tests/integration/harbour/hbbridgehttptest.prg)
cover authentication/channel separation, Health/Echo/addon/SQL dispatch,
native NETIO equivalence, JSON/body errors, concurrent contexts, status
sanitization, shutdown/restart and startup rollback. Results belong to
[acceptance](acceptance.md); historical 416-check evidence predates HTTP.

The targeted Windows run on 2026-10-06 passed **65 checks, zero failures,
no skips**, log tmp/http-tests-f3476462dfbb4fe6b64d63b0de1c1149/results.log.
It covered byte-exact HTTP framing under UTF8EX, accents/CJK/supplementary
characters, BMP escapes and surrogate pairs, SQLite text, native Unicode
execution, credential bytes and malformed-input rejection. It tested plain
HTTP; direct HTTPS, Linux and MSSQL Unicode remain unaccepted.

hbhttpd's native request parsing/timeouts differ from the Protheus adapter.
Its buffers/timeouts do not inherit `protheusReadChunkBytes`,
`protheusTimeoutMs` or the Protheus payload/wire budgets. JSON/body/results
are materialized in memory. `MaxWorkers` bounds worker threads; hbhttpd's
accepted-connection queue has no explicit bound here. It does not provide
the Protheus listener's immediate rejection at capacity. The native parser
reads the body before the adapter authenticates the request. Configurable
admission/queue/header/body/deadline policies remain work, without introducing
a fixed proof-of-concept payload ceiling. Broader HTTP conformance,
larger volumes and additional codepage/backend combinations, TLS and Linux
need dedicated acceptance before a
remote production profile is advertised. Web actions and a versioned REST
resource model can extend the same registry without introducing ERP inference.
