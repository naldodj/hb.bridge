#Requires -Version 7.0
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$commands = @(Get-Command git -All -CommandType Application)
$git = $commands[0].Source
if ($IsWindows) {
    $native = $commands | Where-Object Source -NotMatch '[/\\]cygwin(?:32|64)?[/\\]' | Select-Object -First 1
    if ($native) { $git = $native.Source }
}
$paths = & $git -c "safe.directory=$($projectRoot.Replace('\', '/'))" -C $projectRoot ls-files -z --cached --others --exclude-standard
if ($LASTEXITCODE -ne 0) { throw 'Cannot enumerate project documentation.' }
$files = @(($paths -join "`n") -split "`0" | Where-Object { $_ -like '*.md' -and $_ -notmatch '^(tmp|out|\.deps|brainstorming)/' } | Sort-Object -Unique)
$failures = [Collections.Generic.List[string]]::new()
$pattern = '\[[^\]]*\]\((?:<([^>]+)>|([^\r\n)]+))\)'
foreach ($relative in $files) {
    $path = Join-Path $projectRoot $relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
    $content = [IO.File]::ReadAllText($path)
    foreach ($match in [regex]::Matches($content, $pattern)) {
        $target = if ($match.Groups[1].Success) { $match.Groups[1].Value } else { $match.Groups[2].Value -replace '\s+"[^"]*"$', '' }
        $target = $target.Split('#')[0].Trim()
        if (-not $target -or $target -match '^[A-Za-z][A-Za-z0-9+.-]*:') { continue }
        $resolved = [IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetDirectoryName($path)) $target))
        $repoRelative = [IO.Path]::GetRelativePath($projectRoot, $resolved).Replace('\', '/')
        if ($repoRelative -match '^(tmp|out)/') {
            $failures.Add("${relative}: generated artifact is not a durable documentation target: $target")
        } elseif (-not (Test-Path -LiteralPath $resolved)) {
            $failures.Add("${relative}: missing local target: $target")
        }
    }
}
if ($failures.Count) {
    $failures | ForEach-Object { Write-Host $_ }
    throw "Documentation link check failed: $($failures.Count) targets."
}
Write-Host "Documentation links passed: $($files.Count) documents; no tmp/out link dependencies."
