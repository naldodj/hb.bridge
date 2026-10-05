#Requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateRange(0, 65535)] [int] $Port,
    [ValidateRange(1, 2147483647)] [int] $MaxWorkers,
    [ValidateNotNullOrEmpty()] [string] $Config
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
& (Join-Path $projectRoot 'scripts\run-hbbridge.ps1') @PSBoundParameters
exit $LASTEXITCODE
