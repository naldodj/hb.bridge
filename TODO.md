# hbBridge roadmap

[Português](TODO.pt-BR.md)

Bring Harbour, C and Zig capabilities to Protheus and native Harbour clients
through one extensible implementation. [README](README.md) describes the
current product and intended architecture. A checked item records implemented
code or specifically identified evidence, not unrestricted platform acceptance.

[WIP](WIP.md) records the bounded active package, ordered tasks, decisions,
prerequisites and evidence. Continue there instead of reanalyzing this entire
roadmap. Reconcile completed items here when the package closes; intermediate
commits/publication preserve its progress. Package 001 is real MSSQL acceptance.

## Principles to preserve

- Harbour's familiar xBase syntax makes services approachable to AdvPL/TLPP
  developers; its runtime, RDDs and contribs supply the functional base.
- Harbour's native C API and the C ABI connect libraries and Zig; Zig provides
  native components and a build toolchain, with ownership/error contracts.
- NETIO/native serialization serves Harbour; an interoperable contract serves
  Protheus. Services and versions are shared independently of transport/codec.
- Use native `hbhttpd` and its dependencies for HTTP/REST and web
  administration of hbBridge/NETIO through the same core.
- **Generic executor:** Protheus resolves business rules, tenant ID, company,
  branch, `xFilial`, dictionary/table sharing and physical table names. hbBridge
  executes supplied queries/parameters; application addons receive explicit
  business inputs. Generic authorization never invents ERP predicates/context.
- SQL profiles are an opaque keyed map. Each call/dataset chooses an alias;
  the library has no demo default. Oracle alias naming does not imply an
  implemented Oracle connector. See [architecture](docs/architecture.md).
- Reuse VF IO `hb_vf*` for local/remote files; TLPP's future facade uses opaque
  session-owned resources, never serialized pointers.
- Keep one implementation in `src/`; examples launch it and tests share its
  components. Earlier proof-of-concept code is retained in Git history.
- Prefer Harbour hashes and TLPP JSONObject/THashMap. Arrays require a concrete
  native API/contract and documented allocation/copy/search considerations.
- Four-space own-source indentation and English identifiers. Files are
  lowercase; functions, procedures, methods, namespaces and classes use
  PascalCase. A class file uses the exact class name in lowercase.
  Preserve external API/native symbols and upstream formatting/notices.
- English documentation plus `.pt-BR` counterparts; use the three mandatory
  commit tools via the project-owned hbrun. See [standards](docs/standards.md).
- Start debugging with native `hbdebug`; HBDAP and its VS Code extension are
  optional later integrations, with separate worker/runtime acceptance.
- Remove arbitrary payload caps; distinguish runtime/API capacities from
  optional budgets. Negotiate blocks respecting MAXSTRINGSIZE and memory.
- Current Protheus contract is HBBRIDGE/1, framed JSON and gzip; future none/gzip
  negotiation is distinct from NETIO's native mechanisms.
- One host incorporates NETIO: data 0.0.0.0:2941, administration 127.0.0.1:2940
  with a separate credential, Protheus 0.0.0.0:1512; all configurable.

## Existing foundation

- [x] Multithreaded TCP host, shared registry/dispatcher, Health/Echo/ADDON.Execute.
- [x] Health exercises Harbour → C → Zig; static hbnetio composition in hbbridge.hbm.
- [x] TLPP frame HBBRIDGE/1|JSON|<JSON-byte-count> with complete string gzip;
  incremental zlib C codecs on the Harbour side.
- [x] In-memory PRG/HB compilation and HRB loading, local symbols per call,
  unloading and MT addon isolation/error regressions.
- [x] Server/client partial-send code and structured errors; forced TLPP failure
  and positive partial-send acceptance remain pending.
- [x] Protheus Health/ADDON/two 200,000-byte Echo calls manually accepted;
  varied request gzip 152,964 bytes, identical complete result.
- [x] SQLMIX/SQLite/MSSQL-ODBC Query, keyed dataset and database-side pagination.
  Operator accepted 29 SQLite checks on 2026-10-04, reconfirmed on 2026-10-07
  at 16:13:33, thread 27136, `profile=sqlite_demo`; real MSSQL remains pending.
- [x] Syslog UDP module exists; integration into call lifecycle is pending.
- [x] Shared protocol constants, rejection of other signatures/formats and
  [brainstorming transport review](docs/transports-sessions-security.md).

