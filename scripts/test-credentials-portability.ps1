#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('Create', 'Verify')][string] $Mode,
    [Parameter(Mandatory)][string] $FixtureDirectory,
    [string] $HbCompileRoot,
    [string] $ZigPath
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$fixture = [IO.Path]::GetFullPath($FixtureDirectory)
if (-not (Test-Path -LiteralPath $fixture -PathType Container)) { throw 'Synthetic fixture directory must already exist.' }
. (Join-Path $PSScriptRoot 'toolchain.ps1')
$toolchain = Resolve-HBBridgeToolchain -ProjectRoot $projectRoot -HbCompileRoot $HbCompileRoot -ZigPath $ZigPath
$runRoot = Join-Path $projectRoot ('tmp/credentials-portability-' + [guid]::NewGuid().ToString('N'))
$buildDirectory = Join-Path $runRoot 'build'
$zigPrefix = Join-Path $runRoot 'zig'
[IO.Directory]::CreateDirectory($buildDirectory) | Out-Null
$previous = Enter-HBBridgeToolchain -Toolchain $toolchain
Push-Location -LiteralPath $projectRoot
try {
    & $toolchain.Zig build --prefix $zigPrefix -Doptimize=ReleaseSafe
    if ($LASTEXITCODE -ne 0) { throw 'Credential portability probe library build failed.' }
    $target = Join-Path $runRoot 'hbbridgecredentialportabilitytest'
    & $toolchain.Hbmk2 "-comp=$($toolchain.Compiler)" -hbexe -mt -gtstd -w3 -es2 `
        tests/probes/hbbridge.credentials.portability.test.hb src/hb/services/hbbridge.credentials.hb `
        src/c/hbbridge.credentials.native.c src/c/hbbridge.utf8.c `
        "-L$(Join-Path $zigPrefix 'lib')" -lhbbridge_zig "-o$target" "-workdir=$buildDirectory"
    if ($LASTEXITCODE -ne 0) { throw 'Credential portability probe executable build failed.' }
    & ($target + $toolchain.ExecutableExtension) $Mode.ToLowerInvariant() $fixture
    if ($LASTEXITCODE -ne 0) { throw 'Synthetic credential portability probe failed.' }
} finally {
    Pop-Location
    Exit-HBBridgeToolchain -PreviousEnvironment $previous
}
