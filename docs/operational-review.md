# Operational review: security, capacity and resilience

[Português](operational-review.pt-BR.md) · [Roadmap](../TODO.md) · [Current package](../WIP.md)

This review records useful follow-up ideas from an external project assessment.
It is not an implementation or a production acceptance. Work remains in the
roadmap; this note does not change the active package or prescribe new defaults.

## Existing boundaries

- Protheus TCP currently has no client authentication or TLS layer, and its
  server bind defaults to `0.0.0.0`. HTTP is optional and uses separate service
  and admin credentials; HTTP TLS does not secure TCP or NETIO. Restrict listener
  access until the appropriate channel protection has been implemented and
  accepted. Direct HTTP TLS and Linux require separate acceptance. See
  [credentials](credentials.md), [HTTP](http.md) and [configuration](configuration.md).
- The caller resolves and supplies ERP context when a service needs it; the
  dispatcher does not automatically authenticate a tenant or infer company and
  branch. A trusted application addon may implement its own business rules.
- `MaxWorkers` bounds active workers, not every queue or resource. TCP closes
  connections at capacity; the HTTP adapter can return `BUSY`/503, but hbhttpd
  reads the body before adapter authentication and its accepted-socket queue is
  not explicitly bounded. See [HTTP limits](http.md).
- Syslog is linked but not connected to the host/RPC lifecycle. Logical SQL
  leases are tracked by the bridge; optional physical connection reuse belongs
  to the ODBC driver manager. Lease counts are not physical-pool occupancy.
  See [architecture](architecture.md) and [SQL connections](sql-connections.md).
- `RPCRDD.Execute` can have an unknown outcome after submission or a lost
  response. Current timeouts are separate per layer and do not establish a
  universal end-to-end deadline. Never automatically replay a potentially
  side-effecting operation merely because its response was lost. See
  [SQL execution](sql-execution.md) and [TCP framing](milestone2-framing.md).

## Worth considering in future packages

1. **Admission and overload:** measure queue, workers and wait times by
   transport; design bounded, configurable admission and deadlines at the layer
   where resources are consumed. Define rejection behavior, including 503 for
   service capacity and 429 when an explicit per-client rate policy applies.
   Test slow clients, concurrent overload, recovery and normal workloads.
   These are policy choices, not fixed payload limits.
2. **Operational telemetry:** define counters and bounded latency histograms by
   service, transport and outcome, so percentiles are derived from observations.
   Distinguish admitted/active/rejected work, SQL lock or connection wait and
   logical leases. Report physical-pool metrics only if a verified source exposes
   them. Limit label cardinality, exclude SQL/credentials/personal data, test
   collector failure and measure overhead. Evaluate a protected, optional
   Prometheus exporter after the internal contract exists.
3. **Client resilience:** assess an optional per-endpoint circuit breaker with
   bounded thresholds, cooldown, recovery probes and caller-visible state. Keep
   it separate from connection retry and operation replay; preserve total budget
   and allow retries only when the operation contract establishes safety.
4. **Contracts and native boundaries:** assess a versioned common result/error
   envelope without silently breaking existing clients or exposing native error
   descriptions. Maintain transport contract tests; test malformed inputs,
   ownership, cleanup and C/Zig/Harbour ABI under failure and concurrency.
5. **Dependency upkeep and comparisons:** the manifest pins Zig 0.16.0 archives
   and checksums and exact Harbour/hb_compile revisions; managed patch purposes
   are already documented in [dependencies](dependencies.md). Keep testing
   patch application and review upstream changes before each upgrade. Compare
   performance only with equivalent work and published methodology; an addon
   returning metrics alone is not equivalent to transferring a full dataset.

Relevant tasks already exist in [TODO](../TODO.md); concrete scope and acceptance
belong to a future WIP package. No change to the SQL password-rotation decision
or to the generic hbBridge/application-addon boundary is implied.
