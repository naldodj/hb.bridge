# Active hbBridge work package

[Português](WIP.pt-BR.md) · [Roadmap](TODO.md) · [Acceptance](docs/acceptance.md)

## Package 004: portable server credential protection

The first slice protects a configured SQL credential in hbBridge at rest on
Windows and Linux. Protheus continues to send only the opaque SQL profile and
application context. The common design must allow later NETIO, administration
and HTTP consumers; TLPP client-side protection requires a separate verified
provider. No secret-storage or transport-security capability is implied until
its own acceptance. See [credential review](docs/credentials.md).

- [x] C01: inventoried current configuration, consumers, diagnostic exposure and
  toolchain. Specified the versioned authenticated SQL password envelope,
  external-key file provider, compatibility and recovery boundaries. The
  Windows x64 and Linux x86_64 WSL2 probes passed for binary serialization,
  authenticated encryption, secure OS entropy and the synthetic Harbour/C/Zig
  ABI with pinned Harbour and Zig 0.16.0. Windows Authz and transient Linux
  service units validated the access model with synthetic data. Production
  provider validation remains in C02 and deployment identity acceptance in C05.
  See the [C01 design and evidence](docs/credentials.md#c01-native-building-blocks-and-local-administration).
- [ ] C02: implement and test the portable local server provider and key lifecycle;
  authenticated encryption, unique nonces, context binding, explicit errors,
  no embedded master key and minimal secret lifetime. Prevent downgrade or
  treating ciphertext as a password when resolution fails.
  The Harbour/C/Zig bridge and initial synthetic test passed 45 checks on
  Windows, with a DACL restricted to the current user and LocalSystem. Ubuntu
  WSL passed 45 checks as root with mode 600, both with global Harbour
  r2610242111 and with an isolated managed Harbour r2609292008 and Zig 0.16.
  Private staging and exclusive publication passed normal, concurrent and
  controlled interruption tests on both platforms. A crash can leave a private
  staged key. Synthetic recovery tests on Windows and WSL remove the orphan after the
  interrupted process exits, creates a complete key and confirms retries do not
  replace it. Filesystem durability and service identities remain open.
  Simulated cleanup failures preserved an existing key on Windows and
  WSL, and preserved the published key and staged copy after publication on WSL.
  The reader now rejects unsafe existing-key permissions: synthetic Windows
  tests covered an Everyone grant and inherited DACL; WSL covered mode 0644
  and a synthetic key created and used by the unprivileged `nobody` identity.
  A synthetic envelope and its key were transferred and decrypted successfully
  Windows to WSL and WSL to Windows; changing each bound context field failed.
  Windows key paths now decode UTF-8 independently of the active Harbour codepage;
  the synthetic provider suite passed 48 checks on Windows and on WSL as root
  with global Harbour and Zig 0.16, including cross-codepage access.
  This checks the provider format, not INI migration or SQL authentication.
  Actual separate service identities and deployment filesystems still need
  acceptance. The provider is integrated with structured SQL; interactive local
  credential editing remains unfinished.
- [ ] C03: integrate the provider into one MSSQL SQL-authentication profile with
  ODBC-safe escaping. Keep integrated authentication and existing configurations
  compatible; reject ambiguous plaintext/reference combinations and do not expose
  credentials through diagnostics, errors, config-info, discovery or logs.
  The managed ODBC patch no longer requests a completed connection string or
  includes the input in allocation errors; connection failure reports SQLSTATE
  and a fixed message. Synthetic missing-DSN redaction and the read-only real
  MSSQL suite passed on Windows. Structured INI/JSON references now survive
  normalization and resolve only for connection attempts; synthetic tests cover
  escaping, conflicting forms, absent keys, altered envelopes and redaction.
  The focused suite passed 24 checks on Windows and on Ubuntu WSL as root with
  the isolated managed Harbour/Zig toolchain; no Linux MSSQL server was tested.
  A read-only Windows/MSSQL probe encrypts the configured password in memory,
  builds a temporary protected JSON profile and uses the regular query path.
  The focused loopback fixture passed 23 checks per run on Windows and
  Ubuntu WSL, covering missing keys and altered authentication tags over
  TCP and HTTP. Provider causes remain distinct internally. Both transports
  returned the sanitized `CONNECTION_FAILED` result, and HTTP used status
  500. Responses and captured output contained no synthetic credential
  markers, Echo recovered after each failure and ODBC remained untouched.
  The full Harbour suite passed 920 checks on Windows. Service-identity
  and live Linux MSSQL acceptance remain open.
- [ ] C04: provide a local credential utility with non-echoed input, no secrets in
  command-line arguments, atomic updates and documented key permissions, backup,
  manual update and migration. No automatic database password rotation.
  Provide an explicit connection test using the saved profile and credential,
  a harmless query, sanitized diagnostics and connection cleanup; do not start
  listeners, print secrets or change database data.
  A first local `--credential-test` mode tests an existing protected MSSQL
  profile with a fixed `SELECT 1`, returning only PASS/FAIL. Windows validation
  used a temporary protected profile against MSSQL and exercised the product
  executable without printing the password or envelope. A local key-creation
  command uses the existing exclusive, permission-restricted file provider.
  An internal INI update planner prepares only an existing encrypted password
  in memory and preserves unrelated bytes; it does not authenticate the new
  envelope or write files. Synthetic checks passed on Windows and Ubuntu WSL
  using the standalone Harbour parser. A separate update preparer authenticates
  the old envelope against the profile context, seals and verifies a replacement,
  and rejects credentials referenced by multiple profiles. Synthetic Windows
  checks cover the preparation and failure cases; it still writes no files.
  An isolated native terminal-input probe rejects redirected input and restores
  terminal state on tested cancellation paths; synthetic Windows and WSL PTY
  checks passed. The reader remains outside the product executable.
  A byte-level preflight rejects already-observed INI changes, but cannot prevent
  changes between comparison and publication. Synthetic local replacement probes
  passed on Windows/NTFS and WSL; Windows `ReplaceFileW` changed DACL inheritance
  metadata in both tested scenarios, even when trustees and rights stayed equal.
  An isolated Linux publication candidate passed synthetic WSL checks for
  cooperative locking, snapshots, metadata, unsafe files and failure outcomes.
  It is not linked to the product; Windows returns unsupported. NTFS `MoveFileExW`
  preserved the tested descriptor without an open reader but failed with one.
  A synthetic NTFS `FileRenameInfoEx` probe preserved owner, group and DACL with
  an open reader but lost an alternate data stream; SACL inspection was unavailable
  to the test identity. An isolated native probe detects the tested alternate
  stream and hard link and reports a missing SACL privilege without altering the
  file; successful privileged access and preservation remain untested. It does
  not authorize publication. Windows sharing tests block ordinary writers but
  reveal that delete sharing still permits replacement by another process. Linux
  tests also cover concurrent changes after staging and interruption leaving a
  restricted orphan; uncooperative writers can race.
  A synthetic integration test connects authenticated preparation to the
  isolated publisher: Windows refuses publication without modifying the INI;
  WSL publishes the fixture, decrypts the replacement and rejects a stale retry.
  The focused suite passed 51 checks on Windows and 53 on WSL with global
  Harbour, Zig and the project-patched ODBC core. No real SQL server was used.
  The isolated Linux publisher now verifies every directory from the root.
  Ubuntu WSL passed 25 checks as root and 24 as `nobody` on the Linux
  filesystem. Unsafe ancestors were refused before opening the lock and a
  private directory under a trusted sticky ancestor remained usable. The
  focused Windows credential suite passed all 51 checks, including refusal
  without modifying the INI.
  A test-only mode now connects the terminal reader, authenticated preparation
  and publisher against an isolated synthetic INI. Ubuntu WSL passed 53
  standard checks. All four interactive cases passed as root and as `nobody`:
  publication and reload, redirected input, cancellation and a concurrent
  INI edit. The focused Windows suite passed 51 checks and the update mode
  refused before prompting or writing. No live database was used.
  The terminal fixture now takes a bounded native INI snapshot before and
  after input. The reader and publisher share checks for regular files,
  path ownership and unsupported metadata. Earlier publication discarded
  a `nodump` inode flag despite an empty extended-attribute list. Both
  operations now refuse that fixture, preserving the file and its flag.
  The reader and publisher share a 1 MiB cap so an accepted replacement
  can be read again. On Ubuntu WSL, the standalone suite passed 41 checks
  each on tmpfs and ext4 as root, and 40 on tmpfs as `nobody`. Windows
  refused the snapshot without creating files. The integrated WSL suite
  passed 53 checks, and all four terminal cases passed as root and as `nobody`.
  These changes are linked into probes only.
  On Windows/NTFS, a read-only preflight now combines file attributes,
  stream enumeration and security inspection in the same handle when
  SACL access is available. It distinguishes a sharing conflict,
  unsupported metadata and missing privilege. The suite passed 19 checks,
  including preserving the original bytes, observed security and directory
  contents on refusal. The test token lacked `SeSecurityPrivilege`.
  The dedicated audit probe scopes privilege activation to a private thread
  token and diagnoses failures by stage and Win32 code. Refusal without
  assignment returned code 1300 and created no file. On 2026-11-27 a
  temporary local test account passed all 21 checks, including reading and
  comparing a protected SACL with a nonempty audit ACE and refusing to
  overwrite an existing fixture. The right, account, profile and synthetic
  file directory were removed. Preservation through an atomic replacement
  remains open.
  Production-safe atomic publication, metadata preservation, Linux integration,
  interactive command, deployment and full acceptance remain open.
- [ ] C05: validate tampering, wrong/missing key, unavailable provider, Unicode,
  concurrent calls, cleanup and redaction; run real SQL acceptance with synthetic
  secrets where possible on Windows, plus Linux build/runtime and service identity
  acceptance. Record tested environments and explicitly retain uncovered scopes.
- [ ] C06: update bilingual configuration, deployment, dependency and security
  guides, acceptance evidence and ChangeLogs. Document migration and rollback;
  preserve the current protected-file workflow until replacement is accepted.

**Completion:** the SQL slice and utility work in their recorded Windows/Linux
scopes and failure cases, with reproducible checks and no secret leaks in examined
outputs. NETIO/admin/HTTP secret integration, Protheus/TLPP secret storage,
optional OpenBao/OS vault providers and TLS for each channel are separate future
work unless explicitly added with their own acceptance. `RPCRDD` remains generic.

## Previous package

Package 003 delivered controlled and registered-source turnover examples and
real Protheus TCP/HTTP drill-down within the recorded scope. A later visual
observation confirmed an SRE transfer over TCP and HTTP; historical reconciliation
remains open, as does standalone monthly-report acceptance. See
[package 003 history](docs/validation/package-003.md).
