# HTTP services and web administration

[Português](http.pt-BR.md)

hbBridge uses Harbour's **hbhttpd** inside the same executable as NETIO and
the Protheus TCP adapter. The [HTTP adapter](../src/hb/transports/http/hbbridge.http.hb)
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
SendTimeoutMs=30000
Compression=auto
CompressionMinBytes=1024
CompressionLevel=1
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

`SendTimeoutMs` budgets sending each complete response after service execution
and encoding, not the SQL call or request reception. Default 30000 ms; zero
disables this deadline. The managed hbhttpd sends bounded 65536-byte chunks,
retries partial/nonblocking sends within the remaining budget and closes an
incomplete response before logging success or processing another keep-alive
request. A 1000 ms socket wait is a readiness budget, not a mandatory sleep.
The native elapsed clock uses Harbour `hb_timerGet()`; platform clock behavior
still depends on that runtime. Direct TLS and Linux require separate acceptance.

## Response compression

`Compression=auto` negotiates gzip using `Accept-Encoding`, including quality
weights, explicit exclusions and wildcard. The default threshold is 1024 bytes
and zlib level 1. Prefer identity when it has a higher quality, the body is
small or compression does not reduce bytes. If identity is forbidden, an
accepted gzip representation may be used even for small/expanding bodies.
No acceptable available coding returns an empty 406. `Compression=off` disables
gzip. `Vary: Accept-Encoding`, `Content-Encoding: gzip` and compressed-byte
`Content-Length` describe the selected representation; JSON/UTF-8 stays unchanged.

JSON names are `httpSendTimeoutMs`, `httpCompression`,
`httpCompressionMinBytes` and `httpCompressionLevel`; corresponding CLI options
are `-httpsendtimeoutms=`, `-httpcompression=`, `-httpcompressionminbytes=` and
`-httpcompressionlevel=`. Level accepts 1..9. Threshold zero permits attempting
compression on all nonempty bodies; it is not a payload limit. Compression
reuses the incremental native codec without narrowing the total input to a
zlib chunk length. Responses are still materialized in memory; this is not
streaming query execution or HTTP chunked transfer.

The TLPP HTTP client defaults to `Accept-Encoding: gzip`, configurable with
`[hbBridge] HTTPAcceptEncoding=gzip|identity` in AppServer INI or the optional
fourth constructor argument. The installed FWRest returned raw gzip bytes in
the isolated probe; hbBridge explicitly uses `GzStrDecomp()` before its NUL-safe
JSON parser and rejects damaged gzip. If a native client already expands the
body, its JSON is parsed once without another decompression. HTTP requests
remain plain JSON. Compare fresh benchmark runs with the effective policy
recorded; historical identity reports are not gzip measurements.

The benchmark overrides the INI preference: its HTTP route explicitly creates
the client with `New(url, token, timeout, "gzip", .T.)`, sends
`Accept-Encoding: gzip, identity;q=0` and verifies mandatory-gzip client support.
It rejects an uncompressed response with `HTTP_COMPRESSION_REQUIRED`, including
a 406 when server compression is off. `httpRequireGzip=true` and
`httpAcceptEncoding` record this policy in the report. General application
clients keep optional gzip negotiation unless the fifth argument is true.

The RPC HTTP path also consumes the shared dispatcher's native result and
encodes it once, eliminating the previous encode/decode/encode traversal of
the complete result. TCP and HTTP retain shared validation, service permissions,
binary rejection and precision-preserving JSON.

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
frame does not belong to HTTP. Response gzip is negotiated independently as
described below. Request gzip and chunked request decoding remain unsupported.
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
        "alias": "MSSQL/pData",
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
Manual AppServer validation accepted 13 checks on 2026-10-07 without
identifying that SQL backend. In manual AppServer runs on 2026-10-08,
`U_HBBridgeHTTPTestMSSQL()` and
`U_HBBridgeHTTPTestSQLite()` separately passed **13 checks each**, using
fixture defaults `MSSQL/pData` and `sqlite_demo`. MSSQL ran on thread 25976
at 10:33:33–10:33:34; SQLite ran on thread 9916 at 10:34:07, São Paulo time.
Both include SQL pages/values through the common dataset; see
[acceptance](acceptance.md). These convenience entries do not force a profile
on the generic HTTP client.

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

