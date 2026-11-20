# Addon publication and native execution: design review

[Português](addon-publication.pt-BR.md) · [Current example bundle](addon-bundle.md) · [Roadmap](../TODO.md)

This document records a proposal and a review of a native-addon idea. It does
not introduce an addon registry, discovery endpoint, native loader or new
authorization policy. Those capabilities require a later implementation and
acceptance. Business rules may reside in trusted Harbour addons; the host remains
generic and the caller supplies explicit application context.

## Current behavior

`ADDON.Execute` accepts a relative `module` and `params`. The server resolves
the module under `addonRoot`; the path is not currently an individual publication
registry. Its [executor](../src/hb/addons/hbbridge.addon.hb) compiles `.hb`/`.prg`
as needed or loads an HRB with `HB_HRB_BIND_FORCELOCAL`, executes it with JSON
and a native context, and unloads its HRB handle for each call. Installed addon
code is trusted code with the privileges of the hbBridge process.

The example bundle has a hardcoded, case-sensitive action map inside the HRB.
The map is specific to that example bundle, not a limitation requiring every
independent addon to use the same actions. `Service.List` advertises services;
it is not a publication catalog for individual addons. The current channel
permission `addon.execute` is not per-user or per-addon authorization.

## Proposed publication and discovery

An administrator-controlled catalog could map a stable logical name and version
to an installed module and an explicit entry contract. For example, the following
is a possible future INI format, **not a supported configuration today**:

```ini
[Addon/turnover]
Enabled=1
Module=examples/hbbridgeaddons.hrb
Contract=bundle-action-v1
Action=turnoverReport
```

A future request could name `turnover` and provide only its parameters. The
server, not the caller, selects the trusted module and the configured bundle
action. Independent HRBs can retain a direct entry contract. Mapping an action
does not automatically register arbitrary functions inside an HRB: the chosen
entry contract and its supported actions still need to be defined and validated.
The current example bundle would still need to recognize its own actions.
For a native addon, the same logical identity and version could resolve to an
administrator-installed `.dll` on Windows or `.so` on Linux; the server would
select its platform artifact rather than accepting a binary path from the client.

The proposed catalog would validate identifiers, duplicate entries, versions,
enabled state and allowed artifact paths, including traversal and filesystem
link handling. Entries should refer to administrator-installed artifacts under
an allowed root; a client must not supply a filesystem path or function symbol
to bypass a registered-only policy. Preserve existing `module` callers through
an explicit compatibility mode and define its migration and default before
implementation; enabling a registry alongside unrestricted paths alone would not
enforce publication. Startup, update and reload semantics remain design choices.

A future catalog endpoint could expose the logical name, version and enabled
state to an authorized caller, without disclosing local paths or credentials.
Distinguish **configured/enabled**, **artifact present**, and **validated or
loaded**: a configuration entry or existing file alone does not prove that it
will load or execute successfully. Do not run business actions as a discovery
probe. Channel restrictions and, when implemented, authenticated identity and
per-addon authorization should filter discovery and execution consistently.
Protheus menus may consume the catalog, while user permissions remain the
responsibility of the application and the eventual server authorization model.

## Review of the native addon idea

**Target scope:** if native addons are adopted, they must support Windows and
Linux under the same logical publication and invocation contracts. The host may
use platform-specific loading and build mechanisms behind that contract. A
Windows-only prototype would be an intermediate experiment, not completion of
the native-addon feature. This does not change the current HRB execution model.

Compiling Harbour functions through `-gc3` to C can be worth benchmarking for
CPU-heavy work. It still uses Harbour VM/runtime operations; it is not a promise
that every expression becomes independent native arithmetic. In the pinned
[Harbour C generator](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/src/compiler/gencc.c),
codeblocks can still contain pcode. An HRB compiled with `-gh` remains an HRB;
the host's `-gc3` does not make the HRB's functions native. SQL, encoding,
loading and transport costs must be measured separately.

The reviewed DLL idea is plausible as a proof of concept, but its assumptions
do not establish a portable implementation:

- The pinned [`hbmaindllp` bridge](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/src/vm/maindllp/dllpcode.c)
  is Windows-specific; this observation concerns that bridge, not a platform
  restriction on hbBridge. The pinned Harbour [`hb_LibLoad` implementation](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/src/vm/dynlibhb.c)
  also has a `dlopen` path where supported. That path alone does not prove that
  a native addon shares the intended VM safely. Linux needs a tested linkage and
  symbol-export strategy; macOS is a separate future evaluation.
- The project and proposed sample have different entry contracts: the current
  HRB receives JSON and native context, whereas the proposed example receives a
  hash. An adapter must preserve error, ownership and permission semantics.
- An HRB `STATIC` pointer is not a reliable process-wide singleton across the
  current unload/reload lifecycle. Concurrent first loads, global symbol
  collisions, ABI compatibility, retained classes and active calls must be
  handled explicitly before any library is cached or unloaded.
- The proposal's `-ldflags=` examples are not the `hbmk2` command-line/project
  option in the pinned tool: its option is `-ldflag=`. The flag meaning and
  availability still have to be verified separately for each linker and OS.
  `-static` also does not by itself prove a fully static system executable.
- Native libraries execute within the server process and are trusted code;
  exporting VM symbols does not provide isolation. Whether `hb_DynCall`, direct
  Harbour symbols or an explicit versioned C ABI is suitable depends on the
  actual interface; no blanket prohibition or safety guarantee is assumed.

Before changing the loader, measure equivalent results and JSON contracts for
the current HRB, a candidate that caches HRB **bytes** while loading a separate
handle per call, and a native prototype. Measure cold/warm load time, execution,
SQL, serialization, memory and concurrent behavior separately. Verify version
replacement, failure recovery, shutdown, ownership and platform compatibility.
The existing [benchmark evolution](benchmark-evolution.md) already tracks native
C/Zig comparisons. A native addon should be adopted only if measurements and
its lifecycle justify the additional complexity.

The platform feasibility test should build and run the same small addon on
Windows (`.dll`) and Linux (`.so`, including WSL as an initial Linux environment),
using the same public addon identity, input and result. Evaluate Windows VM
bridging and, on Linux, a shared Harbour runtime or host-exported VM symbols;
the choice is not yet made. Verify that each process uses the intended compatible
VM, without a second incompatible runtime, and test concurrent calls, error
handling, load lifetime and version changes on both systems. Neither a successful
build nor the presence of `dlopen` alone establishes these guarantees.
