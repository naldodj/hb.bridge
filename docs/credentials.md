# MSSQL credentials on Windows and Linux

[Português](credentials.pt-BR.md)

Status: architecture proposal. The current runtime accepts an ODBC
`connectionString` in each MSSQL profile; an encrypted password format,
credential editor and key provider have **not** been implemented. Do not put
an `encrypted_secret` placeholder in a runtime configuration and expect it
to be decrypted. Protheus sends the profile alias and query, not database
credentials. These credentials belong to the hbBridge server installation.

For the operator's current Protheus deployment, database passwords rarely
change, and a change requires manual coordination of database access, ODBC
and DBAccess settings. This deployment constraint defines the initial design:
securely store and resolve a stable SQL credential. Automatic SQL-password
rotation is outside this scope. hbBridge must support a future manual update
or migration of its own credential without automatically changing external
ODBC/DBAccess credentials. This is an operational requirement for this
installation, not a claim that every Protheus deployment follows that policy.

An INI file is portable. Encryption requires a separately managed key;
embedding both ciphertext and a fixed decryption key in the same installation
only hides the password from casual inspection. Windows Credential Manager
or DPAPI may be useful optional providers, but cannot be the only supported
backend for a product that must also run on Linux.

| Option | Advantage | Constraint |
| --- | --- | --- |
| Integrated authentication | No SQL password in hbBridge configuration. | Windows uses the process identity; Linux requires Kerberos credentials and renewal for services. |
| Plain ODBC string in a restricted INI | Already supported; simple initial configuration. | Contains plaintext secrets if `UID/PWD` are supplied; backups and copied files carry them. |
| Encrypted password in INI, external key file | Same envelope and management workflow on both systems. | Key permissions, backup, optional encryption master-key replacement and service access require their own procedure; compromise of the running service still exposes usable credentials. |
| OS vault | Uses existing administrative controls. | OS-specific identity, provisioning and migration; optional backend behind the common contract. |
| External secret manager | Central secure storage and audit. | Additional service dependency; optional backend for reading stable SQL credentials. |

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
wrong key, truncated data, non-ASCII passwords and support for optional
encryption master-key replacement before marking this feature complete.
Random-number and zeroization APIs must be verified against the pinned Zig
release, not assumed from another version.
If an operator chooses to replace this master key, the same SQL password is
re-encrypted; this does not change the database password or require
SQL-password rotation.

## Optional OpenBao provider: RFC review on 2026-10-07

The operator's RFC in `hbridge.news.txt` is feasible as a future optional
**credential provider** that reads stable SQL credentials from OpenBao KV v2,
alongside integrated authentication, encrypted INI with an external key and
OS providers. It belongs to package 003 in [WIP](../WIP.md). Neither OpenBao
nor a database secrets engine, dynamic credentials or an MSSQL plugin is a
prerequisite for the initial credential provider or package 001 MSSQL
acceptance. No OpenBao adapter, secret RPC service or new parser fields have
been implemented.

The intended SQL flow remains `Protheus alias/query -> hbBridge authorized
profile -> credential provider -> ODBC -> result`. Protheus resolves business
context and passes parameters; hbBridge resolves only the installed technical
credential reference. Vault address/mount/path/authentication belong to server
configuration. Avoid an unrestricted `ReadSecret(path)` service. Returning raw
secrets to Protheus would require a separately scoped use case, permissions and
protected transport; it is not needed for server-side SQL execution.

Zig's C ABI and Harbour `HB_FUNC` can implement an internal provider. They do
not register a callable function in the AppServer: the RFC's direct TLPP
`HB_BAO_READ(...)` call must be replaced by the existing bridge client/service
boundary. Compare a native adapter with [OpenBao Agent/Proxy](https://openbao.org/docs/agent-and-proxy/)
for authentication/renewal; either choice requires an identified runtime and
Windows/Linux acceptance.

[KV v2](https://openbao.org/docs/api/secret/kv/kv-v2/) supports versioned storage
and a configured `/<mount>/data/<path>` API with the `data.data` response envelope.
The mount must actually use v2. KV storage does not rotate an SQL password or
provide a database credential lease. The provider reads the installed secret;
administrators can explicitly update it after a coordinated manual credential
change. hbBridge does not alter the database password, write KV secrets or
update external ODBC/DBAccess settings automatically.

Dynamic issuance/SQL-password rotation is a separate future project only if
explicitly requested. It would require its own database-engine/plugin and
[lease lifecycle](https://openbao.org/docs/concepts/lease/) acceptance. The
2026-10-07 RFC review recorded `database-mssql` as community-supported rather
than built-in under the [plugin policy](https://openbao.org/community/policies/plugins/);
that finding is background for future evaluation, not a KV v2 prerequisite.

[AppRole](https://openbao.org/docs/auth/approle/) still needs protected SecretID/
token delivery. Use a service identity and scoped policies; an environment
variable alone does not make a credential ephemeral. [Response wrapping](https://openbao.org/docs/concepts/response-wrapping/)
is a delivery option, with TTL, expected creation path, single use and restart
reprovisioning. Validate HTTPS CA/hostname; do not forward tokens through
unauthorized redirects. Configure provider deadlines and unavailable-vault
behavior without silently falling back to another credential. Cache KV data
with an explicit refresh policy and invalidation when an administrator updates
the stored credential. Renew or replace OpenBao authentication tokens as
required by their TTL and invalidate access on revocation. Token renewal
maintains access to the same stored SQL credential; it does not change the
database password. Authentication bootstrap, token lifecycle and optional
encryption master-key replacement remain separate security procedures even with stable SQL
passwords.

The RFC code is conceptual and uses APIs from an earlier Zig version. The
pinned **0.16.0** HTTP client requires an `Io` instance and the current request/
response APIs; allocator, ArrayList and JSON APIs also differ. Its 4096-byte
buffer and 1 MiB read cap are sketch values, not hbBridge capacities. Define
buffer ownership, configurable policy and structured sanitized errors before
implementation, including required output length on insufficient capacity.

For the OpenBao provider, target **no application-managed local persistence of
destination passwords**; the encrypted-INI provider still stores ciphertext.
This does not mean no plaintext anywhere. TLS, JSON, Harbour strings and ODBC may copy
plaintext in memory. Freeing an allocation does not erase it; use the pinned
secure-zero API on owned mutable buffers and audit additional copies/driver
behavior. Minimize lifetime and copies without promising total erasure after
the handshake. Server providers should resolve/connect internally and return
only execution results or authorized sanitized diagnostics.

## Management utility

Start with a local CLI using the same credential/configuration services as
the host: create/import key, set/update/delete credential, test connection and
optionally replace the encryption master key. A credential update records a
password already provisioned by the administrator; it does not change the SQL
password at the database or update ODBC/DBAccess settings. Ask for passwords
interactively without echo; avoid command-line password arguments and
recording secrets in logs. Writes must be atomic, preserve
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