[HTTP integration tests](../tests/integration/harbour/hbbridge.http.test.hb)
cover authentication/channel separation, Health/Echo/addon/SQL dispatch,
native NETIO equivalence, JSON/body errors, concurrent contexts, status
sanitization, shutdown/restart and startup rollback. Results belong to
[acceptance](acceptance.md); historical 416-check evidence predates HTTP.

The targeted Windows run on 2026-10-06 passed **65 checks, zero failures,
no skips**, log tmp/http-tests-f3476462dfbb4fe6b64d63b0de1c1149/results.log.
It covered byte-exact HTTP framing under UTF8EX, accents/CJK/supplementary
characters, BMP escapes and surrogate pairs, SQLite text, native Unicode
execution, credential bytes and malformed-input rejection. It tested plain
HTTP; it did not cover direct HTTPS, Linux or MSSQL Unicode. The 2026-10-08
native MSSQL suite later accepted the exercised Unicode types. Manual
AppServer runs of the HTTP entries accepted their 13 common checks per backend.
Broader SQL Unicode/types through Protheus HTTP, HTTPS, Linux and controlled
failure/resource/performance cases remain pending. The manual AppServer results
do not replace the native **92 MSSQL** or **566 default regression** checks.
Resume M06 in [WIP](../WIP.md) for controlled failures/recovery.

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

<a id="http-review-on-2026-10-24"></a>

## HTTP review on 2026-10-24

The supplied benchmark reports showed HTTP costs worth investigating. Three
reported workloads illustrate that diagnostic observation; timings are means
in milliseconds, not matched measurements of the revised server:

| Rows / page size | hbBridge TCP | hbBridge HTTP | Protheus REST |
| --- | ---: | ---: | ---: |
| 1000 / 100 | 417.5 | 637.6 | 770.8 |
| 10000 / 1000 | 1188.7 | 2569.1 | 1642.2 |
| 10000 / 10000 | 712.6 | 1982.3 | 895.1 |

Those reports did not identify deployed source/RPO hashes or physical pooling.
Their timing cannot establish the effect of a later code change. Inspection
identified a per-send socket wait, incomplete-send handling to strengthen,
missing HTTP gzip and a redundant full RPC JSON encode/decode/encode cycle.
The 1000 ms socket argument was a maximum wait, not an unconditional delay.
The managed patch and adapter changes described above address those paths.

Fresh Windows validation used plain loopback HTTP, the pinned dependencies
and an isolated AppServer 24.3.1.5. Installed services, INI and RPO were not
replaced. The [sanitized manifest](validation/http.response.windows.json)
records build/source identities and the separate verification scopes:

| Verification | Result |
| --- | --- |
| Complete native regression | 777 checks, zero failures, exit 0. |
| Managed hbhttpd send-fault probe | 18 assertions, zero failures, exit 0; short sends, keep-alive, stalled-reader deadline, incomplete pipeline and coordinated stop. |
| Isolated TLPP compilation | All 55 sources, zero errors, exit 0. |
| Installed FWRest and actual TLPP client | 14 checks, zero failures, exit 0; UTF-8/NUL, identity/gzip, seven-byte transfer chunks, invalid CRC, recovery and mandatory gzip. |

The actual MSSQL AppServer benchmark then confirmed both mandatory-gzip
outcomes, with `HTTPAcceptEncoding=identity` deliberately set in its isolated
INI. With server compression enabled, two measured traversals plus one warmup
of 10000 rows/page10000 passed, exit 0; the report retained
`httpRequireGzip=true` and `httpAcceptEncoding="gzip, identity;q=0"`. With
server compression off, warmup failed as expected: sample `QUERY_FAILED`,
service code `HTTP_COMPRESSION_REQUIRED`, HTTP 406 and process exit 1.
There was no identity fallback. These are correctness cases, not a paired
performance comparison.

A separate real MSSQL comparison used `m08.constant.v1`, 10000 rows in one
10000-row page, concurrency one and ODBC pooling off. Four AppServer runs
alternated identity, gzip, identity, gzip, each with two warmups and five
measured traversals. All 20 measured and eight warmup traversals passed:

| Response policy | First run mean (ms) | Second run mean (ms) | Combined measured mean (ms) |
| --- | ---: | ---: | ---: |
| identity | 1948.210 | 1790.348 | 1869.279 |
| gzip | 816.158 | 1004.748 | 910.453 |

The combined gzip mean was about 51.3% lower in this short local series.
Both policies used the same revised server build; this measures the response
encoding policy, not the isolated benefit of each send/serialization change.
The comparison preceded mandatory gzip in the benchmark. Its current HTTP
route cannot be switched to identity through the INI. Diagnostic identity
comparisons require an explicitly configured ordinary client.

