#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string] $Config,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string] $Profile,
    [string] $HbCompileRoot,
    [string] $ZigPath
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$configPath = [IO.Path]::GetFullPath($Config)
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    Write-Host 'MSSQL prerequisite failed: CONFIG_NOT_FOUND'
    exit 2
}
. (Join-Path $PSScriptRoot 'toolchain.ps1')
$toolchain = Resolve-HBBridgeToolchain -ProjectRoot $projectRoot -HbCompileRoot $HbCompileRoot -ZigPath $ZigPath
$runRoot = Join-Path $projectRoot ('tmp/mssql-tests-' + [Guid]::NewGuid().ToString('N'))
$buildRoot = Join-Path $runRoot 'build'
New-Item -ItemType Directory -Path $buildRoot | Out-Null
$previousEnvironment = Enter-HBBridgeToolchain -Toolchain $toolchain
$testExit = 1
Push-Location -LiteralPath $projectRoot
try {
    & $toolchain.Zig build
    if ($LASTEXITCODE -ne 0) { throw 'The Zig library build failed.' }
    $testTarget = Join-Path $runRoot 'hbbridgemssqltest'
    $testExecutable = $testTarget + $toolchain.ExecutableExtension
    & $toolchain.Hbmk2 "-comp=$($toolchain.Compiler)" tests/integration/harbour/hbbridgemssqltest.hbp `
        "-o$testTarget" "-workdir=$buildRoot"
    if ($LASTEXITCODE -ne 0) { throw 'The MSSQL acceptance executable build failed.' }
    Set-Location -LiteralPath $runRoot
    # The executable accepts only the private file path and explicit alias.
    # It emits fixed errors, approved server metadata and assertion results.
    & $testExecutable $configPath $Profile 2>&1 | Tee-Object -FilePath (Join-Path $runRoot 'results.log')
    $testExit = $LASTEXITCODE
    Write-Host "MSSQL acceptance artifacts and sanitized log: $runRoot"
}
finally {
    Pop-Location
    Exit-HBBridgeToolchain -PreviousEnvironment $previousEnvironment
}
exit $testExit
