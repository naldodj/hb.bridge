# hbBridge conventions

[Português](AGENTS.pt-BR.md) · [Detailed standards](docs/standards.md)

- For package work, read [WIP.md](WIP.md) and resume its next unfinished task.
  Update progress/evidence and both language versions. Reopen decisions only
  for new evidence, reproducible failures, changed requirements/dependencies
  or user instructions. Renew WIP after its completion criteria pass;
  intermediate commits/publication do not reset it. TODO retains the roadmap.
- Use four spaces per indentation level in project-owned sources. Preserve
  upstream formatting, copyright and license notices in third-party files.
- Treat `tmp/` as entirely disposable scratch. Commands must not require a
  previous tmp run. Version reusable helpers/fixtures in `scripts/`/`tests/`;
  keep sanitized acceptance summaries in `docs/validation/`. Historical tmp
  log paths are provenance, never retention requirements. `out/` is generated;
  managed build dependencies belong in `.deps/`.
- Compile TLPP from its maintained source path whenever possible. If a test
  or validation needs copied/generated `.tlpp` files under `tmp/`, remove them
  immediately after use, including failures, with `try`/`finally` or equivalent
  cleanup. Retained duplicate sources confuse the TOTVS extension's source
  resolution. Keep logs, source lists and hashes as evidence instead of copies;
  never delete the maintained originals during this cleanup.
- Use `#include "totvs.ch"` as the default TLPP header. Add `tlpp-core.th`,
  `tlpp-rest.th` or other headers only for declarations/macros actually used,
  not merely because a source has the `.tlpp` extension.
- Prefer `tlpp.ToStr(nValue)` for ordinary TLPP numeric-to-text conversion.
  Use explicit formatting when width/scale is part of the output contract.
  Keep alias-scoped negation inside the expression: `(cAlias)->(!Eof())`.
- Numeric JSON uses the shared precision-preserving codec, independently of
  `SET DECIMALS`/`SET FIXED`. Do not change global SETs to repair serialization
  or infer business rounding. Restore temporary addon SET changes on every exit.
- Group variable declarations by data type and order the groups alphabetically
  by their type prefix, for example `a`, `c`, `d`, `j`, `l`, `n`, `o`, `x`.
  Full variable names within a type group need not be alphabetized. Preserve
  initialization dependencies; assign values after declarations when needed.
- Resolve constants and loop-invariant expressions before loops, including
  character conversions and lengths of unchanged strings/containers. Keep
  changing values, clocks, I/O and mutable-state checks inside the loop.
- Use English identifiers. Files are lowercase. Functions, procedures,
  methods, namespaces and classes use PascalCase. Source basenames use
  lowercase words separated by dots:
  `HBBridgeClient` lives in `hbbridge.client.tlpp`. Removing the dots must
  yield the class name in lowercase; dots do not denote namespace segments.
- Write project-owned source comments, error messages, logs and UI labels in
  English. Translate Portuguese comments encountered while editing or reviewing
  sources, preserving their technical meaning and external API names. Preserve
  external API text and intentional language/encoding test data. Portuguese
  documentation remains in the paired `.pt-BR` files.
- Write documentation in an impersonal style, focused on decisions, results
  and evidence. Prefer "Validation confirmed" or "Validation recorded".
  Distinguish manual AppServer execution from local automated checks through
  the validation method and artifacts, preserving dates, scope and status.
- Use the same module naming convention for Harbour, TLPP, C and Zig;
  extensions identify the language. Product modules start with `hbbridge`.
- Use `.hb` for project-owned Harbour sources, tests and addons. Preserve
  upstream `.prg` files and support for external/runtime `.prg` inputs.
  `.hbp`/`.hbm` entries compile `.hb` as source; a `.hb` path as the first
  `hbmk2` argument selects script execution. For direct compilation, put
  `-hbexe` (executable) or `-gh` (HRB) before the source path.
- Preserve conventional Git document names (`README`, `LICENSE`, `AGENTS`,
  `TODO`, `ChangeLog`), the project's requested `WIP.md`/`WIP.pt-BR.md` names
  and the agreed `.pt-BR` locale suffix. Pair English
  documentation with Portuguese. Other document basenames are lowercase English.
- Preserve external API spellings, case-sensitive protocol/JSON fields and
  compiler-required C macros/symbols, including uppercase `HB_FUNC` symbols.
- Prefer Harbour hashes for records, settings, metadata and keyed lookups.
  Prefer TLPP `JSONObject` for JSON contracts and `THashMap` for suitable
  internal maps. Use arrays only where a native API or contract requires them;
  document the concrete allocation/copy/search tradeoff.
- Expose public Protheus APIs through classes with explicit namespaces. Use
  static methods for utilities without state; local helpers may be static
  functions. Existing test procedures with the `U_` prefix keep their
  published names, such as `U_HBBridgeConnectionTest`.
- Use Harbour `THREAD STATIC` for mutable state owned by a worker thread.
  Initialize per-request state explicitly or keep it in locals/parameters;
  worker reuse and HRB reload do not imply a reset. Shared process resources,
  such as the SQL mutex, retain synchronized ordinary `STATIC` storage.
- Keep hbBridge generic. Protheus resolves its business rules, tenant, company,
  branch, `xFilial` and physical table names; services/addons receive explicit
  inputs. SQL aliases are opaque keys, never automatic ERP context resolvers.
  The TLPP library must not force a demo database profile.
- Obtain active Protheus DBAccess connection settings through `FWGetTopInfo()`
  instead of reconstructing server/port/database/alias from INI keys. Preserve
  an existing connection and close only a connection opened by the caller.
- In TLPP `catch xError` blocks, consume the captured value and release an
  object with `if (ValType(xError)=="O"); FreeObj(@xError); endif` after handling
  it. Keep the variable declared as variant; the compiler must see its use.
- Reuse native `hbhttpd` for HTTP/REST and web administration through the
  shared service core. Keep runtime dependencies and enabled capabilities
  explicit; `-hblib` is a build mode, not a separate Harbour contrib.
- The Protheus preprocessor turns `User Function Name` into `U_Name`.
  Existing direct `procedure U_Name` declarations need no conversion.
- Resolve build dependencies with `scripts/bootstrap.ps1` and the pinned
  `config/dependencies.json`. Do not hardcode a developer's SDK checkout or
  use the former bundled `bin/harbour` runtime.
- Before every commit, run `scripts/commit-check.ps1`: it must pass
  `.hbcommit/check.hb`, `.hbcommit/commit.hb` and the read-only validation mode
  of `.hbcommit/3rdpatch.hb`. Do not bypass failed checks or mutate the index.
  Default scope is changed/new files; `-Staged` validates changed indexed
  contents and `-All` requests a full review. Policy/tool/configuration changes
  force full validation; third-party checks always retain their global scope.
