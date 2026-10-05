# Commit validation tools

[Português](README.pt-BR.md)

This directory contains the Harbour source checkers `check.hb`, `commit.hb`
and `3rdpatch.hb`. Their upstream copyright notices and GPL terms remain in
the sources; [LICENSE.txt](LICENSE.txt) preserves the Harbour license text.
They are development tools, separate from the pending hbBridge product
licensing decision.

Run the complete checks from the checkout root with PowerShell 7:

```powershell
pwsh ./scripts/bootstrap.ps1
pwsh ./scripts/commit-check.ps1
pwsh ./scripts/commit-check.ps1 -InstallHook
```

The wrapper resolves `hbrun` from this project's managed `hb_compile` build.
It never depends on a bundled runtime under this directory or a global
`hbrun` command. `-HbCompileRoot` and `-ZigPath` are explicit development
overrides; normal use requires the local bootstrap.

The default check covers existing tracked files and nonignored new files.
It runs both `check.hb` and `commit.hb`, validates the source naming and
documentation pairs, and executes `3rdpatch.hb -validate` for each vendored
component. The checks do not stage files, fix formatting, update dependencies
or create commits.

`-InstallHook` installs a local Git pre-commit hook only after these checks
pass. It preserves a different existing hook and reports the integration
needed. The hook calls `scripts/commit-check.ps1 -Staged`, which reads all
tracked files from the index into an isolated `tmp/` snapshot. Therefore
the gate examines the content that will actually be committed, including
staged deletions and files whose working copies differ. It does not change
the index or the checkout.

Own file names are lowercase English. Standard names such as `README`,
`AGENTS`, `TODO`, `LICENSE` and `ChangeLog` and the locale suffix `.pt-BR`
are retained. TLPP class file basenames match their PascalCase class names
converted to lowercase. Own Harbour and TLPP function, procedure, method
and namespace names are lowercase; existing `U_` test entry points remain
compatible. Own source indentation uses four spaces. Native APIs and
third-party source conventions retain their required spelling and format.

`3rdpatch.hb -validate` performs no downloads, patch applications or file
rewrites. Each component metadata file declares `ORIGIN`, `VER`, `URL`,
`MAP` and one `SHA256` for every mapped file. Hashes normalize CRLF to LF
so a Git checkout on Windows or Linux produces the same verification.
Updating vendor content requires a separate reviewed update of provenance
and checksums; normal commits only validate them.

The `commit.hb -c` mode returns failure when validation fails, and its normal
preparation mode uses the shared `check.hb` policies. Forced validation
bypass is disabled. Local optional identity configuration belongs in
`.hbcommit/config.ini`, which is ignored; `.hbcommit` is a directory.

The old runtime and unrelated local helpers were preserved in ignored
`tmp/commit-runtime-before-bootstrap/` and `tmp/commit-tools-legacy/`
during migration. They are not project dependencies.
