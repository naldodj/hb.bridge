#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string] $Config,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string] $Profile,
    [string] $HbCompileRoot,
    [string] $ZigPath,
    [switch] $Failures,
    [switch] $Concurrency,
    [switch] $Pooling,
    [switch] $Integrity,
    [ValidateSet('off', 'driver')][string] $ODBCPooling,
    [string] $OtherProfile,
    [Nullable[int]] $HTTPListenBacklog,
    [string] $FailureODBCDriver,
    [switch] $Serve
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if ([int]$Failures.IsPresent + [int]$Concurrency.IsPresent + [int]$Pooling.IsPresent + [int]$Integrity.IsPresent -gt 1) {
    throw '-Failures, -Concurrency, -Pooling and -Integrity are mutually exclusive.'
}
if ($ODBCPooling -and -not ($Pooling -or $Concurrency)) {
    throw '-ODBCPooling requires -Pooling or -Concurrency.'
}
if ($OtherProfile -and -not $Pooling) { throw '-OtherProfile requires -Pooling.' }
if ($null -ne $HTTPListenBacklog -and (-not $Concurrency -or $HTTPListenBacklog -lt 1)) {
    throw '-HTTPListenBacklog requires -Concurrency and a positive native integer.'
}
if ($Serve -and -not ($Failures -or $Concurrency -or $Integrity)) { throw '-Serve requires -Failures, -Concurrency or -Integrity.' }
if ($Failures) {
    if ([string]::IsNullOrWhiteSpace($FailureODBCDriver)) {
        Write-Host 'MSSQL prerequisite failed: FAILURE_ODBC_DRIVER_REQUIRED'
        exit 2
    }
    if ($IsWindows) {
        $failureDriver = Get-OdbcDriver -Name $FailureODBCDriver -Platform '64-bit' -ErrorAction SilentlyContinue
        if (-not $failureDriver) {
            Write-Host 'MSSQL prerequisite failed: FAILURE_ODBC_DRIVER_NOT_INSTALLED'
            exit 2
        }
    } elseif ($IsLinux) {
        $odbcInst = Get-Command odbcinst -ErrorAction SilentlyContinue
        if (-not $odbcInst) {
            Write-Host 'MSSQL prerequisite failed: ODBCINST_REQUIRED_FOR_FAILURE_FIXTURE'
            exit 2
        }
        & $odbcInst.Source -q -d -n $FailureODBCDriver *> $null
        if ($LASTEXITCODE -ne 0) {
            Write-Host 'MSSQL prerequisite failed: FAILURE_ODBC_DRIVER_NOT_INSTALLED'
            exit 2
        }
    }
}
$configPath = [IO.Path]::GetFullPath($Config)
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    Write-Host 'MSSQL prerequisite failed: CONFIG_NOT_FOUND'
    exit 2
}
. (Join-Path $PSScriptRoot 'toolchain.ps1')
$toolchain = Resolve-HBBridgeToolchain -ProjectRoot $projectRoot -HbCompileRoot $HbCompileRoot -ZigPath $ZigPath
& (Join-Path $PSScriptRoot 'prepare-odbc.ps1') -HbCompileRoot $toolchain.HbCompileRoot -ZigPath $toolchain.Zig
if (-not $?) { throw 'Managed ODBC dependency preparation failed.' }
$runRoot = Join-Path $projectRoot ('tmp/mssql-tests-' + [Guid]::NewGuid().ToString('N'))
$buildRoot = Join-Path $runRoot 'build'
New-Item -ItemType Directory -Path $buildRoot | Out-Null
$previousEnvironment = Enter-HBBridgeToolchain -Toolchain $toolchain
$testExit = 1
Push-Location -LiteralPath $projectRoot
try {
    & $toolchain.Zig build
    if ($LASTEXITCODE -ne 0) { throw 'The Zig library build failed.' }
    $targetName = if ($Failures) { 'hbbridge.mssql.failure.test' }
        elseif ($Concurrency) { 'hbbridge.mssql.concurrency.test' }
        elseif ($Pooling) { 'hbbridge.mssql.pooling.test' }
        elseif ($Integrity) { 'hbbridge.mssql.integrity.test' } else { 'hbbridgemssqltest' }
    $testProject = if ($Failures) {
        'tests/integration/harbour/hbbridge.mssql.failure.test.hbp'
    } elseif ($Concurrency) {
        'tests/integration/harbour/hbbridge.mssql.concurrency.test.hbp'
    } elseif ($Pooling) {
        'tests/integration/harbour/hbbridge.mssql.pooling.test.hbp'
    } elseif ($Integrity) {
        'tests/integration/harbour/hbbridge.mssql.integrity.test.hbp'
    } else { 'tests/integration/harbour/hbbridge.mssql.test.hbp' }
    $testTarget = Join-Path $runRoot $targetName
    $testExecutable = $testTarget + $toolchain.ExecutableExtension
    & $toolchain.Hbmk2 "-comp=$($toolchain.Compiler)" $testProject `
        "-o$testExecutable" "-workdir=$buildRoot"
    if ($LASTEXITCODE -ne 0) { throw 'The MSSQL acceptance executable build failed.' }
    Set-Location -LiteralPath $runRoot
    # The executable accepts only the private file path and explicit alias.
    # It emits fixed errors, approved server metadata and assertion results.
    $testArguments = @($configPath, $Profile)
    if ($Failures) {
        $testArguments += $FailureODBCDriver
        $testArguments += $(if ($Serve) { 'serve' } else { 'test' })
    } elseif ($Concurrency) {
        $testArguments += $(if ($Serve) { 'serve' } else { 'test' })
        if ($null -ne $HTTPListenBacklog -or $ODBCPooling) {
            $testArguments += $(if ($null -ne $HTTPListenBacklog) { $HTTPListenBacklog.ToString() } else { 'native' })
        }
        if ($ODBCPooling) { $testArguments += $ODBCPooling }
    } elseif ($Pooling) {
        $testArguments += $(if ($ODBCPooling) { $ODBCPooling } else { 'driver' })
        if ($OtherProfile) { $testArguments += $OtherProfile }
    } elseif ($Integrity) {
        $testArguments += $(if ($Serve) { 'serve' } else { 'test' })
    }
    & $testExecutable @testArguments 2>&1 | Tee-Object -FilePath (Join-Path $runRoot 'results.log')
    $testExit = $LASTEXITCODE
    Write-Host "MSSQL acceptance artifacts and sanitized log: $runRoot"
}
finally {
    Pop-Location
    Exit-HBBridgeToolchain -PreviousEnvironment $previousEnvironment
}
exit $testExit
