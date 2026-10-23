#Requires -Version 7.0
[CmdletBinding()]
param(
    [string] $HbCompileRoot,
    [string] $ZigPath,
    [switch] $Serve,
    [ValidateRange(1, 3600)][int] $ServeSeconds = 120,
    [string] $Config,
    [string] $Profile
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if ($Config -or $Profile) {
    if (-not $Serve -or -not $Config -or -not $Profile) {
        throw '-Config and -Profile must be supplied together with -Serve.'
    }
    $Config = [IO.Path]::GetFullPath($Config)
    if (-not (Test-Path -LiteralPath $Config -PathType Leaf)) { throw 'Private SQL configuration not found.' }
}

function Get-BenchmarkFixtureSQL {
    param([string] $Path, [string] $FunctionName, [int] $Rows)
    $sourceText = [IO.File]::ReadAllText($Path)
    $bodyPattern = '(?ims)^static function ' + [regex]::Escape($FunctionName) + '\b.*?(?=^static (?:function|procedure|method) |\z)'
    $functionBody = [regex]::Match($sourceText, $bodyPattern).Value
    $digits = [regex]::Match($functionBody, '(?i)cDigits\s*:=\s*"([^"]*)"').Groups[1].Value
    $returnMatch = [regex]::Match($functionBody, '(?im)^\s*return\s*\(?\s*"')
    if (-not $functionBody -or -not $digits -or -not $returnMatch.Success) {
        throw "Cannot inspect benchmark fixture function $FunctionName."
    }
    $expression = $functionBody.Substring($returnMatch.Index)
    $expression = [regex]::Replace($expression, '(?i)^\s*return\s*', '')
    $tokenPattern = '"(?<literal>[^"]*)"|(?<digits>\bcDigits\b)|(?<rows>hb_ntos\s*\(\s*nRows\s*\)|AllTrim\s*\(\s*Str\s*\(\s*nRows\s*\)\s*\))'
    $residue = [regex]::Replace($expression, $tokenPattern, '', 'IgnoreCase')
    if ([regex]::Replace($residue, '[\s+;()]', '') -ne '') {
        throw "Unsupported benchmark fixture expression in $FunctionName."
    }
    $rowLiteral = $Rows.ToString([Globalization.CultureInfo]::InvariantCulture)
    $result = [Text.StringBuilder]::new()
    foreach ($token in [regex]::Matches($expression, $tokenPattern, 'IgnoreCase')) {
        if ($token.Groups['literal'].Success) { [void]$result.Append($token.Groups['literal'].Value) }
        elseif ($token.Groups['digits'].Success) { [void]$result.Append($digits) }
        else { [void]$result.Append($rowLiteral) }
    }
    return $result.ToString()
}

$fixtureSources = @(
    @{ Path = 'src/tlpp/tests/protheus/hbbridge.benchmark.test/hbbridge.benchmark.test.tlpp'; Function = 'BenchmarkSQL' },
    @{ Path = 'addons/examples/hbbridgebenchmarkaddon.hb'; Function = 'AddonSQL' },
    @{ Path = 'tests/integration/harbour/hbbridge.benchmark.addon.test.hb'; Function = 'BenchmarkAddonSQL' }
)
foreach ($rows in @(1, 17, 100000)) {
    $expectedSQL = $null
    foreach ($fixture in $fixtureSources) {
        $actualSQL = Get-BenchmarkFixtureSQL -Path (Join-Path $projectRoot $fixture.Path) `
            -FunctionName $fixture.Function -Rows $rows
        if ($null -eq $expectedSQL) { $expectedSQL = $actualSQL }
        elseif ($actualSQL -cne $expectedSQL) { throw 'Benchmark fixture SQL differs between TLPP, addon and test.' }
    }
}
Write-Host 'Benchmark fixture SQL source identity: TLPP/addon/test, three row counts; PASS.'

. (Join-Path $PSScriptRoot 'toolchain.ps1')
$toolchain = Resolve-HBBridgeToolchain -ProjectRoot $projectRoot -HbCompileRoot $HbCompileRoot -ZigPath $ZigPath
& (Join-Path $PSScriptRoot 'prepare-odbc.ps1') -HbCompileRoot $toolchain.HbCompileRoot -ZigPath $toolchain.Zig
if (-not $?) { throw 'Managed ODBC dependency preparation failed.' }
$runRoot = Join-Path $projectRoot ('tmp/benchmark-addon-tests-' + [Guid]::NewGuid().ToString('N'))
$addonRoot = Join-Path $runRoot 'addons'
$buildRoot = Join-Path $runRoot 'build'
New-Item -ItemType Directory -Path $addonRoot, $buildRoot | Out-Null
$previousEnvironment = Enter-HBBridgeToolchain -Toolchain $toolchain
$testExit = 1
Push-Location -LiteralPath $projectRoot
try {
    & $toolchain.Zig build
    if ($LASTEXITCODE -ne 0) { throw 'The Zig library build failed.' }

    foreach ($addon in @('hbbridgebenchmarkaddon', 'hbbridgesampleaddon')) {
        $source = Join-Path $projectRoot "addons/examples/$addon.hb"
        $target = Join-Path $addonRoot $addon
        & $toolchain.Hbmk2 -gh -n2 -w3 -es2 $source "-o$target"
        if ($LASTEXITCODE -ne 0) { throw "Could not compile addon fixture $addon." }
    }
    & $toolchain.Hbmk2 -gh -n2 -w3 -es2 `
        (Join-Path $projectRoot 'tests/integration/harbour/hbbridge.numeric.addon.hb') `
        "-o$(Join-Path $addonRoot 'hbbridge.numeric.addon.hrb')"
    if ($LASTEXITCODE -ne 0) { throw 'Could not compile numeric addon ABI fixture.' }

    $testTarget = Join-Path $runRoot 'hbbridge.benchmark.addon.test'
    $testExecutable = $testTarget + $toolchain.ExecutableExtension
    & $toolchain.Hbmk2 "-comp=$($toolchain.Compiler)" tests/integration/harbour/hbbridge.benchmark.addon.test.hbp `
        "-o$testExecutable" "-workdir=$buildRoot"
    if ($LASTEXITCODE -ne 0) { throw 'The benchmark addon test executable build failed.' }
    Set-Location -LiteralPath $runRoot
    if ($Serve) { Write-Host "Benchmark addon fixture working directory: $runRoot" }
    & $testExecutable $addonRoot $(if ($Serve) { 'serve' } else { 'test' }) $ServeSeconds $Config $Profile 2>&1 | Tee-Object -FilePath (Join-Path $runRoot 'results.log')
    $testExit = $LASTEXITCODE
    Write-Host "Benchmark addon test artifacts and log: $runRoot"
}
finally {
    Pop-Location
    Exit-HBBridgeToolchain -PreviousEnvironment $previousEnvironment
}
exit $testExit
