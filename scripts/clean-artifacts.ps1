#Requires -Version 7.0
<#
.SYNOPSIS
Previews or removes disposable tmp content and regenerable out build caches.
.EXAMPLE
./scripts/clean-artifacts.ps1
.EXAMPLE
./scripts/clean-artifacts.ps1 -Apply -MinAgeDays 7
.EXAMPLE
./scripts/clean-artifacts.ps1 -Target out -Apply -MinAgeDays 0 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
param(
    [ValidateSet('all', 'tmp', 'out')][string] $Target = 'all',
    [ValidateRange(0, 36500)][int] $MinAgeDays = 7,
    [switch] $Apply,
    [string[]] $KeepPath = @(),
    [string] $ReportPath
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
$comparer = if ($IsWindows) { [StringComparer]::OrdinalIgnoreCase } else { [StringComparer]::Ordinal }
$separator = [IO.Path]::DirectorySeparatorChar
$roots = @((Join-Path $projectRoot 'tmp'), (Join-Path $projectRoot 'out'))
$cutoff = [DateTime]::UtcNow.AddDays(-$MinAgeDays)
$mode = if (-not $Apply) { 'Preview' } elseif ($WhatIfPreference) { 'WhatIf' } else { 'Apply' }
$items = [Collections.Generic.Dictionary[string, IO.FileSystemInfo]]::new($comparer)
$protected = [Collections.Generic.Dictionary[string, string]]::new($comparer)
$links = [Collections.Generic.List[string]]::new()
$warnings = [Collections.Generic.List[string]]::new()
$objectExtensions = @('.obj', '.o')

function Test-ContainedPath {
    param([string] $Path, [string] $Parent)

    return $Path.Equals($Parent, $comparison) -or $Path.StartsWith($Parent.TrimEnd($separator) + $separator, $comparison)
}

function Assert-SafeAncestry {
    param([string] $Path)

    $ancestor = [IO.Path]::GetFullPath($Path)
    while ($ancestor) {
        $item = Get-Item -LiteralPath $ancestor -Force -ErrorAction SilentlyContinue
        if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw 'A cleanup path or ancestor is a symbolic link/junction.'
        }
        $parent = [IO.Path]::GetDirectoryName($ancestor)
        if ($parent -eq $ancestor) { break }
        $ancestor = $parent
    }
}

function Get-RelativeArtifactPath {
    param([string] $Path)

    return [IO.Path]::GetRelativePath($projectRoot, $Path).Replace('\', '/')
}

function Add-ProtectedPath {
    param([string] $Path, [string] $Reason)

    if ($items.ContainsKey($Path) -and -not $protected.ContainsKey($Path)) {
        $protected.Add($Path, $Reason)
    }
}

function Test-ProtectedTree {
    param([string] $Path)

    foreach ($kept in $protected.Keys) {
        if ((Test-ContainedPath $Path $kept) -or (Test-ContainedPath $kept $Path)) { return $true }
    }
    foreach ($link in $links) {
        if (Test-ContainedPath $link $Path) { return $true }
    }
    return $false
}

Assert-SafeAncestry $projectRoot
foreach ($root in $roots) {
    Assert-SafeAncestry $root
    if (-not (Test-Path -LiteralPath $root)) { continue }
    $rootItem = Get-Item -LiteralPath $root -Force
    if ($rootItem -isnot [IO.DirectoryInfo]) { throw 'A cleanup root is not a directory.' }
    $pending = [Collections.Generic.Stack[IO.DirectoryInfo]]::new()
    $pending.Push($rootItem)
    while ($pending.Count) {
        $directory = $pending.Pop()
        foreach ($item in Get-ChildItem -LiteralPath $directory.FullName -Force) {
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                $links.Add($item.FullName)
                continue
            }
            $items.Add($item.FullName, $item)
            if ($item -is [IO.DirectoryInfo]) { $pending.Push($item) }
        }
    }
}
Write-Verbose "Inventoried $($items.Count) entries without following links."

