# Controlled MSSQL failures and recovery

[Português](README.pt-BR.md) · [Test catalog](../../../../../tests/README.md) · [Acceptance](../../../../../docs/acceptance.md)

`HBBridge.Test.HBBridgeFailureTest` exercises the real SQL service through
the Protheus TCP and HTTP clients. It checks invalid SQL, an unknown alias,
an unavailable connection and, when an explicit timeout profile is supplied,
a native SQL statement timeout. Each failure must have a sanitized error,
no partial result and immediate recovery with `SELECT 77 AS RECOVERY_ID`.
The dataset checks also require clearing the previous rows/metadata,
returning false from `MoreToRead()` after failure and reopening successfully.

## Configure the regular hbBridge host for manual tests

SQL profiles belong in the **INI read by the hbBridge server**. For the
local installation, `out/hbbridge.exe -config="C:/tmp/hbbridge.ini"` selects
`C:/tmp/hbbridge.ini`. That file holds `[SQL/m06/refused]` and
`[SQL/m06/query-timeout]`.

The AppServer `appserver.ini` configures the Protheus client through
`[hbBridge]`: `Host`, `Port`, `TimeoutMs`, `HTTPURL`, `HTTPToken`,
`HTTPTimeoutSeconds` and `SQLProfile`. It does not define the SQL connections
for these two profiles. Tests send their aliases to the server selected by
those client endpoints.

1. Duplicate the **complete** working `[SQL/MSSQL/pData]` section in the
   private hbBridge INI, preserving connection, authentication and TLS keys.
   Rename only the copied section header to `[SQL/m06/query-timeout]`.
   Add or update these keys in the copy; values are seconds:

   ```ini
   LoginTimeoutSeconds=2
   QueryTimeoutSeconds=1
   ```

   Profile inheritance is not implemented: only the header and timeouts
   change; all other connection keys must be present in the copy.
   Preserve the original section for baseline/recovery queries.

2. Add another section for a deliberately refused local connection:

   ```ini
   [SQL/m06/refused]
   Driver=mssql
   ODBCDriver=ODBC Driver 18 for SQL Server
   Server=tcp:127.0.0.1,65534
   Database=master
   Authentication=sql
   Username=m06-fictitious-user
   Password=m06-fictitious-secret
   Encrypt=optional
   LoginTimeoutSeconds=1
   QueryTimeoutSeconds=1
   ```

   `65534` is an example port: verify that no local listener uses it, or
   replace it with another unused port. These credentials are fictitious.
   The named driver must be installed. For example,
   `Get-NetTCPConnection -LocalPort 65534 -State Listen -ErrorAction SilentlyContinue`
   shows an existing listener; choose a different port if it returns one.
   The isolated launcher below reserves its refused port for the test lifetime.

3. Restart the regular hbBridge with the modified file:

   ```powershell
   .\out\hbbridge.exe -config="C:\tmp\hbbridge.ini"
   ```

   Configuration is loaded at startup. Editing the INI does not add profiles
   to an already running process.

4. In Protheus, keep this hbBridge host's actual endpoints in the AppServer
   `[hbBridge]` section. `SQLProfile=MSSQL/pData` remains the working profile.
   `U_HBBridgeTCPAndHTTPFailureTest()` already passes `m06/refused` and
   `m06/query-timeout`; these aliases must exactly match the server INI sections.

This procedure uses the regular executable and its endpoints. The
`-Failures -Serve` mode below starts another test host with in-memory
profiles and its own ports, without adding these sections to the private INI.

## Prepare the isolated host

Use an existing working MSSQL profile from a private configuration file:

```powershell
./scripts/test-hbbridge-mssql.ps1 -Config C:/tmp/hbBridge.ini -Profile MSSQL/pData `
    -Failures -FailureODBCDriver 'ODBC Driver 18 for SQL Server' -Serve
