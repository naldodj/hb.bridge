#Requires -Version 7.0
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $PSScriptRoot 'commit-check-selection.ps1')
$gitPath = Get-CommitCheckGitPath
$runRoot = Join-Path $projectRoot ('tmp/commit-check-selection-' + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($runRoot) | Out-Null
$script:selectionChecks = 0

function Write-SelectionFixtureFile {
    param([string] $Root, [string] $Path, [string] $Content)

    $filePath = Join-Path $Root $Path
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($filePath)) | Out-Null
    [IO.File]::WriteAllText($filePath, $Content, [Text.UTF8Encoding]::new($false))
}

function New-SelectionFixture {
    param([string] $Name, [switch] $Unborn)

    $root = Join-Path $runRoot ($Name + ' work tree ünicode')
    [IO.Directory]::CreateDirectory($root) | Out-Null
    Invoke-CommitCheckGit -ProjectRoot $root -GitPath $gitPath -Arguments @('init', '--quiet') | Out-Null
    Invoke-CommitCheckGit -ProjectRoot $root -GitPath $gitPath -Arguments @('config', 'user.name', 'Selection fixture') | Out-Null
    Invoke-CommitCheckGit -ProjectRoot $root -GitPath $gitPath -Arguments @('config', 'user.email', 'selection@example.invalid') | Out-Null
    Invoke-CommitCheckGit -ProjectRoot $root -GitPath $gitPath -Arguments @('config', 'core.autocrlf', 'false') | Out-Null
    Invoke-CommitCheckGit -ProjectRoot $root -GitPath $gitPath -Arguments @('config', 'core.hooksPath', (Join-Path $root 'no-hooks')) | Out-Null
    if (-not $Unborn) {
        foreach ($path in @('plain.txt', 'staged.txt', 'partial.txt', 'delete-only.txt', 'rename old.txt',
            'docs/guide.md', 'docs/guide.pt-BR.md', 'AGENTS.md', 'AGENTS.pt-BR.md',
            '.hbcommit/check.hb', 'config/dependencies.json')) {
            Write-SelectionFixtureFile -Root $root -Path $path -Content "original`n"
        }
        Write-SelectionFixtureFile -Root $root -Path '.gitignore' -Content "ignored.txt`n"
        Invoke-CommitCheckGit -ProjectRoot $root -GitPath $gitPath -Arguments @('add', '--all') | Out-Null
        Invoke-CommitCheckGit -ProjectRoot $root -GitPath $gitPath -Arguments @('-c', 'commit.gpgSign=false', 'commit', '--quiet', '-m', 'Fixture baseline') | Out-Null
    }
    return $root
}

function Assert-SelectionCondition {
    param([string] $Name, [bool] $Condition)

    if (-not $Condition) { throw "Commit selection assertion failed: $Name" }
    $script:selectionChecks++
}

function Assert-SelectionFiles {
    param([string] $Name, [object] $Selection, [AllowEmptyCollection()][string[]] $Expected = @())

    $matches = $Selection.Files.Count -eq $Expected.Count
    foreach ($path in $Expected) { $matches = $matches -and ($Selection.Files -ccontains $path) }
    Assert-SelectionCondition -Name $Name -Condition $matches
}

function Get-SelectionIndexHash {
    param([string] $Root)

    $indexPath = (Invoke-CommitCheckGit -ProjectRoot $Root -GitPath $gitPath -Arguments @('rev-parse', '--git-path', 'index')).TrimEnd([char[]]"`r`n")
    if (-not [IO.Path]::IsPathRooted($indexPath)) { $indexPath = Join-Path $Root $indexPath }
    return (Get-FileHash -LiteralPath $indexPath -Algorithm SHA256).Hash
}