Intermediate behavior: mandatory gzip, whole JSON materialization, one
connection per call and no OS service. Optional payload/wire budgets default 0;
buffers/timeouts/workers are settings within real runtime capacities. Pages are
implemented; streaming/negotiation remain pending. A repeated-character Echo
alone is not proof of fragmented/incompressible transfer; the later varied
Echo acceptance supplies that normal-flow evidence.

## Delivery sequence

0. Organization, shared composition and baseline regressions.
1. Extensible registry, embedded NETIO, configurable networking and client INI.
2. Product framing repair, negotiated transfer, persistence and memory policy.
3. SQL/ODBC acceptance, pages, DBF/NETIO and VF IO facade.
4. Addons, contrib services and useful C/Zig extensions.
5. OS service, security, administration, packaging and operational acceptance.
6. Jobs, batches and incremental processing; optional AMQP.

SQL can use today's contract while block transfer evolves. Large values depend
on milestone 2; DBF needs NETIO from milestone1. Debugging, C/Zig and service
infrastructure can advance alongside those stages; HBDAP does not block hbdebug.

## Milestone 0: organization and independent tooling

Historical [reorganization](docs/reorganization.md) preserved reference
revision b45595b, with normalized 72 checks and 74 after extraction; distinguish
test-fixture fixes from implementation changes.

- [x] Normalize local client 127.0.0.1 and fixture HRB identities; automate setup
  without skips. Compare the baseline before/after and record the reference.
- [x] Separate host/lifecycle, dispatcher, transports, handlers, addon loader,
  telemetry and clients; maintain shared hbbridge.hbm with separate entry points.
- [x] Keep examples/mvp as a launcher of the product, not duplicated sources.
- [x] Move Harbour integration/unit/contract tests and compile all Protheus
  tests with the `src/tlpp/` tree. Exercise Health and the sample addon in Harbour.
- [x] Validate product build/CLI and structural TLPP acceptance separately;
  milestone 1 AppServer behavior was accepted 2026-10-03.
- [x] Rename TLPP files/classes consistently and related Harbour/C/Zig modules;
  retain published U_ test entry names and PascalCase classes.
- [x] Adopt `.hb` for project-owned Harbour sources, `.tlpp` for Protheus and
  `.hrb` for compiled addons; migrate current source/build/doc references,
  preserving shared basenames, ordinary `.hbp` builds and `.prg` addon support.
- [x] Move maintenance tools to .hbcommit; preserve upstream notices and remove
  the bundled bin/harbour runtime from the layout.
- [x] Pin and resolve project-owned hb_compile, Harbour and checksum-verified Zig;
  compile the required runtime/tools/contribs rather than depend on local SDKs.
- [x] Parameterize proprietary TOTVS SDK directories/environment and optional
  operator stop/start scripts. Pair English/Portuguese docs and document setup.
- [ ] Delegate selected external contrib dependencies, including OpenSSL, to
  hb_compile; consume generated environment, deploy runtime artifacts and
  validate cache receipts by capabilities/triplet/versions. No duplicate resolver.
- [ ] Resolve the pinned hb_compile native-Linux gap upstream or declare a
  supported WSL/Docker route; pin external package baselines/checksums as well.
- [x] Recompile/run renamed TLPP classes and revised optional-profile checks
  on the AppServer: operator-reported recompilation after `.hb` migration;
  Query/Config/Connection/HTTP passed on 2026-10-07. All 16 configuration
  checks were true at 16:14:06, thread 30596. No compiler log/hashes supplied.
- [ ] Execute Linux bootstrap/build/runtime acceptance and other architectures;
  Windows results do not certify them. Record build receipts and exact artifacts.

## Debugging: cross-cutting work

Native hbdebug exists, but current loader/build does not yet enable a debug
profile. Keep Harbour debug metadata distinct from native C/Zig `-debug`.

- [ ] Development profile with -b, hbdebug linkage, suitable GT/terminal and
  documented activation/source paths. Apply it to PRG/HB compilation and HRB
  preparation, preserving module/source/line identity.
- [ ] Breakpoint/step/stack/locals/resume in a handler and addon, returning the
  correct RPC response. Start with a controlled request/worker and terminal owner.
- [ ] Specify other-worker behavior during pause, debug timeouts and client
  disconnect without replaying side effects.
- [ ] Load/unload/fault/resume/stop cleanup without stale debug state; normal
  console/service must require no debugger UI. Provide an Echo/addon recipe
  with build/results, RPC correlation and separate TLPP/C/Zig investigation.