An independent wire check obtained 582624 identity bytes and 107099 gzip
bytes, an 81.6% reduction. Both decoded bodies were byte-identical, SHA-256
`37FAB9EF66483944DEEF51F9C51ADFC9E13EDACABDBAAB0EFA5638F4B7A03EA9`.
The maintained `tests/probes/hbbridge.http.wire.test.py` reproduces that check
against a freshly started MSSQL fixture's `endpoints.json`; old ports and
scratch directories are not prerequisites. Compression ratio alone is not
a latency measurement.

Raw AppServer summaries had a known initialization INFO line interleaved
inside their JSON. Analysis removed that exact line and actual line breaks
to recover the complete reports, then validated success and aggregates.
No sample value or report statistic was changed. The manifest distinguishes
the comparison's RPO from the later mandatory-gzip compilation/probe.

The final native patch also resolves `CR_LF + CR_LF` once in the worker-local
`cHeaderEnd`. The read loop, trace and `ParseRequestHeader` use that same value;
the parser receives it explicitly. Repeated `Accept-Encoding` field lines are
combined before negotiation, preserving exclusions across lines.

A later diagnostic compiled 56 TLPP sources and passed the same 14 FWRest
checks, then alternated five measured requests plus one warmup per encoding.
Every 10000-row response passed direct value validation. Its gzip phase means
were 179.851 ms for FWRest/server/network, 1.511 ms for expansion, 43.158 ms
for JSON parsing and 23.194 ms for row validation; total 247.808 ms. Identity
total was 271.786 ms. These wall-clock phases exclude dataset processing and
are a separate observation, not a replacement for the M08 comparison above.
The maintained `profile-protheus-http.ps1` reproduces this diagnostic against
a newly served M08 endpoint. Decompression was a small part of this sample;
the native-request phase does not separate SQL, encoding and network time.

The JSON codec now resolves UTF-8 once per encoded document rather than per
scalar. A serializer-only comparison preserved all 582434 output bytes under
DECIMALS 2/18 and FIXED off/on. Two alternating-batch runs observed mean times
33.988/34.648 ms and 36.678/33.283 ms before/after caching. The latter batch CVs
were 15.3%/17.7%; these variable results establish no reliable latency gain.
`benchmark-harbour-json.ps1` versions the comparison without SQL/HTTP.

No per-stage CPU or memory measurement, Linux/direct TLS acceptance, production
capacity or general speedup is inferred. Responses remain materialized; further
work should isolate server execution/encoding and caller parsing/copies.
T01 remains an unimplemented contract draft in [WIP](../WIP.md).

### Provided benchmark exports on 2026-10-24

All six later exports passed independent recalculation: 31 selected series,
17580 measured samples and 62 warmups; zero discrepancies in totals,
mean/median/P95, population SD/CV, throughput or row/page/call counts. All
reports record mandatory gzip. The two 1500-iteration workloads show these
client-traversal means, in milliseconds:

| Rows / page size | TCP | HTTP gzip | Protheus REST | HTTP mean reduction vs REST |
| --- | ---: | ---: | ---: | ---: |
| 1000 / 100 | 389.741 | 459.361 | 623.639 | 26.34% |
| 10000 / 1000 | 1093.398 | 1423.550 | 1485.433 | 4.17% |

The larger workload's HTTP P95 was 2096.303 ms versus REST 1910.647 ms;
its lower mean does not establish a better tail. Addon/Protheus single-job
internal means were 299.803/385.686 ms and 504.281/1018.630 ms, respectively;
their scope remains separate from the client traversal table.

Against the older rounded HTTP observations above, the new long-run means
are approximately 28.0%/44.6% lower. TCP and REST also changed. No deployed
binary/RPO, pooling identity or matched system-load record is supplied, so
the complete difference cannot be attributed to a specific patch/invariant.
The short five-iteration runs also varied; this is no monotonic speed claim.

Reproduce export analysis with Python 3:

```powershell
python ./tests/probes/hbbridge.benchmark.report.test.py `
    --directory <export-directory> --output <new-summary.json>
```

The analyzer reads JSON only, validates successful selected series and
recomputes measured statistics. Its corruption control rejected an altered
mean. Raw exports/HTML remain outside Git; sanitized settings, file hashes
and results are retained in the HTTP validation manifest.
