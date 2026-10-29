#Requires -Version 7.0

# Read-only Git selection shared by the commit gate and isolated fixture tests.
function Get-CommitCheckGitPath {
    if ($IsWindows) {
        $candidate = Join-Path $env:ProgramFiles 'Git/cmd/git.exe'
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    return (Get-Command git -CommandType Application -ErrorAction Stop).Source
}

function Invoke-CommitCheckGit {
    param(
        [Parameter(Mandatory)][string] $ProjectRoot,
        [Parameter(Mandatory)][string[]] $Arguments,
        [string] $GitPath = (Get-CommitCheckGitPath)
    )

    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $GitPath
    $info.WorkingDirectory = $ProjectRoot
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.StandardOutputEncoding = [Text.UTF8Encoding]::new($false, $true)
    $info.StandardErrorEncoding = [Text.UTF8Encoding]::new($false)
    foreach ($argument in @('-c', ('safe.directory=' + $ProjectRoot), '-C', $ProjectRoot) + $Arguments) {
        $info.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    try {
        if (-not $process.Start()) { throw 'The Git validation process did not start.' }
        $output = $process.StandardOutput.ReadToEndAsync()
        $errors = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        $text = $output.GetAwaiter().GetResult()
        $errorText = $errors.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0) {
            throw "Git validation failed ($($process.ExitCode)): $errorText"
        }
        return $text
    } finally {
        $process.Dispose()
    }
}

function Get-CommitCheckDocumentationPair {
    param([Parameter(Mandatory)][string] $Path)

    if (-not $Path.EndsWith('.md', [StringComparison]::Ordinal) -or
        $Path.StartsWith('.hbcommit/', [StringComparison]::Ordinal) -or
        $Path.StartsWith('brainstorming/', [StringComparison]::Ordinal)) { return '' }
    if ($Path.EndsWith('.pt-BR.md', [StringComparison]::Ordinal)) {
        return $Path.Substring(0, $Path.Length - '.pt-BR.md'.Length) + '.md'
    }
    return $Path.Substring(0, $Path.Length - '.md'.Length) + '.pt-BR.md'
}

function Get-CommitCheckMissingDocumentationPair {
    param(
        [Parameter(Mandatory)][string] $ValidationRoot,
        [AllowEmptyCollection()][string[]] $Files = @()
    )

    foreach ($relativePath in $Files) {
        $pairedPath = Get-CommitCheckDocumentationPair -Path $relativePath
        if ($pairedPath -and -not (Test-Path -LiteralPath (Join-Path $ValidationRoot $pairedPath) -PathType Leaf)) {
            "${relativePath}: missing documentation pair $pairedPath"
        }
    }
}

function Get-CommitCheckSelection {
    param(
        [Parameter(Mandatory)][string] $ProjectRoot,
        [switch] $Staged,
        [switch] $All,
        [string] $GitPath = (Get-CommitCheckGitPath)
    )

    $projectPath = [IO.Path]::GetFullPath($ProjectRoot)
    $gitArguments = @{ ProjectRoot = $projectPath; GitPath = $GitPath }
    $available = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $changed = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $selected = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $deleted = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $fullReasons = [Collections.Generic.List[string]]::new()
    # One porcelain query reports index/worktree changes and untracked files.
    # Optional locks are disabled so status cannot refresh/write the index.
    # No rename collapsing: both removed and added paths must participate in
    # policy invalidation and documentation-pair validation.
    $changeText = Invoke-CommitCheckGit @gitArguments -Arguments @(
        '--no-optional-locks', 'status', '--porcelain=v1', '-z', '--untracked-files=all', '--no-renames'
    )
    foreach ($record in $changeText.Split([char]0, [StringSplitOptions]::RemoveEmptyEntries)) {
        if ($record.Length -lt 4 -or $record[2] -ne ' ') { throw 'Git returned an invalid validation status record.' }
        if ($Staged -and ($record[0] -eq ' ' -or $record[0] -eq '?')) { continue }
        [void]$changed.Add($record.Substring(3))
    }
    foreach ($path in $changed) {
        if ($path -cmatch '^(?:\.hbcommit/|config/|AGENTS(?:\.pt-BR)?\.md$|docs/standards(?:\.pt-BR)?\.md$|\.(?:gitattributes|gitignore|editorconfig)$|scripts/(?:commit-check(?:-selection)?|toolchain|bootstrap)\.ps1$)') {
            $fullReasons.Add($path)
        }
    }
    $full = [bool]$All -or $fullReasons.Count -gt 0
    if ($full -or ($Staged -and $changed.Count -gt 0)) {
        $listing = if ($Staged) { @('ls-files', '-z', '--cached') } else {
            @('ls-files', '-z', '--cached', '--others', '--exclude-standard')
        }
        $listingText = Invoke-CommitCheckGit @gitArguments -Arguments $listing
        foreach ($path in $listingText.Split([char]0, [StringSplitOptions]::RemoveEmptyEntries)) {
            if ($Staged -or (Test-Path -LiteralPath (Join-Path $projectPath $path) -PathType Leaf)) {
                [void]$available.Add($path)
            }
        }
    } elseif (-not $Staged) {
        # The usual worktree gate needs only paths reported by status and
        # surviving documentation companions, not every tracked repository file.
        foreach ($path in $changed) {
            if (Test-Path -LiteralPath (Join-Path $projectPath $path) -PathType Leaf) {
                [void]$available.Add($path)
            }
            $pairedPath = Get-CommitCheckDocumentationPair -Path $path
            if ($pairedPath -and (Test-Path -LiteralPath (Join-Path $projectPath $pairedPath) -PathType Leaf)) {
                [void]$available.Add($pairedPath)
            }
        }
    }
    foreach ($path in $changed) {
        if (-not $available.Contains($path)) { [void]$deleted.Add($path) }
    }
    if ($full) {
        foreach ($path in $available) { [void]$selected.Add($path) }
    } else {
        foreach ($path in $changed) {
            if ($available.Contains($path)) { [void]$selected.Add($path) }
            # A deleted/renamed document must still validate its surviving
            # companion, even when that companion's content did not change.
            $pairedPath = Get-CommitCheckDocumentationPair -Path $path
            if ($pairedPath -and $available.Contains($pairedPath)) { [void]$selected.Add($pairedPath) }
        }
    }
    $files = [string[]]@($selected)
    $changes = [string[]]@($changed)
    $deletions = [string[]]@($deleted)
    $reasons = [string[]]@($fullReasons)
    [Array]::Sort($files, [StringComparer]::Ordinal)
    [Array]::Sort($changes, [StringComparer]::Ordinal)
    [Array]::Sort($deletions, [StringComparer]::Ordinal)
    [Array]::Sort($reasons, [StringComparer]::Ordinal)
    return [pscustomobject]@{
        GitPath = $GitPath
        Staged = [bool]$Staged
        Full = $full
        ExplicitAll = [bool]$All
        FullReasons = $reasons
        ChangedPaths = $changes
        DeletedPaths = $deletions
        Files = $files
    }
}

function New-CommitCheckSnapshot {
    param(
        [Parameter(Mandatory)][string] $ProjectRoot,
        [Parameter(Mandatory)][string] $SnapshotRoot,
        [string] $GitPath = (Get-CommitCheckGitPath)
    )

    $snapshotPath = [IO.Path]::GetFullPath($SnapshotRoot)
    if (Test-Path -LiteralPath $snapshotPath) { throw 'The validation snapshot requires a new empty directory.' }
    [IO.Directory]::CreateDirectory($snapshotPath) | Out-Null
    $prefix = $snapshotPath.Replace('\', '/') + '/'
    # checkout-index without --index/-u only reads staged contents; it does
    # not refresh index entries or alter files in the developer's checkout.
    Invoke-CommitCheckGit -ProjectRoot $ProjectRoot -GitPath $GitPath -Arguments @(
        'checkout-index', '--all', ('--prefix=' + $prefix)
    ) | Out-Null
    return $snapshotPath
}

function Remove-CommitCheckSnapshot {
    param(
        [Parameter(Mandatory)][string] $ProjectRoot,
        [Parameter(Mandatory)][string] $SnapshotRoot
    )

    $scratchPath = [IO.Path]::GetFullPath((Join-Path $ProjectRoot 'tmp'))
    $snapshotPath = [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($SnapshotRoot))
    $comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    if (-not $snapshotPath.StartsWith($scratchPath + [IO.Path]::DirectorySeparatorChar, $comparison)) {
        throw 'Validation cleanup must stay strictly inside the project tmp directory.'
    }
    # Verify the absolute target and its ancestors before any recursive deletion.
    # Reject links so cleanup cannot affect sources outside the disposable copy.
    $ancestor = $snapshotPath
    while ($ancestor) {
        if (Test-Path -LiteralPath $ancestor) {
            $item = Get-Item -LiteralPath $ancestor -Force
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw 'Validation cleanup cannot traverse a symbolic link or junction.'
            }
            if ($item -isnot [IO.DirectoryInfo]) { throw 'Validation cleanup requires a directory target and ancestors.' }
        }
        $ancestor = [IO.Path]::GetDirectoryName($ancestor)
    }
    if (-not (Test-Path -LiteralPath $snapshotPath)) { return }
    foreach ($item in Get-ChildItem -LiteralPath $snapshotPath -Force -Recurse) {
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw 'Validation cleanup cannot remove a snapshot containing a symbolic link or junction.'
        }
    }
    Remove-Item -LiteralPath $snapshotPath -Recurse -Force
}
