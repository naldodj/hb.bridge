# TCP client component lifetime

[Português](README.pt-BR.md) · [Benchmark](../hbbridge.benchmark.test/README.md) · [Active package](../../../../../WIP.md)

`HBBridge.Test.HBBridgeClientLifecycleTest` exercises repeated TCP requests
without a SQL workload. `HBBridgeClient` owns one lazily created native
`TSocketClient`, reconnecting that component for each request. The wire contract
remains one request/response per TCP connection. This prevents allocating a new
terminal component for every page of a long dataset traversal.

Compile this directory with the complete `src/tlpp` tree. Supply an explicit
working hbBridge host/TCP port and a different verified closed port on that
host. The test neither starts listeners nor edits either INI. No SQL profile,
HTTP token or database credential is required by this test.

```tlpp
// 1513 is an example only: verify that it is closed before using it.
nResult := U_HBBridgeClientLifecycleTest("127.0.0.1", 1512, 1513, 6000, 30000)
```

Arguments are host, working port, refused port, repeated Health call count and
per-request timeout in milliseconds. Host and both ports are mandatory.
Omitted call count/timeout use 6000 and 30000 ms. The count is configurable;
6000 covers more calls than the 5020 TCP page requests in the recorded
500-iteration benchmark with two warmups and ten pages per iteration. It does
not re-read 50 million SQL rows.

For a licensed AppServer CLI setup, using the private INI beside its executable:

```bat
appserver.exe -ini="private-lifecycle.ini" -run=U_HBBridgeClientLifecycleCLI -env=PROTHEUS --host=127.0.0.1 --port=1512 --refused-port=1513 --calls=6000 --timeout-ms=30000
```

Flags use unique `--name=value` entries and canonical positive decimal
integers. The timeout applies to each request; it is not a total run budget.
Progress is printed every 1000 successful repeated Health calls.

The returned/printed report contains 17 keyed checks: initial Health for two
independent clients, repeated calls, an unknown service followed by recovery
on the same client, isolation of the second client, two refused attempts,
healthy-client recovery, idempotent cleanup and rejection after closing.
Closing the first client must leave the second usable. A refusal is accepted
only when the response code is `CONNECT_FAILED`; an accidentally active
refused-port fixture fails visibly. Failures retain safe categories rather
than native descriptions, endpoints or payloads. `Run(...)` returns a
caller-owned `JSONObject`; the public `U_` wrappers print its JSON and return
0 for success or 1 for failure.

`Close()` permanently closes that client and attempts native
`CloseConnection()`/`FreeObj` cleanup. It returns false while the client is busy
or when cleanup fails. Calls after closing return `CLIENT_CLOSED`. Each normal
or failed connection attempt also closes its connection before another call.
Use one owned client per worker; this test does not infer thread sharing from
the old static mitigation.

Optional `ClassMethArray` reflection reports the native cleanup-method names
available in the tested runtime. The test does not guess or invoke undocumented
`End`/`Destroy` methods. It does not measure the terminal registry, native
allocator or process memory, so successful repeated requests are not proof of
leak freedom. Native reflection uses the positional array supplied by that API;
checks and reports remain keyed JSON objects.

Focused AppServer CLI acceptance on 2026-10-18 passed 6000 Health calls
and all 17 checks, exit 0. Evidence:
`tmp/comparison-protheus-0d6eed2eb4554737acfe9a05f902d8da/validation.json`,
`results.lifecycle`. The current client source matches that recorded snapshot.
[Consolidated V01 evidence](../../../../../docs/acceptance.md#v01-v02-benchmark-acceptance-on-2026-10-19).
This accepts the exercised component lifetime/recovery behavior, without
allocator/terminal-registry leak claims. Earlier M08 measurements retain their
scope; the larger manual TCP/HTTP retry remains failed.
