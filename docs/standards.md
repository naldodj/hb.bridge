# Naming, source layout and contribution standards

[Português](standards.pt-BR.md)

Use four spaces in project-owned source. Imported Harbour maintenance tools
and zlib headers keep their upstream formatting and notices. Use English
identifiers. Files are lowercase; functions, procedures, methods, namespaces
and classes use PascalCase, following the owner's explicit clarification. Conventional
Git filenames and the `.pt-BR` locale suffix are exceptions to lowercase.

Project-owned Harbour modules, tests and addons use `.hb`; imported upstream
sources retain `.prg`. External/runtime `.prg` inputs remain supported. This
extension convention does not change the Harbour language or module names.
Both `.hb` and `.prg` are classified as xBase by GitHub Linguist and checked
for class filenames, PascalCase declarations and four-space indentation.
Imported maintenance utilities and third-party sources keep their exceptions.

`hbmk2` compiles `.hb` source entries in `.hbp` and `.hbm` build files.
On the command line, a `.hb` path as the first argument selects script
execution, like `hbrun`. For direct source compilation, put `-hbexe` before
the path to build an executable, or `-gh` before it to produce an HRB:
`hbmk2 -hbexe module.hb` or `hbmk2 -gh module.hb`.

| Responsibility | TLPP class / file | Harbour module |
| --- | --- | --- |
| Client | `HBBridgeClient` / `hbbridgeclient.tlpp` | Native clients use NETIO APIs; no redundant client class is introduced. |
| HTTP client | `HBBridgeHTTPClient` / `hbbridgehttpclient.tlpp` | `transports/http/hbbridgehttp.hb` adapts HTTP to the shared registry. |
| Configuration | `HBBridgeConfig` / `hbbridgeconfig.tlpp` | `host/hbbridgeconfig.hb` and `host/hbbridgeini.hb` configure the server. |
| Time | `HBBridgeTime` / `hbbridgetime.tlpp` | `src/c/hbbridgetime.c` implements the monotonic server clock. |
| SQL dataset | `HBBridgeRPCDataSet` / `hbbridgerpcdataset.tlpp` | `services/hbbridgequery.hb` implements SQL requests. |

Matching names identify related responsibilities; these modules retain their
different client/server roles. Harbour procedural modules do not need empty
classes simply to imitate TLPP. Future Harbour classes must also live in a
file whose basename is their class name in lowercase.

Examples: `HBBridge.Client.HBBridgeClient():New()` and
`HBBridge.RDD.HBBridgeRPCDataSet():OpenSQL(...)`. Existing `U_` test entry
points retain their published spelling. Public Protheus utilities belong to
namespaced classes, with static methods when they have no state. Local static
helpers are allowed. External APIs (`JSONObject`, `TimeCounter`, `hb_Serialize`),
wire fields and compiler-required C macros retain their defined names.

Prefer hashes/objects for named data. Arrays require a concrete native API or
public contract, such as socket addresses, SQLRDD connection arguments or
codec chunks. Explain the justification beside the code.

The product has one implementation under `src/`. Examples launch that product;
tests exercise those same components. `examples/mvp` is a historical example
directory, not a second implementation or an independent product contract.

Use `THREAD STATIC` for mutable Harbour state owned by a worker thread;
per-request state uses locals/parameters or explicit initialization. A reused
thread can retain values across requests and HRB reloads. Process-wide mutexes
and coordinated shared resources remain ordinary synchronized statics. See
[the runtime review](evolution.md#thread-state-and-request-state).

English documentation uses the base filename; Portuguese adds `.pt-BR` before
the extension. Update both together and preserve acceptance records,
restrictions and pending work. Historical changelog paths describe the files
that existed at the time; current instructions use the new names.

## Active work packages

The user-requested `WIP.md` and `WIP.pt-BR.md` are explicit uppercase filename
exceptions. [WIP](../WIP.md) contains one active package's objective, ordered
tasks, established decisions, prerequisites, progress, evidence and completion
criteria. TODO remains the complete roadmap; acceptance and ChangeLog record
results/history. Read WIP to resume the next task instead of restarting analysis.

Update both versions throughout a package. Reconsider decisions only when
new evidence/failures, changed requirements/dependencies or user instructions
justify it, recording the reason. Close with attributable evidence, reconcile
TODO and preserve closure in acceptance/ChangeLog before renewing the same
files for the next bounded package. Commits and publication are independent
of package closure; they do not erase unfinished work. Git retains old WIP versions.

The [managed build](dependencies.md) owns dependencies under `.deps/`.
`.hbcommit/` contains maintenance utilities, not a second runtime. Run the
[commit gate](../scripts/README.md) before every commit: all three Harbour
tools must succeed. Validation does not fix files, apply third-party patches
or stage changes. Preserve upstream licenses independently of the pending
[project licensing decision](licensing.md).
