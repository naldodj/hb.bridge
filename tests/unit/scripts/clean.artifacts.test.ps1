[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function AssertCondition {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function WriteFixtureFile {
    param(
        [string]$Path,
        [string]$Content = 'cleanup fixture'
    )

    $cParent = Split-Path -Parent $Path

    [System.IO.Directory]::CreateDirectory($cParent) | Out-Null
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

function InvokeFixtureGit {
    param(
        [string]$Root,
        [string[]]$Arguments
    )

    $aOutput = @(& $script:cFixtureGit -c "safe.directory=$Root" -C $Root @Arguments 2>&1)

    if ($LASTEXITCODE -ne 0) {
        throw "Fixture Git command failed: $($aOutput -join [Environment]::NewLine)"
    }
}

function NewFixtureProject {
    param([string]$Name)

    $cRoot = Join-Path $script:cFixtureRoot "$Name project with spaces"
    $cScript = Join-Path $cRoot 'scripts/clean-artifacts.ps1'

    [System.IO.Directory]::CreateDirectory((Split-Path -Parent $cScript)) | Out-Null
    [System.IO.Directory]::CreateDirectory((Join-Path $cRoot 'tmp')) | Out-Null
    [System.IO.Directory]::CreateDirectory((Join-Path $cRoot 'out')) | Out-Null
    Copy-Item -LiteralPath $script:cSourceScript -Destination $cScript
    WriteFixtureFile (Join-Path $cRoot 'README.md') '# Cleanup fixture'
    InvokeFixtureGit $cRoot @('init', '--quiet')
    InvokeFixtureGit $cRoot @('add', '--', 'scripts/clean-artifacts.ps1', 'README.md')

    return [pscustomobject]@{ Root = $cRoot; Script = $cScript }
}

function NewGeneratedPath {
    param(
        [string]$Root,
        [string]$Prefix = 'tmp/tests-',
        [string]$Suffix = '/hbbridge.worker.exe'
    )

    return Join-Path $Root ($Prefix + [guid]::NewGuid().ToString('N') + $Suffix)
}

function SetFixtureAge {
    param(
        [string]$Root,
        [int]$Days = 30
    )

    $dTimestamp = [DateTime]::UtcNow.AddDays(-$Days)

    # Children are changed first so creating fixture content cannot refresh an ancestor afterwards.
    Get-ChildItem -LiteralPath $Root -Force -Recurse |
        Sort-Object { $_.FullName.Length } -Descending |
        ForEach-Object { $_.LastWriteTimeUtc = $dTimestamp }
    (Get-Item -LiteralPath $Root -Force).LastWriteTimeUtc = $dTimestamp
}

function GetFixtureSnapshot {
    param([string]$Root)

    $aEntries = @(Get-ChildItem -LiteralPath $Root -Force -Recurse | Sort-Object FullName)
    $cRelative = ''
    $cValue = ''

    $oSnapshot = [System.Collections.Generic.List[string]]::new()

    foreach ($oEntry in $aEntries) {
        $cRelative = [System.IO.Path]::GetRelativePath($Root, $oEntry.FullName)
        # Git may refresh its administrative cache. Compare project contents,
        # including generated roots, rather than Git-owned metadata timestamps.
        if ($cRelative -eq '.git' -or $cRelative.Replace('\', '/').StartsWith('.git/')) { continue }
        if ($oEntry.PSIsContainer) {
            $cValue = 'directory'
        }
        else {
            $cValue = (Get-FileHash -LiteralPath $oEntry.FullName -Algorithm SHA256).Hash
        }
        $oSnapshot.Add("$cRelative|$cValue|$($oEntry.LastWriteTimeUtc.Ticks)")
    }

    return $oSnapshot -join "`n"
}

function InvokeFixtureCleanup {
    param(
        [object]$Project,
        [hashtable]$Options = @{}
    )

    $aOutput = @(& $Project.Script @Options)
    $aSummary = @($aOutput | Where-Object { $_.PSObject.Properties.Name -contains 'Mode' })

    AssertCondition ($aSummary.Count -eq 1) 'Cleanup must return exactly one summary object.'
    return $aSummary[0]
}

function AssertPathExists {
    param(
        [string]$Path,
        [bool]$Expected,
        [string]$Message
    )

    AssertCondition ((Test-Path -LiteralPath $Path) -eq $Expected) $Message
}

function AssertThrows {
    param(
        [scriptblock]$Action,
        [string]$Message
    )

    $lThrew = $false

    try {
        & $Action | Out-Null
    }
    catch {
        $lThrew = $true
    }
    AssertCondition $lThrew $Message
}

function NewFixtureLink {
    param(
        [string]$Path,
        [string]$Target
    )

    $cKind = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }

    New-Item -ItemType $cKind -Path $Path -Target $Target | Out-Null
}

function InvokeTestCase {
    param(
        [string]$Name,
        [scriptblock]$Action
    )

    try {
        & $Action
        $script:oResults.Add([pscustomobject]@{ Name = $Name; Success = $true; Message = '' })
        Write-Host "PASS $Name"
    }
    catch {
        $script:oResults.Add([pscustomobject]@{ Name = $Name; Success = $false; Message = $_.Exception.Message })
        Write-Host "FAIL $Name`: $($_.Exception.Message)"
    }
}

$aGitCommands = @(Get-Command git -All | Where-Object { $_.Source -notmatch '[\\/]cygwin[^\\/]*[\\/]' })

$cFixtureGit = if ($aGitCommands.Count) { $aGitCommands[0].Source } else { (Get-Command git).Source }
$cRepository = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
$cSourceScript = Join-Path $cRepository 'scripts/clean-artifacts.ps1'
$cTemporaryRoot = Join-Path $cRepository 'tmp'
$cFixtureRoot = Join-Path $cTemporaryRoot ('cleanup-script-tests-' + [guid]::NewGuid().ToString('N'))

$oResults = [System.Collections.Generic.List[object]]::new()

AssertPathExists $cSourceScript $true 'The cleanup script must exist before running these tests.'
[System.IO.Directory]::CreateDirectory($cFixtureRoot) | Out-Null

InvokeTestCase 'Default preview is read-only, including ReportPath' {
    $oProject = NewFixtureProject 'preview'
    $cGenerated = NewGeneratedPath $oProject.Root 'out/build-' '/engine.obj'
    $cReport = Join-Path $oProject.Root 'tmp/reports/preview.json'
    WriteFixtureFile $cGenerated
    SetFixtureAge $oProject.Root
    $cBefore = GetFixtureSnapshot $oProject.Root
    $oSummary = InvokeFixtureCleanup $oProject @{ ReportPath = $cReport }
    AssertCondition ($oSummary.Mode -eq 'Preview') 'Default mode must be Preview.'
    AssertCondition ($oSummary.CandidateCount -gt 0) 'Preview must identify an old generated build.'
    AssertCondition ($oSummary.DeletedBytes -eq 0) 'Preview must not report deleted bytes.'
    AssertCondition ((GetFixtureSnapshot $oProject.Root) -ceq $cBefore) 'Preview changed the fixture.'
    AssertPathExists (Split-Path -Parent $cReport) $false 'Preview created a report directory.'
}

InvokeTestCase 'Apply treats all tmp content as disposable and preserves out deliverables' {
    $oProject = NewFixtureProject 'apply'
    $cBuildFile = NewGeneratedPath $oProject.Root 'out/build-' '/nested/engine.obj'
    $cTemporaryExe = NewGeneratedPath $oProject.Root
    $cLog = Join-Path (Split-Path -Parent $cTemporaryExe) 'results.log'
    $cJson = Join-Path (Split-Path -Parent $cTemporaryExe) 'results.json'
    $cFixture = Join-Path (Split-Path -Parent $cTemporaryExe) 'fixture.txt'
    $cRpo = Join-Path (Split-Path -Parent $cTemporaryExe) 'custom.rpo'
    $cScript = Join-Path (Split-Path -Parent $cTemporaryExe) 'reproduce.ps1'
    $cManifest = Join-Path (Split-Path -Parent $cTemporaryExe) 'manifest.json'
    $cExe = Join-Path $oProject.Root 'out/hbbridge.exe'
    $cAddon = Join-Path $oProject.Root 'out/example.hrb'
    $cOutUnknown = Join-Path $oProject.Root 'out/my-own-files/important.exe'
    $cUnknown = Join-Path $oProject.Root 'tmp/my-own-files/important.exe'
    $cUnknownFamilyExe = Join-Path (Split-Path -Parent $cTemporaryExe) 'unknown.exe'
    $cUnknownFamilyDll = Join-Path (Split-Path -Parent $cTemporaryExe) 'unknown.dll'
    $cUnknownFamilyHrb = Join-Path (Split-Path -Parent $cTemporaryExe) 'unknown.hrb'
    $aDisposable = @($cLog, $cJson, $cFixture, $cRpo, $cScript, $cManifest, $cUnknown, $cUnknownFamilyExe, $cUnknownFamilyDll, $cUnknownFamilyHrb)
    $aPreserved = @($cExe, $cAddon, $cOutUnknown)
    WriteFixtureFile $cBuildFile
    WriteFixtureFile $cTemporaryExe
    foreach ($cPath in ($aDisposable + $aPreserved)) { WriteFixtureFile $cPath }
    SetFixtureAge $oProject.Root
    $oSummary = InvokeFixtureCleanup $oProject @{ Apply = $true }
    AssertCondition ($oSummary.Mode -eq 'Apply') 'Apply must report Apply mode.'
    AssertCondition ($oSummary.FailedCount -eq 0) 'Apply reported a deletion failure.'
    AssertCondition ($oSummary.DeletedBytes -gt 0) 'Apply must report reclaimed bytes.'
    AssertPathExists $cBuildFile $false 'Generated out build content was retained.'
    AssertPathExists $cTemporaryExe $false 'An old temporary executable was retained.'
    foreach ($cPath in $aDisposable) { AssertPathExists $cPath $false "Temporary content was retained: $cPath" }
    foreach ($cPath in $aPreserved) { AssertPathExists $cPath $true "Protected content was removed: $cPath" }
    $oAgain = InvokeFixtureCleanup $oProject @{ Apply = $true }
    AssertCondition ($oAgain.DeletedBytes -eq 0) 'A repeated cleanup must be idempotent.'
    AssertCondition (@($oAgain.Candidates | Where-Object Status -eq 'Deleted').Count -eq 0) 'Repeated cleanup reported another deletion.'
}

InvokeTestCase 'A recent descendant protects an old build directory' {
    $oProject = NewFixtureProject 'age'
    $cOld = NewGeneratedPath $oProject.Root 'out/build-' '/old.obj'
    $cRecent = Join-Path (Split-Path -Parent $cOld) 'recent.obj'
    WriteFixtureFile $cOld
    WriteFixtureFile $cRecent
    SetFixtureAge $oProject.Root
    (Get-Item -LiteralPath $cRecent).LastWriteTimeUtc = [DateTime]::UtcNow
    $oSummary = InvokeFixtureCleanup $oProject @{ Apply = $true }
    AssertPathExists $cOld $true 'An old parent was removed despite a recent child.'
    AssertPathExists $cRecent $true 'A recent generated file was removed.'
    AssertCondition ($oSummary.DeletedBytes -eq 0) 'The protected build must not reclaim bytes.'
}

InvokeTestCase 'KeepPath descendants protect candidate ancestors' {
    $oProject = NewFixtureProject 'keep path'
    $cKept = NewGeneratedPath $oProject.Root 'out/build-' '/nested/keep.obj'
    $cOther = Join-Path (Split-Path -Parent $cKept) 'other.obj'
    WriteFixtureFile $cKept
    WriteFixtureFile $cOther
    SetFixtureAge $oProject.Root
    $cKeepRelative = [System.IO.Path]::GetRelativePath($oProject.Root, $cKept)
    $oSummary = InvokeFixtureCleanup $oProject @{ Apply = $true; KeepPath = @($cKeepRelative) }
    AssertPathExists $cKept $true 'KeepPath content was deleted with its parent.'
    AssertPathExists $cOther $true 'The containing candidate must remain intact.'
    AssertCondition ($oSummary.DeletedBytes -eq 0) 'KeepPath ancestor protection was bypassed.'
}

InvokeTestCase 'Documentation, chained JSON and current pointers do not retain tmp content' {
    $oProject = NewFixtureProject 'references'
    $cDocumentExe = NewGeneratedPath $oProject.Root
    $cJsonExe = NewGeneratedPath $oProject.Root
    $cPointerExe = NewGeneratedPath $oProject.Root
    $cUnreferenced = NewGeneratedPath $oProject.Root
    $cChain = Join-Path $oProject.Root 'tmp/fixtures/chain.json'
    $cJsonRelative = [System.IO.Path]::GetRelativePath($oProject.Root, $cJsonExe).Replace('\', '/')
    $cDocumentRelative = [System.IO.Path]::GetRelativePath($oProject.Root, $cDocumentExe).Replace('\', '/')
    $cPointerRelative = [System.IO.Path]::GetRelativePath($oProject.Root, $cPointerExe).Replace('\', '/')
    foreach ($cPath in @($cDocumentExe, $cJsonExe, $cPointerExe, $cUnreferenced)) { WriteFixtureFile $cPath }
    WriteFixtureFile (Join-Path $oProject.Root 'README.md') "[Validation executable]($cDocumentRelative)"
    WriteFixtureFile (Join-Path $oProject.Root 'config/keep.json') '{"receipt":"tmp/fixtures/chain.json"}'
    WriteFixtureFile $cChain (@{ executable = $cJsonRelative } | ConvertTo-Json -Compress)
    WriteFixtureFile (Join-Path $oProject.Root 'tmp/fixture-current.txt') $cPointerRelative
    InvokeFixtureGit $oProject.Root @('add', '--', 'config/keep.json')
    SetFixtureAge $oProject.Root
    $oSummary = InvokeFixtureCleanup $oProject @{ Apply = $true }
    AssertPathExists $cDocumentExe $false 'Documentation silently retained temporary content.'
    AssertPathExists $cJsonExe $false 'Chained JSON silently retained temporary content.'
    AssertPathExists $cPointerExe $false 'A current pointer silently retained temporary content.'
    AssertPathExists $cChain $false 'A temporary JSON reference chain was retained.'
    AssertPathExists (Join-Path $oProject.Root 'tmp/fixture-current.txt') $false 'A temporary current pointer was retained.'
    AssertPathExists $cUnreferenced $false 'The reference test did not exercise an eligible deletion.'
    AssertPathExists (Join-Path $oProject.Root 'README.md') $true 'A permanent document outside tmp/out was removed.'
    AssertPathExists (Join-Path $oProject.Root 'config/keep.json') $true 'A permanent configuration outside tmp/out was removed.'
    AssertCondition ($oSummary.FailedCount -eq 0) 'Referenced temporary content caused a cleanup failure.'
}

InvokeTestCase 'Tracked descendants protect generated build directories' {
    $oProject = NewFixtureProject 'tracked'
    $cTracked = NewGeneratedPath $oProject.Root 'out/build-' '/tracked.obj'
    $cSibling = Join-Path (Split-Path -Parent $cTracked) 'untracked.obj'
    WriteFixtureFile $cTracked
    WriteFixtureFile $cSibling
    InvokeFixtureGit $oProject.Root @('add', '--', [System.IO.Path]::GetRelativePath($oProject.Root, $cTracked))
    SetFixtureAge $oProject.Root
    $oSummary = InvokeFixtureCleanup $oProject @{ Apply = $true; MinAgeDays = 0 }
    AssertPathExists $cTracked $true 'A tracked file was deleted.'
    AssertPathExists $cSibling $true 'A candidate containing tracked content must remain intact.'
    AssertCondition ($oSummary.DeletedBytes -eq 0) 'Tracked descendant protection was bypassed.'
}

InvokeTestCase 'Nested filesystem links preserve their candidate and external target' {
    $oProject = NewFixtureProject 'nested link'
    $cExternal = Join-Path $cFixtureRoot 'external nested target'
    $cOutside = Join-Path $cExternal 'keep.txt'
    $cBuild = NewGeneratedPath $oProject.Root 'out/build-' ''
    $cLink = Join-Path $cBuild 'linked directory'
    WriteFixtureFile $cOutside 'external content must remain unchanged'
    [System.IO.Directory]::CreateDirectory($cBuild) | Out-Null
    NewFixtureLink $cLink $cExternal
    $oSummary = InvokeFixtureCleanup $oProject @{ Apply = $true; MinAgeDays = 0 }
    AssertPathExists $cLink $true 'Cleanup removed a filesystem link.'
    AssertPathExists $cOutside $true 'Cleanup followed a link and deleted external content.'
    AssertCondition ((Get-Content -LiteralPath $cOutside -Raw) -ceq 'external content must remain unchanged') 'External link content changed.'
    AssertCondition ($oSummary.DeletedBytes -eq 0) 'A linked candidate must not be deleted.'
}

InvokeTestCase 'A linked out root is rejected before deletion' {
    $oProject = NewFixtureProject 'root link'
    $cExternal = Join-Path $cFixtureRoot 'external root target'
    $cOutside = Join-Path $cExternal 'keep.txt'
    $cOut = Join-Path $oProject.Root 'out'
    WriteFixtureFile $cOutside
    Remove-Item -LiteralPath $cOut
    NewFixtureLink $cOut $cExternal
    AssertThrows { InvokeFixtureCleanup $oProject @{ Apply = $true; Target = 'out'; MinAgeDays = 0 } } 'A linked output root must be rejected.'
    AssertPathExists $cOut $true 'Cleanup removed the linked output root.'
    AssertPathExists $cOutside $true 'Cleanup modified a linked output target.'
}

InvokeTestCase 'Apply with WhatIf leaves files and report paths untouched' {
    $oProject = NewFixtureProject 'what if'
    $cGenerated = NewGeneratedPath $oProject.Root 'out/build-' '/engine.obj'
    $cReport = Join-Path $oProject.Root 'tmp/reports/whatif.json'
    WriteFixtureFile $cGenerated
    SetFixtureAge $oProject.Root
    $cBefore = GetFixtureSnapshot $oProject.Root
    $oSummary = InvokeFixtureCleanup $oProject @{ Apply = $true; WhatIf = $true; ReportPath = $cReport; MinAgeDays = 0 }
    AssertCondition ($oSummary.Mode -eq 'WhatIf') 'WhatIf mode must be explicit in the summary.'
    AssertCondition ($oSummary.DeletedBytes -eq 0) 'WhatIf must not report deleted bytes.'
    AssertCondition ((GetFixtureSnapshot $oProject.Root) -ceq $cBefore) 'WhatIf changed the fixture.'
    AssertPathExists (Split-Path -Parent $cReport) $false 'WhatIf created a report directory.'
}

InvokeTestCase 'KeepPath cannot escape the generated roots' {
    $oProject = NewFixtureProject 'path traversal'
    $cGenerated = NewGeneratedPath $oProject.Root 'out/build-' '/engine.obj'
    WriteFixtureFile $cGenerated
    AssertThrows { InvokeFixtureCleanup $oProject @{ Apply = $true; KeepPath = @('../outside'); MinAgeDays = 0 } } 'An escaping relative KeepPath must be rejected.'
    AssertThrows { InvokeFixtureCleanup $oProject @{ Apply = $true; KeepPath = @('README.md'); MinAgeDays = 0 } } 'KeepPath outside tmp/out must be rejected.'
    AssertPathExists $cGenerated $true 'KeepPath validation happened after deletion.'
}

InvokeTestCase 'Target selection and zero-day cleanup are explicit' {
    $oProject = NewFixtureProject 'target selection'
    $cOut = NewGeneratedPath $oProject.Root 'out/build-' '/engine.obj'
    $cTmp = NewGeneratedPath $oProject.Root
    WriteFixtureFile $cOut
    WriteFixtureFile $cTmp
    $oSummary = InvokeFixtureCleanup $oProject @{ Apply = $true; Target = 'tmp'; MinAgeDays = 0 }
    AssertPathExists $cTmp $false 'Zero-day cleanup did not remove a fresh generated artifact.'
    AssertPathExists $cOut $true 'Target tmp unexpectedly removed out content.'
    AssertCondition ($oSummary.FailedCount -eq 0) 'Targeted cleanup reported a failure.'
}

InvokeTestCase 'Apply writes an explicit JSON report' {
    $oProject = NewFixtureProject 'report'
    $cGenerated = NewGeneratedPath $oProject.Root 'out/build-' '/engine.obj'
    $cReport = Join-Path $oProject.Root 'tmp/reports/applied.json'
    WriteFixtureFile $cGenerated
    $oSummary = InvokeFixtureCleanup $oProject @{ Apply = $true; ReportPath = $cReport; MinAgeDays = 0 }
    AssertPathExists $cReport $true 'Apply did not write the requested report.'
    $jReport = Get-Content -LiteralPath $cReport -Raw | ConvertFrom-Json
    AssertCondition ($jReport.Mode -eq 'Apply') 'The written report has an incorrect mode.'
    AssertCondition ($jReport.DeletedBytes -eq $oSummary.DeletedBytes) 'The written report disagrees with the returned summary.'
}

InvokeTestCase 'Recognized build, checker and browser profiles are regenerable' {
    $oProject = NewFixtureProject 'generated families'
    $aGenerated = @(
        (Join-Path $oProject.Root 'out/build/temporary.dat'),
        (Join-Path $oProject.Root 'out/benchmark/build/temporary.dat'),
        (NewGeneratedPath $oProject.Root 'tmp/build-' '/temporary.dat'),
        (NewGeneratedPath $oProject.Root 'tmp/commit-check-' '/temporary.dat'),
        (NewGeneratedPath $oProject.Root 'tmp/tests-' '/build/temporary.dat'),
        (Join-Path $oProject.Root 'tmp/benchmark-browser-123/profile-123/temporary.dat')
    )
    foreach ($cPath in $aGenerated) { WriteFixtureFile $cPath }
    $oSummary = InvokeFixtureCleanup $oProject @{ Apply = $true; MinAgeDays = 0 }
    foreach ($cPath in $aGenerated) { AssertPathExists $cPath $false "A recognized generated family was retained: $cPath" }
    AssertCondition ($oSummary.FailedCount -eq 0) 'Recognized generated families reported deletion failures.'
}

InvokeTestCase 'Git metadata is mandatory before any deletion' {
    $oProject = NewFixtureProject 'missing git metadata'
    $cGenerated = NewGeneratedPath $oProject.Root 'out/build-' '/engine.obj'
    $cGit = Join-Path $oProject.Root '.git'
    $cHiddenGit = Join-Path $oProject.Root '.git-hidden-for-test'
    WriteFixtureFile $cGenerated
    Move-Item -LiteralPath $cGit -Destination $cHiddenGit
    try {
        AssertThrows { InvokeFixtureCleanup $oProject @{ Apply = $true; MinAgeDays = 0 } } 'A parent Git repository cannot substitute for fixture Git metadata.'
        AssertPathExists $cGenerated $true 'Missing Git metadata was detected after deletion.'
    }
    finally {
        Move-Item -LiteralPath $cHiddenGit -Destination $cGit
    }
}

InvokeTestCase 'Temporary manifests and extensionless binaries are disposable' {
    $oProject = NewFixtureProject 'extensionless json references'
    $cExecutable = NewGeneratedPath $oProject.Root 'tmp/tests-' '/hbbridge'
    $cDirectory = Split-Path -Parent $cExecutable
    $cBuildFile = Join-Path $cDirectory 'build/temporary.obj'
    $cReceipt = Join-Path $cDirectory 'receipt.json'
    $cUnreferenced = NewGeneratedPath $oProject.Root
    WriteFixtureFile $cExecutable
    WriteFixtureFile $cBuildFile
    WriteFixtureFile $cReceipt '{"executable":"hbbridge","directory":"build"}'
    WriteFixtureFile $cUnreferenced
    $oSummary = InvokeFixtureCleanup $oProject @{ Apply = $true; MinAgeDays = 0 }
    AssertPathExists $cExecutable $false 'An extensionless temporary executable was retained.'
    AssertPathExists $cBuildFile $false 'A manifest silently retained its local build directory.'
    AssertPathExists $cReceipt $false 'A temporary manifest was retained.'
    AssertPathExists $cUnreferenced $false 'The JSON reference test did not exercise a deletion.'
    AssertCondition ($oSummary.FailedCount -eq 0) 'An extensionless temporary artifact caused a cleanup failure.'
}

InvokeTestCase 'A clone without tmp or out remains usable and does not create scratch roots' {
    $oProject = NewFixtureProject 'absent scratch roots'
    $cTmp = Join-Path $oProject.Root 'tmp'
    $cOut = Join-Path $oProject.Root 'out'
    $cReport = Join-Path $cTmp 'reports/absent.json'
    Remove-Item -LiteralPath $cTmp
    Remove-Item -LiteralPath $cOut
    $cBefore = GetFixtureSnapshot $oProject.Root
    foreach ($jOptions in @(
        @{ ReportPath = $cReport },
        @{ Apply = $true; WhatIf = $true; ReportPath = $cReport },
        @{ Apply = $true; MinAgeDays = 0 }
    )) {
        $oSummary = InvokeFixtureCleanup $oProject $jOptions
        AssertCondition ($oSummary.CandidateCount -eq 0) 'Absent scratch roots must have no deletion candidates.'
        AssertCondition ($oSummary.FailedCount -eq 0) 'Absent scratch roots must not be an error.'
        AssertCondition ((GetFixtureSnapshot $oProject.Root) -ceq $cBefore) 'Cleanup changed a clone without generated roots.'
        AssertPathExists $cTmp $false 'Cleanup created an absent tmp root.'
        AssertPathExists $cOut $false 'Cleanup created an absent out root.'
    }
}

InvokeTestCase 'Invalid report ancestors are rejected before deletion' {
    $oProject = NewFixtureProject 'report file ancestor'
    $cExecutable = NewGeneratedPath $oProject.Root
    $cAncestor = Join-Path $oProject.Root 'tmp/report-blocker'
    $cReport = Join-Path $cAncestor 'report.json'
    WriteFixtureFile $cExecutable
    WriteFixtureFile $cAncestor 'This is a file, not a directory.'
    AssertThrows { InvokeFixtureCleanup $oProject @{ Apply = $true; MinAgeDays = 0; ReportPath = $cReport } } 'A file ancestor of ReportPath must be rejected.'
    AssertPathExists $cExecutable $true 'Invalid report ancestry was detected after deletion.'
    AssertCondition ((Get-Content -LiteralPath $cAncestor -Raw) -ceq 'This is a file, not a directory.') 'The report ancestor file changed.'
}

InvokeTestCase 'Documentation references do not retain large temporary binaries' {
    $oProject = NewFixtureProject 'large referenced binary'
    $cExecutable = NewGeneratedPath $oProject.Root
    $cRelative = [System.IO.Path]::GetRelativePath($oProject.Root, $cExecutable).Replace('\', '/')
    WriteFixtureFile $cExecutable
    $oStream = [System.IO.File]::Open($cExecutable, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Write)
    try { $oStream.SetLength(17MB) } finally { $oStream.Dispose() }
    WriteFixtureFile (Join-Path $oProject.Root 'README.md') "[Large executable]($cRelative)"
    $oSummary = InvokeFixtureCleanup $oProject @{ Apply = $true; MinAgeDays = 0 }
    AssertPathExists $cExecutable $false 'A documentation reference retained a large temporary binary.'
    AssertCondition ($oSummary.DeletedBytes -ge 17MB) 'The large binary was not included in reclaimed bytes.'
    AssertCondition ($oSummary.FailedCount -eq 0) 'A large temporary binary caused a cleanup failure.'
}

InvokeTestCase 'Locked files produce a local failure while other artifacts are removed' {
    $oProject = NewFixtureProject 'locked generated file'
    $cLocked = NewGeneratedPath $oProject.Root
    $cOther = NewGeneratedPath $oProject.Root
    WriteFixtureFile $cLocked
    WriteFixtureFile $cOther
    $oStream = [System.IO.File]::Open($cLocked, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
    try {
        $oSummary = InvokeFixtureCleanup $oProject @{ Apply = $true; MinAgeDays = 0 }
        AssertPathExists $cOther $false 'A locked artifact prevented unrelated cleanup.'
        if ($IsWindows) {
            AssertPathExists $cLocked $true 'A file with exclusive Windows sharing was removed.'
            AssertCondition ($oSummary.FailedCount -eq 1) 'The locked file must be reported as one local failure.'
            AssertCondition (@($oSummary.Candidates | Where-Object Status -eq 'Failed').Count -eq 1) 'A failed artifact status is missing.'
        }
        else {
            # POSIX permits unlinking an open file; FileShare.None does not impose a deletion lock there.
            AssertCondition ($oSummary.FailedCount -eq 0) 'Open POSIX files must retain the platform deletion behavior.'
        }
    }
    finally {
        $oStream.Dispose()
    }
}

InvokeTestCase 'A dangling linked output root is rejected before deletion' {
    $oProject = NewFixtureProject 'dangling root link'
    $cExternal = Join-Path $cFixtureRoot 'dangling external target'
    $cOut = Join-Path $oProject.Root 'out'
    [System.IO.Directory]::CreateDirectory($cExternal) | Out-Null
    Remove-Item -LiteralPath $cOut
    NewFixtureLink $cOut $cExternal
    Remove-Item -LiteralPath $cExternal
    AssertThrows { InvokeFixtureCleanup $oProject @{ Apply = $true; Target = 'out'; MinAgeDays = 0 } } 'A dangling linked output root must be rejected.'
    $oLink = Get-Item -LiteralPath $cOut -Force
    AssertCondition (($oLink.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) 'A dangling linked root was removed.'
}

InvokeTestCase 'Malformed referenced JSON cannot silently retain temporary artifacts' {
    $oProject = NewFixtureProject 'invalid json reference'
    $cExecutable = NewGeneratedPath $oProject.Root
    $cDirectory = Split-Path -Parent $cExecutable
    $cBuildFile = Join-Path $cDirectory 'build/temporary.obj'
    $cManifest = Join-Path $cDirectory 'manifest.json'
    $cManifestRelative = [System.IO.Path]::GetRelativePath($oProject.Root, $cManifest).Replace('\', '/')
    $cOther = NewGeneratedPath $oProject.Root
    WriteFixtureFile $cExecutable
    WriteFixtureFile $cBuildFile
    WriteFixtureFile $cManifest '{invalid'
    WriteFixtureFile $cOther
    WriteFixtureFile (Join-Path $oProject.Root 'README.md') "[Artifact manifest]($cManifestRelative)"
    $oSummary = InvokeFixtureCleanup $oProject @{ Apply = $true; MinAgeDays = 0 }
    AssertPathExists $cExecutable $false 'Malformed JSON silently retained its sibling executable.'
    AssertPathExists $cBuildFile $false 'Malformed JSON silently retained its sibling build directory.'
    AssertPathExists $cManifest $false 'A malformed temporary manifest was retained.'
    AssertPathExists $cOther $false 'Malformed JSON blocked unrelated cleanup.'
    AssertCondition ($oSummary.FailedCount -eq 0) 'Temporary JSON parsing must not be a prerequisite for cleanup.'
}

InvokeTestCase 'Saved cleanup previews do not turn their candidates into retained manifests' {
    $oProject = NewFixtureProject 'saved cleanup preview'
    $cBuildFile = NewGeneratedPath $oProject.Root 'out/build-' '/engine.obj'
    $cBuildRelative = [System.IO.Path]::GetRelativePath($oProject.Root, (Split-Path -Parent $cBuildFile)).Replace('\', '/')
    $cPreview = Join-Path $oProject.Root 'tmp/preview.json'
    $cPointer = Join-Path $oProject.Root 'tmp/preview-current.txt'
    WriteFixtureFile $cBuildFile
    $oPreview = InvokeFixtureCleanup $oProject @{ MinAgeDays = 0 }
    AssertCondition ($oPreview.Mode -eq 'Preview') 'The first cleanup must produce a real Preview summary.'
    AssertCondition (@($oPreview.Candidates | Where-Object { $_.Path -eq $cBuildRelative -and $_.Status -eq 'Planned' }).Count -eq 1) 'The original build must be planned before saving the preview.'
    WriteFixtureFile $cPreview ($oPreview | ConvertTo-Json -Depth 20)
    WriteFixtureFile $cPointer 'tmp/preview.json'
    $oSummary = InvokeFixtureCleanup $oProject @{ Apply = $true; MinAgeDays = 0 }
    AssertPathExists $cBuildFile $false 'A saved cleanup preview incorrectly retained its own deletion candidate.'
    AssertPathExists $cPreview $false 'A saved temporary cleanup preview was retained.'
    AssertPathExists $cPointer $false 'A temporary cleanup preview pointer was retained.'
    AssertCondition ($oSummary.FailedCount -eq 0) 'A saved cleanup preview caused a cleanup failure.'
}

$aFailures = @($oResults | Where-Object { -not $_.Success })
$nTestCount = $oResults.Count
$nFailureCount = $aFailures.Count

if ($nFailureCount -eq 0) {
    # Remove only this test's verified sandbox. Unlink reparse points first, without following them.
    $cResolvedRoot = (Get-Item -LiteralPath $cFixtureRoot -Force).FullName
    $cAllowedParent = [System.IO.Path]::GetFullPath($cTemporaryRoot) + [System.IO.Path]::DirectorySeparatorChar
    AssertCondition ($cResolvedRoot.StartsWith($cAllowedParent, [System.StringComparison]::OrdinalIgnoreCase)) 'The cleanup fixture escaped the repository tmp directory.'
    AssertCondition ((Split-Path -Leaf $cResolvedRoot) -match '^cleanup-script-tests-[0-9a-f]{32}$') 'The cleanup fixture name is invalid.'
    Get-ChildItem -LiteralPath $cResolvedRoot -Force -Recurse |
        Where-Object { ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0 } |
        Sort-Object { $_.FullName.Length } -Descending |
        ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force }
    Remove-Item -LiteralPath $cResolvedRoot -Recurse -Force
}
else {
    Write-Host "Failure fixtures retained at: $cFixtureRoot"
}

Write-Host "Artifact cleanup tests: $nTestCount; failures: $nFailureCount"
if ($nFailureCount -gt 0) {
    throw "Artifact cleanup tests failed: $nFailureCount of $nTestCount."
}