Initial acceptance: a real call stops, exposes stack/locals and resumes
correctly in both handler and addon; normal execution remains noninteractive.

Future HBDAP references: private hbdap and hbdap-vscode-extension repositories,
currently local development paths F:\GitHub\hbdap and
F:\GitHub\hbdap-vscode-extension. Existing upstream features are not delivered
or accepted in hbBridge automatically.

- [ ] Pin Harbour/HBDAP/hooks/patches, VS Code/extension/toolchain revisions;
  confirm supported runtime before optional integration with configurable paths.
- [ ] Separate controlled DAP channel, stdout/stderr/logs from DAP framing;
  clean sessions after disconnect and preserve native hbdebug operation.
- [ ] Validate breakpoints/continue/step/stack/locals in a real DAP client;
  advertise only proven capabilities. Install VSIX and document harbour-dap
  launch.json, executable/CWD/sources and chosen launch/attach modes.
- [ ] Test the installed VS Code extension against real handlers/addons,
  distinguishing simulated protocol tests from runtime tests.
- [ ] Validate worker identity, pause/resume scope and isolation before
  concurrent debugging; inspected HBDAP does not guarantee multithread/process.
- [ ] Dynamic PRG/HB/HRB source/breakpoint reload/unload invalidation, attach,
  lost debug client, call completion and host shutdown. Repeat hbdebug scenarios.
- [ ] Document separate TLPP/native debugging; do not claim unified stepping.

Acceptance: reproducible handler/addon DAP session also through installed
VS Code extension, with cleanup and documented capabilities/limitations.

## Milestone 1: common core, NETIO and network configuration

- [x] Record reference Harbour 3.2.1dev r2608271822/Zig 0.16.0/Windows x64 and
  AppServer 24.3.1.5; [acceptance](docs/acceptance.md) records exact scope.
- [x] Separate service handlers and transport representations; common registry
  includes name/version/signature/types/permissions/handler/dependencies/modes
  and exposes capability discovery.
- [x] Review xhb/trpc.prg/client and reuse its description/handler model,
  not XHBR wire format or mutable executor; keep parameters local to each call.
- [x] Namespaced services, structured types/errors and channel permissions;
  user/tenant authorization is future generic security, not ERP rule resolution.
- [x] One executable links hbnetio statically and hosts native NETIO plus
  Protheus adapters, sharing the core and isolating calls/resources.
- [x] Explicit host ownership of multithread listener connections and lifecycle,
  including restart/rollback; upstream operational patterns reused selectively.
- [x] NETIO data bind 0.0.0.0:2941 and separate admin 127.0.0.1:2940 with credential;
  configurable Protheus 0.0.0.0:1512, conflict/invalid-setting checks.
- [x] Configurable TLPP/test destination IP/DNS/port/timeout; reject 0.0.0.0
  as a destination. One strict INI/JSON schema with defaults < file < CLI,
  config-relative directories, executable-adjacent hbbridge.ini and --config-info.
- [x] Read active AppServer INI through namespaced static HBBridgeConfig:
  settings and optional SQLProfile, explicit overrides first. No demo default.
- [x] Earlier operator acceptance: 13 configuration checks, clock/RPC and 29 SQLite
  checks in report recorded 2026-10-04. Prior agent stop-process failure is
  historical; that 2026-10-04 report supplied no compiler log/time/thread/hash.
- [x] Revised operator acceptance on 2026-10-07 after reported recompilation:
  renamed TLPP and all 16 configuration checks, including explicitProfile,
  noForcedProfile and invalidProfile; Query/clock/RPC/HTTP regressions passed.
  Times/threads supplied; actual compiler log, artifact hashes, call arguments
  and effective destination were not supplied. See [acceptance](docs/acceptance.md).
- [ ] Test nondefault host/port/profile with omitted arguments and record
  binary/configuration identity.
- [x] Optional size/time budgets and configurable chunks/workers validated
  against real capacities;0disables application caps/server deadline.
- [ ] Operational memory budgets and negotiated transfer capacities in stage2.
- [x] HB_EXTERN/REQUEST __HB_EXTERN__ and explicit contrib availability;
  native symbol linkage never authorizes all functions.
- [x] RPC filters HBBridge.Call and admin HBBridge.Admin.Status.
- [ ] Additional upstream -rpc/-rpc=module evaluation; these flags are not
  exposed by hbBridge's registry/ADDON.Execute host.
