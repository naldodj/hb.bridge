# Milestone 2: product framing and TCP flow

[Português (Brasil)](milestone2-framing.pt-BR.md)

This delivery repairs the existing transfer and retains HBBridgeClient
New/CallService semantics. The first three constructor arguments remain,
with optional size/buffer policies added. Services use the shared registry,
including ADDON.Execute with module/params for both clients.
Historical Milestone 1 acceptance stays in [acceptance](acceptance.md).

## Bytes and call lifecycle

Before compression:

~~~text
HBBRIDGE/1|JSON|<JSON-byte-length>\n<JSON>
~~~

This is the only Protheus request/response signature.
Length is canonical positive decimal, no leading zeroes, counting only JSON
bytes. Accepted digit count follows runtime string capacity, without a fixed
eight-digit/128-byte ceiling. Declared and actual decimal lengths must match.
Signs, fractional/numeric suffixes, wrong codecs, truncated/excess bodies fail.
The JSON adapter validates syntax afterward.

The entire frame is one gzip member. Client connects/sends; server responds/
closes. Server detects gzip completion without client half-close.
TLPP collects response until normal EOF and decompresses once.
There are no persistent/multiple calls on this connection.

Alternative signatures, raw unframed JSON, zlib wrappers and raw DEFLATE fail.
Harbour keeps native NETIO serialization. Older contracts live in Git history;
there is no parallel MVP or compatibility layer.

## Implementation

- [Harbour framing](../src/hb/transports/protheus/hbbridgeframing.prg) preserves
  decoder state across reads, applies policies/runtime capacities and dispatches
  only after valid completion. Receive/send budgets default 30 seconds.
- [C decoder](../src/c/hbbridgedecoder.c) uses linked zlib inflate, explicit
  release and a GC finalizer. 32 KiB output buffers respect capacity and optional
  expansion budgets before string allocation. Invalid CRC/trailer and extra
  compressed bytes in the same input block fail.
- [C compressor](../src/c/hbbridgecompressor.c) creates gzip incrementally,
  with per-response state and explicit/GC cleanup; the server need not build
  one complete compressed response string.
- [Monotonic clock](../src/c/hbbridgetime.c) uses GetTickCount64 on Windows and
  clock_gettime(CLOCK_MONOTONIC) on POSIX. It fails if unavailable, rather than
  substituting civil time.
- [TLPP](../src/tlpp/hbbridgeclient.tlpp) accumulates gzip, checks compression/
  decompression, exact framing/JSON, and identified success:false errors.
  Partial positive sends advance only by sent bytes, without retrying the
  application operation.

Two gzip members in one received block are invalid. Bytes arriving after the
recognized end are not processed; server closes after response. This is not
a persistent-stream parser; persistence requires new outer framing.

## Policies and runtime capacities

| Setting | Default |
| --- | --- |
| protheusMaxPayloadBytes / -maxpayloadbytes | 0, no additional JSON ceiling. |
| protheusMaxWireBytes / -maxwirebytes | 0, no additional gzip ceiling. |
| protheusReadChunkBytes / -readchunkbytes | 65,536 bytes per I/O buffer. |
| protheusTimeoutMs / -iotimeout | 30,000 ms/receive or send phase; zero disables Harbour deadline. |
| netioTimeout / -netiotimeout | 0 → native -1. |
| maxWorkers / -maxworkers | 64 per listener, configurable. |

Positive size budgets are installation policy. Buffer size is not message size.
Runtime metadata exposes stringBytesMax, socketChunkBytesMax (C long),
zlibChunkBytesMax (uInt), netioTimeoutMsMax (int).
Buffers fit the smaller socket/zlib capacity, including platforms where long
is 64-bit and uInt 32-bit. Technical capacities remain when policies are zero.
Header structure/runtime digits bound validation before body accumulation.

JSON, parsing, buffers and copies still consume memory simultaneously.
Incremental compression is not logical blocks/unlimited memory.
Protheus shutdown drains admitted workers. With zero deadline, incomplete
clients can postpone shutdown indefinitely; forced cancellation is absent.
NETIO signals/closes its connections.

TLPP constructor:
`New(cHost, nPort, nTimeout, nMaxPayloadBytes, nMaxWireBytes, nReadChunkBytes)`.
Extra defaults: 0/0/65536. Timeout defaults 30000 and must be positive;
zero TOTVS timeout semantics remain unaccepted.

GzStrComp/GzStrDecomp require complete strings and actual MAXSTRINGSIZE/memory.
GzStrDecomp has no output bound. Client checks ISIZE before decoding and actual
size afterward, applying optional policy. ISIZE is uint32 modulo 2³² and can be
forged; it is not a decompression allocation guarantee. Current TLPP gzip
assumes a trusted server. Independent blocks and none mode remain pending.

### Deadlines and clocks

TLPP covers connection, reads and checks between sends. Send has no timeout
argument, so a blocking call can exceed budget; gzip/JSON computation is not
interrupted by it.

