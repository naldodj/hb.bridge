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
$probeDirectory = Join-Path $projectRoot ('tmp/credentials-serialization-' + [guid]::NewGuid().ToString('N'))
$probeFile = Join-Path $probeDirectory 'fixture.bin'
[IO.Directory]::CreateDirectory($probeDirectory) | Out-Null
$previous = Enter-HBBridgeToolchain -Toolchain $toolchain
try {
    & $toolchain.Hbrun (Join-Path $projectRoot 'tests/probes/hbbridge.credentials.serialization.test.hb') $probeFile
    if ($LASTEXITCODE -ne 0) { throw "Credential serialization probe failed (exit $LASTEXITCODE)." }
} finally {
    Exit-HBBridgeToolchain -PreviousEnvironment $previous
    if (Test-Path -LiteralPath $probeFile) { Remove-Item -LiteralPath $probeFile -Force }
    if (Test-Path -LiteralPath $probeDirectory) { Remove-Item -LiteralPath $probeDirectory -Force }
}
