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
$runRoot = Join-Path $projectRoot ('tmp/credentials-abi-' + [guid]::NewGuid().ToString('N'))
$buildDirectory = Join-Path $runRoot 'build'
[IO.Directory]::CreateDirectory($buildDirectory) | Out-Null
$previous = Enter-HBBridgeToolchain -Toolchain $toolchain
Push-Location -LiteralPath $projectRoot
try {
    $library = Join-Path $runRoot 'libcredentialprobe.a'
    $target = Join-Path $runRoot 'hbbridgecredentialprobe'
    $arguments = @('build-lib', 'tests/probes/hbbridge.credentials.abi.test.zig', '-O', 'ReleaseSafe', "-femit-bin=$library")
    if ($IsLinux) { $arguments += @('-fPIC', '-fcompiler-rt') }
    & $toolchain.Zig @arguments
    if ($LASTEXITCODE -ne 0) { throw 'Credential ABI probe library build failed.' }
    & $toolchain.Hbmk2 "-comp=$($toolchain.Compiler)" -hbexe -gtstd -w3 -es2 `
        tests/probes/hbbridge.credentials.abi.test.hb tests/probes/hbbridge.credentials.abi.bridge.c `
        "-L$runRoot" -lcredentialprobe "-o$target" "-workdir=$buildDirectory"
    if ($LASTEXITCODE -ne 0) { throw 'Credential ABI probe executable build failed.' }
    & ($target + $toolchain.ExecutableExtension)
    if ($LASTEXITCODE -ne 0) { throw 'Credential ABI probe execution failed.' }
    Write-Host "Credential ABI probe artifacts: $runRoot"
} finally {
    Pop-Location
    Exit-HBBridgeToolchain -PreviousEnvironment $previous
}
