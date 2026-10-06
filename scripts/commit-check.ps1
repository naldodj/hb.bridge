[CmdletBinding()]
param(
    [string] $HbCompileRoot,
    [string] $ZigPath,
    [switch] $Staged,
    [switch] $InstallHook
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $PSScriptRoot 'toolchain.ps1')
$toolchainArguments = @{ ProjectRoot = $projectRoot }
if ($HbCompileRoot) { $toolchainArguments.HbCompileRoot = $HbCompileRoot }
if ($ZigPath) { $toolchainArguments.ZigPath = $ZigPath }
$toolchain = Resolve-HBBridgeToolchain @toolchainArguments

function Invoke-ValidationGit {
    param([string[]] $Arguments)

    $result = & git -c "safe.directory=$projectRoot" -C $projectRoot @Arguments
    if ($LASTEXITCODE -ne 0) { throw "git validation command failed ($LASTEXITCODE)." }
    return $result
}

function Invoke-ValidationTool {
    param([string] $Script, [string[]] $Arguments)

    & $toolchain.Hbrun (Join-Path $projectRoot ".hbcommit/$Script") @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Script rejected the files (exit $LASTEXITCODE)." }
}

function Test-ProjectConventions {
    param([string] $ValidationRoot, [string[]] $Files)

    $failures = [Collections.Generic.List[string]]::new()
    foreach ($relativePath in $Files) {
        $filePath = Join-Path $ValidationRoot $relativePath
        if ($relativePath.EndsWith('.md') -and
            -not $relativePath.StartsWith('.hbcommit/') -and
            -not $relativePath.StartsWith('brainstorming/')) {
            $pairedPath = if ($relativePath.EndsWith('.pt-BR.md')) {
                $relativePath.Substring(0, $relativePath.Length - '.pt-BR.md'.Length) + '.md'
            } else {
                $relativePath.Substring(0, $relativePath.Length - '.md'.Length) + '.pt-BR.md'
            }
            if (-not (Test-Path -LiteralPath (Join-Path $ValidationRoot $pairedPath) -PathType Leaf)) {
                $failures.Add("${relativePath}: missing documentation pair $pairedPath")
            }
        }

        if ($relativePath.StartsWith('.hbcommit/') -or $relativePath.Contains('/third_party/')) { continue }
        if ($relativePath -notmatch '\.(prg|tlpp|c|zig|ps1)$') { continue }
        $content = [IO.File]::ReadAllText($filePath)
        # Read only declarations; ignore examples in comments and native ABI macros.
        $declarationSource = [regex]::Replace($content, '/\*[\s\S]*?\*/', '')
        $declarationSource = [regex]::Replace($declarationSource, '(?m)^\s*(?://|\*|#(?!if|else|endif|define|include)).*$', '')
        if ($relativePath -match '\.(prg|tlpp)$') {
            $classDeclarations = [regex]::Matches($declarationSource, '(?im)^\s*(?:(?:create|define)\s+)?class\s+([a-z_][a-z0-9_]*)')
            foreach ($classDeclaration in $classDeclarations) {
                if ([IO.Path]::GetFileNameWithoutExtension($relativePath) -cne $classDeclaration.Groups[1].Value.ToLowerInvariant()) {
                    $failures.Add("${relativePath}: filename must match its class name in lowercase")
                }
            }
        }
        $declarationPattern = switch -Regex ($relativePath) {
            '\.(prg|tlpp)$' {
                '(?im)^\s*(?:(?:static|public|private|protected|init|exit|user|create|define)\s+)*(?:function|procedure|method|namespace|class)\s+([a-z_][a-z0-9_.]*)'
            }
            '\.ps1$' { '(?im)^\s*function\s+([a-z_][a-z0-9_-]*)' }
            '\.zig$' { '(?m)^\s*(?:(?:pub|export|extern)\s+)*fn\s+([A-Za-z_][A-Za-z0-9_]*)' }
            '\.c$' {
                '(?m)^\s*(?:(?:static|extern)\s+)?(?:const\s+)?(?:void|char|int|double|float|HB_SIZE|HB_BOOL|PHB_ITEM)\s*\**\s+([A-Za-z_][A-Za-z0-9_]*)\s*\([^;{}]*\)\s*(?=\{)|^\s*static\s+HB_GARBAGE_FUNC\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*\)'
            }
        }
        foreach ($declaration in [regex]::Matches($declarationSource, $declarationPattern)) {
            $name = $declaration.Groups[1].Value
            if (-not $name) { $name = $declaration.Groups[2].Value }
            # Zig requires this exact build entry point; U_ is the Protheus test prefix.
            if ($relativePath -ceq 'build.zig' -and $name -ceq 'build') { continue }
            if ($name.StartsWith('U_', [StringComparison]::Ordinal)) { $name = $name.Substring(2) }
            foreach ($segment in ($name -split '[.-]')) {
                if ($segment -cnotmatch '^[A-Z][A-Za-z0-9]*$') {
                    $failures.Add("${relativePath}: own function, procedure, method, namespace and class names must use PascalCase ($name)")
                    break
                }
            }
        }
        $lineNumber = 0
        $blockComment = $false
        foreach ($line in ($content -split '\r?\n')) {
            $lineNumber++
            if ($blockComment) {
                if ($line.Contains('*/')) { $blockComment = $false }
                continue
            }
            if ($line -match '^\s*/\*') {
                $blockComment = -not $line.Contains('*/')
                continue
            }
            if ($line -match '^( +)\S' -and $Matches[1].Length % 4 -ne 0 -and
                $line -notmatch '^\s*[*/]') {
                $failures.Add("${relativePath}:${lineNumber}: indentation must use multiples of four spaces")
            }
        }
    }
    if ($failures.Count -gt 0) {
        foreach ($failure in $failures) { Write-Host $failure }
        throw 'Project naming, indentation or documentation conventions failed.'
    }
}

