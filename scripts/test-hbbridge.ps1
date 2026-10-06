#Requires -Version 7.0
[CmdletBinding()]
param(
    [string] $HbCompileRoot,
    [string] $ZigPath
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'toolchain.ps1')
$toolchain = Resolve-HBBridgeToolchain -ProjectRoot $projectRoot -HbCompileRoot $HbCompileRoot -ZigPath $ZigPath
$runRoot = Join-Path $projectRoot ('tmp/tests-' + [Guid]::NewGuid().ToString('N'))
$addonRoot = Join-Path $runRoot 'addons'
$buildRoot = Join-Path $runRoot 'build'
New-Item -ItemType Directory -Path $addonRoot, $buildRoot | Out-Null
New-Item -ItemType Directory -Path (Join-Path $addonRoot 'examples') | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot 'addons/examples/hbbridgesampleaddon.prg') `
    -Destination (Join-Path $addonRoot 'examples/hbbridgesampleaddon.prg')

$previousEnvironment = Enter-HBBridgeToolchain -Toolchain $toolchain
Push-Location -LiteralPath $projectRoot
try {
    & $toolchain.Zig build
    if ($LASTEXITCODE -ne 0) { throw 'The Zig library build failed.' }

    # Map source names by key, preserving the addon contract's runtime identities.
    $fixtures = @{
        hbbridgefaultaddon = 'hbbridge_mt_fault'
        hbbridgeisolationaddon = 'hbbridge_mt_isolation'
    }
    foreach ($fixture in $fixtures.GetEnumerator()) {
        $source = Join-Path $projectRoot "tests/integration/harbour/$($fixture.Key).prg"
        $target = Join-Path $addonRoot $fixture.Value
        & $toolchain.Hbmk2 -gh -n2 -w3 -es2 $source "-o$target"
        if ($LASTEXITCODE -ne 0) { throw "Could not compile addon fixture $($fixture.Key)." }
    }

    $testTarget = Join-Path $runRoot 'hbbridgeservertest'
    $testExecutable = $testTarget + $toolchain.ExecutableExtension
    & $toolchain.Hbmk2 "-comp=$($toolchain.Compiler)" tests/integration/harbour/hbbridgeservertest.hbp `
        "-o$testTarget" "-workdir=$buildRoot"
    if ($LASTEXITCODE -ne 0) { throw 'The Harbour test executable build failed.' }

    Set-Location -LiteralPath $runRoot
    & $testExecutable 2>&1 | Tee-Object -FilePath (Join-Path $runRoot 'results.log')
    $testExit = $LASTEXITCODE
    Write-Host "Test artifacts and log: $runRoot"
}
finally {
    Pop-Location
    Exit-HBBridgeToolchain -PreviousEnvironment $previousEnvironment
}
exit $testExit
