#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $AppServerDirectory,
    [Parameter(Mandatory)][string] $IniFile,
    [Parameter(Mandatory)][string[]] $IncludeDirectory,
    [string] $Environment = 'PROTHEUS',
    [switch] $CompileAll,
    [string] $Python = 'python'
)

$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$sdkSource = [IO.Path]::GetFullPath($AppServerDirectory)
$sourceIni = [IO.Path]::GetFullPath($IniFile)
$runRoot = Join-Path $projectRoot ('tmp/protheus-http-gzip-' + [guid]::NewGuid().ToString('N'))
$sdkRoot = Join-Path $runRoot 'sdk'
$rpoRoot = Join-Path $runRoot 'rpo'
$dataRoot = Join-Path $runRoot 'data'
foreach ($directory in @($sdkRoot, $rpoRoot, (Join-Path $dataRoot 'system'), (Join-Path $dataRoot 'fixtures'))) {
    [IO.Directory]::CreateDirectory($directory) | Out-Null
}

function Read-GzipIniSections {
    param([string] $Path)
    $sections = @{}
    $section = ''
    foreach ($line in [IO.File]::ReadAllLines($Path)) {
        if ($line -match '^\s*\[([^]]+)\]') {
            $section = $Matches[1]
            if (-not $sections.ContainsKey($section)) { $sections[$section] = @{} }
        } elseif ($section -and $line -match '^\s*([^;#=][^=]*)=(.*)$') {
            $sections[$section][$Matches[1].Trim()] = $Matches[2].Trim()
        }
    }
    return $sections
}

