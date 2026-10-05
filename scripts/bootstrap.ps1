#Requires -Version 7.0
[CmdletBinding()]
param(
    [int] $Jobs = 0,
    [switch] $SkipHarbourBuild,
    [switch] $ForceBuild
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'toolchain.ps1')
$dependencies = get-hbbridgedependencies -ProjectRoot $projectRoot
$platform = get-hbbridgeplatform
$managedRoot = Join-Path $projectRoot '.deps'
New-Item -ItemType Directory -Force -Path $managedRoot | Out-Null

# Prefer native Windows Git over a Cygwin executable, which interprets drive paths differently.
$git = Get-Command git -ErrorAction Stop
if ($IsWindows -and $env:ProgramFiles) {
    $nativeGit = Join-Path $env:ProgramFiles 'Git/cmd/git.exe'
    if (Test-Path -LiteralPath $nativeGit -PathType Leaf) {
        $git = Get-Item -LiteralPath $nativeGit
    }
}
$gitPath = if ($git -is [System.IO.FileInfo]) { $git.FullName } else { $git.Source }

function invoke-dependencygit {
    param([Parameter(Mandatory)][string] $Checkout, [Parameter(Mandatory)][string[]] $Arguments)
    & $gitPath -c "safe.directory=$($Checkout.Replace('\', '/'))" -C $Checkout @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Git failed for managed dependency $Checkout." }
}

function initialize-dependency {
    param([Parameter(Mandatory)][string] $Name, [Parameter(Mandatory)][hashtable] $Definition)
    $checkout = Join-Path $managedRoot $Name
    if (-not (Test-Path -LiteralPath (Join-Path $checkout '.git'))) {
        if (Test-Path -LiteralPath $checkout) {
            throw "Dependency directory already exists without Git metadata: $checkout. Move it aside before bootstrap."
        }
        New-Item -ItemType Directory -Path $checkout | Out-Null
        invoke-dependencygit -Checkout $checkout -Arguments @('init', '--quiet')
        invoke-dependencygit -Checkout $checkout -Arguments @('remote', 'add', 'origin', $Definition.repository)
        invoke-dependencygit -Checkout $checkout -Arguments @('fetch', '--depth=1', 'origin', $Definition.revision)
        invoke-dependencygit -Checkout $checkout -Arguments @('checkout', '--detach', '--quiet', 'FETCH_HEAD')
    }
    $actualRevision = ([string] (invoke-dependencygit -Checkout $checkout -Arguments @('rev-parse', 'HEAD'))).Trim()
    if ($actualRevision -ne $Definition.revision) {
        throw "Dependency $Name is at $actualRevision; expected $($Definition.revision). Bootstrap preserves existing checkouts; move $checkout aside to resolve the new pin."
    }
    $origin = ([string] (invoke-dependencygit -Checkout $checkout -Arguments @('remote', 'get-url', 'origin'))).Trim()
    if ($origin -ne $Definition.repository) { throw "Unexpected origin for managed dependency $Name." }
    return $checkout
}

function initialize-zig {
    $version = $dependencies.zig.version
    $archive = $dependencies.zig.archives[$platform]
    if (-not $archive) { throw "No pinned Zig archive for $platform." }
    $extension = if ($IsWindows) { '.exe' } else { '' }
    $zigRoot = Join-Path $managedRoot "tools/zig/$version"
    $zigPath = Join-Path $zigRoot "zig-$platform-$version/zig$extension"
    if (Test-Path -LiteralPath $zigPath -PathType Leaf) {
        $actualVersion = ([string] (& $zigPath version)).Trim()
        if ($LASTEXITCODE -eq 0 -and $actualVersion -eq $version) { return $zigPath }
        throw "Existing managed Zig is invalid: $zigPath. Move its version directory aside and retry."
    }
    $downloadRoot = Join-Path $managedRoot 'downloads'
    New-Item -ItemType Directory -Force -Path $downloadRoot, $zigRoot | Out-Null
    $downloadFile = Join-Path $downloadRoot ([System.IO.Path]::GetFileName(([uri] $archive.url).AbsolutePath))
    if (-not (Test-Path -LiteralPath $downloadFile)) {
        Write-Host "Downloading pinned Zig $version for $platform."
        Invoke-WebRequest -Uri $archive.url -OutFile $downloadFile
    }
    $actualHash = (Get-FileHash -LiteralPath $downloadFile -Algorithm SHA256).Hash
    if ($actualHash -ne $archive.sha256) {
        throw "Zig archive checksum mismatch: $downloadFile. Remove this file and retry."
    }
    if ($IsWindows) {
        Expand-Archive -LiteralPath $downloadFile -DestinationPath $zigRoot -Force
    }
    else {
        $tar = Get-Command tar -ErrorAction Stop
        & $tar.Source -xf $downloadFile -C $zigRoot
        if ($LASTEXITCODE -ne 0) { throw 'Could not extract the pinned Zig archive; tar with xz support is required.' }
    }
    if (-not (Test-Path -LiteralPath $zigPath -PathType Leaf)) { throw 'The Zig archive did not contain the expected executable.' }
    return $zigPath
}

$hbCompileRoot = initialize-dependency -Name 'hb_compile' -Definition $dependencies.hbCompile
$harbourRoot = initialize-dependency -Name 'harbour' -Definition $dependencies.harbour
$zigPath = initialize-zig
if ($SkipHarbourBuild) {
    Write-Host 'Pinned dependency sources and Zig are ready. Run bootstrap without -SkipHarbourBuild to compile Harbour.'
    return
}

