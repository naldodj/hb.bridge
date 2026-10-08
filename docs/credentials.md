# Credentials on Windows, Linux and Protheus

[Português](credentials.pt-BR.md)

Current configuration supports structured MSSQL fields or an ODBC
`connectionString`. SQL authentication uses plain `Username`/`Password` in
the private server file; integrated authentication omits those fields.
Encrypted credential storage remains an architecture proposal: an encrypted
password format, credential editor and key provider have **not** been
implemented. Do not put
an `encrypted_secret` placeholder in a runtime configuration and expect it
to be decrypted. Protheus sends the profile alias and query, not database
credentials. These credentials belong to the hbBridge server installation.

## All credential consumers: current state and intended protection

The concern raised on 2026-10-08 applies to every credential, including the
AppServer client. Keeping a file outside Git does not encrypt its contents.
The following inventory was checked against the public host and TLPP sources;
no private configuration values were inspected for this review.

| Consumer | Current storage/use | Scope of the encrypted-storage design |
| --- | --- | --- |
| SQL profile on hbBridge | `[SQL/<alias>]` `Username`/`Password`, or `UID/PWD` in an ODBC string; integrated authentication omits the SQL password. | Resolve the SQL secret only on hbBridge. Protheus receives no SQL password and selects only the installed profile alias. |
| Native NETIO client/server | `[NETIO] Password` on hbBridge; Harbour clients supply the same usable secret to `netio_Connect()`. | Protect each consumer's local copy with its own credential provider. A Protheus NETIO facade and NETIO secret configuration have not been implemented. |
| Administration | `[Admin] Password` protects the native NETIO administration endpoint and the web administrator's Basic authentication. | Protect the installed secret; keep administrative access separate from service access. The current two admin endpoints share this setting. |
| HTTP service | `[HTTP] Password` on hbBridge; `[hbBridge] HTTPToken` in the active AppServer INI, or an explicit constructor argument, on Protheus. | Protect both installations. The TLPP client currently reads the token directly, without decryption, and sends it as Bearer authentication. |
| HBBRIDGE/1 TCP client | The current TLPP configuration has no authentication secret; the common TCP transport has no credential authentication/TLS layer. | Define authentication and protected transport separately; encrypted INI storage cannot add them to the wire protocol. |
| HTTPS private key | `PrivateKey` identifies a server-side PEM file when the TLS build/configuration is available. | Protect that file and its backups separately; a certificate path is not a private-key encryption provider. |

Implementation references: [host INI mapping](../src/hb/host/hbbridgeini.hb),
[host validation](../src/hb/host/hbbridgeconfig.hb),
[NETIO adapter](../src/hb/transports/netio/hbbridgenetio.hb),
[HTTP authorization](../src/hb/transports/http/hbbridgehttp.hb),
[TLPP HTTP client](../src/tlpp/hbbridgehttpclient.tlpp) and
[TLPP TCP configuration](../src/tlpp/hbbridgeconfig.tlpp).

The intended common contract is a credential reference resolved locally by
the consumer, or a versioned authenticated ciphertext whose master key is
outside the INI and repository. Each installation/service identity owns its
key and provisioning procedure. An AppServer token and its hbBridge counterpart
may represent the same service secret, but their encrypted local copies must
not require distributing one universal decryption key. Credentials should
also be distinct by purpose: SQL, NETIO service, administration and HTTP service.
Only HTTP-service/admin separation is enforced by current validation.