Static `HBBridge.Client.HBBridgeTime` uses TimeCounter, adapted from
dna.tech.StopWatch.__GetCurrentTimeStamp. Single samples/differences replace
Date/Seconds, without a one-day ceiling.
[Issue #12](https://github.com/naldodj/totvs-protheus-open-issues/issues/12)
reproduces Windows milliseconds/Linux fractional seconds; Unix ×1000 normalizes.
Generic TDN documentation omits that difference. The test checks Sleep(1000)
scale/advance and can detect changed units in a future AppServer fix.

TimeCounter documentation describes differences/Sleep but does not guarantee
monotonicity/wrap. Samples compare to previous/start readings; regression expires
budget rather than extending it. Precision/behavior need build/platform
acceptance. StopWatch's epoch-date conversion was not imported.

Inspected hb_MilliSeconds calls hb_dateMilliSeconds, a UTC civil clock.
The server now uses a local monotonic counter, not portable timestamps.
GetTickCount64 resolution follows Windows timers (typically 10–16 ms):
millisecond units do not imply 1 ms resolution.
POSIX was compiled, not runtime accepted in this delivery.

## Validation history

[The runner](../scripts/test-hbbridge.ps1) shares product components and executes
[framing tests](../tests/integration/harbour/hbbridgeframingtest.prg).
It compares all bytes for gzip exceeding 65,535, fragments header/trailer,
checks expansion policies, CRC/excess/truncation/strict parsing and recovery.
A slow-client test uses an explicit positive total budget; a new fragment
must not reset it.

| Historical run | Result | Evidence |
| --- | --- | --- |
| Earlier 2026-10-03, before ceiling removal/incremental compressor | 196 checks, zero failures/no skips. | tmp/tests-74286b4b21314ae5af43f36267e9e69f/results.log |
| Later 2026-10-03 | 305 checks, zero failures/no skips. | tmp/tests-1156a4ae33964edc925ff65e09748ddb/results.log |
| Current pre-refactor baseline | 412 checks, zero failures/no skips. | tmp/tests-236f1241c1174cf4b193c22f6eedb6e0/results.log |

Reference: Harbour 3.2.1dev (r2608271822), Zig 0.16.0, Windows x64.
The 305 run included exact 24,000,000-byte Echo, JSON/gzip over 16 MiB both
ways, incremental compression, zero/positive budgets, positive/no Harbour
deadline, and nine-digit length validation without allocating 100 MB.
Compressed-response budgets/zlib per-call capacities and isolated product/help
passed. Clock tests added 29 checks: nonnegative integers, no regression, waits
and eight concurrent threads, without changing OS time.
These historical counts do not certify later source/build changes.

[The Protheus test](../src/tlpp/tests/protheus/hbbridgeconnectiontest.tlpp)
keeps Health/ADDON/Echo, compares all 200,000 bytes, and adds varied ASCII whose
gzip must exceed 65,535. It logs counts/results, not the full payload.
Optional fourth nLargePayloadBytes selects an additional Echo; zero skips it.
Clock budget tests cover expiry, fractions, regression and >24-hour values.
Compile hbbridgetime.tlpp with the entire TLPP tree.

Operator confirmation on 2026-10-03: Health/ADDON and both 200,000-byte Echo
passed, varied request gzip 152,964 bytes; clock values/artifact hash absent.
The later session of 2026-10-04 repeated them with 13 configuration and 29
SQLite checks, plus Unix=false, raw 1097.692700, normalized 1097.773500 ms
after Sleep(1000), OK. That accepts Windows scale/advance, not resolution,
real wrap or Linux. Time/thread/arguments/hashes were not supplied.

Receive documentation describes positive bytes/negative failure but not an
explicit FIN/timeout distinction. Client treats zero without error as normal
close and negative as failure. Normal closure was accepted; timeouts/failures
and forced positive partial sends remain pending.
Large transfer tests alone do not force a positive partial return from every
Send implementation.

The agent historically built isolated tmp candidates without replacing the
canonical elevated product or stopping AppServer. Updating the installation
requires stopping the old host, building/restarting, and compiling TLPP via
[build-totvs.cmd](../scripts/build-totvs.cmd) in an authorized administrative
context. Then run
[U_HBBridgeConnectionTest](https://localhost:4321/webapp/?p=U_HBBridgeConnectionTest&e=PROTHEUS).

## Remaining Milestone 2 work

Small uncompressed handshake, outer wire/expanded lengths, independent blocks,
negotiated codecs/compression, types/session resources and persistence/pools.
Gzip remains mandatory until both peers implement negotiation.
Removing application ceilings does not implement block transfers.

Primary references:
[Receive](https://tdn.totvs.com/display/tec/TSocketClient%3AReceive),
[Send](https://tdn.totvs.com/display/tec/TSocketClient%3ASend),
[GetError](https://tdn.totvs.com/display/tec/TSocketClient%3AGetError),
[GzStrComp](https://tdn.totvs.com/display/tec/GzStrComp),
[GzStrDecomp](https://tdn.totvs.com/display/tec/GzStrDecomp),
[FromJSON](https://tdn.totvs.com/display/tec/JSONObject%3AFromJSON),
[zlib API](https://zlib.net/manual.html),
[Harbour seconds](https://github.com/harbour/core/blob/8d94c31367104a57eb9ae6fa248cca2abb8db309/src/rtl/seconds.c#L61),
[Harbour timers](https://github.com/harbour/core/blob/8d94c31367104a57eb9ae6fa248cca2abb8db309/src/common/hbdate.c#L143),
[GetTickCount64](https://learn.microsoft.com/en-us/windows/win32/api/sysinfoapi/nf-sysinfoapi-gettickcount64),
[TimeCounter](https://tdn.totvs.com/display/tec/TimeCounter).
