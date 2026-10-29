#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $AppServerDirectory,
    [Parameter(Mandatory)][string] $IniFile,
    [Parameter(Mandatory)][string] $RpoDirectory,
    [Parameter(Mandatory)][string[]] $IncludeDirectory,
    [string] $Environment = 'PROTHEUS',
    [switch] $NativeTables,
    [switch] $MeasureConversion,
    [ValidateRange(1, 2147483647)][int] $NativeRows = 1025,
    [string] $HBBridgeEndpointsFile
)
$ErrorActionPreference = 'Stop'
foreach ($directory in $IncludeDirectory) {
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
        throw 'IncludeDirectory requires existing directories; pass a PowerShell array for multiple paths.'
    }
}
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$runRoot = Join-Path $projectRoot ('tmp/protheus-presentation-' + [guid]::NewGuid().ToString('N'))
$sdkSource = [IO.Path]::GetFullPath($AppServerDirectory)
$rpoSource = [IO.Path]::GetFullPath($RpoDirectory)
$serverRoot = Join-Path $runRoot 'server'
$apoRoot = Join-Path $runRoot 'apo'
$dataRoot = Join-Path $runRoot 'data'
$iniSource = [IO.Path]::GetFullPath($IniFile)
$utf8 = [Text.UTF8Encoding]::new($false)
$receiptPath = Join-Path $runRoot 'result.json'
$endpoints = $null
if ($HBBridgeEndpointsFile) {
    if (-not $NativeTables) { throw 'HBBridgeEndpointsFile requires -NativeTables.' }
    $endpoints = Get-Content -LiteralPath $HBBridgeEndpointsFile -Raw | ConvertFrom-Json
    if ($endpoints.schemaVersion -ne 1 -or $endpoints.backend -ne 'mssql' -or
        $endpoints.host -ne '127.0.0.1' -or [string]::IsNullOrWhiteSpace($endpoints.profile) -or
        $endpoints.tcpPort -lt 1 -or $endpoints.tcpPort -gt 65535 -or
        $endpoints.httpPort -lt 1 -or $endpoints.httpPort -gt 65535 -or
        $endpoints.httpToken -notmatch '^[A-F0-9]{64}$') {
        throw 'Use the fresh MSSQL endpoint file from test-hbbridge-typed-sql.ps1 -Serve.'
    }
}
$receipt = [ordered]@{
    schemaVersion = 1
    createdUTC = [DateTime]::UtcNow.ToString('o')
    scope = 'Isolated AppServer presentation tests; optional actual MSSQL TCP/gzip HTTP when explicit fresh endpoints are supplied; no interactive UI acceptance'
    status = 'preparing'
    sourceRoot = $projectRoot
    runRoot = $runRoot
    privateIni = 'server/appserver.ini; credentials not exported'
    nativeRows = if ($NativeTables) { $NativeRows } else { $null }
    realSQLRequested = [bool]$endpoints
    executable = $null
    inputRPO = @()
    outputRPO = @()
    sources = @()
    compile = $null
    tests = @()
}

function Save-Receipt {
    [IO.File]::WriteAllText($receiptPath, ($receipt | ConvertTo-Json -Depth 9), $utf8)
}

function Get-SharedReadHash {
    param([string] $Path)
    $stream = [IO.FileStream]::new($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
    try { return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($stream)) }
    finally { $stream.Dispose() }
}

function Read-PrivateSections {
    param([string] $Path)
    $sections = @{}
    $section = ''
    foreach ($line in [IO.File]::ReadAllLines($Path)) {
        if ($line -match '^\s*\[([^]]+)\]') {
            $section = $Matches[1]
            if (-not $sections.ContainsKey($section)) { $sections[$section] = @{} }
        } elseif ($section -and $line -match '^\s*([^;#=][^=]*)=(.*)$') {
            $sections[$section][$Matches[1].Trim()] = $Matches[2].Trim()
        }
    }
    return $sections
}

