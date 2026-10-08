# hbBridge HTTP consumption from TLPP

[Português](README.pt-BR.md)

The [HTTP client](../../src/tlpp/hbbridgehttpclient.tlpp) exposes
`HBBridge.Client.HBBridgeHTTPClient` using Protheus's native `FWRest`.
The [Protheus test](../../src/tlpp/tests/protheus/hbbridgehttptest.tlpp)
exercises the same hbBridge services used by Harbour and the TCP client.
HTTP uses UTF-8 JSON and bearer authentication; it does not use the TCP
`HBBRIDGE/1` frame or gzip. See [the HTTP contract](../../docs/http.md).

## Configure and start the server

HTTP is disabled by default. Make a private copy of
[sqlite.ini](../../config/examples/sqlite.ini), keeping its SQL section,
and add:

```ini
[HTTP]
Enabled=true
Host=127.0.0.1
Port=8080
Password=<service-secret>
TLS=false
```

Replace the placeholder with your own secret. This example needs no `[Admin]`
section: service bearer authentication is separate from web administration.
Build the current product and start it from the repository root, supplying
the private configuration path:

```powershell
./scripts/build-hbbridge.ps1
./scripts/run-hbbridge.ps1 -Config tmp/http.ini
```

The `tmp/http.ini` path above assumes you saved the private copy there.
Stop a previous instance before reusing its ports. For a remote deployment,
use an HTTPS destination with a tested TLS installation or reverse proxy;
plain loopback HTTP is the local example.

## Configure the Protheus client

Add these keys to the active AppServer INI's existing `[hbBridge]` section,
or create that section if absent. Do not create a duplicate section.

```ini
[hbBridge]
HTTPURL=http://127.0.0.1:8080
HTTPToken=<service-secret>
HTTPTimeoutSeconds=30
SQLProfile=sqlite_demo
```

`HTTPToken` must match the server's `[HTTP] Password`; it has no default
secret. Omitted constructor/test arguments read these settings. Explicit
arguments override them. The URL defaults to `http://127.0.0.1:8080`, and
the timeout defaults to 30 **seconds**, independently of TCP `TimeoutMs`.
The timeout configures the native HTTP operation; it is not a monotonic
deadline for the entire call, JSON serialization and local processing.

`SQLProfile=sqlite_demo` selects only this example's profile. You can pass
another opaque alias, such as `mssql/pData`, when it is configured on the
server. The library has no mandatory SQL profile. Protheus supplies SQL,
physical table names, tenant, company and branch rules explicitly.

## Compile and run the example

Compile the complete `src/tlpp/` tree, including the client and test, with
the operator's TOTVS SDK configuration:

```powershell
$env:HBBRIDGE_TOTVS_APPSERVER_DIR = '<your-appserver-directory>'
$env:HBBRIDGE_TOTVS_INCLUDES = '<your-totvs-includes>'
$env:HBBRIDGE_TOTVS_ENV = 'PROTHEUS'
./scripts/build-totvs.cmd
```

