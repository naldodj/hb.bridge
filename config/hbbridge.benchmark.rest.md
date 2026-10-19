# Protheus REST 2.0 benchmark configuration

[Português](hbbridge.benchmark.rest.pt-BR.md) · [INI fragment](hbbridge.benchmark.rest.ini) · [Benchmark](../src/tlpp/tests/protheus/hbbridge.benchmark.test/README.md)

Reuse the existing **Protheus REST 2.0** service on port 4323 with
`[HTTPV11] Sockets=HTTPREST` and `[HTTPREST] Security=1`. Both WSRESTFul and
TLPP annotation routes run through the framework's native Protheus user
authentication. The benchmark route is
`POST /rest/hbbridge/benchmark/page`; its body accepts only
`{rows,pageNumber,pageSize}` for the fixed fixture, never SQL or credentials.

The fragment disables the separate `[HTTPSERVER]` listeners and removes the
extra HTTPREST_HBBRIDGE socket from the active sockets list. `[HTTPURI]
Instances=1,1` keeps one REST worker for the sequential comparison. Preserve
the existing TLS/certificate settings, environment/RPO, licensing, DBAccess
and deployment-owned `PrepareIn` company/branch configuration. Keep HTTPJOB
in the existing startup jobs. This is a merge fragment, not a replacement
AppServer INI; no listener or private credential provider is added.

`[hbBridge] BenchmarkProtheusURL` is the existing service's base URL, including
`/rest`; match its actual protocol and port. `BenchmarkProtheusCredentialSection`
selects an existing server-side section, here `FWWEBEX_PROTHEUS`, containing
`UserName` and `Password`. The native benchmark client builds HTTP Basic from
those values on the AppServer. It does not require the FWWebEx classes to read
the section. No password, authorization value or endpoint is supplied through
the browser form or returned in the report. There is no separate
`BenchmarkProtheusToken`; hbBridge's own HTTP authentication remains separate.

The deployed handler checks HTTPV11 enablement, HTTPREST security, the current
listener's port and HTTPJOB environment. A mismatch returns 503. This guard
checks deployment, not identity: REST 2.0 validates the actual Protheus user
before invoking the endpoint. The handler also rejects malformed Basic headers
without comparing passwords to local configuration. Native `[HTTPSERVER]`
tlppCore authentication alone does not provide Protheus user authentication.

Authenticated invalid fixture parameters return 400; valid pages return 200;
query/cleanup failures return safe fixed English envelopes with status 500.
Compile all TLPP sources, then validate the actual reused listener with absent
credentials, incorrect credentials, valid credentials, invalid parameters and
recovery. Upstream authentication and this REST route still require their own
network acceptance; pure adapter checks do not establish that acceptance.

See the official distinction between
[REST 2.0 and REST tlppCore](https://tdn.totvs.com/display/framework/Entendendo%2Bas%2Bnovidades%2Bdo%2BREST)
and the documented
[FWRest Basic client pattern](https://tdn.totvs.com/display/framework/Exemplo%2Bde%2Bconsumo%2Bcom%2BHTTP%2BBasic).
