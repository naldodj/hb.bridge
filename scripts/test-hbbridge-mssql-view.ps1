#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $Config,
    [Parameter(Mandatory)][string] $Profile,
    [string] $HbCompileRoot,
    [string] $ZigPath
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$configPath = [IO.Path]::GetFullPath($Config)
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf) -or [string]::IsNullOrWhiteSpace($Profile)) {
    throw 'An existing private configuration file and profile are required.'
}
. (Join-Path $PSScriptRoot 'toolchain.ps1')
$toolchain = Resolve-HBBridgeToolchain -ProjectRoot $projectRoot -HbCompileRoot $HbCompileRoot -ZigPath $ZigPath
& (Join-Path $PSScriptRoot 'prepare-odbc.ps1') -HbCompileRoot $toolchain.HbCompileRoot -ZigPath $toolchain.Zig
$runRoot = Join-Path $projectRoot ('tmp/mssql-view-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $runRoot 'build') -Force | Out-Null
$suffix = [Guid]::NewGuid().ToString('N').ToUpperInvariant()
$previous = Enter-HBBridgeToolchain -Toolchain $toolchain
Push-Location -LiteralPath $projectRoot
try {
    & $toolchain.Zig build
    if ($LASTEXITCODE -ne 0) { throw 'The native engine build failed.' }
    $target = Join-Path $runRoot 'hbbridgemssqlviewtest'
    & $toolchain.Hbmk2 "-comp=$($toolchain.Compiler)" tests/integration/harbour/hbbridge.mssql.view.test.hbp `
        "-o$target" "-workdir=$(Join-Path $runRoot 'build')"
    if ($LASTEXITCODE -ne 0) { throw 'The MSSQL view test build failed.' }
    Set-Location -LiteralPath $runRoot
    & ($target + $toolchain.ExecutableExtension) $configPath $Profile $suffix 2>&1 |
        Tee-Object -FilePath (Join-Path $runRoot 'results.log')
    $testExit = $LASTEXITCODE
    Write-Host "MSSQL view test artifacts: $runRoot"
} finally {
    Pop-Location
    Exit-HBBridgeToolchain -PreviousEnvironment $previous
}
exit $testExit
