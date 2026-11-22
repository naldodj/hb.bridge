# TCP buffer sizing test proposal

[Português (Brasil)](tcp-buffer-sizing.pt-BR.md)

`ReadChunkBytes` controls the size of socket I/O operations. It defaults to
65,536 bytes. Set it in `[hbBridge]` in the AppServer INI and `[Protheus]` in
the hbBridge INI. The server also accepts `protheusReadChunkBytes` in JSON and
`-readchunkbytes=` on the command line. Each endpoint can use a different
value. `MaxWireBytes` and `MaxPayloadBytes` continue to govern message sizes.
[TCP framing and configuration](milestone2-framing.md).

The file-reader idea of accounting for memory is relevant under concurrent
load. File length is known when a file is opened, while the TCP receiver
allocates its first read buffer before it knows the message length. At 64
simultaneous calls, one receive buffer per call represents 4 MiB at 64 KiB
and 64 MiB at 1 MiB. This accounts for the buffers alone. Compressed and
expanded messages, temporary copies, and socket and runtime allocations
contribute separately to peak memory.

## 1. Verify buffer reuse at 64 KiB

- Compare allocation inside the read loop with one buffer local to each
  request. Start with Harbour. Its `hb_socketRecv()` receives the requested
  length explicitly and the pinned implementation preserves the length of
  the by-reference string. On AppServer, first measure `Len(cChunk)` before
  and after a short `TSocketClient:Receive()` followed by a longer read on
  the same connection. Reuse there only if the configured capacity can be
  preserved or restored. Consume only the bytes returned by the API.
  [Harbour receiver](../src/hb/transports/protheus/hbbridge.framing.hb), [TLPP client](../src/tlpp/hbbridge.client.tlpp).
- Use the existing fragmented gzip and Echo fixtures. Split the gzip header
  and trailer, force a short read followed by a longer one and exercise
  partial sends. Verify byte-for-byte equality, UTF-8 content and binary zero
  bytes in gzip. A complete gzip member ends the request on Harbour; the
  test responder must close the connection after sending a complete response
  to Protheus. Verify the original total I/O deadline with a slow peer.
  [Harbour regression runner](../scripts/test-hbbridge.ps1), [AppServer connection test](../src/tlpp/tests/protheus/hbbridge.connection.test/hbbridge.connection.test.tlpp).
- Check configured wire and payload limits one byte below, exactly at and
  one byte above each limit. Include corrupt gzip, premature disconnect,
  timeout and a successful call after failure. Hold the effective AppServer
  `MAXSTRINGSIZE` constant and record it. The TLPP path decompresses the
  whole response through `GzStrDecomp()`. Its check of the declared gzip size
  is preliminary. A smaller receive buffer leaves that decompression
  allocation unchanged. [TOTVS `MaxStringSize`](https://tdn-homolog.totvs.com/pages/viewpage.action?pageId=161349793).

## 2. Measure fixed sizes

| Dimension | Proposed comparison |
| --- | --- |
| Buffer size | 32, 64, 128 and 256 KiB. Keep the other endpoint at 64 KiB. Combine sizes only after measuring each endpoint independently. |
| TCP traffic | Deterministic Echo with gzip bodies below, around and above 64 KiB, including about 1 MiB. Use compressible and low-compressibility fixtures within configured limits. Record bytes on the wire and after expansion. |
| Concurrency | Start with 1 and 8 simultaneous calls. Confirm candidates at 32 and near the configured listener capacity where the test AppServer permits it. Keep the actual offered concurrency constant across variants. |
| Environment | Test Harbour on Windows and Linux. Record AppServer and Harbour builds, settings, host topology, and whether Linux ran under WSL. Run the client correctness checks on the AppServer build under evaluation. |
| SQL confirmation | Run the existing TCP benchmark with the same query, row count, page size and profile for 64 KiB and the best candidate. Keep these results separate from Echo. |

Warm up each variant and alternate the baseline and candidate across at
least three paired rounds. For a p95 comparison, collect at least 100
measured successful calls per variant per round, report failures separately
and repeat when baseline variation obscures the difference.

Record p50 and p95 latency, throughput, CPU time per successful call, and
peak process memory for Harbour and AppServer separately. Record the memory
metric and sampling interval used for each process. Count send and receive
calls and actual bytes per call, including short operations. The setting
also affects sending, so both counters are needed to explain a change.
[Existing benchmark](benchmarking.md).

## 3. Decide whether an `auto` mode is warranted

Require all correctness cases to pass. An initial benchmark target is a
repeated improvement of at least 10% in one metric selected before the test
(p95, CPU per call or peak memory). The gain must exceed baseline variation.
Flag a sustained p95 or throughput regression above 5% in any reference
workload. Keep 64 KiB as the default if the evidence is inconclusive and use
explicit per-endpoint overrides where a different fixed value helps.

Prototype `auto` only if fixed-size comparisons under normal load and a
controlled deployment memory limit show a need for different choices. Make
it opt-in and resolve the size when the configuration is loaded. Keep the
meaning of numeric overrides. Compare the prototype with the best fixed
value in each environment and include tests for missing memory data.

Derive an automatic choice from a verified deployment budget and measured
concurrent I/O requirements. Allow room for other allocations and choose
among validated sizes within runtime limits. Physical memory availability,
Windows commit and address-space availability, and Linux cgroup usage and
limits describe different constraints. A Linux deployment may also be
limited by an ancestor cgroup. `GetSrvInfo()[4]` is documented as memory
information and gives no guarantee of available AppServer headroom.
[Windows memory status](https://learn.microsoft.com/en-us/windows/win32/api/sysinfoapi/ns-sysinfoapi-memorystatusex), [Linux cgroup v2 memory controller](https://docs.kernel.org/admin-guide/cgroup-v2.html#memory), [TOTVS `GetSrvInfo`](https://tdn-homolog.totvs.com/display/tec/GetSrvInfo).

Use the default when the memory signal is unavailable. If a known budget
would rule out even the smallest validated size, report that condition
rather than implying the buffer can enforce the process budget. Record the
resolved size and reason in local diagnostics. HTTP and NETIO use their own
I/O policies. Apply the same measurement method to other fixed sizes only
when a specific allocation or I/O cost is observed.
