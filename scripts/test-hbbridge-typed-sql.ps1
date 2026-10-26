#Requires -Version 7.0
[CmdletBinding()]
param(
    [string] $Config,
    [string] $Profile,
    [string] $HbCompileRoot,
    [string] $ZigPath,
    [ValidateRange(10, 600)][int] $TimeoutSeconds = 120,
    [switch] $Serve,
    [ValidateRange(1, 1800)][int] $ServeSeconds = 120
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$mssqlRequested = -not [string]::IsNullOrWhiteSpace($Config) -or -not [string]::IsNullOrWhiteSpace($Profile)
if ($mssqlRequested -and ([string]::IsNullOrWhiteSpace($Config) -or [string]::IsNullOrWhiteSpace($Profile))) {
    throw 'Optional MSSQL acceptance requires both -Config and -Profile.'
}
$configPath = if ($mssqlRequested) { [IO.Path]::GetFullPath($Config) } else { '' }
if ($mssqlRequested -and -not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    throw 'An explicit existing private configuration file is required.'
}
. (Join-Path $PSScriptRoot 'toolchain.ps1')
$toolchain = Resolve-HBBridgeToolchain -ProjectRoot $projectRoot -HbCompileRoot $HbCompileRoot -ZigPath $ZigPath
# The ODBC preparation also prepares the reviewed SQLite extension.
& (Join-Path $PSScriptRoot 'prepare-odbc.ps1') -HbCompileRoot $toolchain.HbCompileRoot -ZigPath $toolchain.Zig
& (Join-Path $PSScriptRoot 'prepare-http.ps1') -HbCompileRoot $toolchain.HbCompileRoot -ZigPath $toolchain.Zig
$runRoot = Join-Path $projectRoot ('tmp/typed-sql-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory((Join-Path $runRoot 'build')) | Out-Null
$previous = Enter-HBBridgeToolchain -Toolchain $toolchain
Push-Location -LiteralPath $projectRoot
try {
    & $toolchain.Zig build
    if ($LASTEXITCODE -ne 0) { throw 'The managed Zig library build failed.' }
    $target = Join-Path $runRoot 'hbbridgetypedquerytest'
    $executable = $target + $toolchain.ExecutableExtension
    & $toolchain.Hbmk2 "-comp=$($toolchain.Compiler)" tests/integration/harbour/hbbridge.typed.query.test.hbp `
        "-o$target" "-workdir=$(Join-Path $runRoot 'build')" 2>&1 |
        Tee-Object -FilePath (Join-Path $runRoot 'build.log')
    if ($LASTEXITCODE -ne 0) { throw 'The typed SQL integration build failed.' }

    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $executable
    $info.WorkingDirectory = $runRoot
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    if ($mssqlRequested -or $Serve) {
        $info.ArgumentList.Add($configPath)
        $info.ArgumentList.Add($(if ($mssqlRequested) { $Profile } else { '' }))
    }
    if ($Serve) {
        $info.ArgumentList.Add('serve')
        $info.ArgumentList.Add($ServeSeconds.ToString([Globalization.CultureInfo]::InvariantCulture))
        $info.Environment['HBBRIDGE_TYPED_HTTP_TOKEN'] = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
        Write-Host "Typed SQL serving workspace: $runRoot"
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    $started = $false
    try {
        if (-not $process.Start()) { throw 'The typed SQL integration test did not start.' }
        $started = $true
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        $clock = [Diagnostics.Stopwatch]::StartNew()
        $readyAt = $null
        $endpointPath = Join-Path $runRoot 'endpoints.json'
        $completed = $false
        while (-not ($completed = $process.WaitForExit(500))) {
            if ($Serve -and $null -eq $readyAt -and (Test-Path -LiteralPath $endpointPath -PathType Leaf)) {
                $readyAt = $clock.Elapsed.TotalSeconds
                Write-Host "Typed SQL listener endpoints: $endpointPath"
            }
            $expired = if ($null -eq $readyAt) {
                $clock.Elapsed.TotalSeconds -gt $TimeoutSeconds
            } else {
                ($clock.Elapsed.TotalSeconds - $readyAt) -gt ($ServeSeconds + 10)
            }
            if ($expired) { break }
        }
        if (-not $completed -and -not $process.HasExited) {
            $process.Kill($true)
            $null = $process.WaitForExit(5000)
        }
        $captureCompleted = [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($stdout, $stderr), 5000)
        $log = if ($stdout.IsCompletedSuccessfully) { $stdout.GetAwaiter().GetResult() } else { '[Standard output capture incomplete.]' + "`n" }
        $log += if ($stderr.IsCompletedSuccessfully) { $stderr.GetAwaiter().GetResult() } else { '[Standard error capture incomplete.]' + "`n" }
        [IO.File]::WriteAllText((Join-Path $runRoot 'console.log'), $log, [Text.UTF8Encoding]::new($false))
        Write-Output $log
        Write-Host "Typed SQL integration output: $runRoot"
        if (-not $completed) { throw 'The typed SQL test exceeded its acceptance or bounded serving budget.' }
        if (-not $captureCompleted) { throw 'The typed SQL test output capture did not complete.' }
        $resultPath = Join-Path $runRoot 'result.json'
        if (-not (Test-Path -LiteralPath $resultPath -PathType Leaf)) { throw 'The typed SQL test did not produce result.json.' }
        $report = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json -AsHashtable
        $valid = $report -is [Collections.IDictionary] -and $report.success -is [bool] -and $report.success -and
            $report.checks -is [Collections.IDictionary] -and $report.checks.Count -gt 0 -and
            ($report.checkCount -is [int] -or $report.checkCount -is [long]) -and
            ($report.failureCount -is [int] -or $report.failureCount -is [long]) -and
            $report.checkCount -eq $report.checks.Count -and $report.failureCount -eq 0 -and
            $report.sqlite.status -eq 'executed'
        if ($valid) {
            foreach ($check in $report.checks.Values) {
                if ($check -isnot [bool] -or -not $check) { $valid = $false; break }
            }
        }
        if ($mssqlRequested -and $report.mssql.status -ne 'executed') { $valid = $false }
        if ($report.checks -is [Collections.IDictionary]) {
            foreach ($name in @('sqlite.hook.sharedHashOutputSurvives', 'sqlite.exactSigned64Endpoints',
                'sqlite.nullDistinctFromEmptyAndMissing', 'sqlite.boundPageAndCount',
                'sqlite.beyondLastKeepsTotalsAndMetadata', 'sqlite.recoveryAfterFailures',
                'sqlite.wire.tcp.exactResultAndMetadata', 'sqlite.wire.http.gzip',
                'sqlite.wire.rest.exactResultAndMetadata', 'caller.noActiveLeases')) {
                if (-not $report.checks.ContainsKey($name) -or -not $report.checks[$name]) { $valid = $false }
            }
            if ($mssqlRequested) {
                foreach ($name in @('mssql.exactDecimalBindingAndResult', 'mssql.wire.tcp.exactResultAndMetadata',
                    'mssql.wire.http.gzip', 'mssql.wire.rest.exactResultAndMetadata')) {
                    if (-not $report.checks.ContainsKey($name) -or -not $report.checks[$name]) { $valid = $false }
                }
            }
        }
        $serveReport = $null
        if ($Serve) {
            $serveResultPath = Join-Path $runRoot 'serve.result.json'
            if (-not (Test-Path -LiteralPath $serveResultPath -PathType Leaf)) {
                throw 'The typed SQL serving fixture did not produce serve.result.json.'
            }
            $serveReport = Get-Content -LiteralPath $serveResultPath -Raw | ConvertFrom-Json -AsHashtable
            foreach ($field in @('success', 'ready', 'tcpStopped', 'httpStopped', 'noActiveLeases')) {
                if ($serveReport[$field] -isnot [bool] -or -not $serveReport[$field]) { $valid = $false }
            }
        }
        $dependencies = Get-HBBridgeDependencies -ProjectRoot $projectRoot
        $receipt = [ordered]@{
            schemaVersion = 1
            scope = 'Real managed SDD hook, common QueryTyped service, TCP and gzip HTTP; no AppServer acceptance'
            success = ($process.ExitCode -eq 0 -and $valid)
            exitCode = $process.ExitCode
            platform = Get-HBBridgePlatform
            compiler = $toolchain.Compiler
            compilerVersion = $dependencies.zig.version
            harbourRevision = $dependencies.harbour.revision
            mssqlRequested = $mssqlRequested
            servingRequested = [bool]$Serve
            serveSeconds = if ($Serve) { $ServeSeconds } else { $null }
            serving = $serveReport
            executableSHA256 = (Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash
            dependenciesSHA256 = (Get-FileHash -LiteralPath (Join-Path $projectRoot 'config/dependencies.json') -Algorithm SHA256).Hash
            managedReceiptSHA256 = [ordered]@{}
            sourceSHA256 = [ordered]@{}
            resultSHA256 = (Get-FileHash -LiteralPath $resultPath -Algorithm SHA256).Hash
            result = $report
        }
        foreach ($managed in @('.deps/odbc/receipt.json', '.deps/sqlite/receipt.json', '.deps/http/receipt.json')) {
            $managedPath = Join-Path $projectRoot $managed
            if (-not (Test-Path -LiteralPath $managedPath -PathType Leaf)) { throw "Missing managed build receipt: $managed." }
            $receipt.managedReceiptSHA256[$managed] = (Get-FileHash -LiteralPath $managedPath -Algorithm SHA256).Hash
        }
        foreach ($source in @('tests/integration/harbour/hbbridge.typed.query.test.hb',
            'tests/integration/harbour/hbbridge.http.test.hb',
            'tests/integration/harbour/hbbridge.typed.query.test.hbp', 'scripts/test-hbbridge-typed-sql.ps1',
            'src/c/hbbridge.sql.typed.h', 'src/c/hbbridge.sql.binding.c',
            'src/c/hbbridge.sqlite.typed.c', 'src/c/hbbridge.odbc.typed.c',
            'src/hb/services/hbbridge.query.hb', 'src/hb/services/hbbridge.services.hb', 'hbbridge.hbm')) {
            $sourcePath = Join-Path $projectRoot $source
            if (Test-Path -LiteralPath $sourcePath -PathType Leaf) {
                $receipt.sourceSHA256[$source] = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
            }
        }
        [IO.File]::WriteAllText((Join-Path $runRoot 'receipt.json'),
            ($receipt | ConvertTo-Json -Depth 20) + "`n", [Text.UTF8Encoding]::new($false))
        if (-not $receipt.success) { throw 'Typed SQL integration failed; inspect result.json and console.log.' }
    } finally {
        try {
            if ($started -and -not $process.HasExited) {
                $process.Kill($true)
                if (-not $process.WaitForExit(5000)) { throw 'The owned typed SQL test did not stop.' }
            }
        } finally {
            $process.Dispose()
        }
    }
} finally {
    Pop-Location
    Exit-HBBridgeToolchain -PreviousEnvironment $previous
}
