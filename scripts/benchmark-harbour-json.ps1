#Requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateRange(1, 100000)][int] $Rows = 10000,
    [ValidateRange(1, 10000)][int] $EncodesPerBatch = 50,
    [ValidateRange(2, 100)][int] $Batches = 8,
    [ValidateRange(0, 1000)][int] $Warmup = 3,
    [string] $HbCompileRoot,
    [string] $ZigPath
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $PSScriptRoot 'toolchain.ps1')
$toolchain = Resolve-HBBridgeToolchain -ProjectRoot $projectRoot -HbCompileRoot $HbCompileRoot -ZigPath $ZigPath
$runRoot = Join-Path $projectRoot ('tmp/json-benchmark-' + [guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory((Join-Path $runRoot 'build')) | Out-Null
$productSourcePath = Join-Path $projectRoot 'src/c/hbbridge.json.c'
$productSourceHash = (Get-FileHash -LiteralPath $productSourcePath -Algorithm SHA256).Hash
$optimized = [IO.File]::ReadAllText($productSourcePath)
$baseline = $optimized
# Generate the historical lookup path from this working tree, never from HEAD.
# Every other serializer change is therefore shared by the compared variants.
$replacements = [ordered]@{
    '    PHB_CODEPAGE utf8;' = ''
    'scalar = hb_jsonEncodeCP( value, &size, 0, buffer->utf8 );' = 'scalar = hb_jsonEncodeCP( value, &size, 0, hb_cdpFindExt( "UTF8" ) );'
    '    buffer.utf8 = hb_cdpFindExt( "UTF8" );' = ''
    '    hb_vmSetCDP( buffer.utf8 );' = '    hb_vmSetCDP( hb_cdpFindExt( "UTF8" ) );'
}
foreach ($replacement in $replacements.GetEnumerator()) {
    if ([regex]::Matches($baseline, [regex]::Escape($replacement.Key)).Count -ne 1) {
        throw "JSON benchmark cannot isolate the codepage cache: $($replacement.Key)"
    }
    $baseline = $baseline.Replace($replacement.Key, $replacement.Value)
}
$sources = @{ baseline = $baseline; optimized = $optimized }
foreach ($variant in $sources.Keys) {
    $source = $sources[$variant].Replace('HB_FUNC( HBBRIDGEJSONENCODE )', "HB_FUNC( HBBRIDGEJSONENCODE$($variant.ToUpperInvariant()) )").
        Replace('HB_FUNC( HBBRIDGEJSONDECODE )', "HB_FUNC( HBBRIDGEJSONDECODE$($variant.ToUpperInvariant()) )")
    [IO.File]::WriteAllText((Join-Path $runRoot "$variant.c"), $source, [Text.UTF8Encoding]::new($false))
}
$previous = Enter-HBBridgeToolchain -Toolchain $toolchain
Push-Location -LiteralPath $projectRoot
try {
    & $toolchain.Zig build
    if ($LASTEXITCODE -ne 0) { throw 'The Zig library build failed.' }
    $target = Join-Path $runRoot 'hbbridgejsonbenchmark'
    $executable = $target + $toolchain.ExecutableExtension
    & $toolchain.Hbmk2 "-comp=$($toolchain.Compiler)" -hbexe -mt -gtstd -w3 -es2 `
        tests/probes/hbbridge.json.benchmark.hb (Join-Path $runRoot 'baseline.c') `
        (Join-Path $runRoot 'optimized.c') src/c/hbbridge.time.c -Lzig-out/lib -lhbbridge_zig `
        "-o$target" "-workdir=$(Join-Path $runRoot 'build')"
    if ($LASTEXITCODE -ne 0) { throw 'JSON benchmark build failed.' }
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $executable
    $info.WorkingDirectory = $runRoot
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    foreach ($argument in @($Rows, $EncodesPerBatch, $Batches, $Warmup)) { $info.ArgumentList.Add([string] $argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    $started = $false
    try {
        if (-not $process.Start()) { throw 'JSON benchmark did not start.' }
        $started = $true
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        $completed = $process.WaitForExit(180000)
        if (-not $completed) { $process.Kill($true); $process.WaitForExit() }
        $log = $stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult()
        [IO.File]::WriteAllText((Join-Path $runRoot 'console.log'), $log, [Text.UTF8Encoding]::new($false))
        Write-Output $log
        if (-not $completed) { throw 'JSON benchmark exceeded its 180-second budget; use fewer encodes/batches.' }
        if ($process.ExitCode -ne 0) { throw "JSON benchmark failed (exit $($process.ExitCode))." }
    } finally {
        if ($started -and -not $process.HasExited) { $process.Kill($true); $process.WaitForExit() }
        $process.Dispose()
    }
    $reportPath = Join-Path $runRoot 'result.json'
    $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json -AsHashtable
    $baselineHash = (Get-FileHash -LiteralPath (Join-Path $runRoot 'baseline.json') -Algorithm SHA256).Hash
    $optimizedHash = (Get-FileHash -LiteralPath (Join-Path $runRoot 'optimized.json') -Algorithm SHA256).Hash
    if (-not $report.success -or $baselineHash -ne $optimizedHash) { throw 'JSON benchmark output differs between variants.' }
    $report.payloadSHA256 = $baselineHash
    $report.sourceSHA256 = $productSourceHash
    $report.sources = @{}
    $report.statistics = @{}
    $report.statisticsScope = 'Population spread of batch mean time per encode; individual encode latencies are not sampled.'
    $means = @{}
    foreach ($variant in @('baseline', 'optimized')) {
        $values = @($report.samples[$variant].Values | ForEach-Object { $_ / $EncodesPerBatch } | Sort-Object)
        $mean = ($values | Measure-Object -Average).Average
        $means[$variant] = $mean
        $variance = ($values | ForEach-Object { [math]::Pow($_ - $mean, 2) } | Measure-Object -Average).Average
        $deviation = [math]::Sqrt($variance)
        $middle = [int] [math]::Floor($values.Count / 2)
        $median = if ($values.Count % 2) { $values[$middle] } else { ($values[$middle - 1] + $values[$middle]) / 2 }
        $report.statistics[$variant] = @{
            meanMsPerEncode = $mean
            medianMsPerEncode = $median
            minMsPerEncode = $values[0]
            maxMsPerEncode = $values[-1]
            populationStdDevMs = $deviation
            cvPercent = if ($mean -gt 0) { 100 * $deviation / $mean } else { $null }
        }
        $report.sources[$variant] = (Get-FileHash -LiteralPath (Join-Path $runRoot "$variant.c") -Algorithm SHA256).Hash
    }
    $report.comparison = @{
        baselineMeanMsPerEncode = $means.baseline
        optimizedMeanMsPerEncode = $means.optimized
        reductionPercent = if ($means.baseline -gt 0) { 100 * (1 - $means.optimized / $means.baseline) } else { $null }
        limitation = 'Serializer-only microbenchmark; no SQL, HTTP, compression or end-to-end speedup is inferred.'
    }
    [IO.File]::WriteAllText($reportPath, ($report | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false))
    Write-Output ($report.comparison | ConvertTo-Json -Compress)
    Write-Host "JSON benchmark output: $runRoot"
} finally {
    Pop-Location
    Exit-HBBridgeToolchain -PreviousEnvironment $previous
}
