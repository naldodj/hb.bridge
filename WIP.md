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
  This checks the provider format, not INI migration or SQL authentication.
  Actual separate service identities and deployment filesystems still need
  acceptance. The provider is integrated with structured SQL; the local CLI
  is not implemented.
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
  Wider transport, service-identity and Linux SQL acceptance remain open.
- [ ] C04: provide a local credential utility with non-echoed input, no secrets in
  command-line arguments, atomic updates and documented key permissions, backup,
  manual update and migration. No automatic database password rotation.
  Provide an explicit connection test using the saved profile and credential,
  a harmless query, sanitized diagnostics and connection cleanup; do not start
  listeners, print secrets or change database data.
  A first local `--credential-test` mode tests an existing protected MSSQL
  profile with a fixed `SELECT 1`, returning only PASS/FAIL. Windows validation
  used a temporary protected profile against MSSQL and exercised the product
  executable without printing the password or envelope. Interactive input,
  atomic credential updates, deployment and full acceptance remain open.
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
