#Requires -Version 7.0
[CmdletBinding()]
param(
    [string] $HbCompileRoot,
    [string] $ZigPath,
    [string] $OutputDirectory
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'toolchain.ps1')
$toolchain = resolve-hbbridgetoolchain -ProjectRoot $projectRoot -HbCompileRoot $HbCompileRoot -ZigPath $ZigPath
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) { $OutputDirectory = Join-Path $projectRoot 'out' }
$outputRoot = [System.IO.Path]::GetFullPath($OutputDirectory)
$executable = Join-Path $outputRoot "hbbridge$($toolchain.ExecutableExtension)"
if ($IsWindows) {
    $active = Get-Process -Name hbbridge -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -eq $executable }
    if ($active) {
        throw "The output executable is running (PID $($active.Id -join ', ')). Stop it yourself or choose -OutputDirectory for an isolated build."
    }
}
New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null
$buildRoot = Join-Path $outputRoot ('build-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $buildRoot | Out-Null
$previousEnvironment = enter-hbbridgetoolchain -Toolchain $toolchain
Push-Location -LiteralPath $projectRoot
try {
    & $toolchain.Zig build
    if ($LASTEXITCODE -ne 0) { throw 'The Zig library build failed.' }
    $target = Join-Path $outputRoot 'hbbridge'
    & $toolchain.Hbmk2 "-comp=$($toolchain.Compiler)" hbbridge.hbp "-o$target" "-workdir=$buildRoot"
    if ($LASTEXITCODE -ne 0) { throw 'The hbBridge executable build failed.' }
    Write-Host "hbBridge executable: $executable"
}
finally {
    Pop-Location
    exit-hbbridgetoolchain -PreviousEnvironment $previousEnvironment
}
