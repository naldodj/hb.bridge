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
& (Join-Path $PSScriptRoot 'prepare-http.ps1') -HbCompileRoot $toolchain.HbCompileRoot -ZigPath $toolchain.Zig
if (-not $?) { throw 'Managed HTTP dependency preparation failed.' }
$runRoot = Join-Path $projectRoot ('tmp/http-send-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory((Join-Path $runRoot 'build')) | Out-Null
$previous = Enter-HBBridgeToolchain -Toolchain $toolchain
Push-Location -LiteralPath $projectRoot
try {
    $target = Join-Path $runRoot 'hbbridgehttpsendtest'
    & $toolchain.Hbmk2 "-comp=$($toolchain.Compiler)" -hbexe -mt -gtstd -w3 -es2 `
        tests/probes/hbbridge.http.send.test.hb src/c/hbbridge.time.c hbhttpd.hbc `
        "-o$target" "-workdir=$(Join-Path $runRoot 'build')"
    if ($LASTEXITCODE -ne 0) { throw 'Native HTTP send probe build failed.' }
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $target + $toolchain.ExecutableExtension
    $info.WorkingDirectory = $runRoot
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    $started = $false
    try {
        if (-not $process.Start()) { throw 'Native HTTP send probe did not start.' }
        $started = $true
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        $completed = $process.WaitForExit(30000)
        if (-not $completed) { $process.Kill($true); $process.WaitForExit() }
        $log = $stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult()
        [IO.File]::WriteAllText((Join-Path $runRoot 'results.log'), $log, [Text.UTF8Encoding]::new($false))
        Write-Output $log
        if (-not $completed) { throw 'Native HTTP send probe exceeded its 30-second budget.' }
        if ($process.ExitCode -ne 0) { throw "Native HTTP send probe failed (exit $($process.ExitCode))." }
    } finally {
        if ($started -and -not $process.HasExited) { $process.Kill($true); $process.WaitForExit() }
        $process.Dispose()
    }
    Write-Host "Native HTTP send probe output: $runRoot"
} finally {
    Pop-Location
    Exit-HBBridgeToolchain -PreviousEnvironment $previous
}
