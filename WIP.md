# Active hbBridge work package

[Português](WIP.pt-BR.md) · [Roadmap](TODO.md) · [Acceptance](docs/acceptance.md)

## Package 004: portable server credential protection

The first slice protects a configured SQL credential in hbBridge at rest on
Windows and Linux. Protheus continues to send only the opaque SQL profile and
application context. The common design must allow later NETIO, administration
and HTTP consumers; TLPP client-side protection requires a separate verified
provider. No secret-storage or transport-security capability is implied until
its own acceptance. See [credential review](docs/credentials.md).

- [ ] C01: inventory current configuration, consumers, leaks, toolchain and
  tests; confirm a versioned authenticated envelope, external-key provider,
  configuration compatibility, recovery and threat boundaries. Validate Zig
  0.16 random/crypto/ABI and service identity on each target before implementation.
- [ ] C02: implement and test the portable local server provider and key lifecycle;
  authenticated encryption, unique nonces, context binding, explicit errors,
  no embedded master key and minimal secret lifetime. Prevent downgrade or
  treating ciphertext as a password when resolution fails.
- [ ] C03: integrate the provider into one MSSQL SQL-authentication profile with
  ODBC-safe escaping. Keep integrated authentication and existing configurations
  compatible; reject ambiguous plaintext/reference combinations and do not expose
  credentials through diagnostics, errors, config-info, discovery or logs.
- [ ] C04: provide a local credential utility with non-echoed input, no secrets in
  command-line arguments, atomic updates and documented key permissions, backup,
  manual update and migration. No automatic database password rotation.
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
real Protheus TCP/HTTP drill-down within the recorded scope. Standalone monthly
report visual acceptance, real SRE movements and historical reconciliation were
deferred, not silently accepted. See [package 003 history](docs/validation/package-003.md).
