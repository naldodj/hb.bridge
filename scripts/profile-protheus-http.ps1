#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $AppServerDirectory,
    [Parameter(Mandatory)][string] $IniFile,
    [Parameter(Mandatory)][string[]] $IncludeDirectory,
    [Parameter(Mandatory)][string] $EndpointsFile,
    [string] $Environment = 'PROTHEUS',
    [ValidateRange(1, 100)][int] $Iterations = 5,
    [ValidateRange(0, 20)][int] $Warmup = 1
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$endpoint = Get-Content -LiteralPath $EndpointsFile -Raw | ConvertFrom-Json
if ($endpoint.host -ne '127.0.0.1' -or $endpoint.httpPort -lt 1 -or $endpoint.httpPort -gt 65535) {
    throw 'The diagnostic requires an explicit loopback M08 MSSQL fixture endpoint.'
}
foreach ($value in @($endpoint.token, $endpoint.profile)) {
    if ([string]::IsNullOrWhiteSpace($value) -or $value -match '[\r\n\x00]') {
        throw 'Fixture credentials/profile must be nonempty single-line values.'
    }
}
# This maintained runner creates its own SDK/RPO and confirms real FWRest behavior.
$setup = @(& (Join-Path $PSScriptRoot 'test-protheus-http-gzip.ps1') `
    -AppServerDirectory $AppServerDirectory -IniFile $IniFile `
    -IncludeDirectory $IncludeDirectory -Environment $Environment -CompileAll 6>&1)
$receipt = @($setup | ForEach-Object { $_.ToString() } | Where-Object { $_ -like 'HTTP gzip probe output: *' })
if ($receipt.Count -ne 1) { throw 'The isolated setup did not return one owned scratch directory.' }
$runRoot = $receipt[0].Substring('HTTP gzip probe output: '.Length)
$sdkRoot = Join-Path $runRoot 'sdk'
$ownedIni = Join-Path $sdkRoot 'appserver.ini'
$profileIni = @(
    '[HBHTTPProfile]', ('URL=http://127.0.0.1:' + $endpoint.httpPort),
    ('Token=' + $endpoint.token), ('Profile=' + $endpoint.profile),
    ('Iterations=' + $Iterations), ('Warmup=' + $Warmup)
) -join "`r`n"
[IO.File]::AppendAllText($ownedIni, "`r`n" + $profileIni + "`r`n", [Text.UTF8Encoding]::new($false))
$run = & (Join-Path $PSScriptRoot 'run-protheus-cli.ps1') `
    -AppServerDirectory $sdkRoot -IniFile $ownedIni -Environment $Environment `
    -Program U_HBBridgeHTTPProfileProbe -TimeoutSeconds (120 + 60 * ($Iterations + $Warmup))
$rawLog = [IO.File]::ReadAllText($run.Log)
$startupMarker = '[INFO ][SERVER] TOTVS Application Server Initializing...'
# This installed logger may split one ConOut JSON record with its startup line.
# Remove only that exact known line; preserve the raw log and reject malformed JSON.
$normalizedLog = $rawLog.Replace($startupMarker, '').Replace("`r", '').Replace("`n", '')
$observations = @([regex]::Matches($normalizedLog, 'HBBRIDGE_HTTP_PROFILE (\{[^{}]*\})') |
    ForEach-Object { $_.Groups[1].Value | ConvertFrom-Json })
$completed = @($observations | Where-Object completed)
$samples = @($observations | Where-Object { $null -ne $_.encoding })
if ($run.ExitCode -ne 0 -or $run.TimedOut -or $completed.Count -ne 1 -or $completed[0].failures -ne 0 -or
    $samples.Count -ne 2 * ($Iterations + $Warmup) -or @($samples | Where-Object { -not $_.success }).Count -ne 0) {
    throw "HTTP phase profiling failed; inspect the private scratch log: $($run.Log)"
}
$result = [ordered]@{
    schemaVersion = 1
    success = $true
    fixture = 'm08.constant.v1; 10000 rows, one page, full row-value validation'
    scope = 'Diagnostic FWRest POST + expansion + JSON parse + direct row validation; not dataset/M08 statistics'
    clock = 'HBBridgeTime.TimeCounter.normalized.ms'
    iterationsPerEncoding = $Iterations
    warmupPerEncoding = $Warmup
    order = 'identity/gzip first order alternates per pair'
    nativeRequestScope = 'Post, GetHTTPCode, GetResult and response Content-Encoding; includes server SQL/serialization/network'
    constructionTimed = 'included only in totalMs'
    fwRestExpansion = 'wireBytes represent raw gzip only when rawGzip is true'
    logReconstruction = 'only exact known AppServer startup INFO marker and line breaks removed; raw log retained'
    appServerSHA256 = $run.AppServerSHA256
    samples = $samples
    averages = [ordered]@{}
}
foreach ($encoding in @('identity', 'gzip')) {
    $measured = @($samples | Where-Object { $_.encoding -eq $encoding -and -not $_.warmup })
    $average = [ordered]@{}
    foreach ($field in @('fwRestMs', 'decompressMs', 'jsonParseMs', 'validateMs', 'totalMs', 'wireBytes', 'decodedBytes')) {
        $average[$field] = ($measured | Measure-Object -Property $field -Average).Average
    }
    $result.averages[$encoding] = $average
}
$output = Join-Path $runRoot 'profile.json'
$result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $output -Encoding utf8
$result.averages | ConvertTo-Json -Depth 4 | Write-Output
Write-Host "HTTP phase profile: $output"
