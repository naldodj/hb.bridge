#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $ProjectRoot,
    [Parameter(Mandatory)][string] $OutputFile
)

$ErrorActionPreference = 'Stop'
$sourceRoot = Join-Path ([IO.Path]::GetFullPath($ProjectRoot)) 'src/tlpp'
if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
    throw 'The TLPP source directory does not exist.'
}

# The AppServer directory expander can mistake dotted directory names for
# source files. Supply an explicit recursive list of regular TLPP files.
$sources = [string[]] @(Get-ChildItem -LiteralPath $sourceRoot -Filter '*.tlpp' -File -Recurse |
    Sort-Object FullName | ForEach-Object { $_.FullName })
if ($sources.Count -eq 0) {
    throw 'No TLPP sources were found.'
}
$listPath = [IO.Path]::GetFullPath($OutputFile)
$listDirectory = [IO.Path]::GetDirectoryName($listPath)
New-Item -ItemType Directory -Path $listDirectory -Force | Out-Null
# TOTVS .lst syntax is one line, separated and terminated by semicolons.
# See Application Server - Command Line, "Arquivo .Lst".
if (@($sources | Where-Object { $_.Contains(';') }).Count -gt 0) {
    throw 'TOTVS source-list paths cannot contain a semicolon.'
}
[IO.File]::WriteAllText($listPath, ($sources -join ';') + ';', [Text.UTF8Encoding]::new($false))
Write-Host "TOTVS compilation list: $($sources.Count) TLPP source files."
