#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $AppServerDirectory,
    [Parameter(Mandatory)][string] $IniFile,
    [Parameter(Mandatory)][ValidatePattern('^U_[A-Za-z0-9_]+$')][string] $Program,
    [string] $Environment = 'PROTHEUS',
    [string[]] $Argument = @(),
    [ValidateRange(1, 2147483647)][int] $TimeoutSeconds = 180
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$serverDirectory = [IO.Path]::GetFullPath($AppServerDirectory)
$configuration = [IO.Path]::GetFullPath($IniFile)
$executable = Join-Path $serverDirectory $(if ($IsWindows) { 'appserver.exe' } else { 'appserver' })
if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) { throw 'AppServer executable not found.' }
if (-not (Test-Path -LiteralPath $configuration -PathType Leaf)) { throw 'Explicit AppServer INI not found.' }
$comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
if (-not [string]::Equals([IO.Path]::GetDirectoryName($configuration), $serverDirectory, $comparison)) {
    throw 'The AppServer INI must be in the explicitly supplied AppServer directory. Use an isolated SDK copy for a private INI.'
}
$runRoot = Join-Path $projectRoot ('tmp/protheus-cli-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($runRoot) | Out-Null
$info = [Diagnostics.ProcessStartInfo]::new()
$info.FileName = $executable
$info.WorkingDirectory = $serverDirectory
$info.UseShellExecute = $false
$info.CreateNoWindow = $true
$info.RedirectStandardOutput = $true
$info.RedirectStandardError = $true
$launchArguments = @(('-run=' + $Program), ('-env=' + $Environment))
if (-not [string]::Equals([IO.Path]::GetFileName($configuration), 'appserver.ini', $comparison)) {
    $launchArguments = @('-ini', [IO.Path]::GetFileName($configuration)) + $launchArguments
}
foreach ($value in $launchArguments + $Argument) {
    $info.ArgumentList.Add($value)
}
$process = [Diagnostics.Process]::new()
$process.StartInfo = $info
$timedOut = $false
$started = $false
try {
    if (-not $process.Start()) { throw 'AppServer test process did not start.' }
    $started = $true
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    $clock = [Diagnostics.Stopwatch]::StartNew()
    while (-not $process.WaitForExit(1000)) {
        if ($clock.Elapsed.TotalSeconds -gt $TimeoutSeconds) {
            $timedOut = $true
            $process.Kill($true)
            $process.WaitForExit()
            break
        }
    }
    $logPath = Join-Path $runRoot 'console.log'
    [IO.File]::WriteAllText($logPath, ($stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult()).Replace("`0", ''), [Text.UTF8Encoding]::new($false))
    # No INI contents, private paths, command-line credentials or tokens in receipts.
    $result = [pscustomobject]@{
        Program = $Program
        ExitCode = $process.ExitCode
        TimedOut = $timedOut
        AppServerSHA256 = (Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash
        Log = $logPath
        Scope = 'CLI process execution only; inspect the program assertions for acceptance'
    }
    $result | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $runRoot 'result.json') -Encoding utf8
    $result
} finally {
    if ($started -and -not $process.HasExited) { $process.Kill($true); $process.WaitForExit() }
    $process.Dispose()
}
