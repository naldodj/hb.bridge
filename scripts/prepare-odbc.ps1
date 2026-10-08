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
$patchDefinition = $dependencies.harbour.odbcPatch
if (-not $patchDefinition -or [string]::IsNullOrWhiteSpace($patchDefinition.path) -or
    [string]::IsNullOrWhiteSpace($patchDefinition.sha256)) {
    throw 'The managed SDDODBC patch definition is required in config/dependencies.json.'
}
$patchFile = Join-Path $projectRoot $patchDefinition.path
$patchHash = (Get-FileHash -LiteralPath $patchFile -Algorithm SHA256).Hash
if ($patchHash -ne $patchDefinition.sha256) {
    throw 'The managed SDDODBC patch checksum does not match config/dependencies.json.'
}

$installRoot = Split-Path -Parent $toolchain.HarbourBin
$libraryPlatform = if ($IsWindows) { 'win' } else { 'linux' }
$libraryRoot = Join-Path $installRoot "lib/$libraryPlatform/$($toolchain.Compiler)"
$libraryFile = Join-Path $libraryRoot 'libsddodbc.a'
$installModule = Join-Path $installRoot 'contrib/sddodbc'
$includeRoot = Join-Path $installRoot 'include'
$managedODBCRoot = Join-Path $projectRoot '.deps/odbc'
$receiptFile = Join-Path $managedODBCRoot 'receipt.json'
New-Item -ItemType Directory -Force -Path $managedODBCRoot | Out-Null
if (-not $ForceBuild -and (Test-Path -LiteralPath $libraryFile -PathType Leaf) -and
    (Test-Path -LiteralPath (Join-Path $installModule 'sddodbc.hbc') -PathType Leaf) -and
    (Test-Path -LiteralPath (Join-Path $includeRoot 'sddodbc.hbx') -PathType Leaf) -and
    (Test-Path -LiteralPath $receiptFile -PathType Leaf)) {
    $receipt = $null
    try {
        $receipt = Get-Content -LiteralPath $receiptFile -Raw | ConvertFrom-Json -AsHashtable
    }
    catch {
        # An incomplete receipt cannot certify the installed library.
    }
    $libraryHash = (Get-FileHash -LiteralPath $libraryFile -Algorithm SHA256).Hash
    if ($receipt -and $receipt.harbourRevision -eq $dependencies.harbour.revision -and
        $receipt.patchSha256 -eq $patchHash -and $receipt.librarySha256 -eq $libraryHash -and
        $receipt.platform -eq $libraryPlatform -and $receipt.compiler -eq $toolchain.Compiler) {
        Write-Host 'Managed SDDODBC is ready.'
        return
    }
}

if ($IsLinux) {
    $odbcHeaderRoots = @('/usr/include', '/usr/local/include')
    if (-not [string]::IsNullOrWhiteSpace($env:HB_WITH_ODBC)) {
        if ($env:HB_WITH_ODBC -eq 'no') {
            throw 'SDDODBC is required; HB_WITH_ODBC=no disables its native dependency.'
        }
        if ($env:HB_WITH_ODBC -ne 'yes') { $odbcHeaderRoots = @($env:HB_WITH_ODBC) }
    }
    $odbcHeadersExist = $false
    foreach ($headerRoot in $odbcHeaderRoots) {
        $odbcHeadersExist = $odbcHeadersExist -or (Test-Path -LiteralPath (Join-Path $headerRoot 'sql.h') -PathType Leaf)
    }
    if (-not $odbcHeadersExist) {
        throw 'Linux unixODBC development headers are required (sql.h). Install unixodbc-dev or unixODBC-devel, or set HB_WITH_ODBC to the include directory.'
    }
}

# Preserve the pinned Harbour checkout; patch only a disposable managed copy.
$stageRoot = Join-Path $managedODBCRoot ('stage-' + [Guid]::NewGuid().ToString('N'))
$buildRoot = Join-Path $stageRoot 'build'
New-Item -ItemType Directory -Path $buildRoot | Out-Null
Copy-Item -LiteralPath (Join-Path $toolchain.HarbourRoot 'contrib/sddodbc') -Destination $stageRoot -Recurse
$git = Get-Command git -ErrorAction Stop
$gitPath = $git.Source
if ($IsWindows -and $env:ProgramFiles) {
    $nativeGit = Join-Path $env:ProgramFiles 'Git/cmd/git.exe'
    if (Test-Path -LiteralPath $nativeGit -PathType Leaf) { $gitPath = $nativeGit }
}
$relativeStage = [IO.Path]::GetRelativePath($projectRoot, $stageRoot).Replace('\', '/')
Push-Location -LiteralPath $projectRoot
try {
    & $gitPath -c "safe.directory=$($projectRoot.Replace('\', '/'))" apply --no-index `
        --check --ignore-space-change "--directory=$relativeStage" $patchFile
    if ($LASTEXITCODE -ne 0) { throw 'The reviewed SDDODBC patch does not apply to the pinned source.' }
    & $gitPath -c "safe.directory=$($projectRoot.Replace('\', '/'))" apply --no-index `
        --ignore-space-change "--directory=$relativeStage" $patchFile
    if ($LASTEXITCODE -ne 0) { throw 'Could not apply the reviewed SDDODBC patch.' }
}
finally { Pop-Location }

$previousEnvironment = Enter-HBBridgeToolchain -Toolchain $toolchain
try {
    New-Item -ItemType Directory -Force -Path $libraryRoot, $installModule, $includeRoot | Out-Null
    $moduleRoot = Join-Path $stageRoot 'sddodbc'
    & $toolchain.Hbmk2 "-comp=$($toolchain.Compiler)" (Join-Path $moduleRoot 'sddodbc.hbp') `
        "-I$(Join-Path $toolchain.HarbourRoot 'contrib/rddsql')" `
        "-o$(Join-Path $libraryRoot 'sddodbc')" "-workdir=$buildRoot"
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $libraryFile -PathType Leaf)) {
        throw 'Could not compile the managed SDDODBC library. Check the native ODBC development dependencies.'
    }
    Copy-Item -LiteralPath (Join-Path $moduleRoot 'sddodbc.hbc') -Destination $installModule -Force
    Get-ChildItem -LiteralPath $moduleRoot -File | Where-Object { $_.Extension -in '.ch', '.hbx' } |
        Copy-Item -Destination $includeRoot -Force
    @{
        harbourRevision = $dependencies.harbour.revision
        patchSha256 = $patchHash
        librarySha256 = (Get-FileHash -LiteralPath $libraryFile -Algorithm SHA256).Hash
        platform = $libraryPlatform
        compiler = $toolchain.Compiler
        stage = $stageRoot
    } | ConvertTo-Json | Set-Content -LiteralPath $receiptFile -Encoding utf8
    Write-Host 'Managed SDDODBC library is ready.'
}
finally { Exit-HBBridgeToolchain -PreviousEnvironment $previousEnvironment }
