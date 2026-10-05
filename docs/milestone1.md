# Milestone 1: shared core and embedded NETIO

[Português (Brasil)](milestone1.pt-BR.md)

The console host embeds the Protheus adapter and hbnetio in one process.
Both use [the service registry](../src/hb/core/hbbridgedispatcher.prg).
The host creates/seals its catalog before listeners; mutable call parameters
and results never belong to the shared catalog.

## Configuration and execution

~~~powershell
pwsh ./scripts/build-hbbridge.ps1
./out/hbbridge.exe "-config=config/examples/hbbridge.ini"
~~~

[INI](../config/examples/hbbridge.ini)/[JSON](../config/examples/hbbridge.json)
keep NETIO `0.0.0.0:2941`, admin `127.0.0.1:2940`, Protheus
`0.0.0.0:1512`. Admin requires adminPassword. The host creates netioRoot when
needed; addonRoot locates modules and missing modules fail the call.
Runtime directories/credentials belong to the installation.

Precedence: defaults < one file < CLI, independent of `-config` position.
File paths are file-relative; CLI/default paths are working-directory-relative
and normalized before listeners. Use absolute paths for supervised deployment.
JSON keys/CLI options are case-sensitive, INI keys/sections are not.
Automatic adjacent hbbridge.ini and sanitized --config-info are documented in
[configuration](configuration.md), including the AppServer client section.
The operator later accepted 13 TLPP configuration checks and clock/RPC/SQLite.

| JSON field | CLI | Default |
| --- | --- | --- |
| protheusHost / protheusPort | -host / -port | 0.0.0.0 / 1512 |
| protheusMaxPayloadBytes | -maxpayloadbytes | 0, no added JSON ceiling |
| protheusMaxWireBytes | -maxwirebytes | 0, no added gzip ceiling |
| protheusReadChunkBytes | -readchunkbytes | 65,536 |
| protheusTimeoutMs | -iotimeout | 30,000 ms/phase; zero disables Harbour deadline |
| netioHost / netioPort | -netiohost / -netioport | 0.0.0.0 / 2941 |
| adminHost / adminPort | -adminhost / -adminport | 127.0.0.1 / 2940 |
| netioRoot / addonRoot | -netioroot / -addonroot | data / addons |
| maxWorkers | -maxworkers | 64 per listener |
| netioTimeout | -netiotimeout | 0 → native -1, no deadline |
| netioPassword / adminPassword | INI/JSON only | Empty |

Binds are IPv4; clients use real IP/DNS. NETIO/admin ports are 1–65535;
Protheus accepts zero for OS-assigned test ports. Invalid settings and
overlapping bind conflicts fail. Partial startup rolls back opened listeners.
Help opens no listeners.

Native NETIO uses znet streams with a password and no stream compression
without one; this is not TLS or tenant authentication.
The Protheus adapter requires HBBRIDGE/1/gzip.
Zero budgets remove only application ceilings; string/API/memory capacities
remain. Runtime-limit metadata exposes string/socket/zlib/NETIO capacities.
The read buffer fits socket/zlib limits, not total-message size.
C/Harbour gzip is incremental, but JSON and TLPP strings are materialized.

## Services and internal contract

`hbbridgedispatch(hRegistry, cService, xParams, hContext, nVersion)` takes/
returns Harbour values. Default version: 1. Unknown service/version, wrong
signature and handler failure return a hash with `success:false`,
`error` and `code`. Protheus converts it to JSON.

| Version 1 service | Input | Result | Channel |
| --- | --- | --- | --- |
| Health | Any permitted value | success/message through C/Zig | Data |
| Echo | Any permitted value | success/service/params | Data |
| ADDON.Execute | Hash with module/params | Addon result hash | Data |
| Core.Upper | String | success/result | Data |
| Core.Version | Any permitted value | success/result | Data |
| Service.List | Any permitted value | Metadata and profile types | Data/admin |
| Admin.Status | Any permitted value | Endpoint state/counters | Admin |

SQL was added later and is described in [Milestone 3](milestone3-sql.md).

