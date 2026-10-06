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
$patchDefinition = $dependencies.harbour.httpPatch
$patchFile = Join-Path $projectRoot $patchDefinition.path
$patchHash = (Get-FileHash -LiteralPath $patchFile -Algorithm SHA256).Hash
if ($patchHash -ne $patchDefinition.sha256) {
    throw 'The managed hbhttpd patch checksum does not match config/dependencies.json.'
}

$installRoot = Split-Path -Parent $toolchain.HarbourBin
$libraryPlatform = if ($IsWindows) { 'win' } else { 'linux' }
$libraryRoot = Join-Path $installRoot "lib/$libraryPlatform/$($toolchain.Compiler)"
$managedHTTPRoot = Join-Path $projectRoot '.deps/http'
$receiptFile = Join-Path $managedHTTPRoot 'receipt.json'
New-Item -ItemType Directory -Force -Path $managedHTTPRoot | Out-Null
$tlsEnabled = $env:HB_HTTP_TLS -eq '1'
if (-not [string]::IsNullOrWhiteSpace($env:HB_HTTP_TLS) -and -not $tlsEnabled) {
    throw 'To link direct TLS, set HB_HTTP_TLS=1; leave it unset for plain HTTP.'
}
$requiredLibraries = @('hbhttpd', 'hbtcpio')
if ($tlsEnabled) { $requiredLibraries += 'hbssl' }
$librariesExist = $true
foreach ($library in $requiredLibraries) {
    $librariesExist = $librariesExist -and (Test-Path -LiteralPath (Join-Path $libraryRoot "lib$library.a"))
}
if (-not $ForceBuild -and $librariesExist -and (Test-Path -LiteralPath $receiptFile)) {
    $receipt = Get-Content -LiteralPath $receiptFile -Raw | ConvertFrom-Json -AsHashtable
    $librariesMatch = $true
    foreach ($library in $requiredLibraries) {
        $actualHash = (Get-FileHash -LiteralPath (Join-Path $libraryRoot "lib$library.a") -Algorithm SHA256).Hash
        $librariesMatch = $librariesMatch -and $receipt.libraryHashes -and
            ($receipt.libraryHashes[$library] -eq $actualHash)
    }
    if ($receipt.harbourRevision -eq $dependencies.harbour.revision -and
        $receipt.patchSha256 -eq $patchHash -and $receipt.tls -eq $tlsEnabled -and $librariesMatch) {
        Write-Host 'Managed hbhttpd and hbtcpio are ready.'
        return
    }
}

