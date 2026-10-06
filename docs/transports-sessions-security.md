# Brainstorming review: transports, sessions and security

[Português (Brasil)](transports-sessions-security.pt-BR.md)

Analysis dated 2026-09-30 of local brainstorming/brainstorming.md, product sources
and official references. The ignored brainstorming directory preserves ideas;
this published guide records conclusions. Documentary feasibility/static review
does not equal Protheus acceptance. Delivery criteria are in [TODO](../TODO.md).

## Decisions and priority

| Topic | Conclusion | Dependency |
| --- | --- | --- |
| Harbour/C/Zig, embedded NETIO, common catalog | Preserve agreed foundation. | Milestones 0–1, one implementation/executable. |
| Persistent TCP | Sequential reuse first, bounded pool afterward. | Milestone 2 after framing. |
| Single-socket multiplexing | Feasible with explicit protocol/coordination. | Later, based on need/testing. |
| Isolation | Per-call context, explicit session resources. | Milestones 1–3; ownership/cleanup. |
| TLS | TSSLClient ↔ hbssl/OpenSSL for Protheus. | Early prototype, Milestone 5 acceptance. |
| JWT | Optional credentials over protected channel. | Shared context/authorization, Milestone 5. |
| tGrpc | Conditional on documented Smartlink contract. | Independent investigation, no SQL/VF blocking. |
| AMQP | Optional jobs/events adapter. | Milestone 6 with broker/delivery semantics. |
| Zig buffers/transport | C ABI extension with measurements. | Milestone 4/prototypes; reuse existing stacks. |

## HTTP addition on 2026-10-06

The project adopts **hbhttpd** for HTTP services and web administration in
the same process. Its adapter invokes the existing registry, with data/admin
credentials separated. The initial admin web page exposes read-only shared
status, including NETIO. Administrative mutations and a versioned REST
resource model remain extensions of the generic core. **hbtcpio** supplies
native TCP VF IO; **hbssl/OpenSSL** are optional direct-HTTPS dependencies;
`-hblib` is a build mode. See [HTTP routes and readiness](http.md) and
[dependencies](dependencies.md). This addition is later than the original
brainstorming review; historical validation does not certify it.

## Current behavior and persistence

The current server binds 0.0.0.0, default port 1512; local client uses 127.0.0.1.
The Protheus signature is HBBRIDGE/1. Brainstorming refers to older behavior.
See [entry](../src/hb/host/hbbridgemain.prg) and
[listener](../src/hb/transports/protheus/hbbridgeserver.prg).

[The client](../src/tlpp/hbbridgeclient.tlpp) creates/closes its socket inside
CallService; each worker serves one request then closes.
A socket class does not automatically implement reuse.
Persistence first needs stream framing, partial reads/writes and preservation
of bytes belonging to the next message.

First support one active call per connection. A later pool needs a bound,
exclusive acquisition, wait deadline, eviction and separation by endpoint,
security profile and session. Cross-job/thread object lifetimes require TLPP
validation. Persistence reduces opening/ephemeral-port costs but still uses
sockets/buffers and, under the current model, workers.