Registry metadata includes name/version, input/output ValType or any,
permission/dependencies and immediate mode. A handler is a two-argument
codeblock: input value and call context. Register extensions before sealing.
Discovery returns metadata copies, excluding handlers, mutexes, handles,
credentials and internal state. Dynamic contrib loading/dependency resolution
is not delivered here.

Permitted native types: U/C/L/N/D/T/A/H, with string hash keys. Strings may
contain binary bytes. Cycles, objects, codeblocks, symbols and live pointers
are rejected. NETIO preserves dates/timestamps; JSON follows its adapter.
Codepages/cross-revision compatibility need acceptance.
Remote cursor/stream IDs are later work.

The server creates context containing transport, addon root, host state and
channel permissions. User/company fields in parameters confer no permission.
Data/admin separation is implemented; user/tenant authorization is pending.

## Harbour client

~~~harbour
local pConnection, hResult

pConnection := netio_GetConnection( "127.0.0.1", 2941, 5000 )
if ! Empty( pConnection )
    hResult := netio_FuncExec( pConnection, "HBBridge.Call", "Echo", ;
        { "today" => Date(), "bytes" => Chr( 0 ) + Chr( 255 ) }, 1 )
    hResult := netio_FuncExec( pConnection, "HBBridge.Call", "Core.Upper", "harbour", 1 )
    hResult := netio_FuncExec( pConnection, "HBBridge.Call", "Service.List" )
endif
pConnection := nil
~~~

Supply a password in netio_GetConnection's fourth argument when configured.
5,000 ms is the example client's policy, independent of server defaults.
NETIO already serializes values; explicit hb_Serialize/hb_Deserialize can
transport a binary serialized string if an operation requires one.
No Protheus framing is inserted into NETIO.

Native limits: password 64 bytes; 8,192 files/connection; some units use uint32
lengths. See [NETIO notes](../src/hb/transports/netio/README.md).

For VF IO, netio_Connect registers/configures the provider/default connection;
net: paths support open/read/write/seek/close. Balance every connection with
netio_Disconnect and close files first. Native tests compare binary bytes under
netioRoot. DBF RDD acceptance and TLPP file services remain pending.

## Administration and shutdown

Data RPC exposes only **HBBridge.Call**. Admin exposes that gateway with admin
permissions plus **HBBridge.Admin.Status**. RPC names are case-sensitive;
HB_EXTERN linkage is not arbitrary remote authorization.

Admin uses invalid root `*?:*?:` to prevent file operations, following upstream.
It provides status; remote stop, user management and system-service install
are later work. Addons run in the host process with its OS account permissions.

`hbbridgehoststop()` signals listeners and joins threads.
Protheus drains admitted workers; NETIO signals idle/active connections,
whose handles use Harbour GC. With protheusTimeoutMs zero, a client that
never completes/disconnects can prolong shutdown. No forced cancellation
exists; executing handlers/addons must return for their threads to stop.
Execution deadlines/cooperative cancellation are future contract features.

The host owns threads around netio_Listen/Accept/RPCFilter/Server instead of
the detached netio_MTServer wrapper, retaining the single-executable design.

## Validation and remaining work

The [runner](../scripts/test-hbbridge.ps1) shares product components and creates
isolated fixtures. Beyond 74 original checks it added registry/configuration,
native NETIO/VF IO, admin, addon failure and stop/restart/rollback tests.

Historical Milestone 1 acceptance on 2026-10-03:
**159 checks, zero failures, no skips**, including 12 concurrent native calls
and invalid admin credentials. Isolated product/help/invalid CLI passed.
The operator compiled three TLPP sources without errors and accepted WebApp
Health/ADDON/Echo, preserving all 200,000 Echo characters.
See [acceptance](acceptance.md).

TRPCFunction description/handler separation served as a design reference.
Its XHBR protocol and mutable executor were not copied.
Batches/progress/cancellation remain Milestone 6 work.

Later milestones require only HBBRIDGE/1 and ADDON.Execute, removing old
aliases/ceilings and adding optional policies/incremental C gzip.
A later Harbour run passed 276 checks, then the current baseline reached 412.
Normal TLPP configuration/RPC was accepted on 2026-10-04; timeout/failure
scenarios remain pending. Historical counts do not validate later refactors.
See [Milestone 2](milestone2-framing.md) and [TODO](../TODO.md).
