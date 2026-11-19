# Credentials on Windows, Linux and Protheus

[Português](credentials.pt-BR.md)

Configuration supports structured MSSQL fields or an ODBC `connectionString`.
Structured SQL authentication can use a protected credential reference with a
separate file key, or the existing plaintext `Username`/`Password` form.
Integrated authentication omits SQL credentials. The local credential editor
and its connection-test command are not implemented yet; placeholders are not
valid encrypted values. Protheus sends the profile alias and query, not database
credentials. These credentials belong to the hbBridge server installation.

The Harbour/C/Zig local provider is connected to the structured SQL path. The first
45 checks passed on Windows with a protected DACL; 45 also passed as root on
Ubuntu WSL with mode 600 using both the global Harbour and the project-pinned
managed Harbour/Zig toolchain in an isolated Linux filesystem. Actual
service-account permissions still require acceptance. Key creation writes and flushes a private staging file before
exclusive publication; a controlled process interruption left the destination
absent on Windows and WSL Linux. A crash can still leave a restricted staging
file requiring explicit inspection and removal; use a trusted directory and do
not assume crash durability. `KEY_CLEANUP_FAILED` means staging cleanup failed:
the final key may already exist, so inspect both paths before retrying.
Before writing a key, the Windows bridge verifies the protected DACL it created;
the Unix bridge rejects a staging file whose mode grants group or other access.
Before reading an existing key, the Unix bridge rejects group or other mode
permissions. On Windows, the reader requires a protected DACL containing only
explicit allow entries for the file owner, the current identity or LocalSystem;
other entries, including deny or inherited entries, are rejected conservatively.
The owner is considered trusted: the directory and its administration must be
trusted too. The service identity needs read and READ_CONTROL access, and can
differ from the owner. A dedicated group or additional administrator entry is
not accepted by this initial policy; provision the ACL accordingly. Inadequate
or unverifiable permissions return `KEY_PERMISSIONS_UNSAFE`; an inaccessible
file can instead return `KEY_UNAVAILABLE`. The checks do not prevent privileged
administrators or root from accessing files, and filesystem behavior and actual
service identities need their own acceptance.

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

Implementation references: [host INI mapping](../src/hb/host/hbbridge.ini.hb),
[host validation](../src/hb/host/hbbridge.config.hb),
[NETIO adapter](../src/hb/transports/netio/hbbridge.netio.hb),
[HTTP authorization](../src/hb/transports/http/hbbridge.http.hb),
[TLPP HTTP client](../src/tlpp/hbbridge.http.client.tlpp) and
[TLPP TCP configuration](../src/tlpp/hbbridge.config.tlpp).

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
acceptance criteria for the broader credential plan; only the initial SQL
provider and its recorded tests have been implemented.

For the referenced Protheus deployment, database passwords rarely
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

## Structured SQL credential contract

The strict INI parser accepts the following sections and fields. The envelope
shown is a placeholder, not a usable credential; the local editor is pending.

```ini
[SQL/protheus]
Driver=mssql
Authentication=sql
ODBCDriver=ODBC Driver 18 for SQL Server
Server=tcp:sql.example,1433
Database=protheus
Encrypt=mandatory
TrustServerCertificate=false
Credential=protheus

[Credential/protheus]
User=hbbridge_reader
KeyId=primary
Password=enc:v1:<authenticated-envelope>

[Key/primary]
Provider=file
Location=/etc/hbbridge/keys/primary.key
```

The protected profile uses structured SQL authentication. A profile with
`Credential` rejects `Username`, `Password`, a raw `ConnectionString` or integrated
authentication. Existing unprotected profiles keep their current validation.
The server applies the existing ODBC quoting rules and resolves the credential
immediately before connecting. The plaintext structured `Password` field reserves
the `enc:v` prefix to prevent an encrypted envelope being sent as a password.
Relative key locations are resolved against the configuration file directory.
JSON uses top-level `credentials` and `credentialKeys` objects with `user`,
`keyId`, `password` and `provider`, `location` fields respectively; the SQL
profile references its credential through `credential`.
Configuration validation checks the references and envelope prefix without
opening the key or connecting; missing keys, malformed envelopes and wrong
keys fail closed when a connection is attempted. `--config-info` is therefore
not a credential or database connection test.

