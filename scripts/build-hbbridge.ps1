#Requires -Version 7.0
[CmdletBinding()]
param(
   [string] $HbCompileRoot = 'C:\GitHub\hb_compile'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$outputRoot = Join-Path $projectRoot 'out'
$canonicalExe = Join-Path $outputRoot 'hbBridge.exe'
$hbCompileBin = Join-Path $HbCompileRoot 'out\zig\bin'
$hbmk2 = Join-Path $hbCompileBin 'hbmk2.exe'

if (-not (Test-Path -LiteralPath $hbmk2)) {
   throw "hbmk2 nao encontrado em: $hbmk2"
}

$active = Get-Process -Name 'hbBridge' -ErrorAction SilentlyContinue |
   Where-Object { $_.Path -eq $canonicalExe }

if ($active) {
   Write-Host "Encerrando hbBridge ativo antes da compilacao (PID $($active.Id))."
   $active | Stop-Process -Force
}

foreach ($obsoleteBuildPattern in @('hbBridge-*.exe', 'hbBridge-*.pdb')) {
   Get-ChildItem -LiteralPath $outputRoot -File -Filter $obsoleteBuildPattern -ErrorAction SilentlyContinue |
      ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force }
}

$env:PATH = "$hbCompileBin;$env:PATH"
Set-Location -LiteralPath $projectRoot

$zig = Get-Command 'zig.exe' -ErrorAction SilentlyContinue
if (-not $zig) {
   throw "zig.exe nao encontrado no PATH. Instale o Zig ou informe-o no PATH."
}

& $zig.Source build
if ($LASTEXITCODE -ne 0) {
   exit $LASTEXITCODE
}

& $hbmk2 -comp=zig hbBridge.hbp
if ($LASTEXITCODE -ne 0) {
   exit $LASTEXITCODE
}

Write-Host "Executavel canonico gerado: $canonicalExe"
