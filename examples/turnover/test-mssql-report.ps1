#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $Config,
    [Parameter(Mandatory)][string] $Profile,
    [Parameter(Mandatory)][string] $AddonRoot,
    [string] $Executable,
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z_][A-Za-z0-9_]{0,127}$')][string] $QueryTable,
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9]{1,20}$')][string] $QueryCode,
    [ValidatePattern('^[A-Za-z0-9]{1,20}$')][string] $BranchQueryCode,
    [ValidatePattern('^[A-Za-z0-9]{1,20}$')][string] $CostQueryCode,
    [ValidatePattern('^[A-Za-z0-9]{1,20}$')][string] $JobQueryCode,
    [ValidatePattern('^[A-Za-z0-9]{1,20}$')][string] $EmployeeQueryCode,
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9]+$')][string] $Company,
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9]+$')][string] $Branch,
    [string[]] $Branches,
    [Parameter(Mandatory)][ValidatePattern('^[0-9]{6}$')][string] $StartPeriod,
    [Parameter(Mandatory)][ValidatePattern('^[0-9]{6}$')][string] $EndPeriod,
    [Parameter(Mandatory)][hashtable] $TableMappings
)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$configuration = [IO.Path]::GetFullPath($Config)
$addonRoot = [IO.Path]::GetFullPath($AddonRoot)
if ([string]::IsNullOrWhiteSpace($Executable)) { $Executable = Join-Path $root 'out/hbbridge.exe' }
$serverExecutable = [IO.Path]::GetFullPath($Executable)
if (-not (Test-Path -LiteralPath $serverExecutable -PathType Leaf)) { throw 'Missing hbBridge executable.' }
if (-not (Test-Path -LiteralPath (Join-Path $addonRoot 'hbbridgeaddons.hrb'))) { throw 'Missing test addon.' }
foreach ($period in @($StartPeriod, $EndPeriod)) {
    $parsed = [datetime]::MinValue
    if (-not [datetime]::TryParseExact($period, 'yyyyMM', [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::None, [ref]$parsed)) { throw 'Periods must be valid calendar months.' }
}
if ([string]::CompareOrdinal($StartPeriod, $EndPeriod) -gt 0) { throw 'StartPeriod must not exceed EndPeriod.' }
foreach ($item in $Branches) { if ($item -notmatch '^[A-Za-z0-9]+$') { throw 'Invalid branch identifier.' } }
$branchList = if ($Branches.Count -gt 0) { ($Branches | ForEach-Object { "'$_'" }) -join ',' } else { $null }
$requiredMappings = @('SRA990', 'SRE990', 'SRJ990', 'CTT990', 'SR7990')
foreach ($name in $requiredMappings) {
    if (-not $TableMappings.ContainsKey($name) -or $TableMappings[$name] -notmatch '^[A-Za-z_][A-Za-z0-9_]{0,127}$') {
        throw 'Supply a resolved physical SQL identifier for each required source table.'
    }
}
$ini = @{}
$section = ''
foreach ($line in [IO.File]::ReadAllLines($configuration)) {
    if ($line -match '^\s*\[([^]]+)\]') { $section = $Matches[1] }
    elseif ($line -match '^\s*([^;#=]+)=(.*)$') {
        if (-not $ini.ContainsKey($section)) { $ini[$section] = @{} }
        $ini[$section][$Matches[1].Trim()] = $Matches[2].Trim()
    }
}
$sqlProfile = $ini['SQL/' + $Profile]
if ($null -eq $sqlProfile -or $sqlProfile.Driver -ne 'MSSQL' -or [string]::IsNullOrWhiteSpace($sqlProfile.DSN) -or
    [string]::IsNullOrWhiteSpace($sqlProfile.Database) -or [string]::IsNullOrWhiteSpace($sqlProfile.Username) -or
    [string]::IsNullOrWhiteSpace($sqlProfile.Password) -or [string]::IsNullOrWhiteSpace($ini.HTTP.Password)) {
    throw 'The profile must contain a configured MSSQL DSN, SQL login and HTTP token.'
}
$builder = [System.Data.Odbc.OdbcConnectionStringBuilder]::new()
$builder['DSN'] = $sqlProfile.DSN
$builder['DATABASE'] = $sqlProfile.Database
$builder['UID'] = $sqlProfile.Username
$builder['PWD'] = $sqlProfile.Password
$connection = [System.Data.Odbc.OdbcConnection]::new($builder.ConnectionString)
$process = $null
$table = '##HBB_' + [guid]::NewGuid().ToString('N')
$monthTable = '#HBBM_' + [guid]::NewGuid().ToString('N')
$branchTable = '##HBB_' + [guid]::NewGuid().ToString('N')
$costTable = '##HBB_' + [guid]::NewGuid().ToString('N')
$jobTable = '##HBB_' + [guid]::NewGuid().ToString('N')
$firstCost = $null
$firstCostHasTransfer = $false
$firstJob = $null
$firstJobHasTransfer = $false
$employeeTable = '##HBB_' + [guid]::NewGuid().ToString('N')
$fixtureTables = @()
if ($EmployeeQueryCode -and -not $JobQueryCode) { throw 'Employee validation requires the job query.' }
if ($JobQueryCode -and -not $CostQueryCode) { throw 'Job validation requires the cost-center query.' }
try {
    $connection.Open()
    $command = $connection.CreateCommand()
    $command.CommandText = "SELECT CAST(ZX__QUERY AS VARCHAR(MAX)) FROM [$QueryTable] WHERE ZX__CODIGO=? AND D_E_L_E_T_=''"
    [void]$command.Parameters.Add('code', [System.Data.Odbc.OdbcType]::VarChar, 20)
    $command.Parameters[0].Value = $QueryCode
    $sql = ([string]$command.ExecuteScalar()).TrimEnd([char]0)
    $command.Parameters.Clear()
    if ($sql.Contains([char]0)) { throw 'The registered SQL contains an embedded NUL.' }
    $anchor = '(?im)^\s*SELECT\s+DISTINCT\s*\r?\n\s*TURNOVERT\.PERIODO'
    if ([regex]::Matches($sql, $anchor).Count -ne 1 -or ([regex]::Matches($sql, 'INTO\s+!TABLENAME!', 'IgnoreCase')).Count -ne 1) {
        throw 'The registered source has an unsupported shape.'
    }
    $sql = [regex]::Replace($sql, $anchor, "`nINSERT INTO [$table] (PERIODO,TTRFSAI,TTRFENT,TFUNIMES,TFUNADMMES,TFUNMES,TFUNDEMMES,TFUNFMES,TURNOVER,TURNMOVF)`nSELECT DISTINCT`nTURNOVERT.PERIODO")
    $sql = [regex]::Replace($sql, 'INTO\s+!TABLENAME!', '', 'IgnoreCase')
    $replacements = @{
        '!TBLTMPMONTHS!' = $monthTable; '!EMPRESA!' = "'$Company'"; '!FILIALDE!' = "'$Branch'"; '!FILIALATE!' = "'$Branch'"
        '!DATARQDE!' = "'$StartPeriod'"; '!DATARQATE!' = "'$EndPeriod'"; '!CCDE!' = "''"; '!CCATE!' = "'z'"
        '!FUNCAODE!' = "''"; '!FUNCAOATE!' = "'z'"
    }
    if ($branchList) {
        foreach ($column in @('SRA.RA_FILIAL', 'PERIODO.RA_FILIAL')) {
            $expression = $column + ' BETWEEN !FILIALDE! AND !FILIALATE!'
            if (-not $sql.Contains($expression)) { throw 'Company branch predicate is missing.' }
            $sql = $sql.Replace($expression, $column + ' IN (' + $branchList + ')')
        }
        if ($sql.Contains('!FILIALDE!') -or $sql.Contains('!FILIALATE!')) { throw 'Unexpected company branch predicate.' }
    }
    foreach ($key in $replacements.Keys) { $sql = $sql.Replace($key, $replacements[$key]) }
    foreach ($name in $requiredMappings) {
        $sql = [regex]::Replace($sql, '(?i)(?<![A-Z0-9_])' + $name + '(?![A-Z0-9_])', '[' + $TableMappings[$name] + ']')
    }
    if ($sql -match '![A-Z_]+!') { throw 'Unresolved query parameter.' }
    $command.CommandText = "CREATE TABLE [$table] (PERIODO VARCHAR(6), TTRFSAI BIGINT, TTRFENT BIGINT, TFUNIMES FLOAT, TFUNADMMES FLOAT, TFUNMES FLOAT, TFUNDEMMES FLOAT, TFUNFMES FLOAT, TURNOVER FLOAT, TURNMOVF FLOAT)"
    [void]$command.ExecuteNonQuery()
    $ports = [Collections.Generic.HashSet[int]]::new()
    while ($ports.Count -lt 4) {
        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
        $listener.Start()
        [void]$ports.Add($listener.LocalEndpoint.Port)
        $listener.Stop()
    }
    $ports = @($ports)
    $launchArgs = @(('"-config=' + $configuration + '"'), '-host=127.0.0.1', "-port=$($ports[0])", '-netiohost=127.0.0.1',
        "-netioport=$($ports[1])", '-adminhost=127.0.0.1', "-adminport=$($ports[2])", '-httphost=127.0.0.1',
        "-httpport=$($ports[3])", ('"-addonroot=' + $addonRoot + '"'))
    $process = Start-Process -FilePath $serverExecutable -ArgumentList $launchArgs -WindowStyle Hidden -PassThru
    $headers = @{ Authorization = 'Bearer ' + $ini.HTTP.Password }
    $uri = "http://127.0.0.1:$($ports[3])/api/v1/rpc"
    $ready = $false
    for ($attempt = 0; $attempt -lt 100 -and -not $ready; $attempt++) {
        if ($process.HasExited) { break }
        try { $h = Invoke-RestMethod -Uri "http://127.0.0.1:$($ports[3])/api/v1/health" -Headers $headers -TimeoutSec 1; $ready = $h.success }
        catch { Start-Sleep -Milliseconds 200 }
    }
    if (-not $ready) { throw 'The isolated server did not start.' }
    $request = @{ service = 'RPCRDD.Execute'; params = @{ requestVersion = 1; alias = $Profile; sql = $sql } } | ConvertTo-Json -Depth 12 -Compress
    $execute = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -ContentType 'application/json' -Body $request -TimeoutSec 120
    if (-not $execute.success) { throw ('Execute did not complete: ' + $execute.code + '; outcome=' + $execute.outcome) }
    $branchSql = $null
    if ($BranchQueryCode) {
        $command.CommandText = "SELECT CAST(ZX__QUERY AS VARCHAR(MAX)) FROM [$QueryTable] WHERE ZX__CODIGO=? AND D_E_L_E_T_=''"
        [void]$command.Parameters.Add('code', [System.Data.Odbc.OdbcType]::VarChar, 20)
        $command.Parameters[0].Value = $BranchQueryCode
        $branchBatch = ([string]$command.ExecuteScalar()).TrimEnd([char]0)
        $command.Parameters.Clear()
        if ($branchBatch.Contains([char]0) -or ([regex]::Matches($branchBatch, $anchor)).Count -ne 1 -or
            ([regex]::Matches($branchBatch, 'INTO\s+!TABLENAME!', 'IgnoreCase')).Count -ne 1 -or
            $branchBatch -notmatch '(?is)SELECT\s+DISTINCT\s+TURNOVERT\.PERIODO\s*,\s*TURNOVERT\.RA_FILIAL') {
            throw 'The registered branch source has an unsupported shape.'
        }
        $branchBatch = [regex]::Replace($branchBatch, $anchor, "`nINSERT INTO [$branchTable] (PERIODO,RA_FILIAL,TTRFSAI,TTRFENT,TFUNIMES,TFUNADMMES,TFUNMES,TFUNDEMMES,TFUNFMES,TURNOVER,TURNMOVF)`nSELECT DISTINCT`nTURNOVERT.PERIODO")
        $branchBatch = [regex]::Replace($branchBatch, 'INTO\s+!TABLENAME!', '', 'IgnoreCase')
        $replacements['!TBLTMPMONTHS!'] = '#HBBM_' + [guid]::NewGuid().ToString('N')
        if ($branchList) {
            foreach ($column in @('SRA.RA_FILIAL', 'PERIODO.RA_FILIAL')) {
                $expression = $column + ' BETWEEN !FILIALDE! AND !FILIALATE!'
                if (-not $branchBatch.Contains($expression)) { throw 'Branch source predicate is missing.' }
                $branchBatch = $branchBatch.Replace($expression, $column + ' IN (' + $branchList + ')')
            }
            if ($branchBatch.Contains('!FILIALDE!') -or $branchBatch.Contains('!FILIALATE!')) { throw 'Unexpected branch predicate.' }
        }
        foreach ($key in $replacements.Keys) { $branchBatch = $branchBatch.Replace($key, $replacements[$key]) }
        foreach ($name in $requiredMappings) {
            $branchBatch = [regex]::Replace($branchBatch, '(?i)(?<![A-Z0-9_])' + $name + '(?![A-Z0-9_])', '[' + $TableMappings[$name] + ']')
        }
        if ($branchBatch -match '![A-Z_]+!') { throw 'Unresolved branch query parameter.' }
        $command.CommandText = "CREATE TABLE [$branchTable] (PERIODO VARCHAR(6), RA_FILIAL VARCHAR(32), TTRFSAI BIGINT, TTRFENT BIGINT, TFUNIMES FLOAT, TFUNADMMES FLOAT, TFUNMES FLOAT, TFUNDEMMES FLOAT, TFUNFMES FLOAT, TURNOVER FLOAT, TURNMOVF FLOAT)"
        [void]$command.ExecuteNonQuery()
        $request = @{ service = 'RPCRDD.Execute'; params = @{ requestVersion = 1; alias = $Profile; sql = $branchBatch } } | ConvertTo-Json -Depth 12 -Compress
        $execute = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -ContentType 'application/json' -Body $request -TimeoutSec 120
        if (-not $execute.success -or $execute.outcome -ne 'completed') { throw ('Branch Execute did not complete: ' + $execute.code + '; outcome=' + $execute.outcome) }
        $branchSql = "SELECT PERIODO,RA_FILIAL,TTRFSAI,TTRFENT,TFUNIMES,TFUNADMMES,TFUNMES,TFUNDEMMES,TFUNFMES,TURNOVER,TURNMOVF FROM [$branchTable] ORDER BY PERIODO,RA_FILIAL"
    }
    $sql = "SELECT PERIODO,TTRFSAI,TTRFENT,TFUNIMES,TFUNADMMES,TFUNMES,TFUNDEMMES,TFUNFMES,TURNOVER,TURNMOVF FROM [$table] ORDER BY PERIODO"
    $addonParams = @{ profile = $Profile; sql = $sql; bindings = @{} }
    if ($branchSql) { $addonParams.branchSql = $branchSql; $addonParams.branchBindings = @{} }
    $request = @{ service = 'ADDON.Execute'; params = @{ module = 'hbbridgeaddons.hrb'; params = @{ action = 'turnoverReport'; params = $addonParams } } } | ConvertTo-Json -Depth 12 -Compress
    $reply = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -ContentType 'application/json' -Body $request -TimeoutSec 120
    if (-not $reply.success) { throw ('Addon did not complete: ' + $reply.code) }
    $command.CommandText = "SELECT COUNT(*) FROM [$table]"
    $rowCount = [int]$command.ExecuteScalar()
    if ($rowCount -lt 2 -or $reply.rowCount -ne $rowCount) { throw 'Report row count mismatch.' }
    $command.CommandText = $sql
    $reader = $command.ExecuteReader()
    try {
        $names = @('transferOut', 'transferIn', 'initial', 'admissions', 'active', 'dismissals', 'final', 'turnoverPercent', 'dismissalPercent')
        while ($reader.Read()) {
            $period = $reader.GetString(0).Trim()
            $entry = $reply.periods.PSObject.Properties[$period]
            if ($null -eq $entry) { throw 'Report period is missing.' }
            for ($index = 0; $index -lt $names.Count; $index++) {
                $raw = [double]$reader.GetValue($index + 1)
                $mapped = [double]::Parse([string]$entry.Value.($names[$index]), [Globalization.CultureInfo]::InvariantCulture)
                if ([Math]::Abs($raw - $mapped) -gt 0.000000001) { throw 'Report measure mismatch.' }
            }
        }
    } finally { $reader.Dispose() }
    if ($branchSql) {
        $command.CommandText = $branchSql
        $reader = $command.ExecuteReader()
        $branchCount = 0
        try {
            while ($reader.Read()) {
                $period = $reader.GetString(0).Trim()
                $branch = $reader.GetString(1).Trim()
                $periodEntry = $reply.branches.PSObject.Properties[$period]
                if ($null -eq $periodEntry) { throw 'Branch report period is missing.' }
                $entry = $periodEntry.Value.PSObject.Properties[$branch]
                if ($null -eq $entry) { throw 'Branch report key is missing.' }
                for ($index = 0; $index -lt $names.Count; $index++) {
                    $raw = [double]$reader.GetValue($index + 2)
                    $mapped = [double]::Parse([string]$entry.Value.($names[$index]), [Globalization.CultureInfo]::InvariantCulture)
                    if ([Math]::Abs($raw - $mapped) -gt 0.000000001) { throw 'Branch report measure mismatch.' }
                }
                $branchCount++
            }
        } finally { $reader.Dispose() }
        if ($branchCount -eq 0 -or $reply.branchRowCount -ne $branchCount) { throw 'Branch report row count mismatch.' }
        'Real branch query via Execute and addon: PASS; rows=' + $branchCount + '; measures match source'
    }
    if ($CostQueryCode) {
        $command.CommandText = "SELECT CAST(ZX__QUERY AS VARCHAR(MAX)) FROM [$QueryTable] WHERE ZX__CODIGO=? AND D_E_L_E_T_=''"
        [void]$command.Parameters.Add('code', [System.Data.Odbc.OdbcType]::VarChar, 20)
        $command.Parameters[0].Value = $CostQueryCode
        $costBatch = ([string]$command.ExecuteScalar()).TrimEnd([char]0)
        $command.Parameters.Clear()
        if ($costBatch.Contains([char]0) -or ([regex]::Matches($costBatch, $anchor)).Count -ne 1 -or
            ([regex]::Matches($costBatch, 'INTO\s+!TABLENAME!', 'IgnoreCase')).Count -ne 1 -or
            $costBatch -notmatch '(?is)SELECT\s+DISTINCT\s+TURNOVERT\.PERIODO\s*,\s*TURNOVERT\.RA_FILIAL\s*,\s*TURNOVERT\.RA_CC\s*,\s*TURNOVERT\.CTT_DESC01') {
            throw 'The registered cost-center source has an unsupported shape.'
        }
        $costBatch = [regex]::Replace($costBatch, $anchor, "`nINSERT INTO [$costTable] (PERIODO,RA_FILIAL,RA_CC,CTT_DESC01,TTRFSAI,TTRFENT,TFUNIMES,TFUNADMMES,TFUNMES,TFUNDEMMES,TFUNFMES,TURNOVER,TURNMOVF)`nSELECT DISTINCT`nTURNOVERT.PERIODO")
        $costBatch = [regex]::Replace($costBatch, 'INTO\s+!TABLENAME!', '', 'IgnoreCase')
        $replacements['!TBLTMPMONTHS!'] = '#HBBM_' + [guid]::NewGuid().ToString('N')
        $replacements['!DATARQATE!'] = "'$StartPeriod'"
        foreach ($key in $replacements.Keys) { $costBatch = $costBatch.Replace($key, $replacements[$key]) }
        foreach ($name in $requiredMappings) {
            $costBatch = [regex]::Replace($costBatch, '(?i)(?<![A-Z0-9_])' + $name + '(?![A-Z0-9_])', '[' + $TableMappings[$name] + ']')
        }
        if ($costBatch -match '![A-Z_]+!') { throw 'Unresolved cost-center query parameter.' }
        $command.CommandText = "CREATE TABLE [$costTable] (PERIODO VARCHAR(6), RA_FILIAL VARCHAR(32), RA_CC VARCHAR(32), CTT_DESC01 VARCHAR(255), TTRFSAI BIGINT, TTRFENT BIGINT, TFUNIMES FLOAT, TFUNADMMES FLOAT, TFUNMES FLOAT, TFUNDEMMES FLOAT, TFUNFMES FLOAT, TURNOVER FLOAT, TURNMOVF FLOAT)"
        [void]$command.ExecuteNonQuery()
        $request = @{ service = 'RPCRDD.Execute'; params = @{ requestVersion = 1; alias = $Profile; sql = $costBatch } } | ConvertTo-Json -Depth 12 -Compress
        $execute = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -ContentType 'application/json' -Body $request -TimeoutSec 120
        if (-not $execute.success -or $execute.outcome -ne 'completed') { throw ('Cost-center Execute did not complete: ' + $execute.code + '; outcome=' + $execute.outcome) }
        $costSql = "SELECT PERIODO,RA_FILIAL,RA_CC,CTT_DESC01,TTRFSAI,TTRFENT,TFUNIMES,TFUNADMMES,TFUNMES,TFUNDEMMES,TFUNFMES,TURNOVER,TURNMOVF FROM [$costTable] ORDER BY RA_CC,CTT_DESC01"
        $request = @{ service = 'RPCRDD.QueryTyped'; params = @{ requestVersion = 1; alias = $Profile; sql = $costSql; bindings = @{} } } | ConvertTo-Json -Depth 12 -Compress
        $costReply = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -ContentType 'application/json' -Body $request -TimeoutSec 120
        if (-not $costReply.success) { throw ('Cost-center QueryTyped failed: ' + $costReply.code) }
        $command.CommandText = $costSql
        $reader = $command.ExecuteReader()
        $costCount = 0
        $costKeys = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        try {
            while ($reader.Read()) {
                if (-not $costKeys.Add($reader.GetString(2).Trim())) { throw 'Duplicate cost-center key.' }
                $hasTransfer = ([double]$reader.GetValue(4) + [double]$reader.GetValue(5)) -gt 0
                if ($null -eq $firstCost -or (-not $firstCostHasTransfer -and $hasTransfer)) {
                    $firstCost = $reader.GetString(2).Trim(); $firstCostHasTransfer = $hasTransfer
                }
                $costCount++
                $row = $costReply.rows.PSObject.Properties[[string]$costCount].Value
                if ($null -eq $row -or ([string]$row.PERIODO).Trim() -ne $reader.GetString(0).Trim() -or
                    ([string]$row.RA_FILIAL).Trim() -ne $reader.GetString(1).Trim() -or
                    ([string]$row.RA_CC).Trim() -ne $reader.GetString(2).Trim() -or
                    ([string]$row.CTT_DESC01).Trim() -ne $reader.GetString(3).Trim()) { throw 'Cost-center dimension mismatch.' }
                $costNames = @('TTRFSAI','TTRFENT','TFUNIMES','TFUNADMMES','TFUNMES','TFUNDEMMES','TFUNFMES','TURNOVER','TURNMOVF')
                for ($index = 0; $index -lt $costNames.Count; $index++) {
                    $raw = [double]$reader.GetValue($index + 4)
                    $mapped = [double]::Parse([string]$row.($costNames[$index]), [Globalization.CultureInfo]::InvariantCulture)
                    if ([Math]::Abs($raw - $mapped) -gt 0.000000001) { throw 'Cost-center measure mismatch.' }
                }
            }
        } finally { $reader.Dispose() }
        if ($costCount -eq 0 -or $costReply.rowCount -ne $costCount) { throw 'Cost-center row count mismatch.' }
        'Real filtered cost-center query via Execute and QueryTyped: PASS; rows=' + $costCount
    }
    if ($JobQueryCode) {
        $command.CommandText = "SELECT CAST(ZX__QUERY AS VARCHAR(MAX)) FROM [$QueryTable] WHERE ZX__CODIGO=? AND D_E_L_E_T_=''"
        [void]$command.Parameters.Add('code', [System.Data.Odbc.OdbcType]::VarChar, 20)
        $command.Parameters[0].Value = $JobQueryCode
        $jobBatch = ([string]$command.ExecuteScalar()).TrimEnd([char]0)
        $command.Parameters.Clear()
        if ($jobBatch.Contains([char]0) -or ([regex]::Matches($jobBatch, $anchor)).Count -ne 1 -or
            ([regex]::Matches($jobBatch, 'INTO\s+!TABLENAME!', 'IgnoreCase')).Count -ne 1 -or
            $jobBatch -notmatch '(?is)SELECT\s+DISTINCT\s+TURNOVERT\.PERIODO\s*,\s*TURNOVERT\.RA_FILIAL\s*,\s*TURNOVERT\.RA_CC\s*,\s*TURNOVERT\.CTT_DESC01\s*,\s*TURNOVERT\.RA_CODFUNC\s*,\s*TURNOVERT\.RJ_DESC') {
            throw 'The registered job source has an unsupported shape.'
        }
        $jobBatch = [regex]::Replace($jobBatch, $anchor, "`nINSERT INTO [$jobTable] (PERIODO,RA_FILIAL,RA_CC,CTT_DESC01,RA_CODFUNC,RJ_DESC,TTRFSAI,TTRFENT,TFUNIMES,TFUNADMMES,TFUNMES,TFUNDEMMES,TFUNFMES,TURNOVER,TURNMOVF)`nSELECT DISTINCT`nTURNOVERT.PERIODO")
        $jobBatch = [regex]::Replace($jobBatch, 'INTO\s+!TABLENAME!', '', 'IgnoreCase')
        $replacements['!TBLTMPMONTHS!'] = '#HBBM_' + [guid]::NewGuid().ToString('N')
        $replacements['!CCDE!'] = "'" + $firstCost.Replace("'", "''") + "'"
        $replacements['!CCATE!'] = $replacements['!CCDE!']
        foreach ($key in $replacements.Keys) { $jobBatch = $jobBatch.Replace($key, $replacements[$key]) }
        foreach ($name in $requiredMappings) {
            $jobBatch = [regex]::Replace($jobBatch, '(?i)(?<![A-Z0-9_])' + $name + '(?![A-Z0-9_])', '[' + $TableMappings[$name] + ']')
        }
        if ($jobBatch -match '![A-Z_]+!') { throw 'Unresolved job query parameter.' }
        $command.CommandText = "CREATE TABLE [$jobTable] (PERIODO VARCHAR(6), RA_FILIAL VARCHAR(32), RA_CC VARCHAR(32), CTT_DESC01 VARCHAR(255), RA_CODFUNC VARCHAR(32), RJ_DESC VARCHAR(255), TTRFSAI BIGINT, TTRFENT BIGINT, TFUNIMES FLOAT, TFUNADMMES FLOAT, TFUNMES FLOAT, TFUNDEMMES FLOAT, TFUNFMES FLOAT, TURNOVER FLOAT, TURNMOVF FLOAT)"
        [void]$command.ExecuteNonQuery()
        $request = @{ service = 'RPCRDD.Execute'; params = @{ requestVersion = 1; alias = $Profile; sql = $jobBatch } } | ConvertTo-Json -Depth 12 -Compress
        $execute = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -ContentType 'application/json' -Body $request -TimeoutSec 120
        if (-not $execute.success -or $execute.outcome -ne 'completed') { throw ('Job Execute did not complete: ' + $execute.code + '; outcome=' + $execute.outcome) }
        $jobSql = "SELECT PERIODO,RA_FILIAL,RA_CC,CTT_DESC01,RA_CODFUNC,RJ_DESC,TTRFSAI,TTRFENT,TFUNIMES,TFUNADMMES,TFUNMES,TFUNDEMMES,TFUNFMES,TURNOVER,TURNMOVF FROM [$jobTable] ORDER BY RA_CODFUNC,RJ_DESC"
        $request = @{ service = 'RPCRDD.QueryTyped'; params = @{ requestVersion = 1; alias = $Profile; sql = $jobSql; bindings = @{} } } | ConvertTo-Json -Depth 12 -Compress
        $jobReply = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -ContentType 'application/json' -Body $request -TimeoutSec 120
        if (-not $jobReply.success) { throw ('Job QueryTyped failed: ' + $jobReply.code) }
        $command.CommandText = $jobSql
        $reader = $command.ExecuteReader()
        $jobCount = 0
        $jobKeys = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        try {
            while ($reader.Read()) {
                if (-not $jobKeys.Add($reader.GetString(4).Trim())) { throw 'Duplicate job key.' }
                $hasTransfer = ([double]$reader.GetValue(6) + [double]$reader.GetValue(7)) -gt 0
                if ($null -eq $firstJob -or (-not $firstJobHasTransfer -and $hasTransfer)) {
                    $firstJob = $reader.GetString(4).Trim(); $firstJobHasTransfer = $hasTransfer
                }
                $jobCount++
                $row = $jobReply.rows.PSObject.Properties[[string]$jobCount].Value
                $dimensions = @('PERIODO','RA_FILIAL','RA_CC','CTT_DESC01','RA_CODFUNC','RJ_DESC')
                for ($index = 0; $index -lt $dimensions.Count; $index++) {
                    if ($null -eq $row -or ([string]$row.($dimensions[$index])).Trim() -ne $reader.GetString($index).Trim()) { throw 'Job dimension mismatch.' }
                }
                if ($reader.GetString(2).Trim() -ne $firstCost) { throw 'Job did not honor the selected cost center.' }
                for ($index = 0; $index -lt $costNames.Count; $index++) {
                    $raw = [double]$reader.GetValue($index + 6)
                    $mapped = [double]::Parse([string]$row.($costNames[$index]), [Globalization.CultureInfo]::InvariantCulture)
                    if ([Math]::Abs($raw - $mapped) -gt 0.000000001) { throw 'Job measure mismatch.' }
                }
            }
        } finally { $reader.Dispose() }
        if ($jobCount -eq 0 -or $jobReply.rowCount -ne $jobCount) { throw 'Job row count mismatch.' }
        'Real filtered job query via Execute and QueryTyped: PASS; rows=' + $jobCount
    }
    if ($EmployeeQueryCode) {
        $command.CommandText = "SELECT CAST(ZX__QUERY AS VARCHAR(MAX)) FROM [$QueryTable] WHERE ZX__CODIGO=? AND D_E_L_E_T_=''"
        [void]$command.Parameters.Add('code', [System.Data.Odbc.OdbcType]::VarChar, 20)
        $command.Parameters[0].Value = $EmployeeQueryCode
        $employeeBatch = ([string]$command.ExecuteScalar()).TrimEnd([char]0)
        $command.Parameters.Clear()
        $employeeAnchor = '(?im)^\s*SELECT\s+DISTINCT\s*\r?\n\s*(?:TURNOVERT\.PERIODO|LEFT\s*\(\s*TURNOVERT\.PERIODO\s*,\s*6\s*\)\s+AS\s+PERIODO)'
        if ($employeeBatch.Contains([char]0) -or ([regex]::Matches($employeeBatch, $employeeAnchor)).Count -ne 1 -or
            ([regex]::Matches($employeeBatch, 'INTO\s+!TABLENAME!', 'IgnoreCase')).Count -ne 1 -or
            $employeeBatch -notmatch '(?is)SELECT\s+DISTINCT\s+(?:TURNOVERT\.PERIODO|LEFT\s*\(\s*TURNOVERT\.PERIODO\s*,\s*6\s*\)\s+AS\s+PERIODO)\s*,\s*TURNOVERT\.RA_FILIAL\s*,\s*TURNOVERT\.RA_CC\s*,\s*TURNOVERT\.CTT_DESC01\s*,\s*TURNOVERT\.RA_CODFUNC\s*,\s*TURNOVERT\.RJ_DESC\s*,\s*TURNOVERT\.RA_MAT\s*,\s*TURNOVERT\.SRARECNO') {
            throw 'The registered employee source has an unsupported shape.'
        }
        $employeeSelect = [regex]::Match($employeeBatch, $employeeAnchor)
        $employeeBatch = $employeeBatch.Insert($employeeSelect.Index, "`nINSERT INTO [$employeeTable] (PERIODO,RA_FILIAL,RA_CC,CTT_DESC01,RA_CODFUNC,RJ_DESC,RA_MAT,SRARECNO,TTRFSAI,TTRFENT,TFUNIMES,TFUNADMMES,TFUNMES,TFUNDEMMES,TFUNFMES,TURNOVER,TURNMOVF)`n")
        $employeeBatch = [regex]::Replace($employeeBatch, 'INTO\s+!TABLENAME!', '', 'IgnoreCase')
        $replacements['!TBLTMPMONTHS!'] = '#HBBM_' + [guid]::NewGuid().ToString('N')
        $replacements['!CCDE!'] = "'" + $firstCost.Replace("'", "''") + "'"
        $replacements['!CCATE!'] = $replacements['!CCDE!']
        $replacements['!FUNCAODE!'] = "'" + $firstJob.Replace("'", "''") + "'"
        $replacements['!FUNCAOATE!'] = $replacements['!FUNCAODE!']
        foreach ($key in $replacements.Keys) { $employeeBatch = $employeeBatch.Replace($key, $replacements[$key]) }
        foreach ($name in $requiredMappings) {
            $employeeBatch = [regex]::Replace($employeeBatch, '(?i)(?<![A-Z0-9_])' + $name + '(?![A-Z0-9_])', '[' + $TableMappings[$name] + ']')
        }
        if ($employeeBatch -match '![A-Z_]+!') { throw 'Unresolved job query parameter.' }
        $command.CommandText = "CREATE TABLE [$employeeTable] (PERIODO VARCHAR(6), RA_FILIAL VARCHAR(32), RA_CC VARCHAR(32), CTT_DESC01 VARCHAR(255), RA_CODFUNC VARCHAR(32), RJ_DESC VARCHAR(255), RA_MAT VARCHAR(32), SRARECNO BIGINT, TTRFSAI BIGINT, TTRFENT BIGINT, TFUNIMES FLOAT, TFUNADMMES FLOAT, TFUNMES FLOAT, TFUNDEMMES FLOAT, TFUNFMES FLOAT, TURNOVER FLOAT, TURNMOVF FLOAT)"
        [void]$command.ExecuteNonQuery()
        $request = @{ service = 'RPCRDD.Execute'; params = @{ requestVersion = 1; alias = $Profile; sql = $employeeBatch } } | ConvertTo-Json -Depth 12 -Compress
        $execute = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -ContentType 'application/json' -Body $request -TimeoutSec 120
        if (-not $execute.success -or $execute.outcome -ne 'completed') { throw ('Employee Execute did not complete: ' + $execute.code + '; outcome=' + $execute.outcome) }
        $employeeSql = "SELECT T.PERIODO,T.RA_FILIAL,T.RA_CC,T.CTT_DESC01,T.RA_CODFUNC,T.RJ_DESC,T.RA_MAT,T.SRARECNO,SRA.RA_NOME,SRA.RA_ADMISSA,SRA.RA_DEMISSA,T.TTRFSAI,T.TTRFENT,T.TFUNIMES,T.TFUNADMMES,T.TFUNMES,T.TFUNDEMMES,T.TFUNFMES,T.TURNOVER,T.TURNMOVF FROM [$employeeTable] T LEFT JOIN [$($TableMappings.SRA990)] SRA ON SRA.R_E_C_N_O_=T.SRARECNO AND SRA.D_E_L_E_T_=' ' ORDER BY T.RA_MAT,T.SRARECNO"
        $request = @{ service = 'RPCRDD.QueryTyped'; params = @{ requestVersion = 1; alias = $Profile; sql = $employeeSql; bindings = @{} } } | ConvertTo-Json -Depth 12 -Compress
        $employeeReply = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -ContentType 'application/json' -Body $request -TimeoutSec 120
        if (-not $employeeReply.success) { throw ('Employee QueryTyped failed: ' + $employeeReply.code) }
        $command.CommandText = $employeeSql
        $reader = $command.ExecuteReader()
        $employeeCount = 0
        $employeeKeys = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        try {
            while ($reader.Read()) {
                if (-not $employeeKeys.Add([string]$reader.GetValue(7))) { throw 'Duplicate employee key.' }
                $employeeCount++
                $row = $employeeReply.rows.PSObject.Properties[[string]$employeeCount].Value
                $dimensions = @('PERIODO','RA_FILIAL','RA_CC','CTT_DESC01','RA_CODFUNC','RJ_DESC','RA_MAT','SRARECNO')
                for ($index = 0; $index -lt $dimensions.Count; $index++) {
                    if ($null -eq $row -or ([string]$row.($dimensions[$index])).Trim() -ne ([string]$reader.GetValue($index)).Trim()) { throw 'Employee dimension mismatch.' }
                }
                if ($reader.GetString(2).Trim() -ne $firstCost -or $reader.GetString(4).Trim() -ne $firstJob) { throw 'Employee did not honor the selected cost center and job.' }
                $personalFields = @('RA_NOME','RA_ADMISSA','RA_DEMISSA')
                for ($index = 0; $index -lt $personalFields.Count; $index++) {
                    $expected = $reader.GetValue($index + 8)
                    $actual = $row.($personalFields[$index])
                    if ($expected -eq [DBNull]::Value) {
                        if ($null -ne $actual) { throw 'Missing SRA attribute was not preserved.' }
                    } elseif (([string]$actual).Trim() -cne ([string]$expected).Trim()) { throw 'Employee attribute mismatch.' }
                }
                for ($index = 0; $index -lt $costNames.Count; $index++) {
                    $raw = [double]$reader.GetValue($index + 11)
                    $mapped = [double]::Parse([string]$row.($costNames[$index]), [Globalization.CultureInfo]::InvariantCulture)
                    if ([Math]::Abs($raw - $mapped) -gt 0.000000001) { throw 'Employee measure mismatch.' }
                }
            }
        } finally { $reader.Dispose() }
        if ($employeeCount -eq 0 -or $employeeReply.rowCount -ne $employeeCount) { throw 'Employee row count mismatch.' }
        $outMatch = "(E.RE_EMPD='$Company' AND E.RE_FILIALD COLLATE DATABASE_DEFAULT=T.RA_FILIAL COLLATE DATABASE_DEFAULT AND E.RE_CCD COLLATE DATABASE_DEFAULT=T.RA_CC COLLATE DATABASE_DEFAULT AND E.RE_MATD COLLATE DATABASE_DEFAULT=T.RA_MAT COLLATE DATABASE_DEFAULT)"
        $inMatch = "(E.RE_EMPP='$Company' AND E.RE_FILIALP COLLATE DATABASE_DEFAULT=T.RA_FILIAL COLLATE DATABASE_DEFAULT AND E.RE_CCP COLLATE DATABASE_DEFAULT=T.RA_CC COLLATE DATABASE_DEFAULT AND E.RE_MATP COLLATE DATABASE_DEFAULT=T.RA_MAT COLLATE DATABASE_DEFAULT)"
        $eventSql = "SELECT DISTINCT T.SRARECNO,E.R_E_C_N_O_ AS EVENTRECNO,E.RE_DATA,E.RE_EMPP,E.RE_FILIALP,E.RE_MATP,E.RE_CCP,E.RE_EMPD,E.RE_FILIALD,E.RE_MATD,E.RE_CCD,CASE WHEN $outMatch THEN 1 ELSE 0 END AS MATCHOUT,CASE WHEN $inMatch THEN 1 ELSE 0 END AS MATCHIN FROM [$employeeTable] T JOIN [$($TableMappings.SRA990)] SRA ON SRA.R_E_C_N_O_=T.SRARECNO AND SRA.D_E_L_E_T_=' ' JOIN [$($TableMappings.SRE990)] E ON E.D_E_L_E_T_=' ' AND E.RE_CODUNIC COLLATE DATABASE_DEFAULT=SRA.RA_CODUNIC COLLATE DATABASE_DEFAULT AND LEFT(E.RE_DATA,6) COLLATE DATABASE_DEFAULT=T.PERIODO COLLATE DATABASE_DEFAULT AND ($outMatch OR $inMatch) ORDER BY T.SRARECNO,E.RE_DATA,E.R_E_C_N_O_"
        $request = @{ service = 'RPCRDD.QueryTyped'; params = @{ requestVersion = 1; alias = $Profile; sql = $eventSql; bindings = @{} } } | ConvertTo-Json -Depth 12 -Compress
        $eventReply = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -ContentType 'application/json' -Body $request -TimeoutSec 120
        if (-not $eventReply.success) { throw ('Matching transfer evidence query failed: ' + $eventReply.code) }
        $command.CommandText = $eventSql
        $reader = $command.ExecuteReader()
        $eventCount = 0
        try {
            $eventNames = @('SRARECNO','EVENTRECNO','RE_DATA','RE_EMPP','RE_FILIALP','RE_MATP','RE_CCP','RE_EMPD','RE_FILIALD','RE_MATD','RE_CCD','MATCHOUT','MATCHIN')
            while ($reader.Read()) {
                $eventCount++
                $row = $eventReply.rows.PSObject.Properties[[string]$eventCount].Value
                for ($index = 0; $index -lt $eventNames.Count; $index++) {
                    $expected = $reader.GetValue($index)
                    $actual = $row.($eventNames[$index])
                    if ($expected -eq [DBNull]::Value) {
                        if ($null -ne $actual) { throw 'Missing transfer field was not preserved.' }
                    } elseif (([string]$actual).Trim() -cne ([string]$expected).Trim()) { throw 'Transfer evidence mismatch.' }
                }
            }
        } finally { $reader.Dispose() }
        if ($eventReply.rowCount -ne $eventCount) { throw 'Transfer evidence row count mismatch.' }
        # Synthetic records exercise both match directions and exclude wrong identities and periods.
        $fixtureTarget = '##HBB_' + [guid]::NewGuid().ToString('N')
        $fixtureSRA = '##HBB_' + [guid]::NewGuid().ToString('N')
        $fixtureSRE = '##HBB_' + [guid]::NewGuid().ToString('N')
        $fixtureTables = @($fixtureTarget, $fixtureSRA, $fixtureSRE)
        $command.CommandText = "CREATE TABLE [$fixtureTarget] (SRARECNO BIGINT, PERIODO VARCHAR(6) COLLATE Latin1_General_BIN, RA_FILIAL VARCHAR(12) COLLATE Latin1_General_BIN, RA_CC VARCHAR(9) COLLATE Latin1_General_BIN, RA_MAT VARCHAR(6) COLLATE Latin1_General_BIN)"
        [void]$command.ExecuteNonQuery()
        $command.CommandText = "CREATE TABLE [$fixtureSRA] (R_E_C_N_O_ BIGINT, D_E_L_E_T_ CHAR(1), RA_CODUNIC VARCHAR(20))"
        [void]$command.ExecuteNonQuery()
        $command.CommandText = "CREATE TABLE [$fixtureSRE] (R_E_C_N_O_ BIGINT, D_E_L_E_T_ CHAR(1), RE_CODUNIC VARCHAR(20), RE_DATA VARCHAR(8), RE_EMPP VARCHAR(32), RE_FILIALP VARCHAR(12), RE_MATP VARCHAR(6), RE_CCP VARCHAR(9), RE_EMPD VARCHAR(32), RE_FILIALD VARCHAR(12), RE_MATD VARCHAR(6), RE_CCD VARCHAR(9))"
        [void]$command.ExecuteNonQuery()
        $command.CommandText = "INSERT INTO [$fixtureTarget] VALUES (12,'202302','01','100','001'); INSERT INTO [$fixtureSRA] VALUES (12,' ','SYNTHETIC'); INSERT INTO [$fixtureSRE] VALUES (43,' ','SYNTHETIC','20230210','$Company','02','002','200','$Company','01','001','100'),(44,' ','SYNTHETIC','20230215','$Company','01','001','100','$Company','02','002','200'),(45,' ','OTHER','20230210','$Company','02','002','200','$Company','01','001','100'),(46,' ','SYNTHETIC','20230310','$Company','02','002','200','$Company','01','001','100')"
        [void]$command.ExecuteNonQuery()
        $fixtureSql = $eventSql.Replace("[$employeeTable]", "[$fixtureTarget]").Replace("[$($TableMappings.SRA990)]", "[$fixtureSRA]").Replace("[$($TableMappings.SRE990)]", "[$fixtureSRE]")
        $request = @{ service = 'RPCRDD.QueryTyped'; params = @{ requestVersion = 1; alias = $Profile; sql = $fixtureSql; bindings = @{} } } | ConvertTo-Json -Depth 12 -Compress
        $fixtureReply = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -ContentType 'application/json' -Body $request -TimeoutSec 120
        if (-not $fixtureReply.success -or $fixtureReply.rowCount -ne 2 -or
            [int]$fixtureReply.rows.'1'.MATCHOUT -ne 1 -or [int]$fixtureReply.rows.'1'.MATCHIN -ne 0 -or
            [int]$fixtureReply.rows.'2'.MATCHOUT -ne 0 -or [int]$fixtureReply.rows.'2'.MATCHIN -ne 1) {
            throw 'Synthetic transfer-direction or isolation check failed.'
        }
        'Controlled transfer matches, isolation and mixed collations: PASS; rows=2'
        'Matching transfer evidence via QueryTyped: PASS; rows=' + $eventCount
        'Real filtered employee query via Execute and QueryTyped: PASS; rows=' + $employeeCount
    }
    'Real query via Execute and addon: PASS; monthly rows=' + $rowCount + '; measures match source'
} finally {
    if ($null -ne $process -and -not $process.HasExited) {
        Stop-Process -Id $process.Id -ErrorAction SilentlyContinue
        $process.WaitForExit()
    }
    $connection.Dispose()
}
$verification = [System.Data.Odbc.OdbcConnection]::new($builder.ConnectionString)
try {
    $verification.Open()
    $command = $verification.CreateCommand()
    $command.CommandText = "SELECT OBJECT_ID('tempdb..$table')"
    if ($command.ExecuteScalar() -ne [DBNull]::Value) { throw 'Owned temporary table was not released.' }
    if ($BranchQueryCode) {
        $command.CommandText = "SELECT OBJECT_ID('tempdb..$branchTable')"
        if ($command.ExecuteScalar() -ne [DBNull]::Value) { throw 'Owned branch temporary table was not released.' }
    }
    if ($CostQueryCode) {
        $command.CommandText = "SELECT OBJECT_ID('tempdb..$costTable')"
        if ($command.ExecuteScalar() -ne [DBNull]::Value) { throw 'Owned cost-center temporary table was not released.' }
    }
    if ($JobQueryCode) {
        $command.CommandText = "SELECT OBJECT_ID('tempdb..$jobTable')"
        if ($command.ExecuteScalar() -ne [DBNull]::Value) { throw 'Owned job temporary table was not released.' }
    }
    if ($EmployeeQueryCode) {
        $command.CommandText = "SELECT OBJECT_ID('tempdb..$employeeTable')"
        if ($command.ExecuteScalar() -ne [DBNull]::Value) { throw 'Owned employee temporary table was not released.' }
    }
    foreach ($fixtureTable in $fixtureTables) {
        $command.CommandText = "SELECT OBJECT_ID('tempdb..$fixtureTable')"
        if ($command.ExecuteScalar() -ne [DBNull]::Value) { throw 'Owned transfer fixture table was not released.' }
    }
    'Owned temporary table release: PASS'
} finally { $verification.Dispose() }
