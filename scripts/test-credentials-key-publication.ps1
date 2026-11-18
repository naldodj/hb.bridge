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
$runRoot = Join-Path $projectRoot ('tmp/credentials-publication-' + [guid]::NewGuid().ToString('N'))
$buildDirectory = Join-Path $runRoot 'build'
$fixtureDirectory = Join-Path $runRoot 'fixtures'
$zigPrefix = Join-Path $runRoot 'zig'
[IO.Directory]::CreateDirectory($buildDirectory) | Out-Null
[IO.Directory]::CreateDirectory($fixtureDirectory) | Out-Null
$previous = Enter-HBBridgeToolchain -Toolchain $toolchain
$previousMarker = $env:HBBRIDGE_CREDENTIAL_TEST_MARKER
$previousCleanupFailure = $env:HBBRIDGE_CREDENTIAL_TEST_FAIL_CLEANUP
$env:HBBRIDGE_CREDENTIAL_TEST_MARKER = $null
$env:HBBRIDGE_CREDENTIAL_TEST_FAIL_CLEANUP = $null
Push-Location -LiteralPath $projectRoot
try {
    & $toolchain.Zig build --prefix $zigPrefix -Doptimize=ReleaseSafe
    if ($LASTEXITCODE -ne 0) { throw 'Credential publication probe library build failed.' }
    $target = Join-Path $runRoot 'hbbridgecredentialpublicationtest'
    & $toolchain.Hbmk2 "-comp=$($toolchain.Compiler)" -hbexe -mt -gtstd -w3 -es2 `
        -cflag=-DHBBRIDGE_CREDENTIAL_TEST_PAUSE tests/probes/hbbridge.credentials.interruption.test.hb `
        src/hb/services/hbbridge.credentials.hb src/c/hbbridge.credentials.native.c src/c/hbbridge.utf8.c `
        "-L$(Join-Path $zigPrefix 'lib')" -lhbbridge_zig "-o$target" "-workdir=$buildDirectory"
    if ($LASTEXITCODE -ne 0) { throw 'Credential publication probe executable build failed.' }
    $keyPath = Join-Path $fixtureDirectory 'synthetic.key'
    $markerPath = Join-Path $fixtureDirectory 'ready.marker'
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $target + $toolchain.ExecutableExtension
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.ArgumentList.Add($keyPath)
    $info.Environment['HBBRIDGE_CREDENTIAL_TEST_MARKER'] = $markerPath
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    $started = $false
    try {
        if (-not $process.Start()) { throw 'Credential publication probe could not start.' }
        $started = $true
        $watch = [Diagnostics.Stopwatch]::StartNew()
        while (-not (Test-Path -LiteralPath $markerPath) -and -not $process.HasExited -and $watch.Elapsed.TotalSeconds -lt 30) {
            Start-Sleep -Milliseconds 50
        }
        if (-not (Test-Path -LiteralPath $markerPath)) { throw 'Credential publication probe did not reach the interruption point.' }
        if (Test-Path -LiteralPath $keyPath) { throw 'The final key was published before the interruption point.' }
        $staged = @(Get-ChildItem -LiteralPath $fixtureDirectory -File -Filter 'synthetic.key.tmp.*')
        if ($staged.Count -ne 1 -or $staged[0].Length -ne 32) { throw 'The synthetic staged key was not found or has an invalid size.' }
        if ($IsWindows) {
            $acl = Get-Acl -LiteralPath $staged[0].FullName
            $currentSid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
            $systemSid = [Security.Principal.SecurityIdentifier]::new('S-1-5-18').Value
            if (-not $acl.AreAccessRulesProtected) { throw 'The staged key inherited access rules.' }
            foreach ($rule in $acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier])) {
                if ($rule.AccessControlType -eq [Security.AccessControl.AccessControlType]::Allow -and
                    $rule.IdentityReference.Value -notin @($currentSid, $systemSid)) {
                    throw 'The staged key grants access to an unexpected identity.'
                }
            }
        } else {
            $mode = (& stat -c '%a' -- $staged[0].FullName).Trim()
            if ($LASTEXITCODE -ne 0 -or $mode -notmatch '^0?[0-7]{3}$' -or
                ([Convert]::ToInt32($mode, 8) -band 63) -ne 0) {
                throw 'The staged key has unexpected group or other permissions.'
            }
        }
        $process.Kill($true)
        $process.WaitForExit()
        if (Test-Path -LiteralPath $keyPath) { throw 'An interrupted key was published.' }
        Write-Host 'Interrupted key creation did not publish the final key; one private staged file remains for cleanup.'
    } finally {
        if ($started -and -not $process.HasExited) { $process.Kill($true); $process.WaitForExit() }
        $process.Dispose()
    }
    # The terminated test process no longer owns its synthetic staging file.
    Remove-Item -LiteralPath $staged[0].FullName
    & ($target + $toolchain.ExecutableExtension) $keyPath
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $keyPath -PathType Leaf) -or
        (Get-Item -LiteralPath $keyPath).Length -ne 32) {
        throw 'Synthetic creation after interruption did not publish a complete key.'
    }
    $recovered = [IO.File]::ReadAllBytes($keyPath)
    & ($target + $toolchain.ExecutableExtension) $keyPath 'KEY_EXISTS'
    if ($LASTEXITCODE -ne 0 -or
        [Convert]::ToHexString([IO.File]::ReadAllBytes($keyPath)) -cne [Convert]::ToHexString($recovered)) {
        throw 'A repeated synthetic creation changed the recovered key.'
    }
    Write-Host 'Recovery after interruption created one complete key and preserved it on retry.'
    $collisionPath = Join-Path $fixtureDirectory 'collision.key'
    $original = [byte[]](0..31)
    [IO.File]::WriteAllBytes($collisionPath, $original)
    $previousFailure = $env:HBBRIDGE_CREDENTIAL_TEST_FAIL_CLEANUP
    try {
        $env:HBBRIDGE_CREDENTIAL_TEST_FAIL_CLEANUP = '1'
        & ($target + $toolchain.ExecutableExtension) $collisionPath 'KEY_CLEANUP_FAILED'
        if ($LASTEXITCODE -ne 0) { throw 'Synthetic cleanup-failure test failed.' }
    } finally {
        $env:HBBRIDGE_CREDENTIAL_TEST_FAIL_CLEANUP = $previousFailure
    }
    if ([Convert]::ToHexString([IO.File]::ReadAllBytes($collisionPath)) -cne [Convert]::ToHexString($original)) {
        throw 'Cleanup failure changed the existing destination.'
    }
    if (@(Get-ChildItem -LiteralPath $fixtureDirectory -File -Filter 'collision.key.tmp.*').Count -ne 1) {
        throw 'The synthetic cleanup failure did not retain its staged file.'
    }
    Write-Host 'Cleanup failure was reported and the existing destination remained unchanged.'
    if (-not $IsWindows) {
        $publishedPath = Join-Path $fixtureDirectory 'published.key'
        try {
            $env:HBBRIDGE_CREDENTIAL_TEST_FAIL_CLEANUP = '1'
            & ($target + $toolchain.ExecutableExtension) $publishedPath 'KEY_CLEANUP_FAILED'
            if ($LASTEXITCODE -ne 0) { throw 'Synthetic post-publication cleanup-failure test failed.' }
        } finally {
            $env:HBBRIDGE_CREDENTIAL_TEST_FAIL_CLEANUP = $previousFailure
        }
        $stagedPublished = @(Get-ChildItem -LiteralPath $fixtureDirectory -File -Filter 'published.key.tmp.*')
        if (-not (Test-Path -LiteralPath $publishedPath -PathType Leaf) -or $stagedPublished.Count -ne 1 -or
            [Convert]::ToHexString([IO.File]::ReadAllBytes($publishedPath)) -cne
                [Convert]::ToHexString([IO.File]::ReadAllBytes($stagedPublished[0].FullName))) {
            throw 'A reported cleanup failure did not preserve the published key and staged copy.'
        }
        Write-Host 'Post-publication cleanup failure reported the already published key.'
        $publishedBeforeCleanup = [IO.File]::ReadAllBytes($publishedPath)
        Remove-Item -LiteralPath $stagedPublished[0].FullName
        & ($target + $toolchain.ExecutableExtension) $publishedPath 'KEY_EXISTS'
        if ($LASTEXITCODE -ne 0 -or
            [Convert]::ToHexString([IO.File]::ReadAllBytes($publishedPath)) -cne
                [Convert]::ToHexString($publishedBeforeCleanup)) {
            throw 'Synthetic post-publication recovery changed the published key.'
        }
        Write-Host 'Post-publication recovery preserved the existing key on retry.'
    }
} finally {
    Pop-Location
    $env:HBBRIDGE_CREDENTIAL_TEST_MARKER = $previousMarker
    $env:HBBRIDGE_CREDENTIAL_TEST_FAIL_CLEANUP = $previousCleanupFailure
    Exit-HBBridgeToolchain -PreviousEnvironment $previous
    Get-ChildItem -LiteralPath $fixtureDirectory -File | Remove-Item
    Remove-Item -LiteralPath $fixtureDirectory
}
