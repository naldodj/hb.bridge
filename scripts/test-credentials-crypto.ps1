#Requires -Version 7.0
[CmdletBinding()]
param(
    [string] $HbCompileRoot,
    [string] $ZigPath,
    [string] $CompileOnlyTarget
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $PSScriptRoot 'toolchain.ps1')
$toolchain = Resolve-HBBridgeToolchain -ProjectRoot $projectRoot -HbCompileRoot $HbCompileRoot -ZigPath $ZigPath
Push-Location -LiteralPath $projectRoot
try {
    $arguments = @('test', 'tests/probes/hbbridge.credentials.crypto.test.zig')
    if ($CompileOnlyTarget) { $arguments += @('-target', $CompileOnlyTarget, '-fno-emit-bin') }
    & $toolchain.Zig @arguments
    if ($LASTEXITCODE -ne 0) { throw "Credential cryptography probe failed (exit $LASTEXITCODE)." }
    if ($CompileOnlyTarget) { Write-Host "Credential cryptography probe compiled for $CompileOnlyTarget; no execution was performed." }
} finally {
    Pop-Location
}
