#Requires -Version 7.0
[CmdletBinding()]
param([string] $Output, [string] $HbCompileRoot, [string] $ZigPath)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'toolchain.ps1')
$toolchain = Resolve-HBBridgeToolchain -ProjectRoot $projectRoot -HbCompileRoot $HbCompileRoot -ZigPath $ZigPath
if (-not $Output) { $Output = Join-Path $projectRoot 'addons/examples/hbbridgebenchmarkaddon.hrb' }
$addonOutput = [IO.Path]::GetFullPath($Output)
New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($addonOutput)) -Force | Out-Null
$previousEnvironment = Enter-HBBridgeToolchain -Toolchain $toolchain
try {
    & $toolchain.Hbmk2 -gh -n2 -w3 -es2 (Join-Path $projectRoot 'addons/examples/hbbridgebenchmarkaddon.hb') "-o$addonOutput"
    if ($LASTEXITCODE -ne 0) { throw 'The benchmark addon build failed.' }
    Write-Host "Benchmark addon: $addonOutput"
} finally {
    Exit-HBBridgeToolchain -PreviousEnvironment $previousEnvironment
}
