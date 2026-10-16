#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string] $Config,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string] $Profile,
    [ValidateRange(1, 100000)][int] $Rows = 1000,
    [ValidateRange(1, 100000)][int] $PageSize = 100,
    [ValidateRange(1, 1000000)][int] $Iterations = 5,
    [ValidateRange(0, 1000000)][int] $Warmup = 2,
    [ValidateSet('all', 'local', 'tcp', 'http')][string] $Route = 'all',
    [ValidateSet('off', 'driver')][string] $ODBCPooling = 'off',
    [ValidateRange(1, 1)][int] $Concurrency = 1,
    [ValidateRange(1, 2147483647)][int] $SocketTimeoutMs = 15000,
    [ValidateRange(10, 60000)][int] $SampleIntervalMs = 50,
    [ValidateRange(1, 2147483647)][int] $ProcessTimeoutSeconds = 900,
    [ValidateRange(0, 3600)][int] $ServeSeconds = 0,
    [string] $HbCompileRoot,
    [string] $ZigPath
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if ($ServeSeconds -gt 0 -and $Route -ne 'http') { throw '-ServeSeconds requires -Route http.' }
if ($ServeSeconds -ge $ProcessTimeoutSeconds) { throw '-ProcessTimeoutSeconds must exceed -ServeSeconds.' }
$configPath = [IO.Path]::GetFullPath($Config)
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    Write-Host 'MSSQL benchmark prerequisite: CONFIG_NOT_FOUND'
    exit 2
}
. (Join-Path $PSScriptRoot 'toolchain.ps1')
$toolchain = Resolve-HBBridgeToolchain -ProjectRoot $projectRoot -HbCompileRoot $HbCompileRoot -ZigPath $ZigPath
& (Join-Path $PSScriptRoot 'prepare-odbc.ps1') -HbCompileRoot $toolchain.HbCompileRoot -ZigPath $toolchain.Zig
if (-not $?) { throw 'Managed ODBC dependency preparation failed.' }
$runRoot = Join-Path $projectRoot ('tmp/mssql-benchmark-' + [Guid]::NewGuid().ToString('N'))
$buildRoot = Join-Path $runRoot 'build'
New-Item -ItemType Directory -Path $buildRoot | Out-Null
$previousEnvironment = Enter-HBBridgeToolchain -Toolchain $toolchain
$benchmarkExit = 1
Push-Location -LiteralPath $projectRoot
try {
    & $toolchain.Zig build
    if ($LASTEXITCODE -ne 0) { throw 'The Zig library build failed.' }
    $testExecutable = Join-Path $runRoot ('hbbridge.mssql.benchmark.test' + $toolchain.ExecutableExtension)
    & $toolchain.Hbmk2 "-comp=$($toolchain.Compiler)" 'tests/integration/harbour/hbbridge.mssql.benchmark.test.hbp' `
        "-o$testExecutable" "-workdir=$buildRoot"
    if ($LASTEXITCODE -ne 0) { throw 'The MSSQL benchmark executable build failed.' }

    $dependencies = Get-HBBridgeDependencies -ProjectRoot $projectRoot
    $revision = [string](& git -c "safe.directory=$($projectRoot.Replace('\', '/'))" rev-parse HEAD)
    $dirty = [string](& git -c "safe.directory=$($projectRoot.Replace('\', '/'))" status --porcelain --untracked-files=normal)
    $receipt = Get-Content -LiteralPath (Join-Path $projectRoot '.deps/odbc/receipt.json') -Raw |
        ConvertFrom-Json -AsHashtable
    $report = [ordered]@{
        schemaVersion = 1
        kind = 'hbbridge.m08.native.baseline'
        generatedAtUTC = [DateTime]::UtcNow.ToString('o')
        success = $true
        settings = [ordered]@{
            rows = $Rows; pageSize = $PageSize; iterations = $Iterations; warmupIterations = $Warmup
            concurrency = $Concurrency; odbcPooling = $ODBCPooling
            routeOrder = @($(if ($Route -eq 'all') { 'local'; 'tcp'; 'http' } else { $Route }))
            processPerRoute = $true; routeRunsAreSequential = $true
            sampleIntervalMs = $SampleIntervalMs; processTimeoutSeconds = $ProcessTimeoutSeconds
            socketTimeoutMs = $SocketTimeoutMs; serveSeconds = $ServeSeconds
        }
        artifacts = [ordered]@{
            revision = $revision.Trim(); workingTreeModified = -not [string]::IsNullOrWhiteSpace($dirty)
            executableSha256 = (Get-FileHash -LiteralPath $testExecutable -Algorithm SHA256).Hash
            dependenciesSha256 = (Get-FileHash -LiteralPath (Join-Path $projectRoot 'config/dependencies.json') -Algorithm SHA256).Hash
            benchmarkSourceSha256 = (Get-FileHash -LiteralPath (Join-Path $projectRoot 'tests/integration/harbour/hbbridge.mssql.benchmark.test.hb') -Algorithm SHA256).Hash
            runnerSourceSha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash
            harbourRevision = $dependencies.harbour.revision; hbCompileRevision = $dependencies.hbCompile.revision
            zigVersion = $dependencies.zig.version
            odbcPatchSha256 = $receipt.patchSha256; odbcLibrarySha256 = $receipt.librarySha256
        }
        machine = [ordered]@{
            os = [Runtime.InteropServices.RuntimeInformation]::OSDescription
            architecture = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
            logicalProcessors = [Environment]::ProcessorCount
            powershellVersion = $PSVersionTable.PSVersion.ToString()
        }
        methodology = [ordered]@{
            timing = 'Child monotonic whole-dataset milliseconds, including validation; startup/warmup excluded.'
            clockLimitation = 'Windows GetTickCount64 follows the native system tick; averages do not prove sub-tick precision.'
            memory = 'OS working/private bytes sampled for each whole child process; includes client and isolated server for TCP/HTTP.'
            nativePeak = 'Largest observed PeakWorkingSet64 lifetime high-water mark; includes setup/warmup, may miss the final process peak.'
            exclusions = 'No speed threshold, cold database cache claim, parallel SQL claim or route allocation/leak claim.'
            transport = 'Harbour clients use one loopback socket per TCP/HTTP page. This does not measure AppServer clients.'
            profile = 'Only the explicit alias is loaded into the fixture registry; private config content/path/hash is omitted.'
        }
        routes = [ordered]@{}
    }
    foreach ($routeName in $report.settings.routeOrder) {
        $routeRoot = Join-Path $runRoot $routeName
        New-Item -ItemType Directory -Path $routeRoot | Out-Null
        $startInfo = [Diagnostics.ProcessStartInfo]::new()
        $startInfo.FileName = $testExecutable
        $startInfo.WorkingDirectory = $routeRoot
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $startInfo.RedirectStandardOutput = $true
        $startInfo.RedirectStandardError = $true
        foreach ($argument in @($configPath, $Profile, $routeName, $Rows.ToString(), $PageSize.ToString(),
            $Iterations.ToString(), $Warmup.ToString(), $ODBCPooling, $SocketTimeoutMs.ToString(), $ServeSeconds.ToString())) {
            $startInfo.ArgumentList.Add($argument)
        }
        $process = [Diagnostics.Process]::new()
        $process.StartInfo = $startInfo
        $memorySamples = [Collections.Generic.List[object]]::new()
        $phaseStats = [ordered]@{}
        $nativePeakWorking = 0L
        $timedOut = $false
        $memoryAvailable = $true
        $stopwatch = [Diagnostics.Stopwatch]::StartNew()
        try {
            if (-not $process.Start()) { throw 'Could not start the isolated benchmark process.' }
            $outputTask = $process.StandardOutput.ReadToEndAsync()
            $errorTask = $process.StandardError.ReadToEndAsync()
            while (-not $process.HasExited) {
                if ($stopwatch.Elapsed.TotalSeconds -ge $ProcessTimeoutSeconds) {
                    $timedOut = $true
                    $process.Kill($true)
                    break
                }
                $phase = 'starting'
                try {
                    $phaseValue = Get-Content -LiteralPath (Join-Path $routeRoot 'phase.json') -Raw -ErrorAction Stop |
                        ConvertFrom-Json -AsHashtable -ErrorAction Stop
                    if ($phaseValue.phase -in @('setup', 'warmup', 'measured', 'serving', 'cleanup', 'complete')) {
                        $phase = $phaseValue.phase
                    }
                } catch { }
                try {
                    $process.Refresh()
                    $working = $process.WorkingSet64
                    $private = $process.PrivateMemorySize64
                    $nativePeakWorking = [Math]::Max($nativePeakWorking, $process.PeakWorkingSet64)
                    $sample = [pscustomobject]@{
                        elapsedMs = $stopwatch.Elapsed.TotalMilliseconds; phase = $phase
                        workingBytes = $working; privateBytes = $private
                    }
                    $memorySamples.Add($sample)
                    if (-not $phaseStats.Contains($phase)) {
                        $phaseStats[$phase] = [ordered]@{
                            samples = 0; firstWorkingBytes = $working; lastWorkingBytes = $working
                            peakWorkingBytes = $working; firstPrivateBytes = $private
                            lastPrivateBytes = $private; peakPrivateBytes = $private
                        }
                    }
                    $stats = $phaseStats[$phase]
                    $stats.samples++
                    $stats.lastWorkingBytes = $working; $stats.lastPrivateBytes = $private
                    $stats.peakWorkingBytes = [Math]::Max($stats.peakWorkingBytes, $working)
                    $stats.peakPrivateBytes = [Math]::Max($stats.peakPrivateBytes, $private)
                } catch {
                    if (-not $process.HasExited) { $memoryAvailable = $false }
                }
                [Threading.Thread]::Sleep($SampleIntervalMs)
            }
            $process.WaitForExit()
            $stdout = $outputTask.GetAwaiter().GetResult()
            $stderr = $errorTask.GetAwaiter().GetResult()
            [IO.File]::WriteAllText((Join-Path $routeRoot 'results.log'), $stdout + $stderr)
            $stopwatch.Stop()
            $routeExit = $process.ExitCode
            $childResult = $null
            $childResultFile = Join-Path $routeRoot 'result.json'
            if (Test-Path -LiteralPath $childResultFile -PathType Leaf) {
                try { $childResult = Get-Content -LiteralPath $childResultFile -Raw | ConvertFrom-Json -AsHashtable }
                catch { }
            }
            $expectedCalls = [long][Math]::Ceiling($Rows / [double]$PageSize) * $Iterations
            $valid = -not $timedOut -and $routeExit -eq 0 -and $null -ne $childResult -and
                $childResult.success -eq $true -and $childResult.metrics.iterations -eq $Iterations -and
                $childResult.metrics.rows -eq ([long]$Rows * $Iterations) -and
                $childResult.metrics.calls -eq $expectedCalls -and $childResult.checks.failures -eq 0
            $routeReport = [ordered]@{
                success = [bool]$valid; exitCode = $routeExit; processTimedOut = $timedOut
                processElapsedMs = $stopwatch.Elapsed.TotalMilliseconds
                result = $childResult
                memory = [ordered]@{
                    scope = 'whole route child process, including all client/server threads and setup/cleanup'
                    method = 'System.Diagnostics.Process.Refresh/WorkingSet64/PrivateMemorySize64'
                    available = $memoryAvailable -and $memorySamples.Count -gt 0
                    sampleCount = $memorySamples.Count; intervalMs = $SampleIntervalMs
                    sampledPhases = $phaseStats; observedLifetimePeakWorkingBytes = $nativePeakWorking
                    missingPhaseSamples = 'A phase shorter than the sampling interval may have no sample.'
                }
            }
            if ($childResult -and $childResult.fixture.sql) {
                $sqlBytes = [Text.Encoding]::UTF8.GetBytes($childResult.fixture.sql)
                $routeReport.fixtureSqlSha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($sqlBytes))
            }
            $memorySamples | Export-Csv -LiteralPath (Join-Path $routeRoot 'memory.csv') -NoTypeInformation -Encoding utf8
            $report.routes[$routeName] = $routeReport
            if (-not $valid) { $report.success = $false }
            Write-Host "MSSQL benchmark route=$routeName; success=$valid; samples=$($memorySamples.Count); exit=$routeExit"
        }
        finally {
            if ($process.Id -and -not $process.HasExited) { $process.Kill($true); $process.WaitForExit() }
            $process.Dispose()
        }
    }
    $report | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $runRoot 'benchmark.json') -Encoding utf8
    $benchmarkExit = if ($report.success) { 0 } else { 1 }
    Write-Host "MSSQL benchmark artifacts and sanitized JSON: $runRoot"
}
finally {
    Pop-Location
    Exit-HBBridgeToolchain -PreviousEnvironment $previousEnvironment
}
exit $benchmarkExit