try {
    $root = New-SelectionFixture -Name 'clean'
    $selection = Get-CommitCheckSelection -ProjectRoot $root -GitPath $gitPath
    Assert-SelectionFiles -Name 'clean default is empty' -Selection $selection
    Assert-SelectionCondition -Name 'clean default stays differential' -Condition (-not $selection.Full)
    Assert-SelectionFiles -Name 'clean staged is empty' -Selection (Get-CommitCheckSelection -ProjectRoot $root -GitPath $gitPath -Staged)
    $selection = Get-CommitCheckSelection -ProjectRoot $root -GitPath $gitPath -All
    Assert-SelectionCondition -Name 'explicit All checks complete checkout' -Condition ($selection.Full -and $selection.ExplicitAll -and $selection.Files.Count -eq 12)

    $root = New-SelectionFixture -Name 'modified'
    Write-SelectionFixtureFile -Root $root -Path 'plain.txt' -Content "modified`n"
    $indexHash = Get-SelectionIndexHash -Root $root
    Assert-SelectionFiles -Name 'unstaged tracked modification selected' -Selection (Get-CommitCheckSelection -ProjectRoot $root -GitPath $gitPath) -Expected @('plain.txt')
    Assert-SelectionFiles -Name 'staged ignores unstaged modification' -Selection (Get-CommitCheckSelection -ProjectRoot $root -GitPath $gitPath -Staged)
    Assert-SelectionCondition -Name 'selection does not refresh index' -Condition ((Get-SelectionIndexHash -Root $root) -eq $indexHash)

    $root = New-SelectionFixture -Name 'untracked'
    Write-SelectionFixtureFile -Root $root -Path 'new ünicode [1] file.txt' -Content "new`n"
    Write-SelectionFixtureFile -Root $root -Path 'ignored.txt' -Content "ignored`n"
    Assert-SelectionFiles -Name 'NUL-separated Unicode space bracket path preserved' -Selection (Get-CommitCheckSelection -ProjectRoot $root -GitPath $gitPath) -Expected @('new ünicode [1] file.txt')
    Assert-SelectionFiles -Name 'staged excludes untracked files' -Selection (Get-CommitCheckSelection -ProjectRoot $root -GitPath $gitPath -Staged)
    $selection = Get-CommitCheckSelection -ProjectRoot $root -GitPath $gitPath -All
    Assert-SelectionCondition -Name 'All includes nonignored untracked file' -Condition ($selection.Files -ccontains 'new ünicode [1] file.txt')
    Assert-SelectionCondition -Name 'All excludes ignored untracked file' -Condition (-not ($selection.Files -ccontains 'ignored.txt'))

    $root = New-SelectionFixture -Name 'staged-union'
    Write-SelectionFixtureFile -Root $root -Path 'staged.txt' -Content "staged`n"
    Invoke-CommitCheckGit -ProjectRoot $root -GitPath $gitPath -Arguments @('add', '--', 'staged.txt') | Out-Null
    Write-SelectionFixtureFile -Root $root -Path 'plain.txt' -Content "unstaged`n"
    Write-SelectionFixtureFile -Root $root -Path 'added.txt' -Content "added`n"
    Invoke-CommitCheckGit -ProjectRoot $root -GitPath $gitPath -Arguments @('add', '--', 'added.txt') | Out-Null
    Assert-SelectionFiles -Name 'default unions staged unstaged and additions' -Selection (Get-CommitCheckSelection -ProjectRoot $root -GitPath $gitPath) -Expected @('added.txt', 'plain.txt', 'staged.txt')
    Assert-SelectionFiles -Name 'Staged selects changed index entries only' -Selection (Get-CommitCheckSelection -ProjectRoot $root -GitPath $gitPath -Staged) -Expected @('added.txt', 'staged.txt')

    $root = New-SelectionFixture -Name 'partial'
    Write-SelectionFixtureFile -Root $root -Path 'partial.txt' -Content "accepted staged content`n"
    Invoke-CommitCheckGit -ProjectRoot $root -GitPath $gitPath -Arguments @('add', '--', 'partial.txt') | Out-Null
    Write-SelectionFixtureFile -Root $root -Path 'partial.txt' -Content "different unstaged content`n"
    Write-SelectionFixtureFile -Root $root -Path 'new.txt' -Content "untracked`n"
    $indexHash = Get-SelectionIndexHash -Root $root
    $selection = Get-CommitCheckSelection -ProjectRoot $root -GitPath $gitPath -Staged
    Assert-SelectionFiles -Name 'partially staged file selected once' -Selection $selection -Expected @('partial.txt')
    $snapshot = New-CommitCheckSnapshot -ProjectRoot $root -GitPath $gitPath -SnapshotRoot (Join-Path $runRoot 'partial snapshot')
    Assert-SelectionCondition -Name 'snapshot reads staged content' -Condition ([IO.File]::ReadAllText((Join-Path $snapshot 'partial.txt')) -ceq "accepted staged content`n")
    Assert-SelectionCondition -Name 'snapshot excludes untracked content' -Condition (-not (Test-Path -LiteralPath (Join-Path $snapshot 'new.txt')))
    Assert-SelectionCondition -Name 'snapshot preserves unstaged content' -Condition ([IO.File]::ReadAllText((Join-Path $root 'partial.txt')) -ceq "different unstaged content`n")
    Assert-SelectionCondition -Name 'snapshot preserves exact index bytes' -Condition ((Get-SelectionIndexHash -Root $root) -eq $indexHash)
    Remove-CommitCheckSnapshot -ProjectRoot $projectRoot -SnapshotRoot $snapshot
    Assert-SelectionCondition -Name 'completed snapshot is removed immediately' -Condition (-not (Test-Path -LiteralPath $snapshot))
    $selection = Get-CommitCheckSelection -ProjectRoot $root -GitPath $gitPath -Staged -All
    Assert-SelectionCondition -Name 'Staged All checks full index without untracked' -Condition ($selection.Full -and $selection.Files.Count -eq 12 -and -not ($selection.Files -ccontains 'new.txt'))

    $root = New-SelectionFixture -Name 'rename'
    Invoke-CommitCheckGit -ProjectRoot $root -GitPath $gitPath -Arguments @('mv', '--', 'rename old.txt', 'renamed ünicode file.txt') | Out-Null
    $selection = Get-CommitCheckSelection -ProjectRoot $root -GitPath $gitPath -Staged
    Assert-SelectionFiles -Name 'staged rename validates new path' -Selection $selection -Expected @('renamed ünicode file.txt')
    Assert-SelectionCondition -Name 'rename retains removed name for policy decisions' -Condition ($selection.DeletedPaths -ccontains 'rename old.txt')
    Assert-SelectionCondition -Name 'rename retains both changed paths' -Condition ($selection.ChangedPaths.Count -eq 2)

    $root = New-SelectionFixture -Name 'unstaged-rename'
    Move-Item -LiteralPath (Join-Path $root 'rename old.txt') -Destination (Join-Path $root 'renamed worktree.txt')
    $selection = Get-CommitCheckSelection -ProjectRoot $root -GitPath $gitPath
    Assert-SelectionFiles -Name 'unstaged rename validates untracked destination' -Selection $selection -Expected @('renamed worktree.txt')
    Assert-SelectionCondition -Name 'unstaged rename identifies deleted source' -Condition ($selection.DeletedPaths -ccontains 'rename old.txt')

    $root = New-SelectionFixture -Name 'deleted-only'
    Remove-Item -LiteralPath (Join-Path $root 'delete-only.txt')
    $selection = Get-CommitCheckSelection -ProjectRoot $root -GitPath $gitPath
    Assert-SelectionFiles -Name 'deleted-only selection has no nonexistent files' -Selection $selection
    Assert-SelectionCondition -Name 'deleted-only is recorded' -Condition ($selection.DeletedPaths -ccontains 'delete-only.txt')
    Invoke-CommitCheckGit -ProjectRoot $root -GitPath $gitPath -Arguments @('add', '--update') | Out-Null
    Assert-SelectionFiles -Name 'staged deletion has no nonexistent files' -Selection (Get-CommitCheckSelection -ProjectRoot $root -GitPath $gitPath -Staged)

    $root = New-SelectionFixture -Name 'deleted-pair'
    Remove-Item -LiteralPath (Join-Path $root 'docs/guide.pt-BR.md')
    $selection = Get-CommitCheckSelection -ProjectRoot $root -GitPath $gitPath
    Assert-SelectionFiles -Name 'deleted document selects unchanged surviving pair' -Selection $selection -Expected @('docs/guide.md')
    $missingPairs = @(Get-CommitCheckMissingDocumentationPair -ValidationRoot $root -Files $selection.Files)
    Assert-SelectionCondition -Name 'deleted companion is a real conventions failure' -Condition ($missingPairs.Count -eq 1 -and $missingPairs[0] -ceq 'docs/guide.md: missing documentation pair docs/guide.pt-BR.md')
    Invoke-CommitCheckGit -ProjectRoot $root -GitPath $gitPath -Arguments @('add', '--update') | Out-Null
    $selection = Get-CommitCheckSelection -ProjectRoot $root -GitPath $gitPath -Staged
    $snapshot = New-CommitCheckSnapshot -ProjectRoot $root -GitPath $gitPath -SnapshotRoot (Join-Path $runRoot 'deleted pair snapshot')
    Assert-SelectionFiles -Name 'staged deleted companion selects survivor' -Selection $selection -Expected @('docs/guide.md')
    Assert-SelectionCondition -Name 'staged snapshot detects missing companion' -Condition (@(Get-CommitCheckMissingDocumentationPair -ValidationRoot $snapshot -Files $selection.Files).Count -eq 1)
    Remove-CommitCheckSnapshot -ProjectRoot $projectRoot -SnapshotRoot $snapshot
    Remove-Item -LiteralPath (Join-Path $root 'docs/guide.md')
    Assert-SelectionFiles -Name 'deleting both paired documents needs no file content checks' -Selection (Get-CommitCheckSelection -ProjectRoot $root -GitPath $gitPath)

    $root = New-SelectionFixture -Name 'changed-pair'
    Write-SelectionFixtureFile -Root $root -Path 'docs/guide.md' -Content "changed guide`n"
    Assert-SelectionFiles -Name 'changed document validates its surviving pair too' -Selection (Get-CommitCheckSelection -ProjectRoot $root -GitPath $gitPath) -Expected @('docs/guide.md', 'docs/guide.pt-BR.md')
    Assert-SelectionCondition -Name 'complete pair has no conventions failures' -Condition (@(Get-CommitCheckMissingDocumentationPair -ValidationRoot $root -Files @('docs/guide.md', 'docs/guide.pt-BR.md')).Count -eq 0)

    $root = New-SelectionFixture -Name 'policy'
    Write-SelectionFixtureFile -Root $root -Path '.hbcommit/check.hb' -Content "changed validator`n"
    Invoke-CommitCheckGit -ProjectRoot $root -GitPath $gitPath -Arguments @('add', '--', '.hbcommit/check.hb') | Out-Null
    Write-SelectionFixtureFile -Root $root -Path 'config/dependencies.json' -Content "changed config`n"
    $selection = Get-CommitCheckSelection -ProjectRoot $root -GitPath $gitPath
    Assert-SelectionCondition -Name 'validator and config changes force full check' -Condition ($selection.Full -and -not $selection.ExplicitAll -and $selection.Files.Count -eq 12)
    Assert-SelectionCondition -Name 'full check explains both changed policy paths' -Condition ($selection.FullReasons.Count -eq 2 -and $selection.FullReasons -ccontains '.hbcommit/check.hb' -and $selection.FullReasons -ccontains 'config/dependencies.json')
    $selection = Get-CommitCheckSelection -ProjectRoot $root -GitPath $gitPath -Staged
    Assert-SelectionCondition -Name 'staged full trigger ignores unstaged config' -Condition ($selection.Full -and $selection.FullReasons.Count -eq 1 -and $selection.FullReasons[0] -ceq '.hbcommit/check.hb')

    $root = New-SelectionFixture -Name 'unstaged-policy'
    Write-SelectionFixtureFile -Root $root -Path 'AGENTS.md' -Content "changed conventions`n"
    Write-SelectionFixtureFile -Root $root -Path 'staged.txt' -Content "changed staged`n"
    Invoke-CommitCheckGit -ProjectRoot $root -GitPath $gitPath -Arguments @('add', '--', 'staged.txt') | Out-Null
    $selection = Get-CommitCheckSelection -ProjectRoot $root -GitPath $gitPath -Staged
    Assert-SelectionFiles -Name 'unstaged policy cannot expand staged selection' -Selection $selection -Expected @('staged.txt')
    Assert-SelectionCondition -Name 'staged ignores unstaged policy trigger' -Condition (-not $selection.Full)
    Assert-SelectionCondition -Name 'default honors unstaged policy trigger' -Condition (Get-CommitCheckSelection -ProjectRoot $root -GitPath $gitPath).Full

    $root = New-SelectionFixture -Name 'unborn' -Unborn
    Write-SelectionFixtureFile -Root $root -Path 'first ünicode file.txt' -Content "first staged file`n"
    Invoke-CommitCheckGit -ProjectRoot $root -GitPath $gitPath -Arguments @('add', '--', 'first ünicode file.txt') | Out-Null
    Assert-SelectionFiles -Name 'unborn index staged additions work without HEAD' -Selection (Get-CommitCheckSelection -ProjectRoot $root -GitPath $gitPath -Staged) -Expected @('first ünicode file.txt')

    $root = New-SelectionFixture -Name 'tlpp-cleanup' -Unborn
    $sourcePath = Join-Path $root 'src/fixture.tlpp'
    $sourceContent = "// Maintained test source.`n"
    Write-SelectionFixtureFile -Root $root -Path 'src/fixture.tlpp' -Content $sourceContent
    Invoke-CommitCheckGit -ProjectRoot $root -GitPath $gitPath -Arguments @('add', '--', 'src/fixture.tlpp') | Out-Null
    $indexHash = Get-SelectionIndexHash -Root $root
    $snapshot = Join-Path $runRoot 'tlpp snapshot'
    $evidencePath = Join-Path $runRoot 'files.txt'
    [IO.File]::WriteAllText($evidencePath, "src/fixture.tlpp`n", [Text.UTF8Encoding]::new($false))
    try {
        New-CommitCheckSnapshot -ProjectRoot $root -GitPath $gitPath -SnapshotRoot $snapshot | Out-Null
        Assert-SelectionCondition -Name 'TLPP snapshot contains the indexed source' -Condition (
            [IO.File]::ReadAllText((Join-Path $snapshot 'src/fixture.tlpp')) -ceq $sourceContent)
    } finally {
        Remove-CommitCheckSnapshot -ProjectRoot $projectRoot -SnapshotRoot $snapshot
    }
    Assert-SelectionCondition -Name 'TLPP copy removed after successful validation' -Condition (-not (Test-Path -LiteralPath $snapshot))

    $validationFailed = $false
    try {
        try {
            New-CommitCheckSnapshot -ProjectRoot $root -GitPath $gitPath -SnapshotRoot $snapshot | Out-Null
            throw 'Simulated validator rejection.'
        } finally {
            Remove-CommitCheckSnapshot -ProjectRoot $projectRoot -SnapshotRoot $snapshot
        }
    } catch {
        if ($_.Exception.Message -cne 'Simulated validator rejection.') { throw }
        $validationFailed = $true
    }
    Assert-SelectionCondition -Name 'validator failure propagates after cleanup' -Condition $validationFailed
    Assert-SelectionCondition -Name 'TLPP copy removed after failed validation' -Condition (-not (Test-Path -LiteralPath $snapshot))

    $checkoutFailed = $false
    try {
        try {
            New-CommitCheckSnapshot -ProjectRoot $root -GitPath (Join-Path $runRoot 'missing-git-executable') -SnapshotRoot $snapshot | Out-Null
        } finally {
            Remove-CommitCheckSnapshot -ProjectRoot $projectRoot -SnapshotRoot $snapshot
        }
    } catch {
        $checkoutFailed = $true
    }
    Assert-SelectionCondition -Name 'checkout failure is reported' -Condition $checkoutFailed
    Assert-SelectionCondition -Name 'partial snapshot removed after checkout failure' -Condition (-not (Test-Path -LiteralPath $snapshot))
    Remove-CommitCheckSnapshot -ProjectRoot $projectRoot -SnapshotRoot $snapshot
    Assert-SelectionCondition -Name 'cleanup is idempotent' -Condition (-not (Test-Path -LiteralPath $snapshot))
    Assert-SelectionCondition -Name 'cleanup preserves the maintained original' -Condition ([IO.File]::ReadAllText($sourcePath) -ceq $sourceContent)
    Assert-SelectionCondition -Name 'cleanup preserves index bytes' -Condition ((Get-SelectionIndexHash -Root $root) -eq $indexHash)
    Assert-SelectionCondition -Name 'cleanup keeps evidence without source copies' -Condition (Test-Path -LiteralPath $evidencePath -PathType Leaf)
    foreach ($unsafePath in @($projectRoot, (Join-Path $projectRoot 'tmp'), (Join-Path $projectRoot 'src'),
        (Join-Path $projectRoot 'tmp/../src'), (Join-Path $projectRoot 'tmp-sibling/snapshot'))) {
        $rejected = $false
        try { Remove-CommitCheckSnapshot -ProjectRoot $projectRoot -SnapshotRoot $unsafePath }
        catch { $rejected = $true }
        Assert-SelectionCondition -Name 'cleanup rejects a target outside disposable snapshots' -Condition $rejected
    }

    Write-Output "hbBridge commit selection checks: $script:selectionChecks; OK"
} finally {
    Remove-CommitCheckSnapshot -ProjectRoot $projectRoot -SnapshotRoot $runRoot
}
