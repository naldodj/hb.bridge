#Requires -Version 7.0
[CmdletBinding()]
param(
    [string] $HbCompileRoot,
    [string] $ZigPath,
    [switch] $ForceBuild
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'toolchain.ps1')
$toolchain = Resolve-HBBridgeToolchain -ProjectRoot $projectRoot -HbCompileRoot $HbCompileRoot -ZigPath $ZigPath
$dependencies = Get-HBBridgeDependencies -ProjectRoot $projectRoot
$definition = $dependencies.harbour.sqlitePatch
if (-not $definition) { throw 'The managed SQLite patch definition is required.' }
$patchFile = Join-Path $projectRoot $definition.path
$patchHash = (Get-FileHash -LiteralPath $patchFile -Algorithm SHA256).Hash
if ($patchHash -ne $definition.sha256) { throw 'The managed SQLite patch checksum does not match its manifest.' }
$sourceHashes = @{}
foreach ($source in @('src/c/hbbridge.sql.typed.h', 'src/c/hbbridge.sqlite.typed.c')) {
    $sourceHashes[$source] = (Get-FileHash -LiteralPath (Join-Path $projectRoot $source) -Algorithm SHA256).Hash
}
$installRoot = Split-Path -Parent $toolchain.HarbourBin
$libraryPlatform = if ($IsWindows) { 'win' } else { 'linux' }
$libraryRoot = Join-Path $installRoot "lib/$libraryPlatform/$($toolchain.Compiler)"
$libraryFile = Join-Path $libraryRoot 'libsddsqlt3.a'
$managedRoot = Join-Path $projectRoot '.deps/sqlite'
$receiptFile = Join-Path $managedRoot 'receipt.json'
[IO.Directory]::CreateDirectory($managedRoot) | Out-Null
if (-not $ForceBuild -and (Test-Path -LiteralPath $libraryFile) -and (Test-Path -LiteralPath $receiptFile)) {
    $receipt = Get-Content -LiteralPath $receiptFile -Raw | ConvertFrom-Json -AsHashtable
    $sourcesMatch = $receipt.sourceHashes -is [Collections.IDictionary]
    foreach ($source in $sourceHashes.Keys) {
        $sourcesMatch = $sourcesMatch -and $receipt.sourceHashes[$source] -eq $sourceHashes[$source]
    }
    if ($sourcesMatch -and $receipt.harbourRevision -eq $dependencies.harbour.revision -and
        $receipt.patchSha256 -eq $patchHash -and $receipt.platform -eq $libraryPlatform -and
        $receipt.compiler -eq $toolchain.Compiler -and
        $receipt.librarySha256 -eq (Get-FileHash -LiteralPath $libraryFile -Algorithm SHA256).Hash) {
        Write-Host 'Managed SDDSQLite3 is ready.'
        return
    }
}
$stageRoot = Join-Path $managedRoot ('stage-' + [guid]::NewGuid().ToString('N'))
$buildRoot = Join-Path $stageRoot 'build'
[IO.Directory]::CreateDirectory($buildRoot) | Out-Null
Copy-Item -LiteralPath (Join-Path $toolchain.HarbourRoot 'contrib/sddsqlt3') -Destination $stageRoot -Recurse
$sqliteHeaders = Join-Path $stageRoot '3rd/sqlite3'
[IO.Directory]::CreateDirectory($sqliteHeaders) | Out-Null
foreach ($file in @('sqlite3.h', 'sqlite3.hbc')) {
    Copy-Item -LiteralPath (Join-Path $toolchain.HarbourRoot "contrib/3rd/sqlite3/$file") -Destination $sqliteHeaders
}
$moduleRoot = Join-Path $stageRoot 'sddsqlt3'
foreach ($source in $sourceHashes.Keys) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $source) -Destination $moduleRoot
}
$nativeGit = if ($IsWindows) { Join-Path $env:ProgramFiles 'Git/cmd/git.exe' } else { (Get-Command git -ErrorAction Stop).Source }
$relativeStage = [IO.Path]::GetRelativePath($projectRoot, $stageRoot).Replace('\', '/')
$previousEnvironment = Enter-HBBridgeToolchain -Toolchain $toolchain
Push-Location -LiteralPath $projectRoot
try {
    & $nativeGit -c "safe.directory=$($projectRoot.Replace('\', '/'))" apply --no-index --check --ignore-space-change "--directory=$relativeStage" $patchFile
    if ($LASTEXITCODE -ne 0) { throw 'The reviewed SQLite patch does not apply to its pinned source.' }
    & $nativeGit -c "safe.directory=$($projectRoot.Replace('\', '/'))" apply --no-index --ignore-space-change "--directory=$relativeStage" $patchFile
    if ($LASTEXITCODE -ne 0) { throw 'Could not apply the managed SQLite patch.' }
    & $toolchain.Hbmk2 "-comp=$($toolchain.Compiler)" (Join-Path $moduleRoot 'sddsqlt3.hbp') `
        "-I$(Join-Path $toolchain.HarbourRoot 'contrib/rddsql')" `
        "-o$(Join-Path $libraryRoot 'sddsqlt3')" "-workdir=$buildRoot"
    if ($LASTEXITCODE -ne 0) { throw 'Could not compile managed SDDSQLite3.' }
    $installModule = Join-Path $installRoot 'contrib/sddsqlt3'
    [IO.Directory]::CreateDirectory($installModule) | Out-Null
    Copy-Item -LiteralPath (Join-Path $moduleRoot 'sddsqlt3.hbc') -Destination $installModule -Force
    Copy-Item -LiteralPath (Join-Path $moduleRoot 'sddsqlt3.hbx') -Destination (Join-Path $installRoot 'include') -Force
    $receipt = @{
        harbourRevision = $dependencies.harbour.revision
        patchSha256 = $patchHash
        sourceHashes = $sourceHashes
        librarySha256 = (Get-FileHash -LiteralPath $libraryFile -Algorithm SHA256).Hash
        platform = $libraryPlatform
        compiler = $toolchain.Compiler
        stage = $stageRoot
    }
    [IO.File]::WriteAllText($receiptFile, (($receipt | ConvertTo-Json -Depth 5) + "`n"), [Text.UTF8Encoding]::new($false))
    Write-Host 'Managed SDDSQLite3 library is ready.'
} finally {
    Pop-Location
    Exit-HBBridgeToolchain -PreviousEnvironment $previousEnvironment
}
