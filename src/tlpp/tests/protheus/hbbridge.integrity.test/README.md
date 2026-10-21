# MSSQL text and numeric integrity in Protheus

[Português](README.pt-BR.md) · [Dataset contract](../../../../../docs/dataset.md) · [Acceptance](../../../../../docs/acceptance.md)

`HBBridge.Test.HBBridgeIntegrityTest` exercises the production TCP and HTTP
clients and `HBBridgeRPCDataSet` with the read-only `d03.mssql.constants.v1`
fixture. Supply an explicit configured MSSQL profile alias. The queries use
constants and do not read or change ERP business tables. The test does not
start listeners or change the hbBridge/AppServer INI files.

Compile this directory together with the complete current `src/tlpp` tree,
including `HBBridgeJSON`, both clients and the dataset, using the target AppServer SDK/includes.
The destination hbBridge must include the current wire/numeric implementation
and managed ODBC patch. See the [compilation script](../../../../../scripts/build-totvs.cmd).
The recorded 2026-10-21 AppServer execution passed **80 checks, zero failures**;
its exact scope and the separate closed JSON-helper run are described below.

## Prepare an isolated MSSQL destination

Use an existing working profile in a private hbBridge configuration:

```powershell
./scripts/test-hbbridge-mssql.ps1 -Config C:\tmp\hbbridge.ini -Profile MSSQL/pData -Integrity -Serve
```

`MSSQL/pData` is an example opaque alias; use the exact alias configured in
that file. The launcher builds the managed components, runs the native
integrity checks and, when they pass, keeps its own loopback TCP/HTTP listeners
available. It reads the private configuration without changing it or exposing
SQL credentials. Existing application services need no restart for this host.

The printed run directory contains `endpoints.json`: use its `profile`,
`tcpPort`, `httpPort` and fixture-only `httpToken`. Construct the HTTP URL as
`http://127.0.0.1:<httpPort>`. Create `d03.stop` in that same directory to stop
the owned host after testing; it also stops after a maximum of ten minutes.
The final native result is separate from the subsequent AppServer result.

## Run from Protheus

The public wrapper forwards to `HBBridgeIntegrityTest():Run()`:

```tlpp
nResult := U_HBBridgeIntegrityTest(cProfile, cHost, nPort, cURL, cToken, nTimeoutSeconds)
```

Arguments are the explicit MSSQL profile, TCP host/port, HTTP base URL/token
and per-request timeout in seconds. Only the profile is mandatory. Omitted
host/port/URL/token use the existing AppServer `[hbBridge]` client settings;
they do not configure the SQL connection. Timeout defaults to 30 seconds and
must be a positive whole number no greater than 2147483. It applies separately
to each request, not to the total test.

For the isolated host, pass the values from its `endpoints.json`. For an
already configured destination:

```tlpp
nResult := U_HBBridgeIntegrityTest("MSSQL/pData")
// Equivalent class entry:
nResult := HBBridge.Test.HBBridgeIntegrityTest():Run("MSSQL/pData")
```

For a licensed AppServer CLI environment, use a private CLI INI beside the
executable. Replace `TCP_PORT` and `HTTP_PORT` with the isolated host's ports
and supply its actual fixture token:

```bat
appserver.exe -ini="private-integrity.ini" -run=U_HBBridgeIntegrityCLI -env=PROTHEUS --profile=MSSQL/pData --host=127.0.0.1 --port=TCP_PORT --url=http://127.0.0.1:HTTP_PORT --token=d03-http-test-only --timeout=30
```

The wrapper forwards the native argument array to `RunCLI(aArguments)`.
Supported flags are `--profile`, `--host`, `--port`, `--url`, `--token` and
`--timeout`, using unique `--name=value` entries. Port/timeout use canonical
whole decimal notation. Invalid arguments or failed checks return 1; all
checks passing returns 0. Preserve the `hbBridge integrity summary:` JSON
and final `hbBridge integrity Protheus OK/FAILED` line as runtime evidence.

## Checked boundaries and limits

- Parser checks distinguish raw UTF-8 JSON from escaped Unicode and verify
  explicit CP1252/UTF-8 conversion. Echo checks cover accented text, the euro
  sign, long text, NUL, empty/null, literal escape text and unchanged caller
  inputs through both clients.
- SQL/dataset checks cover fractional/negative FLOAT, small/large magnitudes,
  a 15-significant-digit numeric check, declared DECIMAL scales, accented
  VARCHAR, Unicode outside CP1252, a surrogate pair across an ODBC chunk
  boundary, NUL/empty/null, EOF and owned TCP close. NUL is also verified in
  defensive `GetRow()`/`GetRows()` snapshots. HTTP checks status 200.
