# MSSQL credentials on Windows and Linux

[Português](credentials.pt-BR.md)

Status: architecture proposal. The current runtime accepts an ODBC
`connectionString` in each MSSQL profile; an encrypted password format,
credential editor and key provider have **not** been implemented. Do not put
an `encrypted_secret` placeholder in a runtime configuration and expect it
to be decrypted. Protheus sends the profile alias and query, not database
credentials. These credentials belong to the hbBridge server installation.

An INI file is portable. Encryption requires a separately managed key;
embedding both ciphertext and a fixed decryption key in the same installation
only hides the password from casual inspection. Windows Credential Manager
or DPAPI may be useful optional providers, but cannot be the only supported
backend for a product that must also run on Linux.

| Option | Advantage | Constraint |
| --- | --- | --- |
| Integrated authentication | No SQL password in hbBridge configuration. | Windows uses the process identity; Linux requires Kerberos credentials and renewal for services. |
| Plain ODBC string in a restricted INI | Already supported; simple initial configuration. | Contains plaintext secrets if `UID/PWD` are supplied; backups and copied files carry them. |
| Encrypted password in INI, external key file | Same envelope and management workflow on both systems. | Key permissions, backup, rotation and service access are required; compromise of the running service still exposes usable credentials. |
| OS vault | Uses existing administrative controls. | OS-specific identity, provisioning and migration; optional backend behind the common contract. |
| External secret manager | Central rotation and audit. | Additional service dependency; optional backend. |

Recommended baseline: public connection settings plus an authenticated,
versioned encrypted password envelope in `hbbridge.ini`, with the master key
provided outside that INI. The first portable provider can be a key file
restricted to the service identity; Windows/Linux vault providers can follow.
Configuration should record the provider and key identifier, not a hardcoded
key or master password. Integrated authentication remains available whenever
the installation can configure it.

## Proposed contract, not accepted by the current parser

The exact names below are a reviewable design; the current strict parser
will reject these additional sections/fields until the feature is implemented:

```ini
[SQL/protheus]
Driver=mssql
ConnectionString=Driver={ODBC Driver 18 for SQL Server};Server=tcp:sql.example,1433;Database=protheus;Encrypt=Yes;TrustServerCertificate=No;
Credential=protheus

[Credential/protheus]
User=hbbridge_reader
KeyId=primary
Password=enc:v1:<authenticated-envelope>

[Key/primary]
Provider=file
Location=/etc/hbbridge/keys/primary.key
```

The Windows key path is installation-specific. Public ODBC settings must not
also supply `UID/PWD` when `Credential` is used. Validation must reject
ambiguous credentials and duplicate ODBC fields. Encode user/password values
using ODBC quoting rules, including semicolons and closing braces. Resolve a
secret only on the server, immediately before connecting; never return it
through `--config-info`, RPC discovery, SQL errors or the AppServer INI.

Use a standard authenticated cipher available in the pinned Zig toolchain,
for example XChaCha20-Poly1305, with random key/nonce, an envelope version,
algorithm and key ID. Bind the profile/credential identity as authenticated
data so moving ciphertext to another credential fails validation. Base64 is
only an encoding. Do not invent a cipher or reuse a fixed nonce. Test tampering,
wrong key, truncated data, non-ASCII passwords and key rotation before marking
this feature complete. Random-number and zeroization APIs must be verified
against the pinned Zig release, not assumed from another version.

## Management utility

Start with a local CLI using the same credential/configuration services as
the host: create/import key, set/delete credential, test connection and rotate
key. Ask for passwords interactively without echo; avoid command-line password
arguments and recording secrets in logs. Writes must be atomic, preserve
unrelated INI settings and detect conflicting edits. Tests should report a
sanitized outcome. A later graphical tool can use the same core and resemble
the DBMonitor workflow without depending on DBAccess storage or decrypting
its passwords. Authentication, authorization and audit of remote management
belong to a later stage; the first editor is local.

Back up ciphertext and keys under separate access controls. Moving the INI
alone must not transfer usable passwords; migration needs an explicit key
import/export procedure. A key file available to the same compromised process
cannot prevent that process from decrypting credentials. Encryption at rest,
file permissions and ODBC TLS solve different parts of the problem.

## Current MSSQL acceptance path

Install an ODBC driver for the server architecture and define a DSN, or supply
a DSN-less connection string in a private configuration file. The supplied
[INI](../config/examples/mssql.ini) and [JSON](../config/examples/mssql.json)
examples use integrated authentication and contain no password. On Linux,
`Trusted_Connection=Yes` requires Kerberos rather than Windows SSPI; the
service must maintain valid tickets. The Microsoft driver supports
[DSN/DSN-less strings](https://learn.microsoft.com/en-us/sql/connect/odbc/linux-mac/connection-string-keywords-and-data-source-names-dsns?view=sql-server-ver17)
and documents [Linux integrated authentication](https://learn.microsoft.com/en-us/sql/connect/odbc/linux-mac/using-integrated-authentication?view=sql-server-ver17).

```powershell
./examples/sql/run.ps1 -Config config/examples/mssql.ini -Profile mssql_demo
```

Run `U_HBBridgeQueryTest("mssql_demo", "127.0.0.1", 1512, 30000)` in Protheus
after rebuilding the renamed TLPP classes. The test uses constant SELECTs and
checks SQL values, error recovery and pagination without writing Protheus
tables. Current SQL operations are direct ODBC/SQLRDD access, independent of
DBAccess's connection management, business rules and locking. Keep production
writes out of this acceptance step. Real MSSQL acceptance, encrypted credential
management and service identity tests on both systems remain pending.
