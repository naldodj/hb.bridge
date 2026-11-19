#Requires -Version 7.0
[CmdletBinding()]
param(
    [string] $HbCompileRoot,
    [string] $ZigPath,
    [switch] $Interactive
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $PSScriptRoot 'toolchain.ps1')
$toolchain = Resolve-HBBridgeToolchain -ProjectRoot $projectRoot -HbCompileRoot $HbCompileRoot -ZigPath $ZigPath
$runRoot = Join-Path $projectRoot ('tmp/credential-terminal-' + [guid]::NewGuid().ToString('N'))
$buildRoot = Join-Path $runRoot 'build'
[IO.Directory]::CreateDirectory($buildRoot) | Out-Null
$target = Join-Path $runRoot 'hbbridgeterminalprobe'
$executable = $target + $toolchain.ExecutableExtension
$previous = Enter-HBBridgeToolchain -Toolchain $toolchain
Push-Location -LiteralPath $projectRoot
try {
    & $toolchain.Hbmk2 "-comp=$($toolchain.Compiler)" tests/probes/hbbridge.credential.terminal.probe.hbp `
        -w3 -es2 "-o$target" "-workdir=$buildRoot"
    if ($LASTEXITCODE -ne 0) { throw 'Credential terminal probe build failed.' }
    $output = 'synthetic-redirected-input' | & $executable 2>&1
    $probeExit = $LASTEXITCODE
    $outputText = $output | Out-String
    if ($probeExit -ne 1 -or $outputText -notmatch 'TERMINAL_PROBE_STATUS=1' -or
        $outputText -match 'Password:|synthetic-redirected-input') {
        throw 'Credential terminal probe did not reject redirected input safely.'
    }
    Write-Host 'PASS: redirected input is rejected without a password prompt.'
    if ($IsLinux) {
        & python3 (Join-Path $projectRoot 'tests/probes/hbbridge.credential.terminal.pty.py') $executable
        if ($LASTEXITCODE -ne 0) { throw 'Credential terminal PTY checks failed.' }
    }
    if ($Interactive) {
        Write-Host 'Enter the synthetic value synthetic-é-secret at the password prompt.'
        & $executable
        if ($LASTEXITCODE -ne 0) { throw 'Interactive credential terminal probe failed.' }
    }
    Write-Host "Credential terminal probe artifacts: $runRoot"
}
finally {
    Pop-Location
    Exit-HBBridgeToolchain -PreviousEnvironment $previous
}
