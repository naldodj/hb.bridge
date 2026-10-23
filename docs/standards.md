# Naming, source layout and contribution standards

[Português](standards.pt-BR.md)

Use four spaces in project-owned source. Imported Harbour maintenance tools
and zlib headers keep their upstream formatting and notices. Use English
identifiers. Files are lowercase; functions, procedures, methods, namespaces
and classes use PascalCase. Conventional
Git filenames and the `.pt-BR` locale suffix are exceptions to lowercase.

Group variable declarations by data type, with a blank line between groups,
and order the groups alphabetically by their type prefix: for example `a`
(array), `c` (character), `d` (date), `j` (JSON), `l` (logical), `n` (numeric),
`o` (object), `x` (variant). Full names within a group need not be alphabetic.
Preserve initialization dependencies; separate declaration and assignment
when their order would otherwise change behavior. Apply the corresponding
type grouping in languages that use different declaration conventions.

Resolve constants and loop-invariant calculations before the loop: for
example `cNul := Chr(0)` and `nLength := Len(cText)` when `cText` is unchanged.
Compute changing values once per iteration where useful. Do not hoist clocks,
I/O, mutable-state checks or lengths of containers that grow/shrink during
iteration. A cached value must remain valid for the entire loop.

For ordinary TLPP numeric-to-text conversion, use `tlpp.ToStr(nValue)` instead
of `AllTrim(Str(nValue))`. Formatting with a required width, decimal scale or
mask remains explicit; generic conversion must not silently replace such a
contract. Write alias-scoped conditions as `(cAlias)->(!Eof())`, keeping the
negation inside the selected work area's expression.

Source basenames separate lowercase words with dots, for example
`hbbridge.rpc.dataset.tlpp`. Removing dots must match the lowercase class
name `HBBridgeRPCDataSet`. This word segmentation does not change namespaces.
Own error messages, logs and UI labels are English; external text and intentional
accent/encoding fixtures retain their original language. Portuguese documentation
uses its paired `.pt-BR` files.

Write documentation in an impersonal style. Record decisions and results as
"Validation confirmed" or "Validation recorded", supported by dates and
artifacts. Describe manual AppServer runs and local automated checks by their
method and evidence, preserving scope, limitations and pending acceptance.

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
| Client | `HBBridgeClient` / `hbbridge.client.tlpp` | Native clients use NETIO APIs; no redundant client class is introduced. |
| HTTP client | `HBBridgeHTTPClient` / `hbbridge.http.client.tlpp` | `transports/http/hbbridge.http.hb` adapts HTTP to the shared registry. |
| Configuration | `HBBridgeConfig` / `hbbridge.config.tlpp` | `host/hbbridge.config.hb` and `host/hbbridge.ini.hb` configure the server. |
| Time | `HBBridgeTime` / `hbbridge.time.tlpp` | `src/c/hbbridge.time.c` implements the monotonic server clock. |
| SQL dataset | `HBBridgeRPCDataSet` / `hbbridge.rpc.dataset.tlpp` | `services/hbbridge.query.hb` implements SQL requests. |

Matching names identify related responsibilities; these modules retain their
different client/server roles. Harbour procedural modules do not need empty
classes simply to imitate TLPP. Future Harbour classes must also live in a
file whose dotted basename, with dots removed, is their class name in lowercase.

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

## Runtime SETs and numeric contracts

Keep Harbour's native presentation defaults (`DECIMALS 2`, `FIXED OFF`);
increasing `SET DECIMALS` is not a serialization repair. The generic core
does not establish a monetary scale or add an arbitrary SET override section
to the INI. A functional requirement must identify each setting, its scope
and its restoration before configuration is introduced. SQL logical scale
and rounding remain explicit caller decisions.

| Concern | Policy |
| --- | --- |
| `SET DECIMALS` / `SET FIXED` | Presentation/operation context, never JSON numeric precision. Preserve the finite native value with `HBBridgeJSONEncode/Decode`, including the addon JSON ABI. |
| Temporary addon settings | Save the previous value and restore it in `ALWAYS`, including errors. Worker reuse and `THREAD STATIC` do not reset SETs between calls. |
| JSON text/codepage | TCP/HTTP request adapters select UTF8EX for execution and restore the previous worker codepage on every exit. Configuration and credentials keep their original bytes. |
| Business/DBF settings | Do not infer `DELETED`, `EXACT`, date format, epoch, locking or ERP rules from a SQL alias. A caller/addon defines any required behavior explicitly and owns temporary changes. |

Binary floating-point remains approximate. A precision-preserving codec avoids
additional serialization rounding; it does not make floating-point arithmetic
an exact decimal type. Explicit SQL CAST/rounding and exact decimal text retain
their documented roles. Regression checks exercise the addon ABI with both
`DECIMALS 2/18` and `FIXED OFF/ON`, restoring the previous test context.

English documentation uses the base filename; Portuguese adds `.pt-BR` before
the extension. Update both together and preserve acceptance records,
restrictions and pending work. Historical changelog paths describe the files
that existed at the time; current instructions use the new names.

## Generated files and reproducibility

`tmp/` is scratch: every entry may be discarded, including logs, copied RPOs,
generated fixtures and pointers. No maintained command requires an earlier tmp
run. Reusable programs/probes belong to `src/`, `addons/`, `scripts/` or `tests/`;
public templates belong to `config/examples/`. `out/` contains generated
deliverables, and `.deps/` contains dependencies resolved from pinned inputs.
Neither tmp nor out is a location for versioned source or permanent evidence.

Keep sanitized acceptance summaries, source/dependency identities, commands and
external prerequisites in [validation documentation](validation/README.md).
A new run produces a new log; it does not recreate the exact historical machine
state/timing. Optional raw historical archives are external, never prerequisites.
Dated tmp paths in acceptance/ChangeLog describe past output locations, without
requiring their continued existence. Explicit cleanup exclusions are temporary
operational choices, not permission to create hidden project dependencies.

TLPP defaults to `#include "totvs.ch"`. Add `tlpp-core.th`, `tlpp-rest.th` or
other headers only for symbols/macros actually used, for example native REST
annotations. Namespace/class declarations alone do not justify extra includes.

## Active work packages

The agreed `WIP.md` and `WIP.pt-BR.md` names are explicit uppercase filename
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