- Native TLPP `N` values use stated comparison tolerances; the small/large
  checks scale values near one. This does not promise complete binary64 bit
  preservation by the AppServer JSON parser. Native codec checks have a
  separate scope. Caller CAST defines business scale; no SX3 rule is inferred.
  `DEC_CREATE()` returns a distinct fixed-decimal type and is not used to
  conceal precision already lost while parsing a JSON number.
- `EXACT_TEXT` projects `DECIMAL(30,10)` as text and must retain
  `12345678901234567890.1234567890` exactly. Converting that string to a native
  number is outside this assertion and can lose digits.
- `BINARY_HEX` explicitly projects VARBINARY as hexadecimal text and expects
  `0001FF007F`. This test submits no raw binary JSON value and does not claim
  automatic binary encoding. Native integrity checks separately verify raw
  byte retrieval and the `BINARY_JSON_UNSUPPORTED` wire refusal.

Inputs are ordinary AppServer text, CP1252 for these fixtures. The clients
encode the textual request once to UTF-8. Returned raw text is checked as
UTF-8; a representable accented value is then converted once with
`DecodeUTF8(cText, "cp1252")` for the consumer assertion. Values outside CP1252
remain UTF-8 and are not forced through that conversion. Parser/channel
conversion must have one explicit owner to avoid double conversion. Neither
text conversion applies to binary or fixes numeric serialization.

## Native AppServer NUL defect and compatibility helper

On the tested AppServer, a direct property retains `A` + `Chr(0)` + `B`, but
native `ToJSON()` truncates its bytes from `410042` to `41`. Native
`FromJSON()` removes the escaped NUL in `"A\u0000B"`, returning `4142`.
The independent reproduction is tracked in
[Protheus issue 14](https://github.com/naldodj/totvs-protheus-open-issues/issues/14).
This is separate from UTF-8 conversion and cannot be repaired by `DecodeUTF8()`.

`HBBridge.Client.HBBridgeJSON():Encode()`/`:Parse()` now preserve NUL in
values for both clients and dataset snapshots. The helper retains native
numeric semantics, performs no codepage conversion and distinguishes genuine
`\u0000` escapes from literal escape text. Property names containing NUL are
rejected explicitly. Ordinary encoding still walks values once to detect NUL
before native serialization, adding linear traversal/key-enumeration work.

The closed helper regression needs neither SQL nor an hbBridge destination:

```tlpp
nResult := U_HBBridgeJSONTest()
```

It exercises ordinary serialization, NUL boundaries/repetition, nested
objects/arrays, Unicode and other escapes, literal escape preservation, input
preservation and malformed/unsupported input. Keep its count/result separate
from `U_HBBridgeIntegrityTest()`.

## Recorded acceptance

On **2026-10-21**, Windows AppServer **24.3.1.5** with an isolated private RPO
passed the production TCP/HTTP MSSQL fixture: **80 checks, zero failures**,
client/server exit codes 0. Receipt:
`tmp/d03-protheus-9c3d1606250449c9a659f92f92c5c6e6/validation.json`.
The native server artifact SHA-256 is
`96A7AC7B0D29C2016B15CAC4D8DCD18E5FA4CE075AF1BA28DE4719A5E8BE5CA1`.
The separate closed JSON-helper run passed **31 checks, zero failures**:
`tmp/d03-local-334459cffda64ccd89f8760b27c8d266/protheus.log`.

Earlier native runs on **2026-10-19** passed 752 generic checks, 73 MSSQL
integrity checks, 92 existing MSSQL checks, 7 independent .NET ODBC reference
checks and 2 Zig numeric checks, all without failures. They complement the
AppServer evidence and do not substitute for it. The managed ODBC correction
includes supplementary characters in UTF-8 SQL input, not only output decoding.

These results accept D03 for the demonstrated fixture/runtime. They do not
certify Linux, other ODBC drivers, raw BLOB JSON support or complete native
binary64 precision in Protheus. Exact large digits remain explicit SQL text
projections; caller CAST remains the business-scale option. Logical metadata
extensions remain future work.

These checks accept only their recorded runtime and fixture. Keep SQL Server,
driver, source/binary/RPO identity, client configuration, final counts and
exit status with the evidence. Business-field validation such as `RA_SALARIO`,
other consumer codepages, broader decimal ranges and package closure retain
their own acceptance requirements in the [active WIP](../../../../../WIP.md).