function Invoke-OwnedProcess {
    param([string[]] $Arguments, [string] $LogPath, [int] $TimeoutSeconds = 240)
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = Join-Path $serverRoot 'appserver.exe'
    $info.WorkingDirectory = $serverRoot
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    foreach ($argument in $Arguments) { $info.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    $started = $false
    $timedOut = $false
    try {
        if (-not $process.Start()) { throw 'Owned AppServer process did not start.' }
        $started = $true
        $output = $process.StandardOutput.ReadToEndAsync()
        $errors = $process.StandardError.ReadToEndAsync()
        $clock = [Diagnostics.Stopwatch]::StartNew()
        while (-not $process.WaitForExit(1000)) {
            if ($clock.Elapsed.TotalSeconds -gt $TimeoutSeconds) {
                $timedOut = $true
                $process.Kill($true)
                $process.WaitForExit()
                break
            }
        }
        $text = ($output.GetAwaiter().GetResult() + $errors.GetAwaiter().GetResult()).Replace([string][char]0, '')
        [IO.File]::WriteAllText($LogPath, $text, $utf8)
        return [pscustomobject]@{ exitCode = $process.ExitCode; timedOut = $timedOut; elapsedMs = $clock.Elapsed.TotalMilliseconds; log = $LogPath; output = $text }
    } finally {
        if ($started -and -not $process.HasExited) { $process.Kill($true); $process.WaitForExit() }
        $process.Dispose()
    }
}

try {
    foreach ($path in @($serverRoot, $apoRoot, (Join-Path $dataRoot 'system'))) {
        [IO.Directory]::CreateDirectory($path) | Out-Null
    }
    if (-not (Test-Path -LiteralPath $iniSource -PathType Leaf)) { throw 'External SDK INI was not found.' }
    $sections = Read-PrivateSections -Path $iniSource
    if (-not $sections.ContainsKey('LicenseClient')) { throw 'The external LicenseClient section is required.' }
    foreach ($file in Get-ChildItem -LiteralPath $sdkSource -File) {
        if ($file.Extension -in @('.exe', '.dll', '.qm') -or $file.Name -in @('tlpp.rpo', 'language.ini')) {
            Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $serverRoot $file.Name) -Force
        }
    }
    foreach ($name in @('tttm120.rpo', 'custom.rpo')) {
        $source = Join-Path $rpoSource $name
        $target = Join-Path $apoRoot $name
        Copy-Item -LiteralPath $source -Destination $target -Force
        $sourceHash = Get-SharedReadHash -Path $source
        $copyHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
        if ($sourceHash -ne $copyHash) { throw 'The isolated RPO copy differs from its external input.' }
        $receipt.inputRPO += [ordered]@{ name = $name; sha256 = $copyHash; bytes = (Get-Item -LiteralPath $target).Length }
    }
    $receipt.executable = [ordered]@{
        name = 'appserver.exe'
        sha256 = (Get-FileHash -LiteralPath (Join-Path $serverRoot 'appserver.exe') -Algorithm SHA256).Hash
        tlppRPOSha256 = (Get-FileHash -LiteralPath (Join-Path $serverRoot 'tlpp.rpo') -Algorithm SHA256).Hash
    }
    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    $listener.Start()
    try { $driverPort = $listener.LocalEndpoint.Port } finally { $listener.Stop() }
    $ini = [Collections.Generic.List[string]]::new()
    $ini.Add('[' + $Environment + ']')
    foreach ($setting in @{
        SourcePath = $apoRoot; RpoCustom = (Join-Path $apoRoot 'custom.rpo'); RootPath = $dataRoot
        StartPath = '\system\'; RpoDb = 'TOP'; RpoLanguage = 'multi'; RpoVersion = '120'; LocalFiles = 'SQLITE'
    }.GetEnumerator()) { $ini.Add($setting.Key + '=' + $setting.Value) }
    # Copy only DBAccess endpoint/profile settings, never the external RPO/data paths.
    if ($sections.ContainsKey($Environment)) {
        foreach ($key in @('DBServer','DBDatabase','DBAlias','DBPort')) {
            if ($sections[$Environment].ContainsKey($key)) { $ini.Add($key + '=' + $sections[$Environment][$key]) }
        }
    }
    foreach ($section in @('LicenseClient', 'DBAccess')) {
        if ($sections.ContainsKey($section)) {
            $ini.Add('[' + $section + ']')
            foreach ($setting in $sections[$section].GetEnumerator()) { $ini.Add($setting.Key + '=' + $setting.Value) }
        }
    }
    if ($null -ne $endpoints) {
        $ini.Add('[hbBridge]')
        $ini.Add('Host=127.0.0.1')
        $ini.Add('Port=' + $endpoints.tcpPort)
        $ini.Add('TimeoutMs=30000')
        $ini.Add('SQLProfile=' + $endpoints.profile)
        $ini.Add('HTTPURL=http://127.0.0.1:' + $endpoints.httpPort)
        $ini.Add('HTTPToken=' + $endpoints.httpToken)
        $ini.Add('HTTPAcceptEncoding=gzip')
        $ini.Add('HTTPTimeoutSeconds=30')
    }
    $ini.Add('[TDS]')
    $ini.Add('AllowApplyPatch=*')
    $ini.Add('AllowEdit=*')
    $ini.Add('[Drivers]')
    $ini.Add('Active=TCP')
    $ini.Add('[TCP]')
    $ini.Add('Type=TCPIP')
    $ini.Add('Port=' + $driverPort)
    $iniPath = Join-Path $serverRoot 'appserver.ini'
    [IO.File]::WriteAllLines($iniPath, $ini, $utf8)
    $sourceList = Join-Path $runRoot 'sources.lst'
    & (Join-Path $projectRoot 'scripts/prepare-totvs-sources.ps1') -ProjectRoot $projectRoot -OutputFile $sourceList
    $sourcePaths = @([IO.File]::ReadAllText($sourceList).Split(';', [StringSplitOptions]::RemoveEmptyEntries))
    foreach ($source in $sourcePaths) {
        $receipt.sources += [ordered]@{ path = [IO.Path]::GetRelativePath($projectRoot, $source).Replace('\', '/'); sha256 = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash }
    }
    $receipt.status = 'compiling'
    Save-Receipt
    $compile = Invoke-OwnedProcess -Arguments @('-compile', ('-files=' + $sourceList),
        ('-includes=' + ($IncludeDirectory -join ';')), ('-env=' + $Environment),
        ('-consolefile=' + (Join-Path $runRoot 'compile.log'))) -LogPath (Join-Path $runRoot 'compile.stdout.log')
    $compileText = $compile.output
    $compileLogPath = Join-Path $runRoot 'compile.log'
    if (Test-Path -LiteralPath $compileLogPath) { $compileText += [IO.File]::ReadAllText($compileLogPath) }
    $expected = 'Total sources\(' + $sourcePaths.Count + '\) Success\(' + $sourcePaths.Count + '\) Errors\(0\)'
    $receipt.compile = [ordered]@{ sourceCount = $sourcePaths.Count; exitCode = $compile.exitCode; timedOut = $compile.timedOut; elapsedMs = $compile.elapsedMs; success = ($compile.exitCode -eq 0 -and -not $compile.timedOut -and $compileText -match $expected); log = 'compile.log'; stdout = 'compile.stdout.log' }
    Save-Receipt
    if (-not $receipt.compile.success) { throw 'Isolated TLPP compilation did not pass; inspect owned compile logs.' }
    $programs = @('U_HBBridgePresentationTest', 'U_HBBridgePresentationPageTest', 'U_HBBridgePresentationSRATest', 'U_HBBridgePresentationRDDTest', 'U_HBBridgePresentationMappingTest', 'U_HBBridgeTypedDataSetTest', 'U_HBBridgeDataSetTest')
    if ($MeasureConversion) { $programs += 'U_HBBridgePresentationPagePerf' }
    if ($NativeTables) { $programs += @('U_HBBridgePresentationProbe', 'U_HBBridgePresentationTableCLI', 'U_HBBridgeNativeBrowseTest') }
    if ($null -ne $endpoints) { $programs += 'U_HBBridgePresentationSQLTest' }
    foreach ($program in $programs) {
        $arguments = @()
        if ($program -eq 'U_HBBridgePresentationTableCLI') { $arguments = @('--native-rows=' + $NativeRows) }
        $run = & (Join-Path $projectRoot 'scripts/run-protheus-cli.ps1') -AppServerDirectory $serverRoot -IniFile $iniPath -Program $program -Environment $Environment -Argument $arguments -TimeoutSeconds 180
        $text = [IO.File]::ReadAllText($run.Log)
        $summaryPattern = switch ($program) {
            'U_HBBridgePresentationTest' { 'hbBridge presentation checks: \d+; OK' }
            'U_HBBridgePresentationPageTest' { 'hbBridge page conversion checks: \d+; OK' }
            'U_HBBridgePresentationPagePerf' { 'hbBridge page conversion performance: OK' }
            'U_HBBridgePresentationSRATest' { 'hbBridge SRA metadata checks: \d+; OK' }
            'U_HBBridgePresentationRDDTest' { 'hbBridge local RDD checks: \d+; OK' }
            'U_HBBridgePresentationMappingTest' { 'hbBridge source mapping checks: \d+; OK' }
            'U_HBBridgePresentationTableTest' { 'hbBridge native table checks: \d+; OK' }
            'U_HBBridgePresentationTableCLI' { 'hbBridge native table checks: \d+; OK' }
            'U_HBBridgeNativeBrowseTest' { 'hbBridge native browse checks: \d+; OK' }
            'U_HBBridgePresentationSQLTest' { 'hbBridge real presentation checks: \d+; OK' }
            'U_HBBridgePresentationProbe' { 'hbBridge presentation SDK probe OK' }
            'U_HBBridgeTypedDataSetTest' { 'hbBridge typed dataset Protheus OK; checks=77; mock calls=\d+' }
            default { 'hbBridge dataset navigation Protheus OK; checks=67; mock calls=31' }
        }
        $summary = [regex]::Match($text, $summaryPattern).Value
        $acceptableExit = if ($program -eq 'U_HBBridgeDataSetTest') { $run.ExitCode -in @(0, -4) } else { $run.ExitCode -eq 0 }
        $receipt.tests += [ordered]@{ program = $program; exitCode = $run.ExitCode; timedOut = $run.TimedOut; success = ($acceptableExit -and -not $run.TimedOut -and $summary.Length -gt 0); summary = $summary; log = $run.Log }
        Save-Receipt
        Write-Output ($program + ': exit=' + $run.ExitCode + '; timedOut=' + $run.TimedOut + '; summary=' + $summary)
        if (-not $receipt.tests[-1].success) { throw 'An isolated dataset suite did not pass; inspect its owned CLI log.' }
    }
    foreach ($source in $receipt.sources) {
        if ((Get-FileHash -LiteralPath (Join-Path $projectRoot $source.path) -Algorithm SHA256).Hash -ne $source.sha256) {
            throw 'A compiled source changed during the presentation run; rerun against the final sources.'
        }
    }
    $receipt.sourceIdentityUnchangedAfterExecution = $true
    foreach ($name in @('tttm120.rpo', 'custom.rpo')) {
        $file = Join-Path $apoRoot $name
        $receipt.outputRPO += [ordered]@{ name = $name; sha256 = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash; bytes = (Get-Item -LiteralPath $file).Length }
    }
    $receipt.status = 'passed'
    Save-Receipt
    Write-Output ('Validation receipt: ' + $receiptPath)
} catch {
    $receipt.status = 'failed'
    Save-Receipt
    throw
}