Version 1 uses XChaCha20-Poly1305. The file provider reads a 32-byte binary key
from the configured path outside the INI. The value after `enc:v1:` is padded
standard Base64 of the 24-byte nonce, ciphertext and 16-byte tag, in that order.
The plaintext is the UTF-8 SQL password. Each encryption uses a new nonce
from the OS CSPRNG. Entropy, format and authentication failures stop the
operation with a sanitized error.

The current provider accepts nonempty UTF-8 passwords up to 4096 bytes, without
NUL, CR or LF. Each authenticated context field is limited to 1024 UTF-8 bytes.
These are current credential-provider implementation limits, separate from RPC
payload policies; oversized or invalid inputs fail rather than being truncated.

The authenticated data starts with the literal bytes `hbbridge/credential/v1`.
It then contains the purpose `sql`, canonical SQL profile identifier,
credential identifier, key identifier and SQL username, in that order. Each
field uses UTF-8 bytes preceded by its unsigned 32-bit big-endian byte length.
Use the identifiers resolved by the configuration parser so equivalent
lookups produce the same bytes. Each envelope is bound to one profile.
Moving it to another profile, changing a bound field or replacing the key
requires re-encryption. The database password stays the same.

## C01: native building blocks and local administration

The intended administrator interface is a local command mode of the same
`hbbridge` executable, using the same provider as the host. Local management
runs without listeners. Command names remain to be specified.

The first SQL slice stores the envelope in the INI and the key in a separate
binary file. The Harbour serialization probe establishes interoperability
for possible future structured secrets. Bound the envelope size and check
version and encoding before decoding. Authenticate before passing plaintext
to the caller. The configuration and key directory require administrator-
controlled write access. The envelope protects a copied INI without its key
and detects changes to the authenticated credential data. An attacker who
controls the host, its process or the SQL destination configuration is
outside this boundary.

Use the existing `hbbridge_zig` static library and a C/Harbour adapter. Pass
binary inputs as pointers with explicit byte lengths. Give the caller
ownership of output buffers and return a status code. Validate lengths and
capacities before accessing memory. Clear key and plaintext buffers owned
by the provider on every exit. Failed output is unavailable to the Harbour
caller.

Preserve the credential reference through both SQL profile normalization
passes and resolve it just before `RDDI_CONNECT` in the SQL pool. Audit native
ODBC diagnostics and allocation errors alongside RPC errors. The managed
driver no longer requests a completed connection-string buffer or passes the
input connection string to allocation errors. Connection failures retain a
validated SQLSTATE and a fixed message instead of driver-supplied text. A
synthetic missing-DSN test checks the native diagnostic and RPC response;
read-only MSSQL acceptance passed on Windows. Harbour and the ODBC driver may
still hold temporary plaintext outside the buffers the provider controls.

The initial WSL2 x86_64 checks on 2026-11-06 used the older system Harbour
3.2.0dev r2307062207 and Zig 0.16.0 cross-compiled from Windows. On 2026-11-11
the Windows x64 checks used managed Harbour 3.2.1dev r2609292008 and Zig 0.16.0.
Serialization preserved binary NUL and EOF bytes. The Zig tests rejected
altered ciphertext, tag, key, nonce and context. The Harbour/C/Zig ABI
probe passed with the pinned toolchain and exercised OS entropy through an
explicit `std.Io.Threaded` instance inside the linked Zig library. The probe
uses `Io.randomSecure` and fails on entropy errors.

