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
$runRoot = Join-Path $projectRoot ('tmp/memio-snapshot-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory((Join-Path $runRoot 'build')) | Out-Null
$previous = Enter-HBBridgeToolchain -Toolchain $toolchain
Push-Location -LiteralPath $projectRoot
try {
    $target = Join-Path $runRoot 'hbbridgememiosnapshottest'
    $executable = $target + $toolchain.ExecutableExtension
    & $toolchain.Hbmk2 "-comp=$($toolchain.Compiler)" -hbexe -mt -gtstd -w3 -es2 `
        tests/probes/hbbridge.memio.snapshot.test.hb hbmemio.hbc "-o$target" "-workdir=$(Join-Path $runRoot 'build')"
    if ($LASTEXITCODE -ne 0) { throw 'MEMIO snapshot probe build failed.' }
    foreach ($mode in @('snapshot', 'absent')) {
        $info = [Diagnostics.ProcessStartInfo]::new()
        $info.FileName = $executable
        $info.WorkingDirectory = $runRoot
        $info.UseShellExecute = $false
        $info.CreateNoWindow = $true
        $info.RedirectStandardOutput = $true
        $info.RedirectStandardError = $true
        $info.ArgumentList.Add($mode)
        $process = [Diagnostics.Process]::new()
        $process.StartInfo = $info
        $started = $false
        try {
            if (-not $process.Start()) { throw 'MEMIO snapshot probe did not start.' }
            $started = $true
            $stdout = $process.StandardOutput.ReadToEndAsync()
            $stderr = $process.StandardError.ReadToEndAsync()
            $completed = $process.WaitForExit(30000)
            if (-not $completed) { $process.Kill($true); $process.WaitForExit() }
            $log = $stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult()
            [IO.File]::WriteAllText((Join-Path $runRoot ($mode + '.log')), $log, [Text.UTF8Encoding]::new($false))
            Write-Output $log
            if (-not $completed) { throw 'MEMIO snapshot probe exceeded its 30-second budget.' }
            $result = $process.ExitCode
        } finally {
            if ($started -and -not $process.HasExited) { $process.Kill($true); $process.WaitForExit() }
            $process.Dispose()
        }
        if ($result -ne 0) { throw "MEMIO snapshot probe '$mode' failed (exit $result)." }
    }
    Write-Host "MEMIO snapshot probe output: $runRoot"
} finally {
    Pop-Location
    Exit-HBBridgeToolchain -PreviousEnvironment $previous
}
