#Requires -Version 7.0
[CmdletBinding()]
param(
    [string] $HbCompileRoot,
    [string] $ZigPath,
    [switch] $TerminalUpdate
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $PSScriptRoot 'toolchain.ps1')
$toolchain = Resolve-HBBridgeToolchain -ProjectRoot $projectRoot -HbCompileRoot $HbCompileRoot -ZigPath $ZigPath
& (Join-Path $PSScriptRoot 'prepare-odbc.ps1') -HbCompileRoot $toolchain.HbCompileRoot -ZigPath $toolchain.Zig
if (-not $?) { throw 'Managed ODBC dependency preparation failed.' }
$runRoot = Join-Path $projectRoot ('tmp/credentials-sql-' + [guid]::NewGuid().ToString('N'))
$buildRoot = Join-Path $runRoot 'build'
[IO.Directory]::CreateDirectory($buildRoot) | Out-Null
$fixtureRoot = $runRoot
$previous = Enter-HBBridgeToolchain -Toolchain $toolchain
Push-Location -LiteralPath $projectRoot
try {
    & $toolchain.Zig build
    if ($LASTEXITCODE -ne 0) { throw 'The Zig library build failed.' }
    $target = Join-Path $runRoot 'hbbridgecredentialsqltest'
    & $toolchain.Hbmk2 "-comp=$($toolchain.Compiler)" tests/probes/hbbridge.credential.sql.test.hbp `
        "-o$target" "-workdir=$buildRoot"
    if ($LASTEXITCODE -ne 0) { throw 'Protected SQL credential test build failed.' }
    if ($IsLinux) {
        # The publication fixture requires a private directory on a Linux filesystem.
        $linuxFixtureRoot = & mktemp -d /tmp/hbbridge-credentials-sql-XXXXXXXX
        if ($LASTEXITCODE -ne 0) { throw 'Could not create a private Linux fixture directory.' }
        $fixtureRoot = $linuxFixtureRoot
    }
    Set-Location -LiteralPath $fixtureRoot
    $executable = $target + $toolchain.ExecutableExtension
    & $executable
    if ($LASTEXITCODE -ne 0) { throw 'Protected SQL credential checks failed.' }
    if ($TerminalUpdate) {
        if ($IsLinux) {
            & python3 (Join-Path $projectRoot 'tests/probes/hbbridge.credential.edit.pty.py') $executable
            if ($LASTEXITCODE -ne 0) { throw 'Credential terminal update PTY checks failed.' }
        }
        else {
            $refusalRoot = Join-Path $runRoot 'terminal-update'
            [IO.Directory]::CreateDirectory($refusalRoot) | Out-Null
            Set-Location -LiteralPath $refusalRoot
            $output = & $executable '--terminal-update-fixture=publish' 2>&1
            $probeExit = $LASTEXITCODE
            if ($probeExit -ne 1 -or ($output | Out-String).Trim() -cne 'CREDENTIAL_EDIT_UNSUPPORTED' -or
                @(Get-ChildItem -LiteralPath $refusalRoot -Force).Count -ne 0) {
                throw 'Unsupported credential terminal update did not refuse before prompting or writing.'
            }
            Write-Host 'PASS: terminal update is refused on Windows without prompting or writing.'
        }
    }
} finally {
    Pop-Location
    Exit-HBBridgeToolchain -PreviousEnvironment $previous
    if ($fixtureRoot -ne $runRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
}