$validationRoot = $projectRoot
$temporaryRoot = Join-Path $projectRoot ('tmp/commit-check-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temporaryRoot -Force | Out-Null

if ($Staged) {
    # Read the index into an isolated snapshot; never change the index or checkout.
    $validationRoot = Join-Path $temporaryRoot 'snapshot'
    New-Item -ItemType Directory -Path $validationRoot -Force | Out-Null
    $snapshotPrefix = $validationRoot.Replace('\', '/') + '/'
    Invoke-ValidationGit -Arguments @('checkout-index', '--all', "--prefix=$snapshotPrefix") | Out-Null
    $fileOutput = Invoke-ValidationGit -Arguments @('ls-files', '-z', '--cached')
} else {
    $fileOutput = Invoke-ValidationGit -Arguments @('ls-files', '-z', '--cached', '--others', '--exclude-standard')
}
$files = @(($fileOutput -join "`n") -split "`0" | Where-Object {
    $_ -and (Test-Path -LiteralPath (Join-Path $validationRoot $_) -PathType Leaf)
} | Sort-Object -Unique)
$fileList = Join-Path $temporaryRoot 'files.txt'
[IO.File]::WriteAllText($fileList, ($files -join "`n") + "`n", [Text.UTF8Encoding]::new($false))

$previousEnvironment = Enter-HBBridgeToolchain -Toolchain $toolchain
Push-Location $validationRoot
try {
    Invoke-ValidationTool -Script 'check.hb' -Arguments @('--list', $fileList)
    Invoke-ValidationTool -Script 'commit.hb' -Arguments @('-c', '--list', $fileList)
    Test-ProjectConventions -ValidationRoot $validationRoot -Files $files
    $vendorMetadata = @(Get-ChildItem -LiteralPath (Join-Path $validationRoot 'src/c/third_party') -Filter '*.hbp' -File -Recurse)
    if ($vendorMetadata.Count -eq 0) { throw 'No third-party validation metadata was found.' }
    foreach ($metadata in $vendorMetadata) {
        Push-Location $metadata.DirectoryName
        try { Invoke-ValidationTool -Script '3rdpatch.hb' -Arguments @('-validate') }
        finally { Pop-Location }
    }
} finally {
    Pop-Location
    Exit-HBBridgeToolchain -PreviousEnvironment $previousEnvironment
}

if ($InstallHook) {
    $hookRelative = Invoke-ValidationGit -Arguments @('rev-parse', '--git-path', 'hooks/pre-commit')
    $hookPath = [IO.Path]::GetFullPath((Join-Path $projectRoot $hookRelative))
    $hookContent = "#!/bin/sh`n# hbBridge mandatory staged checks`nexec pwsh -NoProfile -File `"`$(git rev-parse --show-toplevel)/scripts/commit-check.ps1`" -Staged`n"
    if ((Test-Path -LiteralPath $hookPath) -and [IO.File]::ReadAllText($hookPath) -cne $hookContent) {
        throw "An existing pre-commit hook was preserved. Integrate scripts/commit-check.ps1 -Staged into $hookPath."
    }
    New-Item -ItemType Directory -Path (Split-Path $hookPath -Parent) -Force | Out-Null
    [IO.File]::WriteAllText($hookPath, $hookContent, [Text.UTF8Encoding]::new($false))
    if (-not $IsWindows) {
        [IO.File]::SetUnixFileMode($hookPath, [IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite -bor
            [IO.UnixFileMode]::UserExecute -bor [IO.UnixFileMode]::GroupRead -bor [IO.UnixFileMode]::GroupExecute -bor
            [IO.UnixFileMode]::OtherRead -bor [IO.UnixFileMode]::OtherExecute)
    }
    Write-Host "Installed pre-commit validation: $hookPath"
}

Write-Host "hbBridge commit checks passed: $($files.Count) files; check.hb, commit.hb and 3rdpatch.hb."
