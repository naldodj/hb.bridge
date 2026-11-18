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
$runRoot = Join-Path $projectRoot ('tmp/credentials-permissions-' + [guid]::NewGuid().ToString('N'))
$buildDirectory = Join-Path $runRoot 'build'
$fixtureDirectory = Join-Path $runRoot 'fixtures'
$zigPrefix = Join-Path $runRoot 'zig'
[IO.Directory]::CreateDirectory($buildDirectory) | Out-Null
[IO.Directory]::CreateDirectory($fixtureDirectory) | Out-Null
$previous = Enter-HBBridgeToolchain -Toolchain $toolchain
Push-Location -LiteralPath $projectRoot
try {
    & $toolchain.Zig build --prefix $zigPrefix -Doptimize=ReleaseSafe
    if ($LASTEXITCODE -ne 0) { throw 'Credential permissions probe library build failed.' }
    $target = Join-Path $runRoot 'hbbridgecredentialpermissionstest'
    & $toolchain.Hbmk2 "-comp=$($toolchain.Compiler)" -hbexe -mt -gtstd -w3 -es2 `
        tests/probes/hbbridge.credentials.permissions.test.hb src/hb/services/hbbridge.credentials.hb `
        src/c/hbbridge.credentials.native.c src/c/hbbridge.utf8.c `
        "-L$(Join-Path $zigPrefix 'lib')" -lhbbridge_zig "-o$target" "-workdir=$buildDirectory"
    if ($LASTEXITCODE -ne 0) { throw 'Credential permissions probe executable build failed.' }
    $target += $toolchain.ExecutableExtension
    $keyPath = Join-Path $fixtureDirectory 'synthetic.key'
    & $target create $keyPath
    if ($LASTEXITCODE -ne 0) { throw 'Synthetic key creation failed.' }
    & $target accept $keyPath
    if ($LASTEXITCODE -ne 0) { throw 'The private synthetic key was rejected.' }
    if ($IsWindows) {
        & icacls.exe $keyPath /grant '*S-1-1-0:(R)' | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Could not broaden the synthetic key ACL.' }
    } else {
        & chmod 0644 -- $keyPath
        if ($LASTEXITCODE -ne 0) { throw 'Could not modify synthetic key permissions.' }
    }
    & $target reject $keyPath
    if ($LASTEXITCODE -ne 0) { throw 'The broadly accessible synthetic key was accepted.' }
    if ($IsWindows) {
        & icacls.exe $keyPath '/remove:g' '*S-1-1-0' | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Could not remove the synthetic broad access rule.' }
        & icacls.exe $keyPath /inheritance:e | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Could not enable synthetic key ACL inheritance.' }
        & $target reject $keyPath
        if ($LASTEXITCODE -ne 0) { throw 'The inherited synthetic key ACL was accepted.' }
        & icacls.exe $keyPath /inheritance:r | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Could not disable synthetic key ACL inheritance.' }
    } else {
        & chmod 0600 -- $keyPath
        if ($LASTEXITCODE -ne 0) { throw 'Could not restore synthetic key permissions.' }
    }
    & $target accept $keyPath
    if ($LASTEXITCODE -ne 0) { throw 'The restored private synthetic key was rejected.' }
} finally {
    Pop-Location
    Exit-HBBridgeToolchain -PreviousEnvironment $previous
    Get-ChildItem -LiteralPath $fixtureDirectory -File | Remove-Item
    Remove-Item -LiteralPath $fixtureDirectory
}
