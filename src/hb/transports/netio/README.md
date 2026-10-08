# NETIO transport

[Português](README.pt-BR.md)

[hbbridgenetio.hb](hbbridgenetio.hb) embeds native netio_Listen/Accept/Server
in the product. The host owns connections/threads and coordinates shutdown,
restart and rollback. Data binds `0.0.0.0:2941`; administration binds
`127.0.0.1:2940`, requires a separate credential and disables its file root.

RPC filters expose HBBridge.Call and admin HBBridge.Admin.Status. Services
receive native values through NETIO serialization and share the Protheus
registry. Integration exercises binary VF IO. See
[milestone 1](../../../../docs/milestone1.md) for configuration and scope.

Operational netioTimeout default 0 maps to native -1 (no deadline). Positive
milliseconds must fit native int. Default maxWorkers=64 is configurable,
not a fixed NETIO protocol capacity.

| Resource | Native technical capacity |
| --- | --- |
| Credential | 64 bytes (NETIO_PASSWD_MAX); longer values are rejected to avoid truncation. |
| Open files | 8192 per connection (NETIO_FILES_MAX). |
| Certain RPC/stream units | uint32 lengths, depending on operation. |
| Timeout | Native int; HBBridgeRuntimeLimits()["netioTimeoutMsMax"] reports the compiled capacity. |

These lengths differ from Protheus HBBRIDGE/1 decimal fields and total file
volume. Serialization/buffers/architecture/memory also matter. There is no
general 16 MiB NETIO cap; Protheus payload/wire budgets are independent.
The core stays generic: callers resolve business/tenant/company/branch rules.

Sources: [constants](https://github.com/harbour/core/blob/master/contrib/hbnetio/netio.h),
[native server](https://github.com/harbour/core/blob/master/contrib/hbnetio/netiosrv.c),
[native client](https://github.com/harbour/core/blob/master/contrib/hbnetio/netiocli.c).
