#Requires -Version 7.0
[CmdletBinding()]
param(
    [string] $HbCompileRoot,
    [string] $ZigPath
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $PSScriptRoot 'toolchain.ps1')
$toolchain = Resolve-HBBridgeToolchain -ProjectRoot $projectRoot -HbCompileRoot $HbCompileRoot -ZigPath $ZigPath
$runRoot = Join-Path $projectRoot ('tmp/sqlite-bind-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory((Join-Path $runRoot 'build')) | Out-Null
$previous = Enter-HBBridgeToolchain -Toolchain $toolchain
Push-Location -LiteralPath $projectRoot
try {
    $source = Join-Path $projectRoot 'tests/probes/hbbridge.sqlite.bind.test.hb'
    $target = Join-Path $runRoot 'hbbridgesqlitebindtest'
    $executable = $target + $toolchain.ExecutableExtension
    & $toolchain.Hbmk2 "-comp=$($toolchain.Compiler)" -hbexe -mt -gtstd -w3 -es2 `
        $source hbsqlit3.hbc "-o$target" "-workdir=$(Join-Path $runRoot 'build')" 2>&1 |
        Tee-Object -FilePath (Join-Path $runRoot 'build.log')
    if ($LASTEXITCODE -ne 0) { throw 'SQLite native binding probe build failed.' }

    $resultPath = Join-Path $runRoot 'result.json'
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $executable
    $info.WorkingDirectory = $runRoot
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.ArgumentList.Add($resultPath)
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    $started = $false
    try {
        if (-not $process.Start()) { throw 'SQLite native binding probe did not start.' }
        $started = $true
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        $completed = $process.WaitForExit(30000)
        if (-not $completed) { $process.Kill($true); $process.WaitForExit() }
        $log = $stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult()
        [IO.File]::WriteAllText((Join-Path $runRoot 'probe.log'), $log, [Text.UTF8Encoding]::new($false))
        Write-Output $log
        if (-not $completed) { throw 'SQLite native binding probe exceeded its 30-second budget.' }
        $result = $process.ExitCode
    } finally {
        if ($started -and -not $process.HasExited) { $process.Kill($true); $process.WaitForExit() }
        $process.Dispose()
    }
    if ($result -ne 0) { throw "SQLite native binding probe failed (exit $result)." }
    $report = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json -AsHashtable
    if (-not $report.success -or $report.failureCount -ne 0 -or $report.checkCount -ne $report.checks.Count) {
        throw 'SQLite native binding probe report is inconsistent or failed.'
    }
    foreach ($check in $report.checks.Values) {
        if ($check -isnot [bool] -or -not $check) { throw 'SQLite native binding probe contains an invalid check result.' }
    }
    $requiredChecks = @(
        'int64maximumHasNoDoubleIntermediate', 'int64minimumHasNoDoubleIntermediate',
        'int64maximumExactNativeTextRetrieval', 'int64minimumExactNativeTextRetrieval',
        'int64aboveBinary64ExactIntegerExactHarbourIntegerRetrieval',
        'int64belowBinary64ExactIntegerExactHarbourIntegerRetrieval',
        'nativeValMinimumRequiresCheckedAlternative', 'invalidIntegerNeverReachesNativeBinding',
        'decimalexcessDigitsNativeNumericAffinityLosesDigitsOrScale',
        'decimalfractionalScaleNativeNumericAffinityLosesDigitsOrScale'
    )
    foreach ($name in $requiredChecks) {
        if (-not $report.checks.ContainsKey($name) -or -not $report.checks[$name]) {
            throw "SQLite native binding probe is missing boundary evidence: $name."
        }
    }
    if ($report.observations.decimal.status -ne 'unsupported') {
        throw 'SQLite native binding probe must retain the unsupported fixed-decimal capability.'
    }
    $receipt = [ordered]@{
        schemaVersion = 1
        scope = 'Standalone native hbsqlit3 wrapper proof; no SQLMIX/service integration'
        result = 'result.json'
        resultSha256 = (Get-FileHash -LiteralPath $resultPath -Algorithm SHA256).Hash
        source = 'tests/probes/hbbridge.sqlite.bind.test.hb'
        sourceSha256 = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
        runner = 'scripts/test-harbour-sqlite-bind.ps1'
        runnerSha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash
        executableSha256 = (Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash
        sqliteVersion = $report.sqliteVersion
        integer64 = 'Checked canonical strings through native signed 64-bit integers; both endpoints and exact text retrieval proved'
        fixedDecimal = 'unsupported; native NUMERIC affinity loses digits or scale'
        checkCount = $report.checkCount
        failureCount = $report.failureCount
        platform = Get-HBBridgePlatform
    }
    [IO.File]::WriteAllText((Join-Path $runRoot 'receipt.json'), ($receipt | ConvertTo-Json -Depth 8) + "`n", [Text.UTF8Encoding]::new($false))
    Write-Host "SQLite native binding probe output: $runRoot"
} finally {
    Pop-Location
    Exit-HBBridgeToolchain -PreviousEnvironment $previous
}
