#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $Config,
    [Parameter(Mandatory)][string] $Profile,
    [string] $TestExecutable,
    [string] $HbCompileRoot,
    [string] $ZigPath
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$configPath = [IO.Path]::GetFullPath($Config)
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { throw 'Private INI configuration is unavailable.' }
. (Join-Path $PSScriptRoot 'toolchain.ps1')
$toolchain = Resolve-HBBridgeToolchain -ProjectRoot $projectRoot -HbCompileRoot $HbCompileRoot -ZigPath $ZigPath
& (Join-Path $PSScriptRoot 'prepare-odbc.ps1') -HbCompileRoot $toolchain.HbCompileRoot -ZigPath $toolchain.Zig
if (-not $?) { throw 'Managed ODBC dependency preparation failed.' }
$runRoot = Join-Path $projectRoot ('tmp/mssql-credential-' + [guid]::NewGuid().ToString('N'))
$buildRoot = Join-Path $runRoot 'build'
[IO.Directory]::CreateDirectory($buildRoot) | Out-Null
$previous = Enter-HBBridgeToolchain -Toolchain $toolchain
Push-Location -LiteralPath $projectRoot
try {
    & $toolchain.Zig build
    if ($LASTEXITCODE -ne 0) { throw 'The Zig library build failed.' }
    $target = Join-Path $runRoot 'hbbridgemssqlcredentialtest'
    & $toolchain.Hbmk2 "-comp=$($toolchain.Compiler)" tests/integration/harbour/hbbridge.mssql.credential.test.hbp `
        "-o$target" "-workdir=$buildRoot"
    if ($LASTEXITCODE -ne 0) { throw 'The protected MSSQL test build failed.' }
    Set-Location -LiteralPath $runRoot
    & ($target + $toolchain.ExecutableExtension) $configPath $Profile $TestExecutable
    if ($LASTEXITCODE -ne 0) { throw 'The protected MSSQL credential test failed.' }
} finally {
    Pop-Location
    Exit-HBBridgeToolchain -PreviousEnvironment $previous
}