See [TOTVS compilation](../../scripts/README.md#totvs-compilation) for
service scripts and compilation logs. Run
[U_HBBridgeHTTPTest in WebApp](https://localhost:4321/webapp/?p=U_HBBridgeHTTPTest&e=PROTHEUS)
after aligning the active AppServer INI, or invoke it with explicit values:

```advpl
U_HBBridgeHTTPTest("http://127.0.0.1:8080", "<service-secret>", 30, "sqlite_demo")
```

Arguments are URL, service token, timeout in seconds, SQL profile and addon
module. The omitted SQL profile uses `[hbBridge] SQLProfile`; an explicitly
empty fourth argument skips SQL. The addon defaults to
`examples/hbbridgesampleaddon.hb` on the **server**, and an explicitly empty
fifth argument skips addon execution. For services without those fixtures:

```advpl
U_HBBridgeHTTPTest("http://127.0.0.1:8080", "<service-secret>", 30, "", "")
```

## Reuse the client in a method

Inside a TLPP method, use objects for the service parameters and result:

```advpl
    local oClient := HBBridge.Client.HBBridgeHTTPClient():New() as object
    local jParams := JSONObject():New() as json
    local jResponse as json

    jParams["message"] := "Protheus HTTP example"
    jResponse := oClient:CallService("Echo", jParams)
    ConOut("HTTP status: " + CValToChar(oClient:StatusCode()))
    ConOut(jResponse:ToJSON())

    FreeObj(@jResponse)
    FreeObj(@jParams)
    FreeObj(@oClient)
```

`Health()` performs GET `/api/v1/health`; `Services()` performs GET
`/api/v1/services`. `CallService()` posts the service/params/version envelope
to `/api/v1/rpc`. Inspect the result's `success`, `code` and `error` fields
alongside `StatusCode()`. The accepted 403 and 404 cases retained the
server's structured JSON error. For 401, the tested Protheus LIB reported
`FWRest:cInternalError` as `UNAUTHORIZED` while `GetHTTPCode()` returned zero.
The client normalizes that condition to status 401 and a local `UNAUTHORIZED`
failure; this fallback does not preserve the server's 401 JSON body.

The client uses `FWRest:SetChkStatus(.F.)` to inspect the returned HTTP code
itself, as documented by [TOTVS FWRest](https://tdn.totvs.com/display/framework/FWRest).
Only the native header API requires an array; request parameters and results
use `JSONObject`. `FWRest` supplies HTTP framing and the content length.

Supply parameter strings in the AppServer's text encoding. The client applies
`EncodeUTF8()` once to the complete serialized request; do not pre-encode
individual parameter values. Response JSON is parsed without recoding the
whole body, preserving returned UTF-8 strings. Use `DecodeUTF8()` on a specific
text field when comparing it with local AppServer text or displaying it in
that encoding. The accepted Echo test decodes only its accented field for
comparison; it does not establish support for every Unicode/codepage combination.

The same client can back the existing paginated dataset:

```advpl
    local oClient := HBBridge.Client.HBBridgeHTTPClient():New() as object
    local oDataSet := HBBridge.RDD.HBBridgeRPCDataSet():New(oClient) as object

    if oDataSet:OpenPage("sqlite_demo", "SELECT 1 AS ID", 1, 10, "ID")
        ConOut("ID: " + CValToChar(oDataSet:FieldGet("ID")))
    else
        ConOut(oDataSet:ErrorCode() + ": " + oDataSet:ErrorMessage())
    endif

    oDataSet:Close()
    FreeObj(@oDataSet)
    FreeObj(@oClient)
```

`NextPage()` and `HasNextPage()` retain the existing dataset contract.
The query above is a constant SELECT, with no Protheus table writes.

## Operator acceptance

On **2026-10-07**, the operator compiled/adjusted the sources and ran
`U_HBBridgeHTTPTest` on AppServer thread **25672**. The program started at
15:16:12 and the test ran from **15:16:14 to 15:16:15**. All **13 checks**
were true: GET/POST Health, service discovery, 200,000-byte Echo with the
accent comparison, addon execution, unknown service (404), forbidden
administration (403), invalid token (normalized 401), recovery after failure,
and two query pages with their values.

The supplied output did not identify the SQL alias or backend. It confirms
pagination for the selected profile and does not establish MSSQL acceptance.
Broader Unicode/codepage coverage, HTTPS and alternative client configurations
remain pending. See [the acceptance record](../../docs/acceptance.md).

After reporting recompilation following the Harbour `.hb` migration, the
operator repeated all **13 checks successfully** on the same date: thread
**27296**, test **16:10:44–16:10:45**, and thread **25456**, test
**16:15:03–16:15:04**. Times are São Paulo; both runs took one second and
reported Health HTTP 200, addon execution and paginated values. These are
operator reports, not agent AppServer runs or a supplied compiler log.
The accompanying Query test identifies `sqlite_demo`; the HTTP reports do not
identify their own SQL backend or actual module argument. MSSQL acceptance
remains separate; [the matrix](../../docs/acceptance.md) records the exact scope.
