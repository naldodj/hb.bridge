#Requires -Version 7.0
[CmdletBinding()]
param(
   [string] $HbCompileRoot = (Join-Path $PSScriptRoot '..\..\hb_compile')
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$hbCompileBin = Join-Path $HbCompileRoot 'out\zig\bin'
$hbmk2 = Join-Path $hbCompileBin 'hbmk2.exe'
if (-not (Test-Path -LiteralPath $hbmk2)) {
   throw "hbmk2 nao encontrado em: $hbmk2"
}
$hbmk2 = (Resolve-Path -LiteralPath $hbmk2).Path
$zig = Get-Command 'zig.exe' -ErrorAction Stop
$previousPath = $env:PATH
$env:PATH = "$hbCompileBin;$env:PATH"
$runRoot = Join-Path $projectRoot ('tmp\tests-' + [Guid]::NewGuid().ToString('N'))
$addonRoot = Join-Path $runRoot 'addons'
$buildRoot = Join-Path $runRoot 'build'
New-Item -ItemType Directory -Path $addonRoot, $buildRoot | Out-Null
New-Item -ItemType Directory -Path (Join-Path $addonRoot 'examples') | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot 'addons\examples\sample_addon.prg') -Destination (Join-Path $addonRoot 'examples\sample_addon.prg')

Push-Location -LiteralPath $projectRoot
try {
   & $zig.Source build
   if ($LASTEXITCODE -ne 0) { throw 'Falha no build da biblioteca Zig.' }

   foreach ($fixture in @('mt_fault', 'mt_isolation')) {
      $source = Join-Path $projectRoot "tests\integration\harbour\$fixture.prg"
      $target = Join-Path $addonRoot "hbbridge_$fixture"
      & $hbmk2 -gh -n2 -w3 -es2 $source "-o$target"
      if ($LASTEXITCODE -ne 0) { throw "Falha ao compilar fixture $fixture." }
   }

   $testExe = Join-Path $runRoot 'server_mt.exe'
   & $hbmk2 -comp=zig tests/integration/harbour/server_mt.hbp "-o$testExe" "-workdir=$buildRoot"
   if ($LASTEXITCODE -ne 0) { throw 'Falha no build dos testes Harbour.' }

   # Run against the isolated addon fixtures, preserving the product binary.
   Set-Location -LiteralPath $runRoot
   & $testExe 2>&1 | Tee-Object -FilePath (Join-Path $runRoot 'results.log')
   $testExit = $LASTEXITCODE
   Write-Host "Artefatos e log: $runRoot"
}
finally {
   Pop-Location
   $env:PATH = $previousPath
}
exit $testExit