Use a portable file provider on Windows/Linux, with permissions restricted to
the consuming service identity; OS vaults and OpenBao remain optional adapters.
[DPAPI](https://learn.microsoft.com/en-us/windows/win32/api/dpapi/nf-dpapi-cryptprotectdata)
is an optional Windows integration, not the sole cross-platform backend.
AppServer requires its own supported TLPP adapter and protected provisioning.
The exact TOTVS cryptographic API, supported cipher, key access and behavior
under the Windows/Linux AppServer service identities remain to be verified.
The Zig cipher candidate below does not establish that TLPP can decrypt it;
Harbour `HB_FUNC` exports do not become native AppServer functions.
Do not bootstrap access by returning SQL passwords, NETIO passwords or master
keys through an RPC secret service. Provision each consumer locally or through
an explicitly authenticated administrative channel.

SQL login and native NETIO require a usable secret at connection time; a
one-way password hash cannot replace those inputs. NETIO uses the password
as the stream-encryption key. A future HTTP-only verifier may have different
storage needs, but it requires an explicit authorization redesign; the current
HTTP adapter compares the supplied credential with its configured value.
Do not treat Base64, a hardcoded application key or a password hash inserted
in the existing `Password` field as encrypted credential support.

Protection in files and protection in transit have separate acceptance.
Pinned [Harbour NETIO documentation](https://github.com/harbour/core/blob/6deac9cf3ad977ae829e5bca543d553b92dd4b6d/contrib/hbnetio/readme.txt)
describes ZLIB/Blowfish, and the native adapter uses that stream rather than
a TLS certificate handshake. It must not be advertised as modern TLS with
certificate/hostname validation. HTTP Bearer/Basic secrets require protected
transport; acceptance over local HTTP does not accept HTTPS. The
[Bearer specification](https://www.rfc-editor.org/rfc/rfc6750#section-5.2)
requires protecting tokens in both storage and transport. SQL ODBC TLS,
NETIO transport protection and AppServer-to-hbBridge HTTPS need separate tests.

Before accepting encrypted credentials, verify both consumers on Windows and
Linux, with the actual service identities: no plaintext secret in either INI,
no fixed key in source/binaries, failure on tampering/wrong key/missing provider,
separate permissions/backups, atomic manual updates and explicit migration.
Exercise SQL, NETIO service/admin and HTTP service/admin, including the TLPP
client, and verify that diagnostics, discovery, logs and exceptions expose no
secrets. Missing decryption support must fail explicitly rather than pass the
ciphertext as a password or silently fall back to a plaintext copy. These are
future acceptance criteria; this review introduces no runtime cryptography.

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
| Structured SQL credentials or ODBC string in a restricted INI | Supported configuration for the current acceptance. | `Username`/`Password` or `UID/PWD` are plaintext secrets; backups and copied files carry them. |
| Encrypted password in INI, external key file | Same envelope and management workflow on both systems. | Key permissions, backup, optional encryption master-key replacement and service access require their own procedure; compromise of the running service still exposes usable credentials. |
| OS vault | Uses existing administrative controls. | OS-specific identity, provisioning and migration; optional backend behind the common contract. |
| External secret manager | Central secure storage and audit. | Additional service dependency; optional backend for reading stable SQL credentials. |

Proposed encrypted-storage baseline: public connection settings plus an authenticated,
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
acceptance. No OpenBao adapter, secret RPC service or credential-provider parser fields have
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

Install an ODBC driver for the server architecture and configure a DSN, or
the structured `ODBCDriver`/`Server`/`Database` fields. The supplied
[INI](../config/examples/mssql.ini) and [JSON](../config/examples/mssql.json)
examples use `Authentication=integrated`, with no username/password fields.
Windows uses the hbBridge process identity; Linux needs Kerberos service
credentials. See [Microsoft's integrated-authentication guide](https://learn.microsoft.com/en-us/sql/connect/odbc/linux-mac/using-integrated-authentication?view=sql-server-ver17).

For the local SQL-login route, edit `C:/tmp/hbBridge.ini` outside Git. Fill
`Username` and `Password` in the prepared `[SQL/mssql/pData]` template, using
the existing SQL login. Keep its lines commented until all required values
are ready, then uncomment the whole section. `DSN=pData` selects the ODBC
data source; `Database=pData` explicitly selects its database. These names
are installation examples, not product defaults. The
[configuration guide](configuration.md#mssql-profiles) lists DSN-less settings,
JSON keys, punctuation handling, encryption and validation rules.

This file stores the filled SQL password in plaintext. Restrict access to
the hbBridge process identity and authorized administrators, including its
backups. Supply only the private file path and alias to launchers; keep
credentials out of command arguments, logs and AppServer settings. Existing
`ConnectionString` profiles remain supported as an exclusive alternative.

Rebuild the product for structured fields and validate without connecting:

```powershell
./scripts/build-hbbridge.ps1
./out/hbbridge.exe --config-info "-config=C:/tmp/hbBridge.ini"
```

After the private profile is filled and enabled, run native acceptance:

```powershell
./scripts/test-hbbridge-mssql.ps1 -Config C:/tmp/hbBridge.ini -Profile mssql/pData
```

It uses the shared query core without listeners and begins with a constant
connection probe and actual SQL Server identification. Its read-only fixtures
check native values/types, pages, sanitized failures, cleanup and isolation;
the measured volume is 1000 rows. Prerequisite failures exit `2` and do not
count as successful MSSQL acceptance. It does not execute the Protheus tests.

Start the product separately for those tests:

```powershell
./examples/sql/run.ps1 -Config C:/tmp/hbBridge.ini -Profile mssql/pData
```

Run `U_HBBridgeQueryTest("mssql/pData", "127.0.0.1", 1512, 30000)` in Protheus
with the current TLPP classes. The convenience entries
`U_HBBridgeQueryTestMSSQL()` and `U_HBBridgeQueryTestSQLite()` supply the local
example aliases; they do not change the generic client's defaults.
A server-profile change alone needs no further TLPP build. The test uses constant SELECTs and
checks SQL values, error recovery and pagination without writing Protheus
tables. Current SQL operations are direct ODBC/SQLRDD access, independent of
DBAccess's connection management, business rules and locking. Keep production
writes out of this acceptance step.

On 2026-10-08, the filled private SQL-authentication profile passed **92 native
checks, zero failures and no skips** against SQL Server `16.0.1200.5`, database
`pData`, ODBC Driver `18.6.2.1`, Windows x64 and Harbour `UTF8EX`. The operator
separately passed all **29 Protheus TCP checks for MSSQL** and repeated all
**29 SQLite checks**, threads 660 and 3192 respectively. Later the same day,
the operator passed **13 HTTP checks each** through
`U_HBBridgeHTTPTestMSSQL()` and `U_HBBridgeHTTPTestSQLite()`, threads 25976 and
9916. These separate operator runs accept the exercised TCP/HTTP routes;
integrated authentication, Windows/Linux service identities, HTTPS, encrypted
credential management and broader failure/type cases remain pending. See
[acceptance](acceptance.md) for attributable evidence and remaining work.
