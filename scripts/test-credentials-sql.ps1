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
& (Join-Path $PSScriptRoot 'prepare-odbc.ps1') -HbCompileRoot $toolchain.HbCompileRoot -ZigPath $toolchain.Zig
if (-not $?) { throw 'Managed ODBC dependency preparation failed.' }
$runRoot = Join-Path $projectRoot ('tmp/credentials-sql-' + [guid]::NewGuid().ToString('N'))
$buildRoot = Join-Path $runRoot 'build'
[IO.Directory]::CreateDirectory($buildRoot) | Out-Null
$previous = Enter-HBBridgeToolchain -Toolchain $toolchain
Push-Location -LiteralPath $projectRoot
try {
    & $toolchain.Zig build
    if ($LASTEXITCODE -ne 0) { throw 'The Zig library build failed.' }
    $target = Join-Path $runRoot 'hbbridgecredentialsqltest'
    & $toolchain.Hbmk2 "-comp=$($toolchain.Compiler)" tests/probes/hbbridge.credential.sql.test.hbp `
        "-o$target" "-workdir=$buildRoot"
    if ($LASTEXITCODE -ne 0) { throw 'Protected SQL credential test build failed.' }
    Set-Location -LiteralPath $runRoot
    & ($target + $toolchain.ExecutableExtension)
    if ($LASTEXITCODE -ne 0) { throw 'Protected SQL credential checks failed.' }
} finally {
    Pop-Location
    Exit-HBBridgeToolchain -PreviousEnvironment $previous
}
