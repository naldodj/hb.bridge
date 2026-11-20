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
$runRoot = Join-Path $projectRoot ('tmp/credentials-provider-' + [guid]::NewGuid().ToString('N'))
$buildDirectory = Join-Path $runRoot 'build'
$zigPrefix = Join-Path $runRoot 'zig'
$fixtureDirectory = Join-Path $runRoot 'fixtures'
[IO.Directory]::CreateDirectory($buildDirectory) | Out-Null
[IO.Directory]::CreateDirectory($fixtureDirectory) | Out-Null

$previous = Enter-HBBridgeToolchain -Toolchain $toolchain
Push-Location -LiteralPath $projectRoot
try {
    & $toolchain.Zig build --prefix $zigPrefix -Doptimize=ReleaseSafe
    if ($LASTEXITCODE -ne 0) { throw 'Credential provider Zig library build failed.' }
    $target = Join-Path $runRoot 'hbbridgecredentialprovidertest'
    & $toolchain.Hbmk2 "-comp=$($toolchain.Compiler)" -hbexe -mt -gtstd -w3 -es2 `
        tests/probes/hbbridge.credentials.provider.test.hb src/hb/services/hbbridge.credentials.hb `
        src/c/hbbridge.credentials.native.c src/c/hbbridge.utf8.c `
        "-L$(Join-Path $zigPrefix 'lib')" -lhbbridge_zig "-o$target" "-workdir=$buildDirectory"
    if ($LASTEXITCODE -ne 0) { throw 'Credential provider probe executable build failed.' }
    & ($target + $toolchain.ExecutableExtension) $fixtureDirectory
    if ($LASTEXITCODE -ne 0) { throw "Credential provider probe failed (exit $LASTEXITCODE)." }
    if (@(Get-ChildItem -LiteralPath $fixtureDirectory -File -Filter '*.tmp.*').Count -ne 0) {
        throw 'A normal or rejected key creation retained a staged file.'
    }
    $keyPath = Join-Path $fixtureDirectory 'synthetic é.key'
    if ($IsWindows) {
        $acl = Get-Acl -LiteralPath $keyPath
        $currentSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        $systemSid = [Security.Principal.SecurityIdentifier]::new('S-1-5-18').Value
        if (-not $acl.AreAccessRulesProtected) { throw 'The synthetic key inherited access rules.' }
        $rules = $acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier])
        foreach ($rule in $rules) {
            if ($rule.AccessControlType -eq [Security.AccessControl.AccessControlType]::Allow -and
                $rule.IdentityReference.Value -notin @($currentSid, $systemSid)) {
                throw 'The synthetic key grants access to an unexpected identity.'
            }
        }
        Write-Host 'Synthetic key DACL is protected and restricted to the current identity and LocalSystem.'
    } else {
        $mode = (& stat -c '%a' -- $keyPath).Trim()
        if ($LASTEXITCODE -ne 0 -or $mode -notmatch '^0?[0-7]{3}$' -or
            ([Convert]::ToInt32($mode, 8) -band 63) -ne 0) {
            throw 'The synthetic key has unexpected group or other permissions.'
        }
        Write-Host 'Synthetic key has no group or other permissions.'
    }
    Write-Host "Credential provider probe artifacts: $runRoot"
}
finally {
    Pop-Location
    Exit-HBBridgeToolchain -PreviousEnvironment $previous
    Get-ChildItem -LiteralPath $fixtureDirectory -File | Remove-Item
    Remove-Item -LiteralPath $fixtureDirectory
}
