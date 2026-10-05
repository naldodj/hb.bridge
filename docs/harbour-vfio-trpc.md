# Harbour VF IO and the TRPC review

[Português (Brasil)](harbour-vfio-trpc.pt-BR.md)

This analysis guides implementation; the TLPP file facade and TRPC adaptation
are not delivered. Harbour sources were reviewed on 2026-09-29 at local revision
`bee221e83e580d45076dfc9afa1ce43d9aba521b`. trpc.prg matched the consulted
upstream after newline normalization. Conclusions come from static reading,
not TRPC execution tests.

## VF IO as the file layer

`hb_vf*` is the PRG interface to Harbour FILE IO, dispatching to registered
providers, including NETIO. Reuse this abstraction across transports.
References: [vfile.c](https://github.com/harbour/core/blob/master/src/rtl/vfile.c),
[C interface](https://github.com/harbour/core/blob/master/include/hbapifs.h),
[NETIO provider](https://github.com/harbour/core/blob/master/contrib/hbnetio/netiocli.c).

| Group | APIs |
| --- | --- |
| Lifecycle | hb_vfOpen, hb_vfClose, hb_vfTempFile. |
| Transfer | hb_vfRead, hb_vfReadLen, hb_vfWrite, hb_vfReadAt, hb_vfWriteAt. |
| Position/size | hb_vfSeek, hb_vfSize, hb_vfEof, hb_vfTrunc. |
| Persistence/locks | hb_vfFlush, hb_vfCommit, hb_vfLock, hb_vfUnlock, hb_vfLockTest. |
| Names/metadata | hb_vfExists, hb_vfDirectory, hb_vfRename, hb_vfCopyFile, hb_vfErase, attributes/dates. |
| Provider | hb_vfIsLocal and backend-supported hb_vfConfig options. |

Validate availability/semantics per provider: seek, truncate, locks, flush and
commit cannot be advertised universally. hb_vfLoad/hb_vfSave materialize content;
large transfers use blocks. Capture return values and FError according to each
API; the family has no uniform success return.

### Client integration

- **Harbour:** direct hb_vf* for local/net: files after NETIO registration.
  The client's handle stays local.
- **Protheus:** a registered Files.* family. Open/Read/Write/Seek/Stat/Close are
  proposed service names subject to versioning. The server holds the VF handle
  and returns a session-owned opaque identifier.
- **C/Zig:** sized buffers or C hb_file* through the bridge, respecting ownership,
  threads and closure. Internal pointers are not network identifiers.

Session context selects storage profiles and permitted paths. Do not serialize
handles or expose OS descriptors through hb_vfHandle. Exclude hb_vfConfig options
that reveal internal handles; approve remote options explicitly.

Read/write contracts distinguish actual byte count, EOF and errors, handling
partial operations, exact offsets and disconnect/expiry cleanup.
Each block respects negotiated memory/compression/MAXSTRINGSIZE.
Acceptance includes binary local/NETIO round trips for both clients, offsets,
errors, denied access and resource release. Add providers only after acceptance.
VF IO handles bytes; DBF RDDs retain record/index/lock semantics.

## Selective reuse of contrib/xhb/trpc.prg

The file contains TRPCFunction, TRPCServeCon and TRPCService; its client is
trpccli.prg. It offers function descriptions/registration, authorization levels,
threaded execution, loop/foreach and progress/cancellation callbacks.
Adapt ideas to the shared registry/jobs.
[Server source](https://github.com/harbour/core/blob/master/contrib/xhb/trpc.prg).

| Upstream element | Proposed destination |
| --- | --- |
| Function description, arguments/version | Core registry with hbBridge names/types. |
| Function/executor association | Service handlers, separating call state from catalog. |
| Execution callbacks | Job progress/result/error/cancellation events. |
| Loop/foreach | Batch item results and resource control. |
| Discovery | Capability discovery on existing transports. |

TRPCClient uses its own XHBR protocol, UDP discovery and TCP calls.
Shared Harbour serialization does not make it compatible with NETIO/HBBRIDGE/1.
It will not be added as a mandatory third transport.
[Client source](https://github.com/harbour/core/blob/master/contrib/xhb/trpccli.prg).

### Adaptation requirements

Static findings:

- RecvFunction rejects expanded content above **65,000 bytes** and allocates
  Space(nComp) from the received compressed length.
- SendResult/SendProgress compress above **512 bytes**.
- Function-name grammar rejects dots, including RPCRDD.Query.
- CheckTypes compares ValType; Run mutates the instance call array.
- Invalid metadata may call Alert/QUIT; Authorize defaults to level 1 without
  a callback.

These need changes to limits, concurrency, validation and authorization before
code extraction. A suspected cancellation mismatch also needs reproduction:
the server sends XHBR34, while the client reads it as progress with data.
Validate the paired implementation before reusing that flow.

Compatibility wrappers forward StartThread to hb_threadStart and translate
hb_DeserialNext to hb_Deserialize. Prefer native APIs already used by hbBridge.
References: [xhbmt.prg](https://github.com/harbour/core/blob/master/contrib/xhb/xhbmt.prg),
[xhbfunc.c](https://github.com/harbour/core/blob/master/contrib/xhb/xhbfunc.c).

## Decision and next implementation

**VF IO is the file foundation; TRPC is a selective design reference.**
NETIO remains embedded; Protheus keeps its interoperability contract.

[Milestone 1](milestone1.md) used description/handler separation as a reference:
the registry is socket-independent, with per-call arguments and hbBridge
namespaces/types. No XHBR protocol or mutable executor was incorporated.
Progress/batches follow the jobs milestone.

Harbour already tests NETIO-backed open/read/write/seek/close with binary byte
comparison. The TLPP facade, session resources and DBF acceptance remain
[Milestone 3](milestone3-sql.md)/[TODO](../TODO.md) work.