```

`MSSQL/pData` is an explicit example alias; replace it with the configured
working alias. The named ODBC driver must be installed for the test process
architecture. The runner reads the private file without changing it or
copying credentials into the repository. It creates these in-memory profiles:

| Profile | Purpose |
| --- | --- |
| Explicit working alias | Real MSSQL connection, login timeout 2 seconds and statement timeout 5 seconds. |
| `m06/refused` | Loopback port reserved without listening, fictitious credentials, login/statement timeouts of 1 second. |
| `m06/query-timeout` | Working connection with a 1-second statement timeout. |

The host uses separate loopback TCP, NETIO and HTTP test ports. The TCP/HTTP
ports are printed after the native checks pass; use those ports in the
Protheus calls. The HTTP token `m06-http-test-only` belongs only to this
fixture. No ERP tables or SQL Server service are modified.

The fixture first runs the 46 native checks, then remains available for
**600 seconds**, or until Esc/Ctrl+Q. This is a test-host lifetime, not a
product limit. Omit `-Serve` for native validation followed by cleanup.
Exit 2 means a prerequisite failure; exit 1 means failed checks/runtime;
exit 0 follows successful checks and cleanup.

## Compile the Protheus sources

Compile the complete `src/tlpp` tree, including both files in this directory.
For the local licensed AppServer installation, execute in an administrative
command prompt from the project root:

```bat
C:\totvs\stop-totvs.bat
scripts\build-totvs.cmd "C:\totvs\protheus1212410\protheus\bin\appserver" "C:\totvs\includes;F:\GitHub\hb.bridge\includes" "PROTHEUS"
C:\totvs\start-totvs.bat
```

Adjust the installation/include paths for another machine. Restore the
AppServer after the compilation attempt, including when compilation fails.
The stop/build/start cycle concerns the local TOTVS runtime; it does not
stop MSSQL. Start the isolated hbBridge fixture after compiling so its
600-second window is available for the test calls.

## Direct calls

The published test signatures are:

```tlpp
U_HBBridgeFailureTest(cWorkingProfile, cUnavailableProfile, cHost, nPort, nTimeout, cTimeoutProfile)
U_HBBridgeHTTPFailureTest(cWorkingProfile, cUnavailableProfile, cURL, cToken, nTimeoutSeconds, cTimeoutProfile)
```

`nTimeout` is in milliseconds for TCP; `nTimeoutSeconds` is in seconds for
HTTP. Omitted transport settings use the active AppServer `[hbBridge]`
configuration. Both working and unavailable profile aliases are required
and distinct. The final timeout profile is optional and must also be distinct.
With the isolated host, use the printed ports and include the timeout alias:

```tlpp
U_HBBridgeFailureTest("MSSQL/pData", "m06/refused", "127.0.0.1", nTCPPort, 7000, "m06/query-timeout")
U_HBBridgeHTTPFailureTest("MSSQL/pData", "m06/refused", "http://127.0.0.1:" + cHTTPPort, "m06-http-test-only", 7, "m06/query-timeout")
```

The complete timeout cases expect **38 TCP checks** and **51 HTTP checks**,
with zero failures and 21 service calls per transport. Omitting the final
profile runs **29 TCP checks** and **39 HTTP checks**, with 16 calls each,
without native statement-timeout acceptance. HTTP service failures must
return status 500, followed by status 200 on recovery.

The timeout fixture executes the bounded statement
`WAITFOR DELAY '00:00:04'; SELECT 77 AS RECOVERY_ID`. Its raw service call
must fail after at least 500 ms and before 4000 ms. Keep the client transport
timeout at least 7 seconds so a transport deadline does not substitute for
the 1-second native SQL timeout.

## Command-line calls

The compiled `U_HBBridgeFailureCLI` entry accepts named arguments through
AppServer `-run`. A separate private `hbm06.ini` can retain the installation's
environment, RPO, license and database sections while omitting `OnStart` and
HTTP listeners. Its native driver configuration must include
`[Drivers] Active=TCP` and `[TCP] TYPE=TCPIP`, with `PORT` set to an unused
port. This preserves the permanent `appserver.ini`. Run from the AppServer
directory in `cmd.exe`, replacing the test ports:

```bat
appserver.exe -ini="hbm06.ini" -run=U_HBBridgeFailureCLI -env=PROTHEUS --transport=tcp --working-profile=MSSQL/pData --unavailable-profile=m06/refused --timeout-profile=m06/query-timeout --host=127.0.0.1 --port=<tcp-port> --timeout=7
appserver.exe -ini="hbm06.ini" -run=U_HBBridgeFailureCLI -env=PROTHEUS --transport=http --working-profile=MSSQL/pData --unavailable-profile=m06/refused --timeout-profile=m06/query-timeout --url=http://127.0.0.1:<http-port> --token=m06-http-test-only --timeout=7
```

Preserve the quoted `-ini` value: the tested AppServer parser stripped the
filename extension when it was unquoted. Native `Drivers` settings are still
required by this runtime even when only executing `-run`.

`--timeout` is in seconds for both CLI transports, defaulting to 7. Transport
defaults to `tcp`; `--timeout-profile` may be omitted. Recognized flags must
be unique and nonempty; port/timeout values must be positive whole decimal
numbers. AppServer's own arguments are ignored. Return 0 means all checks
passed; return 1 means invalid arguments, baseline failure or failed checks.
Use the final `controlled failure checks` console report to record the
actual runtime result.

`RunCLI()` borrows the native `Variadic:vArgs` array without copying it;
the array is required by the AppServer interface. Cases/settings/results
remain `JSONObject` values. Short-lived name arrays are required by the
native `JSONObject:GetNames()` API.

## Scope and evidence

On **2026-10-14**, native real-MSSQL validation passed **46 checks, zero
failures, no skips**, covering direct core, NETIO, TCP and HTTP calls:
`tmp/mssql-tests-e22aaf15b69e44ad806a5316060438ec/results.log`.
The managed default regression passed **636 checks, zero failures, no
skips**: `tmp/tests-12c300f8399948e3bb3c20ee13eacc2d/results.log`.
The compiler report at **08:23:38 São Paulo**, thread **32272**, recorded
**30 successful sources and zero errors**, including this class and entry
point, updating the real `custom.rpo`: `tmp/totvs-compile.log`.
Subsequent automated AppServer CLI runs executed the compiled RPO against
the isolated real-MSSQL host, including the optional timeout profile:

| Transport | São Paulo time on 2026-10-14 | Thread | Result | Log |
| --- | --- | --- | --- | --- |
| TCP | 08:28:56–08:29:12 | 29120 | 38 checks, zero failures; exit 0 | `tmp/m06-protheus-tcp-clean-output-20261014.log` |
| HTTP | 08:28:13–08:28:29 | 21392 | 51 checks, zero failures; exit 0 | `tmp/m06-protheus-http-output-20261014.log` |

These are real Protheus runtime checks through `-run`, not manual
SmartClient/WebApp or UI acceptance. The live dataset verifies cleared
state and unsuccessful `MoreToRead()` after failure; the separate accepted
67-check dataset mock verifies request counts and absence of retries.

The ODBC timeout is per native statement, including query/count statements;
login timeout is a separate connection attribute. These settings do not
implement a shared request deadline, explicit server-side cancellation or
SQL cancellation on client disconnect. This test does not certify prolonged
network blackholes, server shutdown/restart, arbitrary UTF-8/FLOAT integrity
or business-scale inference. Broader integrity remains tracked in
[WIP](../../../../../WIP.md).

## Missing fixture profiles

Seven failures per transport can occur when the regular host lacks
`m06/refused` and `m06/query-timeout`: it returns `PROFILE_NOT_FOUND`, not
the expected connection/query failure. Use the `-Failures -Serve` runner
and the endpoints it prints. Its profiles exist only in that process.
The test reports this prerequisite explicitly and never dumps parameters/tokens.
`U_HBBridgeTCPAndHTTPFailureTest()` uses the active AppServer INI endpoints
and SQL profile (with native `FWGetTopInfo()` fallback); it does not create
server-side fixtures. To run it against the isolated host, its client settings
must point to the printed endpoints, or use the explicit wrappers above.

After the diagnostic/logging adjustment, recompilation at 13:09:29 São Paulo
on 2026-10-14 recorded 30 sources/zero source errors. Updated CLI TCP 38 and
HTTP 51 checks passed with exit 0; logs:
`tmp/m06-protheus-tcp-updated-output-20261014.log` and
`tmp/m06-protheus-http-updated-output-20261014.log`. The compiler itself
still exits 0xC0000409 after its completed build report; the subsequent
compiled-RPO CLI processes finish normally. The reported regular-host runs
(38/7 TCP and 51/7 HTTP) are historical prerequisite failures; the confirmed
manual run below resolves them. See the
[acceptance record](../../../../../docs/acceptance.md#sql-native-timeouts-and-appserver-recovery-on-2026-10-14).

## Confirmed manual validation

On 2026-10-14 at **14:30:50 São Paulo**, `U_HBBridgeTCPAndHTTPFailureTest`,
thread **13796**, passed all **38 TCP and 51 HTTP checks**, with zero reported
failures. This accepts the listed manual failure/recovery cases and resolves
the earlier seven failures per transport. Evidence:
`tmp/protheus-failure-manual-20261014-143050.log`. See the
[manual acceptance record](../../../../../docs/acceptance.md#manual-protheus-failure-recovery-on-2026-10-14).
Native handshake diagnostics remain recorded without a verified cause or
resolution; the run does not certify clean TLS/HTTPS, precise duration, GUI
launch route, concurrency or broad UTF-8/FLOAT integrity.
