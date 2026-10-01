#Requires -Version 7.0
[CmdletBinding()]
param(
   [ValidateRange(0, 65535)] [int] $Port = 1512,
   [ValidateRange(1, 2147483647)] [int] $MaxWorkers = 64
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$server = Join-Path $projectRoot 'out\hbBridge.exe'
if (-not (Test-Path -LiteralPath $server)) {
   throw 'Compile o produto com scripts/build-hbbridge.ps1 antes de executar o exemplo.'
}

# The loader currently resolves ./addons relative to the process directory.
Push-Location -LiteralPath $projectRoot
try {
   & $server "-port=$Port" "-maxworkers=$MaxWorkers"
   $serverExit = $LASTEXITCODE
}
finally {
   Pop-Location
}
exit $serverExit