function Invoke-GzipAppServer {
    param([string[]] $Arguments, [string] $OutputFile)
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = Join-Path $sdkRoot 'appserver.exe'
    $info.WorkingDirectory = $sdkRoot
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    foreach ($argument in $Arguments) { $info.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    $started = $false
    try {
        if (-not $process.Start()) { throw 'Isolated gzip AppServer did not start.' }
        $started = $true
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        $clock = [Diagnostics.Stopwatch]::StartNew()
        while (-not $process.WaitForExit(500)) {
            if ($clock.Elapsed.TotalSeconds -gt 60) {
                $process.Kill($true)
                $process.WaitForExit()
                throw 'Isolated gzip AppServer exceeded its 60-second budget.'
            }
        }
        $output = ($stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult()).Replace("`0", '')
        # Store only the probe's sanitized observations. Never publish the INI.
        $observations = @($output -split '\r?\n' | Where-Object { $_ -match 'HBBRIDGE_HTTP_GZIP ' })
        [IO.File]::WriteAllLines($OutputFile, $observations, [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText($OutputFile + '.raw', $output, [Text.UTF8Encoding]::new($false))
        return [pscustomobject]@{ ExitCode = $process.ExitCode; Output = $output; Observations = $observations }
    } finally {
        if ($started -and -not $process.HasExited) { $process.Kill($true); $process.WaitForExit() }
        $process.Dispose()
    }
}

$sections = Read-GzipIniSections -Path $sourceIni
if (-not $sections.ContainsKey($Environment) -or -not $sections[$Environment].ContainsKey('SourcePath')) {
    throw 'The selected external INI must define an environment SourcePath.'
}
if (-not $sections.ContainsKey('LicenseClient')) { throw 'An external LicenseClient section is required.' }
$baseRpoRoot = $sections[$Environment]['SourcePath']
if (-not [IO.Path]::IsPathRooted($baseRpoRoot)) { $baseRpoRoot = Join-Path $sdkSource $baseRpoRoot }
foreach ($file in Get-ChildItem -LiteralPath $sdkSource -File) {
    if ($file.Extension -in @('.exe', '.dll', '.qm') -or $file.Name -in @('tlpp.rpo', 'language.ini')) {
        Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $sdkRoot $file.Name)
    }
}
foreach ($file in Get-ChildItem -LiteralPath $baseRpoRoot -Filter '*.rpo' -File) {
    if ($file.Name -ne 'custom.rpo') { Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $rpoRoot $file.Name) }
}

$fixtureSource = @'
import gzip
import json
import pathlib
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

root = pathlib.Path(sys.argv[1])
payload = json.dumps({"success": True, "payload": "X" * 200000, "accent": "a\u00e7\u00e3o", "nul": "x\u0000y"}, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
(root / "data" / "fixtures" / "body.json").write_bytes(payload)
compressed = gzip.compress(payload, mtime=0)
corrupt = compressed[:-8] + bytes([compressed[-8] ^ 1]) + compressed[-7:]
flaky_calls = 0

class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    def log_message(self, *args):
        pass
    def do_GET(self):
        global flaky_calls
        route = self.path.strip("/")
        plain = route == "identity" or route.startswith(("client-identity/", "client-required-plain/", "client-required-empty/"))
        empty = route.startswith("client-required-empty/")
        damaged = route == "corrupt-gzip"
        if route.startswith("client-flaky/"):
            flaky_calls += 1
            damaged = flaky_calls == 1
        body = b"" if empty else (payload if plain else (corrupt if damaged else compressed))
        expected_accept = "gzip, identity;q=0" if route.startswith("client-required") else ("identity" if plain else "gzip")
        if self.headers.get("Accept-Encoding", "") != expected_accept:
            self.send_error(400)
            return
        self.send_response(406 if empty else 200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Connection", "close")
        if not plain:
            self.send_header("Content-Encoding", "gzip")
        if route == "chunked-gzip":
            self.send_header("Transfer-Encoding", "chunked")
        else:
            self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if route == "chunked-gzip":
            for offset in range(0, len(body), 7):
                piece = body[offset:offset + 7]
                self.wfile.write(("%x\r\n" % len(piece)).encode("ascii") + piece + b"\r\n")
            self.wfile.write(b"0\r\n\r\n")
        else:
            self.wfile.write(body)
        with (root / "fixture.jsonl").open("a", encoding="utf-8") as receipt:
            receipt.write(json.dumps({"route": route, "acceptEncoding": expected_accept, "wireBytes": len(body), "plainBytes": len(payload), "gzipMagic": body[:2] == b"\x1f\x8b"}) + "\n")

server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
(root / "port.txt").write_text(str(server.server_port), encoding="ascii")
server.serve_forever()
'@
$fixturePath = Join-Path $runRoot 'fixture.py'
[IO.File]::WriteAllText($fixturePath, $fixtureSource, [Text.UTF8Encoding]::new($false))
$fixtureInfo = [Diagnostics.ProcessStartInfo]::new()
$fixtureInfo.FileName = $Python
$fixtureInfo.WorkingDirectory = $runRoot
$fixtureInfo.UseShellExecute = $false
$fixtureInfo.CreateNoWindow = $true
$fixtureInfo.ArgumentList.Add($fixturePath)
$fixtureInfo.ArgumentList.Add($runRoot)
$fixture = [Diagnostics.Process]::new()
$fixture.StartInfo = $fixtureInfo
$fixtureStarted = $false
try {
    if (-not $fixture.Start()) { throw 'Loopback gzip fixture did not start.' }
    $fixtureStarted = $true
    $readyClock = [Diagnostics.Stopwatch]::StartNew()
    $portFile = Join-Path $runRoot 'port.txt'
    while (-not (Test-Path -LiteralPath $portFile)) {
        if ($fixture.HasExited -or $readyClock.Elapsed.TotalSeconds -gt 10) { throw 'Loopback gzip fixture was not ready.' }
        Start-Sleep -Milliseconds 100
    }
    $port = [IO.File]::ReadAllText($portFile).Trim()
    $ini = [Collections.Generic.List[string]]::new()
    $ini.Add("[$Environment]")
    foreach ($setting in @{
        SourcePath = $rpoRoot; RpoCustom = (Join-Path $rpoRoot 'custom.rpo'); RootPath = $dataRoot
        StartPath = '\system\'; RpoDb = 'TOP'; RpoLanguage = 'multi'; RpoVersion = '120'; LocalFiles = 'SQLITE'
    }.GetEnumerator()) { $ini.Add($setting.Key + '=' + $setting.Value) }
    $ini.Add('[LicenseClient]')
    foreach ($setting in $sections['LicenseClient'].GetEnumerator()) { $ini.Add($setting.Key + '=' + $setting.Value) }
    $ini.Add('[TDS]')
    $ini.Add('AllowApplyPatch=*')
    $ini.Add('AllowEdit=*')
    $portProbe = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    $portProbe.Start()
    try { $driverPort = $portProbe.LocalEndpoint.Port } finally { $portProbe.Stop() }
    $ini.Add('[Drivers]')
    $ini.Add('Active=TCP')
    $ini.Add('[TCP]')
    $ini.Add('Type=TCPIP')
    $ini.Add("Port=$driverPort")
    $ini.Add('[HBGzipProbe]')
    $ini.Add("URL=http://127.0.0.1:$port")
    [IO.File]::WriteAllLines((Join-Path $sdkRoot 'appserver.ini'), $ini, [Text.UTF8Encoding]::new($false))
    $sourceList = Join-Path $runRoot 'sources.lst'
    $sources = @('src/tlpp/hbbridge.json.tlpp', 'src/tlpp/hbbridge.http.client.tlpp',
        'src/tlpp/tests/protheus/hbbridge.http.test/hbbridge.http.gzip.probe.tlpp') | ForEach-Object { Join-Path $projectRoot $_ }
    if ($CompileAll) {
        $sources = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'src/tlpp') -Filter '*.tlpp' -Recurse -File |
            Sort-Object FullName | ForEach-Object FullName)
    }
    [IO.File]::WriteAllText($sourceList, ($sources -join ';') + ';', [Text.UTF8Encoding]::new($false))
    $includes = (@($IncludeDirectory) + (Join-Path $projectRoot 'includes')) -join ';'
    $compile = Invoke-GzipAppServer -Arguments @('-compile', "-files=$sourceList", "-includes=$includes", "-env=$Environment", "-consolefile=$(Join-Path $runRoot 'compile.log')") -OutputFile (Join-Path $runRoot 'compile-observations.log')
    $expectedCompile = 'Total sources\(' + $sources.Count + '\) Success\(' + $sources.Count + '\) Errors\(0\)'
    if ($compile.ExitCode -ne 0 -or $compile.Output -notmatch $expectedCompile) {
        throw "Isolated gzip probe compilation failed or did not compile all $($sources.Count) sources (exit $($compile.ExitCode)); inspect the private scratch compile log."
    }
    $run = Invoke-GzipAppServer -Arguments @('-run=U_HBBridgeHTTPGzipProbe', "-env=$Environment") -OutputFile (Join-Path $runRoot 'observations.log')
    $run.Observations | Write-Output
    if ($run.ExitCode -ne 0 -or -not ($run.Output -match 'HBBRIDGE_HTTP_GZIP \{"checks":14,"failures":0\}')) {
        throw "Isolated gzip probe failed or did not complete (exit $($run.ExitCode)). Scratch: $runRoot"
    }
    Get-Content -LiteralPath (Join-Path $runRoot 'fixture.jsonl')
    Write-Host "HTTP gzip probe output: $runRoot"
} finally {
    if ($fixtureStarted -and -not $fixture.HasExited) { $fixture.Kill($true); $fixture.WaitForExit() }
    $fixture.Dispose()
}
