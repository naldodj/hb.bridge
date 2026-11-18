#Requires -Version 7.0

function Get-HBBridgePlatform {
    $operatingSystem = if ($IsWindows) { 'windows' } elseif ($IsLinux) { 'linux' } else {
        throw 'The managed toolchain currently supports Windows and Linux.'
    }
    $architecture = switch ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()) {
        'X64' { 'x86_64' }
        'Arm64' { 'aarch64' }
        default { throw 'The managed toolchain currently supports x64 and ARM64.' }
    }
    return "$architecture-$operatingSystem"
}

function Get-HBBridgeDependencies {
    param([Parameter(Mandatory)][string] $ProjectRoot)
    return Get-Content -LiteralPath (Join-Path $ProjectRoot 'config/dependencies.json') -Raw |
        ConvertFrom-Json -AsHashtable
}

function Get-HBBridgeHarbourProfile {
    param([string] $Compiler)

    if ([string]::IsNullOrWhiteSpace($Compiler)) { $Compiler = $env:HBBRIDGE_HARBOUR_COMPILER }
    if ([string]::IsNullOrWhiteSpace($Compiler)) { $Compiler = 'zig' }
    $Compiler = $Compiler.Trim().ToLowerInvariant()
    if ($Compiler -notin @('zig', 'gcc')) {
        throw "Unknown Harbour compiler '$Compiler'. Choose zig or gcc."
    }
    if ($IsWindows -and $Compiler -ne 'zig') {
        throw 'The GCC Harbour profile is available only on Linux.'
    }

    $platform = if ($IsWindows) { 'win' } else { 'linux' }
    $name = if ($IsWindows) { 'zig' } elseif ($Compiler -eq 'gcc') { 'linux' } else { 'linux-zig' }
    return @{
        Name = $name
        Compiler = $Compiler
        Platform = $platform
        LibraryDirectory = "lib/$platform/$Compiler"
    }
}

function Get-HBBridgeManagedContribRoot {
    param(
        [Parameter(Mandatory)][string] $ProjectRoot,
        [Parameter(Mandatory)][string] $Name,
        [Parameter(Mandatory)][hashtable] $Toolchain
    )

    $path = Join-Path $ProjectRoot ".deps/$Name"
    if ($Toolchain.Profile -eq 'linux-zig') {
        $path = Join-Path $path $Toolchain.Profile
    }
    return $path
}

function Resolve-HBBridgeToolchain {
    param(
        [Parameter(Mandatory)][string] $ProjectRoot,
        [string] $HbCompileRoot,
        [string] $ZigPath
    )

    $dependencies = Get-HBBridgeDependencies -ProjectRoot $ProjectRoot
    $managedRoot = Join-Path $ProjectRoot '.deps'
    if ([string]::IsNullOrWhiteSpace($HbCompileRoot)) {
        $HbCompileRoot = Join-Path $managedRoot 'hb_compile'
    }
    $HbCompileRoot = [System.IO.Path]::GetFullPath($HbCompileRoot)
    $profile = Get-HBBridgeHarbourProfile
    $extension = if ($IsWindows) { '.exe' } else { '' }
    $harbourBin = Join-Path $HbCompileRoot "out/$($profile.Name)/bin"
    $hbmk2 = Join-Path $harbourBin "hbmk2$extension"
    $hbrun = Join-Path $harbourBin "hbrun$extension"
    foreach ($required in @($hbmk2, $hbrun)) {
        if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
            throw "Managed Harbour tool not found: $required. Run pwsh ./scripts/bootstrap.ps1 -Compiler $($profile.Compiler) first."
        }
    }

    if ([string]::IsNullOrWhiteSpace($ZigPath)) {
        $platform = Get-HBBridgePlatform
        $zigRoot = Join-Path $managedRoot "tools/zig/$($dependencies.zig.version)"
        $ZigPath = Join-Path $zigRoot "zig-$platform-$($dependencies.zig.version)/zig$extension"
    }
    if (-not (Test-Path -LiteralPath $ZigPath -PathType Leaf)) {
        throw "Pinned Zig not found: $ZigPath. Run pwsh ./scripts/bootstrap.ps1, or pass an explicit -ZigPath."
    }
    $zigVersion = ([string] (& $ZigPath version)).Trim()
    if ($LASTEXITCODE -ne 0 -or $zigVersion -ne $dependencies.zig.version) {
        throw "Zig $($dependencies.zig.version) is required; found '$zigVersion' at $ZigPath."
    }

    return @{
        HbCompileRoot = $HbCompileRoot
        HarbourRoot = Join-Path $managedRoot 'harbour'
        HarbourBin = $harbourBin
        Hbmk2 = $hbmk2
        Hbrun = $hbrun
        Zig = [System.IO.Path]::GetFullPath($ZigPath)
        Compiler = $profile.Compiler
        Profile = $profile.Name
        HarbourPlatform = $profile.Platform
        LibraryDirectory = $profile.LibraryDirectory
        ExecutableExtension = $extension
    }
}

function Enter-HBBridgeToolchain {
    param([Parameter(Mandatory)][hashtable] $Toolchain)
    $installRoot = Split-Path -Parent $Toolchain.HarbourBin
    $environment = @{
        PATH = $Toolchain.HarbourBin + [System.IO.Path]::PathSeparator +
            [System.IO.Path]::GetDirectoryName($Toolchain.Zig) + [System.IO.Path]::PathSeparator + $env:PATH
        HB_COMPILER = $Toolchain.Compiler
        HB_PLATFORM = $Toolchain.HarbourPlatform
        HB_INSTALL_PREFIX = $installRoot
        HB_INSTALL_BIN = $Toolchain.HarbourBin
        HB_INSTALL_INC = Join-Path $installRoot 'include'
        HB_INSTALL_LIB = Join-Path $installRoot $Toolchain.LibraryDirectory
        HB_BUILD_NAME = $null
        HB_HOST_BIN = $Toolchain.HarbourBin
        # hbmk2's Zig compiler command is "zig cc". Prefixing HB_CCPATH can
        # quote the complete string as an executable name; select it via PATH.
        HB_CCPATH = $null
        HB_CCPREFIX = $null
        HB_CCPOSTFIX = $null
    }
    $previousEnvironment = @{}
    foreach ($key in $environment.Keys) {
        $previousEnvironment[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
        [Environment]::SetEnvironmentVariable($key, $environment[$key], 'Process')
    }
    return $previousEnvironment
}

function Exit-HBBridgeToolchain {
    param([Parameter(Mandatory)][hashtable] $PreviousEnvironment)
    foreach ($key in $PreviousEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable($key, $PreviousEnvironment[$key], 'Process')
    }
}