# Patch a disposable project-owned copy; preserve the pinned Harbour checkout.
$stageRoot = Join-Path $managedHTTPRoot ('stage-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $stageRoot | Out-Null
foreach ($module in @('hbhttpd', 'hbtcpio')) {
    Copy-Item -LiteralPath (Join-Path $toolchain.HarbourRoot "contrib/$module") -Destination $stageRoot -Recurse
}
Copy-Item -LiteralPath (Join-Path $toolchain.HarbourRoot 'contrib/hbssl/hbssl.hbc') `
    -Destination (Join-Path $stageRoot 'hbhttpd/hbssl.hbc')
Get-ChildItem -LiteralPath (Join-Path $toolchain.HarbourRoot 'contrib/hbssl') -File |
    Where-Object { $_.Extension -in '.ch', '.hbx' } |
    Copy-Item -Destination (Join-Path $stageRoot 'hbhttpd')
$git = Get-Command git -ErrorAction Stop
if ($IsWindows -and $env:ProgramFiles) {
    $nativeGit = Join-Path $env:ProgramFiles 'Git/cmd/git.exe'
    if (Test-Path -LiteralPath $nativeGit -PathType Leaf) { $gitPath = $nativeGit }
}
if (-not $gitPath) { $gitPath = $git.Source }
$relativeStage = [System.IO.Path]::GetRelativePath($projectRoot, $stageRoot).Replace('\', '/')
Push-Location -LiteralPath $projectRoot
try {
    # A project-relative --directory also prevents Git from skipping this
    # ignored dependency directory when it discovers the project's repository.
    & $gitPath -c "safe.directory=$($projectRoot.Replace('\', '/'))" apply --no-index `
        --check --ignore-space-change "--directory=$relativeStage" $patchFile
    if ($LASTEXITCODE -ne 0) { throw 'The reviewed hbhttpd patch does not apply to the pinned source.' }
    & $gitPath -c "safe.directory=$($projectRoot.Replace('\', '/'))" apply --no-index `
        --ignore-space-change "--directory=$relativeStage" $patchFile
    if ($LASTEXITCODE -ne 0) { throw 'Could not apply the reviewed hbhttpd patch.' }
}
finally { Pop-Location }
$patchedCore = Get-Content -LiteralPath (Join-Path $stageRoot 'hbhttpd/core.prg') -Raw
if (-not $patchedCore.Contains('server[ "REQUEST_BODY" ] := cRequest') -or
    -not $patchedCore.Contains('Len( aThreads ) < ::hConfig[ "MaxWorkers" ]') -or
    -not $patchedCore.Contains('Eval( ::hConfig[ "Ready" ], Self )') -or
    -not $patchedCore.Contains('DO WHILE hb_BAt( CR_LF + CR_LF, cRequest ) == 0 .AND. ! oServer:lStop') -or
    -not $patchedCore.Contains('UAddHeader( "Content-Length", hb_ntos( hb_BLen( t_cResult ) ) )')) {
    throw 'The hbhttpd patch was not applied completely.'
}

$previousEnvironment = Enter-HBBridgeToolchain -Toolchain $toolchain
try {
    foreach ($module in @('hbhttpd', 'hbtcpio')) {
        $moduleRoot = Join-Path $stageRoot $module
        & $toolchain.Hbmk2 "-comp=$($toolchain.Compiler)" (Join-Path $moduleRoot "$module.hbp") `
            "-I$(Join-Path $toolchain.HarbourRoot 'contrib/hbssl')" "-o$(Join-Path $libraryRoot $module)"
        if ($LASTEXITCODE -ne 0) { throw "Could not compile the managed $module library." }
        $installModule = Join-Path $installRoot "contrib/$module"
        New-Item -ItemType Directory -Force -Path $installModule | Out-Null
        Copy-Item -LiteralPath (Join-Path $moduleRoot "$module.hbc") -Destination $installModule -Force
        Get-ChildItem -LiteralPath $moduleRoot -File | Where-Object { $_.Extension -in '.ch', '.hbx' } |
            Copy-Item -Destination (Join-Path $installRoot 'include') -Force
    }
    if ($tlsEnabled) {
        # OpenSSL is an external SDK: HB_WITH_OPENSSL selects its include root.
        # Linux uses distribution development packages; Windows may use hb_compile's resolver.
        $sslRoot = Join-Path $toolchain.HarbourRoot 'contrib/hbssl'
        & $toolchain.Hbmk2 "-comp=$($toolchain.Compiler)" (Join-Path $sslRoot 'hbssl.hbp') `
            "-o$(Join-Path $libraryRoot 'hbssl')"
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath (Join-Path $libraryRoot 'libhbssl.a'))) {
            throw 'TLS requested but hbssl could not be built. Configure the OpenSSL SDK and runtime libraries.'
        }
        $installSSL = Join-Path $installRoot 'contrib/hbssl'
        New-Item -ItemType Directory -Force -Path $installSSL | Out-Null
        Copy-Item -LiteralPath (Join-Path $sslRoot 'hbssl.hbc') -Destination $installSSL -Force
        Get-ChildItem -LiteralPath $sslRoot -File | Where-Object { $_.Extension -in '.ch', '.hbx' } |
            Copy-Item -Destination (Join-Path $installRoot 'include') -Force
    }
    $libraryHashes = @{}
    foreach ($library in $requiredLibraries) {
        $libraryHashes[$library] = (Get-FileHash -LiteralPath (Join-Path $libraryRoot "lib$library.a") -Algorithm SHA256).Hash
    }
    @{
        harbourRevision = $dependencies.harbour.revision
        patchSha256 = $patchHash
        tls = $tlsEnabled
        libraryHashes = $libraryHashes
        stage = $stageRoot
    } | ConvertTo-Json | Set-Content -LiteralPath $receiptFile -Encoding utf8
    Write-Host "Managed HTTP libraries are ready; direct TLS linked: $tlsEnabled"
}
finally { Exit-HBBridgeToolchain -PreviousEnvironment $previousEnvironment }