Harbour already has hb_socketSetKeepAlive/hb_socketSetNoDelay in
[the socket API](https://github.com/harbour/core/blob/master/src/rtl/hbsockhb.c);
new C wrappers are unnecessary. OS keepalive timing varies; application
liveness needs deadlines/possibly heartbeat. Measure TCP_NODELAY under load.
Reconnect with bounded backoff/jitter. Missing mutation responses do not prove
nonexecution; retries require idempotency or prior-result lookup.

Multiplexing needs IDs, one reader/demultiplexer, coordinated writes,
cancellation and flow control. HTTP/2 does not remove TCP packet-loss blocking
across streams. [RFC 9113](https://www.rfc-editor.org/rfc/rfc9113.html#section-1).

## Context, sessions and durability

Guarantee **per-call isolation**, without claiming every operation is stateless.
Calls identify correlation, deadline and explicit authorized context. Protheus
resolves tenant, company, branch, xFilial and physical table names. Future
generic authorization may validate supplied context against identity, without
inferring ERP rules; these fields alone grant no authorization. See
[application responsibilities](architecture.md).

Work areas, SET options, transactions, buffers and module state need ownership/
cleanup. Starting a thread does not prove isolation of statics, C/Zig memory or
shared driver connections.

Live cursors/transactions/VF handles belong to session, user/tenant, owner node
and expiry. IDs do not make them durable. By default disconnect releases
transient resources; authenticated/revalidated resumption is a separate
capability. Operations must reach resource owners. Load balancing without
affinity only works where ownership dependencies are absent or deliberately
resolved. Durable jobs require storage/recovery; storing a handle ID is insufficient.

## TLS and JWT

[TSSLClient](https://tdn.totvs.com/display/tec/Classe+TSSLClient), documented
since AppServer 19.3.1.0 with SSLConfigure, is the direct client candidate.
Harbour [hbssl](https://github.com/harbour/core/tree/master/contrib/hbssl) provides
OpenSSL bindings but is not integrated into the Protheus TCP listener.
The separate HTTP adapter has an optional HTTPS build, with acceptance
described in [HTTP](http.md).

Prototype TLS versions, chain/hostname validation, invalid/expired certificates,
renewal, deadlines and shutdown. mTLS depends on chosen profile/API support.
A failed protected connection must not silently downgrade to plain TCP.
NETIO/admin need separate protection evaluation.

[tSktSslSrv](https://tdn.totvs.com/display/tec/tSktSslSrv) accepts connections;
[tSktSslConn](https://tdn.totvs.com/display/tec/tSktSslConn) represents accepted
ones. Reconsider only for actual Protheus callbacks. Historical examples are
not a justification for obsolete SSL policy.

[tJWT](https://tdn.totvs.com/display/tec/tJWT), documented from 17.3.0.19,
creates/verifies tokens. **Signing is not payload encryption.**
Signed JWT does not make plain TCP/HTTP confidential or prevent reuse of a
captured bearer token. TLS protects the channel; JWT represents verified
identity/claims; the core authorizes services/tenants.

Require an allowed algorithm, signature, issuer, audience, expiry/nbf, trusted
keys and rotation. kid selects already trusted keys, not arbitrary client
origins. Decoding is not authentication; raw crypto bindings alone are not
a full JWT validator. Reuse an existing library and specify issuance, refresh
and persistent-connection revalidation.
[RFC 8725](https://www.rfc-editor.org/rfc/rfc8725.html).

## gRPC: the client's contract is the constraint

[tGrpc documentation](https://tdn.totvs.com/display/tec/tGrpc), reviewed
2026-09-30, describes AppServer 20.3.1.0+ and a predefined Smartlink constructor
model. Supplying smartlink.proto does not prove arbitrary Protobuf support.
The method list says sendMessages while examples say sendMessage; verify the
actual target build.

HB_Grpc remains conditional. Obtain the distributed contract/usage conditions,
implement a matching server and test calls/errors, TLS/authentication, metadata,
deadlines and genuinely exposed streaming modes. Protocol availability does not
prove every operation exists in the TOTVS class.

Evaluate a gRPC library with a C ABI or C wrapper for Harbour/C/Zig.
Both endpoints must agree on methods/messages:
[gRPC model](https://grpc.io/docs/what-is-grpc/core-concepts/).
Do not implement HTTP/2/HPACK/Protobuf from scratch here.
Zig remains toolchain/extension language; zero-copy/latency claims require
measurements and explicit buffer ownership.

## Optional AMQP jobs/events

[tAMQP](https://tdn.totvs.com/display/tec/tAMQP) documents RabbitMQ AMQP 0.9.1,
17.3.0.x applicability, and vhost since 24.3.0.6. Publish/consume/ack/QoS,
correlation and ReplyTo support a prototype, without proving every build's
publisher confirms, nack/requeue or TLS.

The adapter maps messages into the common contract. RabbitMQ is required only
when enabled; NETIO/Protheus remain in one executable. A suitable C consumer
library can use the C/Zig bridge after build/license review.

Durable queues, persistent messages, publisher confirms and consumer ack have
different roles. A proposed worker acknowledges after persisting its result,
accepts redelivery and prevents duplicate effects through idempotency coordinated
with the data mutation. Test failures between effect and ack; do not promise
exactly-once. [RabbitMQ reliability](https://www.rabbitmq.com/docs/reliability).

Specify TTL, bounded retries, dead-letter queues, prefetch and ReplyTo
authorization/correlation. Large results use pages/streams/references within
broker/AppServer limits. If TLPP lacks a required guarantee, document it and
consider Jobs.* submission with a validated server-side publishing adapter.
