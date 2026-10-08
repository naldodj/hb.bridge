# hbBridge conventions

[Português](AGENTS.pt-BR.md) · [Detailed standards](docs/standards.md)

- For package work, read [WIP.md](WIP.md) and resume its next unfinished task.
  Update progress/evidence and both language versions. Reopen decisions only
  for new evidence, reproducible failures, changed requirements/dependencies
  or user instructions. Renew WIP after its completion criteria pass;
  intermediate commits/publication do not reset it. TODO retains the roadmap.
- Use four spaces per indentation level in project-owned sources. Preserve
  upstream formatting, copyright and license notices in third-party files.
- Use English identifiers. Files are lowercase. Functions, procedures,
  methods, namespaces and classes use PascalCase, as explicitly agreed with
  the project owner. A class file uses its exact class name in lowercase:
  `HBBridgeClient` lives in `hbbridgeclient.tlpp`.
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