# Git errors stop planning as well as deletion; tracked-file protection is mandatory.
$gitCommands = @(Get-Command git -All -CommandType Application -ErrorAction Stop)
$gitCommand = $gitCommands[0].Source
if ($IsWindows) {
    $nativeGit = $gitCommands | Where-Object Source -NotMatch '[/\\]cygwin(?:32|64)?[/\\]' | Select-Object -First 1
    if ($nativeGit) { $gitCommand = $nativeGit.Source }
}
$gitSafeRoot = $projectRoot.Replace('\', '/')
$insideWorkTree = & $gitCommand -c "safe.directory=$gitSafeRoot" -C $projectRoot rev-parse --is-inside-work-tree 2>$null
if ($LASTEXITCODE -ne 0 -or $insideWorkTree -ne 'true') {
    throw 'Cleanup must run from its own Git project; Git metadata is unavailable.'
}
$gitPrefix = & $gitCommand -c "safe.directory=$gitSafeRoot" -C $projectRoot rev-parse --show-prefix
if ($LASTEXITCODE -ne 0 -or -not [string]::IsNullOrEmpty([string]$gitPrefix)) { throw 'The script directory must belong to the Git project root.' }
$trackedOutput = & $gitCommand -c "safe.directory=$gitSafeRoot" -C $projectRoot ls-files -z --cached
if ($LASTEXITCODE -ne 0) { throw 'Cannot establish tracked-file protection.' }
foreach ($relative in (($trackedOutput -join "`n") -split "`0")) {
    if (-not $relative) { continue }
    $path = [IO.Path]::GetFullPath((Join-Path $projectRoot $relative))
    Add-ProtectedPath $path 'Git tracked file'

}
foreach ($path in $KeepPath) {
    $fullPath = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($path)) { $path } else { Join-Path $projectRoot $path }))
    if (-not @($roots | Where-Object { Test-ContainedPath $fullPath $_ }).Count) { throw '-KeepPath must stay inside tmp/out.' }
    Assert-SafeAncestry $fullPath
    if (-not (Test-Path -LiteralPath $fullPath)) { throw '-KeepPath does not exist.' }
    if ($roots -contains $fullPath) {
        foreach ($item in $items.Values) {
            if (Test-ContainedPath $item.FullName $fullPath) { Add-ProtectedPath $item.FullName 'Explicit keep path' }
        }
    } else {
        Add-ProtectedPath $fullPath 'Explicit keep path'
    }
}

if ($ReportPath) {
    $ReportPath = [IO.Path]::GetFullPath($(if ([IO.Path]::IsPathRooted($ReportPath)) { $ReportPath } else { Join-Path $projectRoot $ReportPath }))
    if (-not @($roots | Where-Object { Test-ContainedPath $ReportPath $_ }).Count -or $roots -contains $ReportPath) {
        throw '-ReportPath must name a file inside tmp/out.'
    }
    Assert-SafeAncestry $ReportPath
    if (Test-Path -LiteralPath $ReportPath) { throw '-ReportPath already exists; choose a new report file.' }
    $reportAncestor = [IO.Path]::GetDirectoryName($ReportPath)
    while (-not (Test-Path -LiteralPath $reportAncestor)) { $reportAncestor = [IO.Path]::GetDirectoryName($reportAncestor) }
    if ((Get-Item -LiteralPath $reportAncestor -Force) -isnot [IO.DirectoryInfo]) { throw '-ReportPath has a non-directory ancestor.' }
    Add-ProtectedPath $reportAncestor 'Report destination'
}

