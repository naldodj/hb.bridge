# FWRest gzip probe

[Português](README.pt-BR.md) · [HTTP contract](../../../../../docs/http.md)

`U_HBBridgeHTTPGzipProbe` compares the installed FWRest's untouched result
with a known UTF-8 response, then diagnoses native decompression. It covers
identity, gzip, seven-byte HTTP transfer chunks, a damaged CRC and recovery.
The actual hbBridge HTTP client also verifies gzip/identity, embedded NUL,
decompression failure/recovery and invalid encoding configuration. Mandatory
gzip checks cover its accepted response, rejected identity fallback, empty
406 and contradictory constructor options.

Use the isolated runner with an external licensed SDK, INI and vendor includes:

```powershell
./scripts/test-protheus-http-gzip.ps1 `
    -AppServerDirectory <AppServer-directory> -IniFile <external-INI> `
    -IncludeDirectory <vendor-includes> -CompileAll
```

It copies SDK/base RPO into a fresh disposable directory, creates its own INI,
custom RPO and loopback HTTP fixture, and compiles the three required sources
(all project TLPP with `-CompileAll`). It never edits installed configuration,
stops an existing AppServer or requires an old tmp artifact. The external INI
must supply the selected environment's SourcePath and LicenseClient section.
Python 3 is an explicit prerequisite of this test fixture, not of hbBridge.

Accept only complete compilation and the final 14-check/zero-failure marker
with exit 0. Raw diagnostic logs remain private scratch; no INI or SDK copy is
versioned. The compressed fixture is deliberately repetitive: its byte ratio
does not predict SQL results or production performance. Native hbBridge gzip
and socket failure tests are separate [HTTP checks](../../../../../tests/README.md).

The 2026-10-24 Windows run compiled all 55 TLPP sources with zero errors and
passed all 14 checks, exit 0. This confirms the installed FWRest behavior and
the client contract; live SQL timing has a separate
[dated scope](../../../../../docs/http.md#http-review-on-2026-10-24).

For phase diagnostics, start a fresh M08 MSSQL fixture in serve mode, then run:

```powershell
./scripts/profile-protheus-http.ps1 `
    -AppServerDirectory <AppServer-directory> -IniFile <external-INI> `
    -IncludeDirectory <vendor-includes> -EndpointsFile <fresh-endpoints.json>
```

This creates its own SDK/RPO, compiles the phase probe and compares five
measured identity/gzip requests plus one warmup per encoding. It measures
FWRest including server/network, decompression, JSON parsing and direct
validation of all 10000 rows; dataset overhead and full M08 statistics are
outside this diagnostic. The actual benchmark policy still requires gzip.