The same three probes passed on 2026-11-11 with native Linux Zig 0.16.0,
pinned Harbour 3.2.1dev r2609292008 and GCC 16.2.0 in x86_64 WSL2
(Kali Linux userland). The Linux GCC bootstrap installs Harbour libraries to
`lib/linux/gcc`, the directory used by hbBridge's managed toolchain.
Run the [credential feasibility probes](../scripts/README.md#credential-feasibility-probes)
after bootstrapping on the target OS. The Linux executable also linked with
the GCC profile after enabling PIC in the Zig module and installing the
SQLite link metadata. A separate Harbour program compiled, linked and ran
via `hbmk2 -plat=linux -comp=zig` against the existing GCC-built Harbour
libraries in WSL2. On 2026-11-12 the clean Linux Zig bootstrap, managed contrib preparation,
product build and credential ABI probe passed on x86_64 WSL2. The GCC
profile also passed its bootstrap, product build and ABI probe. The
[dependency guide](dependencies.md#linux-compiler-selection) records how
to select either profile.

Windows Authz checks used an in-memory DACL and SID contexts without groups.
`LocalService` could read and could not write, `NetworkService` could not read,
and `LocalSystem` could write. In WSL2, transient systemd units exercised a
synthetic 32-byte file on the native Linux filesystem. With owner/group
`root:nogroup` and mode `0640`, the unit running as `nobody:nogroup` read it
but could not open it for writing. A unit running as `daemon:daemon` could
not read it. The units and synthetic file were temporary.
[Windows Authz API](https://learn.microsoft.com/en-us/windows/win32/api/authz/nf-authz-authzaccesscheck)
· [systemd service identity](https://www.freedesktop.org/software/systemd/man/256/systemd.exec.html#User=).

These checks establish feasibility. The production provider and its ABI
require C02 validation. C05 covers the deployed service tokens, filesystem
permissions after atomic replacement and real SQL connection acceptance.
The TLPP consumer has its own acceptance scope.

## Optional OpenBao provider: RFC review on 2026-10-07

The RFC recorded in `hbridge.news.txt` is feasible as a future optional
**credential provider** that reads stable SQL credentials from OpenBao KV v2,
alongside integrated authentication, encrypted INI with an external key and
OS providers. OpenBao remains separate future work; the [WIP](../WIP.md) starts
with a local provider. Neither OpenBao
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

## Future client authentication and server-side credentials

The common server credential provider may eventually protect the SQL, NETIO,
HTTP and administration secrets used by hbBridge. This does not require a
remote service that returns those secrets: an authenticated client should
receive only permission to invoke authorized operations. The server retains
and uses the backend credentials. An external secret-export API would require
a separately justified contract and security review; it is not proposed here.

For unattended integrations, evaluate a distinct identity per client and
authenticated TLS, such as a client certificate, or a trusted identity provider
issuing scoped, short-lived access tokens. Certificates and token handling must
be supported and validated in each actual Protheus/Harbour client and transport;
the client still needs a protected private key or other bootstrap identity.
Limit authorization by service/profile and explicitly supplied application
context, audit access and support revocation. Protheus continues to resolve ERP
company, branch and permissions; client-provided values do not grant authority.
Certificate-bound OAuth access tokens are standardized in
[RFC 8705](https://www.rfc-editor.org/rfc/rfc8705).

[TOTP](https://www.rfc-editor.org/rfc/rfc6238) requires a shared secret and
clock coordination. It may be useful as an additional factor for interactive
administration; automatically generating it in an unattended client still
requires protecting that client's TOTP secret. Evaluate throttling, replay
prevention, recovery and trusted time before using it. No TOTP, mTLS or token
issuer is implemented by this proposal.

The current native NETIO protocol uses its configured password for the
connection. An unmodified NETIO client still needs that password; keeping it
server-only would require an independently designed gateway or protocol change.
HTTP, TCP and NETIO protections require separate validation. This is later work,
not a prerequisite for the current local SQL credential-provider slice.

## Management utility

Create a new random file-provider key locally:

```text
hbbridge --credential-create-key --key=<key-file-path>
```

The parent directory must already exist. The provider restricts access and
publishes the key exclusively, so it never replaces an existing file. The
command starts no listeners and returns only PASS/FAIL. After failure, inspect
the destination and any private staged files before retrying: a cleanup error
can occur after the key was published. Follow the recovery guidance below.
The command creates a key only; it does not create or modify a credential.

An internal INI planner can prepare the replacement of an existing encrypted
password while retaining unrelated bytes, comments, BOM and line endings. It
validates the INI and the new envelope's canonical structure but does not
authenticate the envelope, read or write the configuration file, or detect
concurrent edits. The future editor must create and authenticate the envelope
against the intended context, then separately protect against conflicting edits
and publish the update atomically. This planner is not a management command.

The initial local connection test accepts an existing protected MSSQL profile:

```text
hbbridge --credential-test --config=<file.ini-or-json> --profile=<profile-alias>
```

It reads the named configuration, resolves its protected credential through
the normal SQL path and executes the fixed, read-only `SELECT 1 AS ID`. It
does not start listeners or accept a password or SQL on the command line. The
result is `Credential connection test: PASS` with exit code 0, or a sanitized
`FAIL` with exit code 1. This is an initial connection test, not a credential
editor; it requires a configured protected MSSQL profile and an accessible key.
The regular SQL connection lifecycle releases its lease after the query. Driver
pooling, if configured, follows the SQL driver's process-wide policy until the
command exits. Live service-identity and Linux/MSSQL acceptance remain open.

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

The connection test will resolve the saved profile and credential, run a
harmless query and release the connection. It will report sanitized success or
failure without starting listeners, exposing secrets or modifying database
data. Implementation and acceptance belong to the SQL integration.

Back up ciphertext and keys under separate access controls. Moving the INI
alone must not transfer usable passwords; migration needs an explicit key
import/export procedure. A key file available to the same compromised process
cannot prevent that process from decrypting credentials. Encryption at rest,
file permissions and ODBC TLS solve different parts of the problem.

The version 1 envelope and its 32-byte key are designed to be portable across
Windows and Linux. The envelope is authenticated against the SQL profile,
credential identifier, key identifier and SQL username; changing any of them
requires resealing with the original key and context. Key paths and operating
system identities are not part of that context. Migration must separately
protect the key, provision destination permissions and adjust local ODBC
settings. An external synthetic-fixture test passed in both directions between
Windows with managed Harbour r2609292008 and Ubuntu WSL with global Harbour
r2610242111. It verifies the provider format and context binding, not an INI
migration utility or a live SQL connection.

### Recovery after interrupted key creation

The following applies to the experimental local provider; there is no integrated
credential editor yet. A staged `key-name.tmp.*` file contains key material.
Do not display its contents, move it to an unprotected directory or remove it
while another process may still be creating the key.

1. Stop or otherwise coordinate all key-creation processes for that destination.
   Inspect the exact destination and staging paths in the trusted directory.
2. If the destination exists, preserve it. `KEY_CLEANUP_FAILED` can occur after
   publication on Unix. A creation retry must not replace that destination.
3. If the destination is absent and the key was previously in use, restore the
   matching key from a protected backup. Creating a different key cannot recover
   ciphertext encrypted with the missing key. Do not promote a staged file based
   only on its name or size.
4. Only after establishing that a staging file is no longer in use and is not
   needed for recovery, remove that specific file with authorized filesystem
   tools. If this was a confirmed first creation with no dependent ciphertext,
   creation can then be retried; otherwise preserve the original key.
5. Verify the key permissions and, once the SQL integration is available, test
   the configured connection. The protocol does not yet guarantee directory
   metadata durability after power loss; validate the actual filesystem.

## Current MSSQL acceptance path

Install an ODBC driver for the server architecture and configure a DSN, or
the structured `ODBCDriver`/`Server`/`Database` fields. The supplied
[INI](../config/examples/mssql.ini) and [JSON](../config/examples/mssql.json)
examples use `Authentication=integrated`, with no username/password fields.
Windows uses the hbBridge process identity; Linux needs Kerberos service
credentials. See [Microsoft's integrated-authentication guide](https://learn.microsoft.com/en-us/sql/connect/odbc/linux-mac/using-integrated-authentication?view=sql-server-ver17).

For the local SQL-login route, edit `C:/tmp/hbBridge.ini` outside Git. Fill
`Username` and `Password` in the prepared `[SQL/MSSQL/pData]` template, using
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
./scripts/test-hbbridge-mssql.ps1 -Config C:/tmp/hbBridge.ini -Profile MSSQL/pData
```

It uses the shared query core without listeners and begins with a constant
connection probe and actual SQL Server identification. Its read-only fixtures
check native values/types, pages, sanitized failures, cleanup and isolation;
the measured volume is 1000 rows. Prerequisite failures exit `2` and do not
count as successful MSSQL acceptance. It does not execute the Protheus tests.

Start the product separately for those tests:

```powershell
./examples/sql/run.ps1 -Config C:/tmp/hbBridge.ini -Profile MSSQL/pData
```

Run `U_HBBridgeQueryTest("MSSQL/pData", "127.0.0.1", 1512, 30000)` in Protheus
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
`pData`, ODBC Driver `18.6.2.1`, Windows x64 and Harbour `UTF8EX`. Separate
manual AppServer runs passed all **29 Protheus TCP checks for MSSQL** and
repeated all **29 SQLite checks**, threads 660 and 3192 respectively. Later the same day,
manual AppServer runs passed **13 HTTP checks each** through
`U_HBBridgeHTTPTestMSSQL()` and `U_HBBridgeHTTPTestSQLite()`, threads 25976 and
9916. These separate manual AppServer runs accept the exercised TCP/HTTP routes;
integrated authentication, Windows/Linux service identities, HTTPS, encrypted
credential management and broader failure/type cases remain pending. See
[acceptance](acceptance.md) for attributable evidence and remaining work.