# Best-effort protection of visible process paths. Never stop a process.
try {
    $processPaths = [Collections.Generic.List[string]]::new()
    $processPathExpression = [regex]::Escape($projectRoot) + '[/\\][^"\r\n]*?(?="|$)'
    if ($IsWindows) {
        foreach ($process in Get-CimInstance Win32_Process -ErrorAction Stop) {
            if ($process.ExecutablePath) { $processPaths.Add($process.ExecutablePath) }
            if ($process.CommandLine) {
                foreach ($match in [regex]::Matches($process.CommandLine, $processPathExpression)) {
                    # First existing prefix also handles an unquoted argument followed by switches.
                    $value = $match.Value
                    while ($value -and -not (Test-Path -LiteralPath $value)) {
                        $space = $value.LastIndexOf(' ')
                        $value = if ($space -lt 0) { '' } else { $value.Substring(0, $space) }
                    }
                    if ($value) { $processPaths.Add($value) }
                }
            }
        }
    } else {
        foreach ($process in Get-Process) {
            if ($process.Path) { $processPaths.Add($process.Path) }
            $commandFile = "/proc/$($process.Id)/cmdline"
            if (Test-Path -LiteralPath $commandFile) {
                try {
                    foreach ($argument in ([IO.File]::ReadAllText($commandFile) -split "`0")) {
                        $value = if ($argument.Contains('=')) { $argument.Substring($argument.IndexOf('=') + 1) } else { $argument }
                        if ($value.StartsWith($projectRoot + $separator, $comparison)) { $processPaths.Add($value) }
                    }
                } catch { }
            }
        }
    }
    foreach ($path in $processPaths) {
        if (-not $items.ContainsKey($path)) { continue }
        $relative = Get-RelativeArtifactPath $path
        $segments = $relative.Split('/')
        if ($segments.Length -gt 2 -and $segments[0] -eq 'tmp') {
            Add-ProtectedPath (Join-Path $roots[0] $segments[1]) 'Visible running process'
        } else {
            Add-ProtectedPath $path 'Visible running process'
        }
    }
} catch { $warnings.Add('Process inventory is incomplete; use -KeepPath and run cleanup between builds/tests.') }
Write-Verbose 'Established Git, explicit keep-path and visible-process protection.'

$candidates = [Collections.Generic.List[object]]::new()
$covered = [Collections.Generic.List[string]]::new()
foreach ($item in ($items.Values | Sort-Object { $_.FullName.Length }, FullName)) {
    $relative = Get-RelativeArtifactPath $item.FullName
    $segments = $relative.Split('/')
    if ($Target -ne 'all' -and $segments[0] -ne $Target) { continue }
    if (@($covered | Where-Object { Test-ContainedPath $item.FullName $_ }).Count) { continue }
    $isDirectory = $item -is [IO.DirectoryInfo]
    $reason = ''
    if ($segments[0] -eq 'tmp' -and $segments.Length -eq 2) {
        $reason = 'Disposable temporary entry'
    } elseif ($segments[0] -eq 'out') {
        if ($isDirectory -and
            (($segments.Length -eq 2 -and $item.Name -match '^build(?:-[a-fA-F0-9]{32})?$') -or $relative -eq 'out/benchmark/build')) {
            $reason = 'Regenerable product build directory'
        } elseif (-not $isDirectory -and $segments.Length -eq 2 -and $item.Extension -in $objectExtensions) {
            $reason = 'Regenerable compiler object'
        }
    }
    if (-not $reason) { continue }
    if ($isDirectory) { $covered.Add($item.FullName) }
    $tree = @($item)
    if ($isDirectory) { $tree += @($items.Values | Where-Object { $_.FullName -ne $item.FullName -and (Test-ContainedPath $_.FullName $item.FullName) }) }
    $bytes = 0L
    foreach ($member in $tree) {
        if ($member -is [IO.FileInfo]) { $bytes += $member.Length }
    }
    $status = 'Planned'
    if (Test-ProtectedTree $item.FullName) { $status = 'Skipped'; $reason = 'Tracked file, explicit keep path, process or link' }
    elseif (@($tree | Where-Object { $_.LastWriteTimeUtc -gt $cutoff }).Count) { $status = 'Skipped'; $reason = 'Artifact or descendant is newer than the age threshold' }
    $candidates.Add([pscustomobject]@{ Path = $relative; Bytes = [long]$bytes; Reason = $reason; Status = $status; DeletedBytes = 0L })
}

