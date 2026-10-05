# Licensing proposal and provenance

[Português (Brasil)](licensing.pt-BR.md)

Status on 2026-10-04: a proposal, **no global license adopted**.
Several project files have public-domain notices; vendor files have their own
licenses. No root LICENSE or complete notices inventory has been published.
This proposal does not replace existing terms.

## Proposed model

The recommendation for enterprise integration is **MIT for genuinely original
hbBridge code**, in Harbour, C, Zig and TLPP, once provenance below is resolved.
MIT permits use, modification and commercial distribution, including closed
products, while preserving required notices; it does not require publishing
modified source. See [MIT at OSI](https://opensource.org/license/mit).

Compiler/language licenses do not automatically determine application licenses.
Use standard license texts and a component inventory, rather than creating
a hybrid "Harbour + Zig" legal text.

| Component | Verified terms / treatment |
| --- | --- |
| Original hbBridge code | MIT proposal, subject to provenance; decision pending. |
| Harbour libraries | Generally GPL v2 or later with linking exception; inspect each contrib/file. |
| Harbour compiler/utilities | Generally GPL v2 or later; library exception does not automatically apply to utility source. |
| Zig | MIT; bundled third-party toolchain components retain their own notices. |
| Vendored zlib headers | Existing zlib license/copyright preserved. |
| `.hbcommit` check/commit/third-party patch tools | Upstream GPL notices preserved; maintain separate provenance and terms. |

The Harbour exception means linking its libraries alone does not impose GPL
on the application. It does not permit relicensing copied GPL utility code or
remove distributed-library obligations.
References: [Harbour terms](https://github.com/harbour/core/blob/master/LICENSE.txt),
[Zig license](https://github.com/ziglang/zig/blob/master/LICENSE).

An alternative, if distributed server modifications should require source
availability, is **GPL v2-or-later server plus MIT original TLPP client**.
That still depends on each part's provenance and grants no exception for
other authors' code. Charging for GPL software does not make its distribution
conditions equivalent to MIT.

## Findings in current sources

The `FileSig` helper in
[the addon loader](../src/hb/addons/hbbridgeaddon.prg) matches the upstream
`hbnetio.prg` helper after whitespace normalization; the load/compile flow
also resembles it. The upstream utility header is GPL v2-or-later without
the library linking exception. A local public-domain notice does not establish
provenance. This is evidence requiring review, not a conclusion about ownership
or legal scope. MIT adoption requires clarifying origin and applying the
relevant terms/permissions.
[Compared upstream source, commit 8d94c31](https://github.com/harbour/core/blob/8d94c31367104a57eb9ae6fa248cca2abb8db309/contrib/hbnetio/utils/hbnetio/hbnetio.prg#L809-L829).

[The TLPP clock](../src/tlpp/hbbridgetime.tlpp) records adaptation of
`dna.tech.StopWatch.__GetCurrentTimeStamp()`. The local `naldodj-tlpp`
checkout has LGPL 2.1 in LICENSE.txt. Confirm ownership and applicable
adaptation terms before standardizing notices; a repository name is not
relicensing permission.

[The zlib record](../src/c/third_party/zlib/README.md) identifies two copied
headers and their source commit; notices remain intact.
TRPC analysis reused design ideas, with no identified copying of its classes,
protocol or executor into hbBridge.

The project-adapted `check.hb`, `commit.hb` and `3rdpatch.hb` preserve
upstream copyright/GPL notices. Moving them to `.hbcommit` or interpreting them
with a locally built hbrun changes neither authorship nor license.

## Formalization after the decision

Create LICENSE with the selected standard text and verified copyright holders,
a third-party notices inventory with origin/version/terms, and required
distribution texts. Add SPDX only where authorized, preserving vendor notices
and previously granted permissions.

The binary package must also account for Harbour runtime, SQL/NETIO contribs,
SQLite, zlib and actual toolchain-incorporated components. Source review alone
does not certify the complete binary package.
[TODO](../TODO.md) tracks licensing and provenance as pending.