- [x] Native Harbour client/core/services integration, NETIO serialization and
  service-level hb_Serialize/hb_Deserialize blobs.
- [x] U/C/L/N/D/T/A/H types, binary/hash string keys; reject cycles, objects,
  blocks and live pointers. Test admin/filter/credentials/VF IO/shutdown.
- [ ] Cross-codepage/runtime serialization compatibility and session resource IDs.
- [x] Prior milestone 1 TLPP compile/RPC accepted 2026-10-03:3sources without
  compiler errors; renamed TLPP/profile behavior accepted by the operator
  in the 2026-10-07 regression after reported recompilation.

Acceptance: native remote/core service, continued Protheus Health/Echo/addons,
configurable channels and separate admin, with each client's interoperable
protocol. An arbitrary tenant/company remains explicit caller data.

## Milestone 2: framing, volumes and compression negotiation

Initial framing repair is delivered; handshake, persistence, blocks and
negotiated compression remain pending. See [milestone 2](docs/milestone2-framing.md).

- [x] Four-space Harbour sources/.editorconfig and shared HBBRIDGE/1 constants.
- [x] Incremental gzip send/receive on Harbour, CRC/final validation, canonical
  decimal JSON length, runtime-derived header capacity, truncation/length errors.
- [x] Remove fixed16MiB/wire/header128byte/eight-digit limits; expose
  hbbridgeruntimelimits: string/socket/zlib chunk and native NETIO timeout capacity.
- [x] Optional payload/wire0, read chunk65536, server timeout30000ms (0off),
  NETIO0→native-1, maxWorkers64; CLI/file policy validation.
- [x] Fragmentation beyond65535compressed bytes, header/trailer fragmentation,
  exact24000000byte Echo, JSON/gzip beyond16MiB, positive/zero policies and
  incremental compressor; earlier305check baseline passed.
- [x] TLPP complete-unit gzip reads, partial writes, structured errors,
  full comparison and incompressible fixture, optional constructor budgets;
  first3arguments retained, positive30000ms default timeout.
- [x] TLPP TimeCounter replaces Date/Seconds/day cap; regression expires budget.
  Adapt StopWatch's reported Windows ms/Linux seconds×1000 through HBBridgeTime.
- [x] Native monotonic C clock for Harbour deadlines/uptime, replacing civil-time
  hb_MilliSeconds; test advancement and concurrent reads.
