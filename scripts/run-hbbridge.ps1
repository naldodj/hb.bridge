#Requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()] [string] $Config,
    [ValidateRange(0, 65535)] [int] $Port,
    [ValidateRange(1, 2147483647)] [int] $MaxWorkers
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$executableName = if ($IsWindows) { 'hbbridge.exe' } else { 'hbbridge' }
$server = Join-Path $projectRoot "out/$executableName"
if (-not (Test-Path -LiteralPath $server -PathType Leaf)) {
    throw 'Compile o produto com scripts/build-hbbridge.ps1 antes de executar.'
}

# Native executable arguments require a positional argument array.
$serverArguments = @()
if ($PSBoundParameters.ContainsKey('Config')) {
    $configPath = $Config
    if (-not [System.IO.Path]::IsPathRooted($configPath)) {
        $configPath = Join-Path $projectRoot $configPath
    }
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
        throw "Arquivo de configuracao nao encontrado: $configPath"
    }
    $configPath = (Resolve-Path -LiteralPath $configPath).Path
    $serverArguments += "-config=$configPath"
}
if ($PSBoundParameters.ContainsKey('Port')) {
    $serverArguments += "-port=$Port"
}
if ($PSBoundParameters.ContainsKey('MaxWorkers')) {
    $serverArguments += "-maxworkers=$MaxWorkers"
}

# Keep addon/default data paths relative to the product workspace.
Push-Location -LiteralPath $projectRoot
try {
    & $server @serverArguments
    $serverExit = $LASTEXITCODE
}
finally {
    Pop-Location
}
exit $serverExit
