# Naming, source layout and contribution standards

[Português](standards.pt-BR.md)

Use four spaces in project-owned source. Imported Harbour maintenance tools
and zlib headers keep their upstream formatting and notices. Use English
identifiers. Files, namespaces, functions and methods are lowercase; classes
use PascalCase, following the owner's explicit clarification. Conventional
Git filenames and the `.pt-BR` locale suffix are exceptions to lowercase.

| Responsibility | TLPP class / file | Harbour module |
| --- | --- | --- |
| Client | `HBBridgeClient` / `hbbridgeclient.tlpp` | Native clients use NETIO APIs; no redundant client class is introduced. |
| Configuration | `HBBridgeConfig` / `hbbridgeconfig.tlpp` | `host/hbbridgeconfig.prg` and `host/hbbridgeini.prg` configure the server. |
| Time | `HBBridgeTime` / `hbbridgetime.tlpp` | `src/c/hbbridgetime.c` implements the monotonic server clock. |
| SQL dataset | `HBBridgeRPCDataSet` / `hbbridgerpcdataset.tlpp` | `services/hbbridgequery.prg` implements SQL requests. |

Matching names identify related responsibilities; these modules retain their
different client/server roles. Harbour procedural modules do not need empty
classes simply to imitate TLPP. Future Harbour classes must also live in a
file whose basename is their class name in lowercase.

Examples: `hbbridge.client.HBBridgeClient():new()` and
`hbbridge.rdd.HBBridgeRPCDataSet():opensql(...)`. Existing `U_` test entry
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

English documentation uses the base filename; Portuguese adds `.pt-BR` before
the extension. Update both together and preserve acceptance records,
restrictions and pending work. Historical changelog paths describe the files
that existed at the time; current instructions use the new names.

The [managed build](dependencies.md) owns dependencies under `.deps/`.
`.hbcommit/` contains maintenance utilities, not a second runtime. Run the
[commit gate](../scripts/README.md) before every commit: all three Harbour
tools must succeed. Validation does not fix files, apply third-party patches
or stage changes. Preserve upstream licenses independently of the pending
[project licensing decision](licensing.md).
