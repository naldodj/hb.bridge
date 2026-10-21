#Requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()] [string] $Config = 'config/examples/sqlite.json',
    [ValidateNotNullOrEmpty()] [string] $Profile,
    [ValidateRange(0, 65535)] [int] $Port,
    [ValidateRange(1, 2147483647)] [int] $MaxWorkers
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$configPath = $Config
if (-not [System.IO.Path]::IsPathRooted($configPath)) {
    $configPath = Join-Path $projectRoot $configPath
}
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    throw "Configuration file not found: $configPath"
}
$configPath = (Resolve-Path -LiteralPath $configPath).Path
if ([System.IO.Path]::GetExtension($configPath) -ieq '.ini') {
    $executableName = if ($IsWindows) { 'hbbridge.exe' } else { 'hbbridge' }
    $server = Join-Path $projectRoot "out/$executableName"
    if (-not (Test-Path -LiteralPath $server -PathType Leaf)) {
        throw 'Build the product with scripts/build-hbbridge.ps1 before running it.'
    }
    # Ask the native adapter for safe metadata; do not duplicate the INI parser.
    $infoArguments = @('--config-info', "-config=$configPath")
    if ($PSBoundParameters.ContainsKey('Port')) {
        $infoArguments += "-port=$Port"
    }
    if ($PSBoundParameters.ContainsKey('MaxWorkers')) {
        $infoArguments += "-maxworkers=$MaxWorkers"
    }
    Push-Location -LiteralPath $projectRoot
    try {
        $configOutput = & $server @infoArguments
        $configExit = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }
    if ($configExit -ne 0) {
        throw 'Could not validate the INI. Check the host error and rebuild the current product if needed.'
    }
    $settings = ($configOutput | Out-String) | ConvertFrom-Json -AsHashtable
}
else {
    $settings = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json -AsHashtable
}
if ($settings -isnot [System.Collections.IDictionary] -or
    -not $settings.ContainsKey('sqlProfiles') -or
    $settings['sqlProfiles'] -isnot [System.Collections.IDictionary] -or
    $settings['sqlProfiles'].Count -eq 0) {
    throw 'The SQL test requires SQL profiles. Use config/examples/sqlite.json or sqlite.ini, or configure MSSQL.'
}
if (-not $PSBoundParameters.ContainsKey('Profile')) {
    foreach ($profileName in $settings['sqlProfiles'].Keys) {
        $Profile = $profileName
        break
    }
}
if (-not $settings['sqlProfiles'].ContainsKey($Profile)) {
    throw "SQL profile is not configured: $Profile"
}

$launchOptions = @{ Config = $configPath }
if ($PSBoundParameters.ContainsKey('Port')) {
    $launchOptions['Port'] = $Port
}
if ($PSBoundParameters.ContainsKey('MaxWorkers')) {
    $launchOptions['MaxWorkers'] = $MaxWorkers
}
$testPort = 1512
if ($settings.ContainsKey('protheusPort')) {
    $testPort = $settings['protheusPort']
}
if ($PSBoundParameters.ContainsKey('Port')) {
    $testPort = $Port
}
$testHost = '127.0.0.1'
if ($settings.ContainsKey('protheusHost') -and $settings['protheusHost'] -ne '0.0.0.0') {
    $testHost = $settings['protheusHost']
}

Write-Host "SQL profile: $Profile"
if ($testPort -eq 0) {
    Write-Host "Protheus: run U_HBBridgeQueryTest with profile $Profile and the TCP port reported by the host."
}
else {
    Write-Host ('Protheus: U_HBBridgeQueryTest("{0}", "{1}", {2}, 30000)' -f $Profile, $testHost, $testPort)
}
if ($Profile -eq 'sqlite_demo' -and $testHost -eq '127.0.0.1' -and $testPort -eq 1512) {
    Write-Host 'WebApp: https://localhost:4321/webapp/?p=U_HBBridgeQueryTest&e=PROTHEUS'
}
Write-Host 'This launcher prepares the server; run the test in AppServer. Ctrl+Q stops hbBridge.'
& (Join-Path $projectRoot 'scripts\run-hbbridge.ps1') @launchOptions
exit $LASTEXITCODE
