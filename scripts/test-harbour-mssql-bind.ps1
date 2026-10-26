#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $Config,
    [Parameter(Mandatory)][string] $Profile,
    [string] $HbCompileRoot,
    [string] $ZigPath
)

$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'This initial native ODBC binding proof supports Windows only.' }
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$configPath = [IO.Path]::GetFullPath($Config)
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { throw 'An explicit private configuration file is required.' }
. (Join-Path $PSScriptRoot 'toolchain.ps1')
$toolchain = Resolve-HBBridgeToolchain -ProjectRoot $projectRoot -HbCompileRoot $HbCompileRoot -ZigPath $ZigPath
& (Join-Path $PSScriptRoot 'prepare-odbc.ps1') -HbCompileRoot $toolchain.HbCompileRoot -ZigPath $toolchain.Zig
& (Join-Path $PSScriptRoot 'prepare-http.ps1') -HbCompileRoot $toolchain.HbCompileRoot -ZigPath $toolchain.Zig
$runRoot = Join-Path $projectRoot ('tmp/mssql-bind-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory((Join-Path $runRoot 'build')) | Out-Null
$previous = Enter-HBBridgeToolchain -Toolchain $toolchain
Push-Location -LiteralPath $projectRoot
try {
    & $toolchain.Zig build
    if ($LASTEXITCODE -ne 0) { throw 'The managed Zig library build failed.' }
    $target = Join-Path $runRoot 'hbbridgemssqlbindtest'
    $executable = $target + $toolchain.ExecutableExtension
    & $toolchain.Hbmk2 "-comp=$($toolchain.Compiler)" tests/probes/hbbridge.mssql.bind.test.hbp `
        "-o$target" "-workdir=$(Join-Path $runRoot 'build')" 2>&1 |
        Tee-Object -FilePath (Join-Path $runRoot 'build.log')
    if ($LASTEXITCODE -ne 0) { throw 'The native MSSQL binding probe build failed.' }
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $executable
    $info.WorkingDirectory = $runRoot
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.ArgumentList.Add($configPath)
    $info.ArgumentList.Add($Profile)
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    $started = $false
    try {
        if (-not $process.Start()) { throw 'The native binding probe did not start.' }
        $started = $true
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        $completed = $process.WaitForExit(60000)
        if (-not $completed -and -not $process.HasExited) {
            try {
                $process.Kill($true)
                $null = $process.WaitForExit(5000)
            } catch {
                # Preserve available output even if owned-process termination fails.
            }
        }
        $captureCompleted = $false
        try {
            $captureCompleted = [Threading.Tasks.Task]::WaitAll([Threading.Tasks.Task[]]@($stdout, $stderr), 5000)
        } catch {
            # A faulted stream must not discard output from the other stream.
        }
        $log = if ($stdout.IsCompletedSuccessfully) { $stdout.GetAwaiter().GetResult() } else { '[Standard output capture incomplete.]' + "`n" }
        $log += if ($stderr.IsCompletedSuccessfully) { $stderr.GetAwaiter().GetResult() } else { '[Standard error capture incomplete.]' + "`n" }
        [IO.File]::WriteAllText((Join-Path $runRoot 'console.log'), $log, [Text.UTF8Encoding]::new($false))
        if (-not $completed) { throw 'The native binding probe exceeded its 60-second budget; captured output is in console.log.' }
        if (-not $captureCompleted) { throw 'The native binding probe output capture did not finish within five seconds.' }
        $resultPath = Join-Path $runRoot 'result.json'
        if (-not (Test-Path -LiteralPath $resultPath -PathType Leaf)) { throw 'The native binding probe did not produce a result.' }
        $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json -AsHashtable
        $validationErrors = [Collections.Generic.List[string]]::new()
        if ($result -isnot [Collections.IDictionary]) {
            $validationErrors.Add('The native report must be an object.')
        } else {
            if ($result.success -isnot [bool] -or -not $result.success) {
                $validationErrors.Add('The native report must declare boolean success true.')
            }
            $checksValid = $result.checks -is [Collections.IDictionary] -and $result.checks.Count -gt 0
            if (-not $checksValid) {
                $validationErrors.Add('The native report must contain a nonempty checks object.')
            } elseif ($result.checkCount -isnot [int] -and $result.checkCount -isnot [long]) {
                $validationErrors.Add('The native check count must be an integer.')
            } elseif ($result.checkCount -ne $result.checks.Count) {
                $validationErrors.Add('The native check count must equal the number of checks.')
            }
            if (($result.failureCount -isnot [int] -and $result.failureCount -isnot [long]) -or $result.failureCount -ne 0) {
                $validationErrors.Add('The native failure count must be integer zero.')
            }
            if ($checksValid) {
                foreach ($check in $result.checks.Values) {
                    if ($check -isnot [bool] -or -not $check) {
                        $validationErrors.Add('Every native check must be boolean true.')
                        break
                    }
                }
            }
            foreach ($identity in @('driverName', 'driverVersion', 'backend', 'backendVersion')) {
                if ($result[$identity] -isnot [string] -or [string]::IsNullOrWhiteSpace($result[$identity])) {
                    $validationErrors.Add('The native report must identify the driver and backend names and versions.')
                    break
                }
            }
            if ($result.backend -isnot [string] -or $result.backend -ine 'Microsoft SQL Server') {
                $validationErrors.Add('The native backend must be Microsoft SQL Server.')
            }
        }
        $dependencies = Get-HBBridgeDependencies -ProjectRoot $projectRoot
        $receipt = [ordered]@{
            schemaVersion = 1
            success = ($process.ExitCode -eq 0 -and $validationErrors.Count -eq 0)
            exitCode = $process.ExitCode
            platform = Get-HBBridgePlatform
            compiler = $toolchain.Compiler
            compilerVersion = $dependencies.zig.version
            executableSHA256 = (Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash
            harbourRevision = $dependencies.harbour.revision
            dependenciesSHA256 = (Get-FileHash -LiteralPath (Join-Path $projectRoot 'config/dependencies.json') -Algorithm SHA256).Hash
            managedReceiptSHA256 = [ordered]@{}
            sourceSHA256 = [ordered]@{}
            resultSHA256 = (Get-FileHash -LiteralPath $resultPath -Algorithm SHA256).Hash
            validationErrors = $validationErrors.ToArray()
            result = $result
        }
        foreach ($managedReceipt in @('.deps/odbc/receipt.json', '.deps/http/receipt.json')) {
            $receipt.managedReceiptSHA256[$managedReceipt] = (Get-FileHash -LiteralPath (Join-Path $projectRoot $managedReceipt) -Algorithm SHA256).Hash
        }
        foreach ($source in @('tests/probes/hbbridge.mssql.bind.test.hb', 'tests/probes/hbbridge.mssql.bind.native.c',
            'tests/probes/hbbridge.mssql.bind.test.hbp', 'scripts/test-harbour-mssql-bind.ps1')) {
            $receipt.sourceSHA256[$source] = (Get-FileHash -LiteralPath (Join-Path $projectRoot $source) -Algorithm SHA256).Hash
        }
        $receipt | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $runRoot 'receipt.json') -Encoding utf8
        Write-Output $log
        Write-Host "MSSQL native binding output: $runRoot"
        if (-not $receipt.success) { throw 'The native MSSQL binding proof failed; inspect the sanitized result.' }
    } finally {
        try {
            if ($started -and -not $process.HasExited) {
                $process.Kill($true)
                if (-not $process.WaitForExit(5000)) { throw 'The owned native binding probe did not exit after termination.' }
            }
        } finally {
            $process.Dispose()
        }
    }
} finally {
    Pop-Location
    Exit-HBBridgeToolchain -PreviousEnvironment $previous
}