# Validate every planned tree before the first deletion. Enumerate one level at
# a time; never traverse a link or use recursive deletion across a changing tree.
$validated = [Collections.Generic.Dictionary[string, object]]::new($comparer)
foreach ($candidate in $candidates) {
    if ($candidate.Status -ne 'Planned') { continue }
    $path = [IO.Path]::GetFullPath((Join-Path $projectRoot $candidate.Path))
    if (-not @($roots | Where-Object { $path -ne $_ -and (Test-ContainedPath $path $_) }).Count) { throw 'Deletion target escaped tmp/out.' }
    Assert-SafeAncestry $path
    $tree = [Collections.Generic.List[IO.FileSystemInfo]]::new()
    $pending = [Collections.Generic.Stack[string]]::new()
    $pending.Push($path)
    while ($pending.Count) {
        $entry = Get-Item -LiteralPath $pending.Pop() -Force
        if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint -or $entry.LastWriteTimeUtc -gt $cutoff) {
            $candidate.Status = 'Skipped'; $candidate.Reason = 'Tree changed during planning'; break
        }
        $tree.Add($entry)
        if ($entry -is [IO.DirectoryInfo]) {
            foreach ($child in Get-ChildItem -LiteralPath $entry.FullName -Force) { $pending.Push($child.FullName) }
        }
    }
    if ($candidate.Status -eq 'Planned') { $validated.Add($path, $tree) }
}

if ($mode -eq 'Apply') {
    foreach ($candidate in $candidates) {
        if ($candidate.Status -ne 'Planned') { continue }
        $path = [IO.Path]::GetFullPath((Join-Path $projectRoot $candidate.Path))
        if (-not $PSCmdlet.ShouldProcess($candidate.Path, 'Remove generated artifact')) {
            $candidate.Status = 'Skipped'; $candidate.Reason = 'ShouldProcess declined'; continue
        }
        try {
            foreach ($entry in ($validated[$path] | Sort-Object { $_.FullName.Length } -Descending)) {
                Assert-SafeAncestry $entry.FullName
                $current = Get-Item -LiteralPath $entry.FullName -Force
                if ($current.LastWriteTimeUtc -gt $cutoff -and $current -is [IO.FileInfo]) { throw 'File changed after planning.' }
                if ($current -is [IO.DirectoryInfo] -and @(Get-ChildItem -LiteralPath $current.FullName -Force).Count) {
                    throw 'Directory still contains unremoved or new entries.'
                }
                $entryBytes = if ($current -is [IO.FileInfo]) { $current.Length } else { 0L }
                Remove-Item -LiteralPath $current.FullName -Force -Confirm:$false
                $candidate.DeletedBytes += $entryBytes
            }
            $candidate.Status = 'Deleted'
        } catch {
            $candidate.Status = 'Failed'
            $candidate.Reason = 'Artifact is locked, changed or inaccessible; remaining entries retained'
        }
    }
}

$planned = @($candidates | Where-Object { $_.Status -in @('Planned', 'Deleted', 'Failed') })
$candidateBytes = 0L
$deletedBytes = 0L
foreach ($candidate in $candidates) {
    if ($candidate.Status -ne 'Skipped') { $candidateBytes += $candidate.Bytes }
    $deletedBytes += $candidate.DeletedBytes
}
$report = [pscustomobject]@{
    Kind = 'hbbridge.artifact-cleanup'
    SchemaVersion = 1
    Mode = $mode
    Target = $Target
    MinAgeDays = $MinAgeDays
    CandidateCount = $planned.Count
    CandidateBytes = $candidateBytes
    DeletedBytes = $deletedBytes
    FailedCount = @($candidates | Where-Object Status -eq 'Failed').Count
    Candidates = $candidates.ToArray()
    Protected = @($protected.GetEnumerator() | Sort-Object Key | ForEach-Object { [pscustomobject]@{ Path = (Get-RelativeArtifactPath $_.Key); Reason = $_.Value } })
    LinksSkipped = @($links | ForEach-Object { Get-RelativeArtifactPath $_ })
    Warnings = $warnings.ToArray()
}
if ($ReportPath -and $mode -eq 'Apply') {
    Assert-SafeAncestry $ReportPath
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($ReportPath)) | Out-Null
    $stream = [IO.File]::Open($ReportPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write)
    try {
        $writer = [IO.StreamWriter]::new($stream, [Text.UTF8Encoding]::new($false))
        try { $writer.WriteLine(($report | ConvertTo-Json -Depth 8)) } finally { $writer.Dispose() }
    } finally { $stream.Dispose() }
}
$report