$profile = if ($IsWindows) { 'zig' } else { 'linux' }
$installRoot = Join-Path $hbCompileRoot "out/$profile"
$receiptFile = Join-Path $installRoot 'hbbridge-toolchain.json'
$manifestHash = (Get-FileHash -LiteralPath (Join-Path $projectRoot 'config/dependencies.json') -Algorithm SHA256).Hash
if (-not $ForceBuild -and (Test-Path -LiteralPath $receiptFile)) {
    $receipt = Get-Content -LiteralPath $receiptFile -Raw | ConvertFrom-Json -AsHashtable
    if ($receipt.manifestSha256 -eq $manifestHash -and $receipt.platform -eq $platform) {
        $null = resolve-hbbridgetoolchain -ProjectRoot $projectRoot
        Write-Host "Managed Harbour is ready: $installRoot"
        return
    }
}

if ($Jobs -le 0) { $Jobs = [System.Environment]::ProcessorCount }
$previousPath = $env:PATH
$env:PATH = [System.IO.Path]::GetDirectoryName($zigPath) + [System.IO.Path]::PathSeparator +
    [System.IO.Path]::GetDirectoryName($gitPath) + [System.IO.Path]::PathSeparator + $previousPath
try {
    $buildEnvironment = @{
        HB_BUILD_CONTRIBS = $dependencies.harbour.contribs
        HB_BUILD_DYN = 'no'
        HB_BUILD_SHARED = 'no'
        HB_BUILD_CONTRIB_DYN = 'no'
    }
    if ($IsWindows) {
        # GNU make otherwise may select a Cygwin/MSYS sh.exe from the ambient PATH.
        $buildEnvironment.SHELL = $env:ComSpec
        $buildEnvironment.HB_SHELL = 'nt'
        & (Join-Path $hbCompileRoot 'scripts/Invoke-HarbourBuild.ps1') -BuildProfile zig `
            -HarbourRoot $harbourRoot -ZigPath $zigPath -SkipToolBootstrap -Jobs $Jobs -Env $buildEnvironment
        if (-not $? -or $LASTEXITCODE -ne 0) { throw 'Managed Harbour build failed; inspect .deps/hb_compile/logs.' }
    }
    else {
        # hb_compile's published native runner targets Windows. Reuse its compatibility
        # preparation and pinned source, then build natively with the OS GNU toolchain.
        foreach ($commandName in @('make', 'gcc', 'ar', 'ld')) {
            if (-not (Get-Command $commandName -ErrorAction SilentlyContinue)) {
                throw "Linux prerequisite missing: $commandName. Install your distribution's build toolchain and unixODBC development headers."
            }
        }
        if (-not (Test-Path -LiteralPath '/usr/include/sql.h') -and -not (Test-Path -LiteralPath '/usr/local/include/sql.h')) {
            throw 'Linux unixODBC development headers are required (sql.h). Install unixodbc-dev or unixODBC-devel and retry.'
        }
        & (Join-Path $hbCompileRoot 'scripts/Prepare-HarbourCompatibility.ps1') -HarbourRoot $harbourRoot
        if (-not $?) { throw 'hb_compile compatibility preparation failed.' }
        $buildEnvironment.HB_INSTALL_PREFIX = $installRoot
        $buildEnvironment.HB_PLATFORM = 'linux'
        $buildEnvironment.HB_COMPILER = 'gcc'
        $buildEnvironment.HB_BUILD_JOBS = [string] $Jobs
        $oldEnvironment = @{}
        foreach ($key in $buildEnvironment.Keys) {
            $oldEnvironment[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
            [Environment]::SetEnvironmentVariable($key, $buildEnvironment[$key], 'Process')
        }
        $logRoot = Join-Path $hbCompileRoot 'logs'
        New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
        $logFile = Join-Path $logRoot ('hbbridge-linux-' + [DateTime]::UtcNow.ToString('yyyyMMddHHmmss') + '.log')
        Push-Location -LiteralPath $harbourRoot
        try {
            & make "-j$Jobs" install 2>&1 | Tee-Object -FilePath $logFile
            if ($LASTEXITCODE -ne 0) { throw "Native Linux Harbour build failed. Inspect $logFile." }
        }
        finally {
            Pop-Location
            foreach ($key in $oldEnvironment.Keys) {
                [Environment]::SetEnvironmentVariable($key, $oldEnvironment[$key], 'Process')
            }
        }
    }

    $null = resolve-hbbridgetoolchain -ProjectRoot $projectRoot
    $libraryDirectory = if ($IsWindows) { 'lib/win/zig' } else { 'lib/linux/gcc' }
    foreach ($library in @('hbnetio', 'rddsql', 'sddsqlt3', 'sddodbc')) {
        $expectedLibrary = Join-Path $installRoot "$libraryDirectory/lib$library.a"
        if (-not (Test-Path -LiteralPath $expectedLibrary -PathType Leaf)) {
            throw "Required Harbour library was not built: $expectedLibrary. Check the bootstrap log and OS dependencies."
        }
    }
    @{
        manifestSha256 = $manifestHash
        platform = $platform
        hbCompileRevision = $dependencies.hbCompile.revision
        harbourRevision = $dependencies.harbour.revision
        zigVersion = $dependencies.zig.version
    } | ConvertTo-Json | Set-Content -LiteralPath $receiptFile -Encoding utf8
    Write-Host "Managed Harbour tools and required libraries are ready: $installRoot"
}
finally {
    $env:PATH = $previousPath
}