- [x] Preserve U_HBBridgeConnectionTest and namespaced static utility APIs;
  [issue12](https://github.com/naldodj/totvs-protheus-open-issues/issues/12)
  documents reproduced units.
- [x] Windows operator clock acceptance:Unix=false, delta1097.692700,
  normalized1097.773500ms after Sleep(1000), OK2026-10-04.
  Reconfirmed 2026-10-07 16:14:31, thread 27084: raw 1089.987500,
  normalized 1090.088100ms, OK.
- [ ] Linux clock, precision, clock adjustments/wrap and future build-unit changes.
- [x] Normal Protheus Health/ADDON/two 200,000-byte Echo calls accepted 2026-10-03
  and reconfirmed 2026-10-04 and 2026-10-07; varied request gzip 152,964 bytes.
- [ ] Forced socket failure/timeout/positive partial Send and exact host artifact;
  blocking Send has no timeout argument, and codec/JSON work is not budget-limited.

### Service/version contract

- [ ] Separate protocol/service versioning, discovery and unsupported capabilities.
- [ ] Small uncompressed handshake for TLPP; native NETIO capability RPC after connect.
- [ ] Negotiate codecs/compression/wire+expanded block sizes/pages/streams in
  both directions. Discover effective AppServer MAXSTRINGSIZE or configure it.
- [ ] Call ID, version, params, explicit authenticated context, deadline,
  result/metadata and code/origin errors; bind tenant as opaque caller context.
- [ ] Null/empty, exact integers/decimal/money, date/time/timezone, Unicode,
  binary/base64, named maps/arrays and byte counts; accept actual TLPP APIs.
- [ ] Versioned Health/Echo/ADDON/header/rows expectations with contract tests.
- [ ] Cooperative cancellation, idempotence and retries; never replay side
  effects automatically after an unknown/disconnected outcome.

### Persistence, pool and sessions

- [ ] Incremental framing first, then one in-flight request per persistent
  connection, explicit close, connect/read/write/call/idle deadlines.
- [ ] Configurable keepalive; measure TCP_NODELAY, needed heartbeat and
  idle/worker limits without equating live TCP with responsive application.
- [ ] Bounded pool keyed by endpoint/TLS/verified identity, exclusive lease,
  bounded queue/expiry and TLPP job/thread lifecycle before socket sharing.
- [ ] Reconnect backoff/jitter, separate retransmission/idempotence/unknown
  result and total budget; immutable correlation/identity/context per call.
- [ ] Cleanup areas/SET/transactions/buffers in every outcome; test
  STATIC/PUBLIC/PRIVATE and connector concurrency.
- [ ] Opaque session/user/tenant resources, TTL, owner validation and explicit
  close; disconnection releases transient resources by default.
- [ ] Resume requires authentication/deadline/revalidation/owner affinity;
  no automatic handle/transaction migration or storage-free durability.
- [ ] Multiplex only after pool: IDs, single reader, demultiplexed replies,
  coordinated writes/cancellation/backpressure.
- [ ] Sequential/coalesced/fragmented calls, slow consumers, expired tokens,
  network/AppServer failures; memory/workers/sockets/latency/tenant isolation.

Acceptance: sequential reuse and bounded pool, no write replay/context/resource
leaks; resume/multiplexing require their own tests.

### Incremental framing and consumption

- [ ] Version/codec/compression/call+stream ID/sequence/final/wire+expanded
  length validated before allocation/decompression. TCP is a byte stream.
- [ ] Partial/coalesced headers/bodies/writes, EOF/truncation/timeout/reconnect;
  evolve HBBRIDGE/1 without confusing JSON and transmitted lengths.
- [x] Read whole compressed response rather than decompress each Receive;
  normal varied Echo accepted, failure scenarios still pending.
- [ ] Inventory runtime/architecture/protocol/API capacities, logical volume,
  per-value/message limits, copies/expansion and installation memory policy.
- [x] Document NETIO64byte credential,8192open files/connection and certain
  uint32RPC/stream units, separately from Protheus frames/file volume.
- [ ] Negotiate per-block/connection limits in both directions; consume pages/
  blocks without full reassembly, producer pacing and bounded in-flight blocks.
- [ ] Large single fields/BLOB streams or remote IDs; a page can contain a
  column larger than MAXSTRINGSIZE. Evaluate native NETIO data/item streams.
- [ ] Ownership/expiry/cancel/disconnect cleanup; resume only where implemented.

### Compression and validation

- [ ] Negotiate none/gzip; independently compressed TLPP blocks compatible
  with native string APIs. Measure minimum size/gain/CPU/latency/local/remote use.
- [ ] Empty/incompressible/already-compressed data and native codec errors;
  interoperable binary fixtures, exact gzip vs zlib/DEFLATE wire identity.
- [ ] Expansion control during decode, not after allocation; trusted blocks
  or none profile where native APIs cannot bound expansion.
- [ ] Native NETIO compression versus HB_SERIALIZE_COMPRESS separately;
  avoid redundant compression. Unicode/binary/sizes/coalescence/failures/versions.

Acceptance: consistent types/errors on both clients; negotiated compression
and logical volume greater than a TLPP string, bounded measured memory and
per-value limits; tested slow-consumer/invalid-decode/disconnect behavior.

## Milestone 3: SQL, DBF and Harbour VF IO

### First Query and acceptance

- [x] SQLite first real backend and MSSQL/SDDODBC second; SQLMIX/RDDSQL and
  keyed alias/sql/header/rows/count/version through shared registry.
- [x] Server-owned plaintext configuration profiles in INI/JSON; never imply
  implemented encryption. [Credential proposal](docs/credentials.md) is portable.
- [x] HBBridgeRPCDataSet with JSONObject, U_HBBridgeQueryTest, explicit pages,
  errors/EOF/close, common SQL/minimal launchers and alternate profile/config.
- [x] SQL aliases are opaque/case-sensitive, including mssql/pData; multiple
  profiles coexist. Optional client default is empty; explicit call wins.
- [x] SQLite file/concurrency/NETIO-vs-TCP regressions; operator 29-check dataset/
  pagination acceptance 2026-10-04 00:40:06 and later reconfirmations,
  latest 2026-10-07 16:13:33, thread 27136, profile=sqlite_demo.
- [ ] Real MSSQL connect/query/page acceptance: driver/DSN/server/client versions.
- [ ] Unavailable connector, broader type/null coverage and real volume in
  Protheus; unknown alias is not connector-failure proof.
- [ ] hbodbc/hbsqlit3 direct API where operations require it.

### Data-access evolution

- [ ] SQL bind values and size/precision/null type metadata; identifier resolution
  stays with the caller. Generic connector/dialect registry, including Oracle
  after real type/pagination acceptance; PostgreSQL sddpg/hbpgsql and MySQL sddmy.
- [x] ROW_NUMBER/BETWEEN pages, sentinel hasNext, explicit order, OpenPage/
  NextPage; gaps in business IDs do not control ordinal pagination.
- [ ] Keyset/cursors/snapshots/deadlines/expiry/large fields and write-stability
  acceptance; measure connector materialization rather than assume pages stream.
- [ ] Explicit transaction scope/commit/rollback/failure, isolated connections/
  workareas, reuse/concurrency/batch lifecycle. No implicit Protheus rule/lock.

### DBF and VF IO

- [ ] Root/net: native RDD access; DBF/index/memo open/read/seek/write/lock/
  unlock/close under concurrency/disconnection.
- [ ] Equivalent authorized TLPP cursor/area IDs and cleanup; distinguish DBF
  RDD/NETIO from SQL Query, reusing representations only where appropriate.
- [ ] hb_vf* open/close/read/write/offset/size/directory/metadata by backend;
  local/net: first, advertise only verified features.
- [ ] Versioned Files.* TLPP facade, storage profiles/allowed paths, opaque
  session handles/TTL/close/disconnect; never serialize pointers or expose
  hb_vfHandle/configuration that leaks internal descriptors.
- [ ] Actual count/EOF/FError/partial operations/precise offsets, negotiated
  blocks without whole-file hb_vfLoad/Save outside memory policy.
- [ ] Seek/truncate/flush/commit/byte locks by provider; preserve RDD index/
  record locking. Cross-provider copy/rename with explicit unsupported errors,
  no assumed atomicity/equivalent semantics.
- [ ] Binary empty/large/offset/permission/disconnect round trips on both clients.

Acceptance: first SQL backend values/errors/close; then incremental datasets/
large fields within negotiated budgets, DBF indexes/locking/isolation and VF
binary integrity/errors/resource release. MSSQL/Oracle claims need evidence.

## Milestone 4: modules, contribs and C/Zig

### Native presentation and shared query results

- [ ] TLPP adapter from an explicit schema/paginated dataset to client-owned
  FWTemporaryTable and native browse, preserving types/nulls and cleanup.
- [ ] Separate RPCRDD.Materialize/Release contract for committed MSSQL staging
  results: explicit profiles/schema, opaque handle/ownership/lease, metadata,
  atomic publication, expiry/crash cleanup and real connector cancellation.
  Do not assume local SQL temp tables or SQLite :memory: cross connections.
  See [the result-table design](docs/evolution.md#tables-for-native-protheus-presentation).

### Module execution and native extensions

- [x] Verify THREAD STATIC isolates per-thread state, including a shared HRB,
  while retained workers preserve values across calls/reloads. Keep request
  state explicit and intentionally shared mutexes synchronized.

- [x] ADDON.Execute shared module/params contract for both clients.
- [ ] Registered module name/version rather than path; native PRG/HB/HRB reuse
  and HBNETIOSRV_RPCMAIN review for upstream -rpc=file modules.
- [ ] Module metadata/dependencies/types/permissions/errors, canonical allowed
  directories, publication/trust and isolation of symbols/statics between
  simultaneously active HRBs. Native reload may retain STATIC values.
- [ ] Cache/unload/update without invalidating active calls; process isolation
  only where justified. Business inputs remain explicit caller parameters.
- [ ] Distinguish Zig toolchain from extension language; versioned C ABI
  pointer+length/ownership/free/errors/alignment/threading/result lifetime.
- [ ] Static libraries first; DLLs only for justified independent update/ABI
  lifecycle, avoiding duplicate incompatible Harbour runtimes.
- [ ] Replace demonstration NUL-string ABI with binary/large buffers/streams,
  VM entry rules and synchronized resource ownership; integrate hb_vf/hb_file
  buffers where needed.
- [ ] First useful C/Zig extension beyond Health with measured case and both
  clients. Select hbcurl HTTP/APIs, hbexpat XML, ZIP/file/data transformations.
- [ ] Discovery advertises only enabled/accepted dependencies; explicit unavailable
  capability errors. Versioned contracts permit new services without transports.

## Milestone 5: services, security and operations

### HTTP/REST and web administration

- [x] TLPP HTTP client/example with active AppServer INI settings, native
  FWRest, GET/POST/bearer, JSON service errors and the existing SQL dataset.
  Operator accepted all 13 checks on 2026-10-07, initially thread 25672;
  reconfirmed threads 27296 (16:10:44–16:10:45) and 25456 (16:15:03–16:15:04),
  each in one second, São Paulo time. HTTP SQL backend remains unidentified.
  See [the example](examples/http/README.md).
- [ ] Extend TLPP HTTP acceptance to alternate configuration, transport failures,
  larger/mixed Unicode values, other LIBs, HTTPS and identified SQL backends.

- [x] Optional `hbhttpd` adapter dispatches to the same registered services as
  NETIO and Protheus. Separate HTTP service credentials and admin permissions;
  default disabled, configurable bind/port, no default password.
- [x] Managed, revision-pinned `hbhttpd` patch exposes the JSON request body
  and makes the native worker count configurable. Use `hbtcpio`; `-hblib` is
  the library build mode, not a separate dependency.
- [x] GET health/catalog, POST JSON service calls and authenticated read-only
  web status for hbBridge and its embedded NETIO endpoints.
- [x] Verify HTTP startup/rollback, auth separation, JSON/SQL/addons, concurrent
  calls, shutdown/restart and unchanged TCP/NETIO regressions in the full suite.
- [ ] Direct HTTPS with `hbssl`/OpenSSL: reproducible SDK/runtime resolution,
  certificate/hostname/chain/renewal and TLS policy acceptance on Windows/Linux.
  HTTP behind a TLS reverse proxy is a separate deployment configuration.
- [ ] Broader REST verb/routes, OpenAPI contract, content/compression negotiation
  and client interoperability; retain generic services and explicit caller context.
- [ ] Evaluate a Zig 0.16-compatible HTTP adapter against measured hbhttpd gaps;
  preserve shared contracts/core and define C ABI/VM thread ownership. Compare
  conformance, resource use, lifecycle and Windows/Linux acceptance first.
- [ ] Configurable HTTP admission policies for the native accepted-socket queue,
  header/body resources and deadlines. Worker count alone does not bound the
  queue; native parsing reads the body before adapter authentication.
- [ ] Expand web administration beyond status: NETIO sessions/resources,
  metrics, configuration/credential management and privileged actions with
  authorization/audit, sharing the operational core rather than spawning hbnetio.

### Services, security and deployment

- [ ] Windows hbwin service install/uninstall/name/autostart and same config
  as console; noninteractive startup independent of working directory.
- [ ] Linux supervised/signals/start/recovery/install; stop admissions, bounded
  draining/cooperative cancel and coordinated NETIO/Protheus/admin/resource cleanup.
- [ ] Admin status/diagnostics with separate credentials/interfaces/permissions;
  generic service/profile/file authorization, distinct linked/exposed core symbols.
- [ ] TSSLClient (documented AppServer19.3.1.0+) with hbssl/OpenSSL; real build,
  SSLConfigure/certificate chain/hostname/deadline/renewal tests, no plaintext fallback.
- [ ] Production TLS versions/mTLS where needed; secure NETIO/admin separately,
  never assume Protheus TLS covers every channel or copy old SSL examples.
- [ ] Optional JWT with existing library/tJWT (17.3.0.19+ documented): allowed
  algorithm, signature/issuer/audience/exp/nbf/trusted keys/rotation; decoding
  claims is not authentication and signed tokens still need protected transport.
- [ ] Identity/token renewal, service/explicit-tenant authorization and persistent
  revalidation; invalid key/signature/audience/expiry/context/certificate tests,
  no secrets/tokens in logs. ERP context remains caller-resolved.
- [ ] Portable authenticated encrypted INI secret/key-provider contract, external
  keys, local CLI set/delete/test and optional encryption-key replacement,
  later shared-core GUI; tamper/wrong
  key/nonce/ODBC escaping/atomic writes/backup/migration/service-identity tests.
  OS vaults optional, not a Windows-only requirement.
- [ ] Package 003 design: common server-side credential provider with optional
  OpenBao KV v2/AppRole or Agent/Proxy, authorized configured references,
  bootstrap/CA validation, cache/token renewal/redaction and Zig 0.16 ABI/memory
  acceptance. Store stable SQL credentials and support manual updates; automatic
  SQL password rotation/dynamic database plugins are outside this initial scope.
  Vault token renewal and encryption-key replacement do not change the SQL
  password. See the [credential review](docs/credentials.md). No service is
  implemented; this future work is not a prerequisite for MSSQL package 001.
- [ ] Configurable concurrency/timeout/queues/memory and driver/thread acceptance;
  connect Syslog lifecycle/calls, collector-failure resilience and redaction.
- [ ] Correlation/latency/errors/wire+expanded bytes/memory/active resources;
  distinguish process liveness and service readiness.
- [ ] Automated RPC/NETIO/SQL/DBF/binary/limit/concurrency/network/module/driver
  regressions, Windows/Linux restart/stop/recovery/port-conflict/bad-config tests.
- [ ] Reproducible packaging with explicit versions, installation/diagnosis/
  upgrade/recovery docs, dependency notices and implemented-feature evidence.
- [x] Official Harbour/Zig licensing comparison and [proposal](docs/licensing.md).
- [ ] Resolve FileSig/loader hbnetio GPL provenance and StopWatch TLPP adaptation;
  preserve imported GPL maintenance tools, confirm owners/permissions before
  project LICENSE/notices/SPDX/adoption. No global license adopted yet.

Acceptance: reproducible service install, remote/configurable binds, separate
admin, tested stop/recovery/cleanup and verifiable environment/metrics/docs.

## Milestone 6: jobs, batches and incremental processing

- [ ] Submit/status/progress/result/cancel contracts, explicit session/user
  owner/expiry, bounded queue/concurrency/resource pacing and stated durability.
- [ ] NETIO streams/TLPP incremental consumption without blocking the whole job;
  adapt TRPC callbacks/loop/foreach/cancel while preserving hbBridge contract.
- [ ] Concurrent cancel/progress/result and suspected TRPC message conflict
  review; disconnect differs from cancel, native calls may not be interruptible.
- [ ] Idempotent submission, batch item results/errors, negotiated limits and
  explicitly advertised atomicity/transactions.
- [ ] Large import/export/transform on the server, only necessary returned
  results; measured memory/cancel/fault/cleanup, durability/resume only if built.

### Optional AMQP

- [ ] tAMQP ↔ RabbitMQ ↔ hbBridge consumer on AMQP 0.9.1, same registry/context;
  record TOTVS/C/C-Zig library build and TLS/vhost/confirms/requeue capabilities.
  TOTVS vhost parameter documented from 24.3.0.6.
- [ ] Correlation/ReplyTo/deadlines/message limits/large-result references,
  bounded prefetch/concurrency and authorized reply destinations.
- [ ] Durable queues/persistent messages/publisher confirms/ack after persisted
  result; redelivery/deduplication/idempotence, bounded retries and failure queue.
- [ ] Producer/worker/broker failure/duplicate tests; no exactly-once promise
  where the API cannot support it. Broker-free installations remain functional.

## Conditional investigations: gRPC and Zig transport

- [ ] Obtain target smartlink.proto: tGrpc documents a predefined Smartlink
  contract from 20.3.1.0, not arbitrary gRPC. Verify actual sendMessage(s),
  build/distribution constraints and supported streaming/deadline/error modes.
- [ ] Minimal interoperable TLS/credentials/metadata/explicit-context proof;
  use existing C ABI/wrapper libraries, not new HTTP2/HPACK/Protobuf stacks.
- [ ] Adopt/defer based on evidence/dependencies/license/cost; do not infer
  generic HB_Grpc support. HTTP/2 streams still share TCP packet-loss blocking.
- [ ] Compare Zig transport/buffers against Harbour: p95/p99 latency,
  throughput/CPU/memory/copies/failure/load, VM ownership/free and measured
  zero-copy only where actually implemented.
- [ ] Keep tSktSslSrv/Conn outside the primary path unless Protheus inbound
  connections have a concrete requirement. Document proof/build/decision.

## Decisions still to make

Exact versioned handshake/frame, block sizes/memory/compression thresholds,
accepted AppServer/connector/platform matrix, extra types/TLPP conversion,
first useful C/Zig service and contrib order, access/token/module/job durability,
TLPP pool scope/session affinity/TLS-gRPC-AMQP dependencies, credential editor/
key rotation and global license/distribution. Preserve xBase familiarity,
native reuse, generic execution and both client profiles throughout.
