#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $AppServerIni,
    [Parameter(Mandatory)][string] $ApplicationTokenFile,
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9]+$')][string] $Company,
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9]+$')][string] $Branch,
    [Parameter(Mandatory)][ValidatePattern('^[0-9]{6}$')][string] $StartPeriod,
    [Parameter(Mandatory)][ValidatePattern('^[0-9]{6}$')][string] $EndPeriod,
    [switch] $SkipCertificateCheck
)

$ErrorActionPreference = 'Stop'
foreach ($period in @($StartPeriod, $EndPeriod)) {
    $parsed = [datetime]::MinValue
    if (-not [datetime]::TryParseExact($period, 'yyyyMM', [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::None, [ref]$parsed)) {
        throw 'Periods must be valid calendar months in YYYYMM format.'
    }
}
if ([string]::CompareOrdinal($StartPeriod, $EndPeriod) -gt 0) { throw 'StartPeriod must not exceed EndPeriod.' }

$section = ''
$configuration = @{}
foreach ($line in [IO.File]::ReadAllLines([IO.Path]::GetFullPath($AppServerIni))) {
    if ($line -match '^\s*\[([^]]+)\]') {
        $section = $Matches[1]
    } elseif ($section -eq 'FWWEBEX_PROTHEUS' -and $line -match '^\s*([^;#=]+)=(.*)$') {
        $configuration[$Matches[1].Trim()] = $Matches[2].Trim()
    }
}
foreach ($key in @('RestURL', 'UserName', 'Password')) {
    if ([string]::IsNullOrWhiteSpace($configuration[$key])) { throw "Missing FWWebEx setting: $key." }
}
$baseUri = [uri]$configuration.RestURL
if ($baseUri.Scheme -ne 'https' -or $baseUri.Host -notin @('localhost', '127.0.0.1', '::1')) {
    throw 'This diagnostic requires the configured loopback HTTPS REST endpoint.'
}
$token = [IO.File]::ReadAllText([IO.Path]::GetFullPath($ApplicationTokenFile)).Trim()
if ([string]::IsNullOrWhiteSpace($token)) { throw 'The application token file is empty.' }
$basic = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($configuration.UserName + ':' + $configuration.Password))
$applicationToken = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('token:' + $token))
$headers = @{ Authorization = 'Basic ' + $basic; tenantId = $Company; 'X-DNATech-Auth-Token' = $applicationToken }
$parameters = [Collections.Generic.List[object]]::new()
foreach ($pair in @(
    @('!EMPRESA!', "'$Company'"), @('!DATARQDE!', "'$StartPeriod'"), @('!DATARQATE!', "'$EndPeriod'"),
    @('!FILIALDE!', "'$Branch'"), @('!FILIALATE!', "'$Branch'"), @('!CCDE!', "''"), @('!CCATE!', "'z'"),
    @('!FUNCAODE!', "''"), @('!FUNCAOATE!', "'z'")
)) { $parameters.Add([string[]]$pair) }
$parameterJson = @{ parameters = $parameters } | ConvertTo-Json -Depth 8 -Compress
$encodedParameters = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($parameterJson))
$endpoint = $baseUri.AbsoluteUri.TrimEnd('/') + '/callProcRestCrudTLPP/post/'

function Invoke-TurnoverModel {
    param([string] $Model, [int] $Page)
    $request = @{
        ClassName = 'userRestCrudTLPPCoreFunction'; FunctionName = 'dna.tech.codModelPost'
        codModel = $Model; parModel = $encodedParameters; PageNumber = $Page; RowspPage = 1
        cEmp = $Company; cFil = $Branch; lChkPrepEnv = $false
        lHTTPCTLen = $true; lFWHTTPEncode = $true; cHTTPCTType = 'application/json; charset=UTF-8'
        lHTTPCTType = $true; setUTF8 = $true; setTrimSpace = $true
    } | ConvertTo-Json -Depth 8 -Compress
    try {
        $response = Invoke-WebRequest -Uri $endpoint -Method Post -Headers $headers -ContentType 'application/json' `
            -Body $request -SkipCertificateCheck:$SkipCertificateCheck -TimeoutSec 120 -SkipHttpErrorCheck
        $data = $null
        try { $data = $response.Content | ConvertFrom-Json -Depth 30 } catch { }
        $items = if ($null -ne $data -and $null -ne $data.table -and $null -ne $data.table.items) {
            @($data.table.items)
        } else { @() }
        return @{ status = [int]$response.StatusCode; data = $data; items = $items }
    } catch {
        return @{ status = 0; data = $null; items = @() }
    }
}

$checks = [ordered]@{}
$first = Invoke-TurnoverModel -Model 'TURNOVERGERALEMPRESA' -Page 1
$checks.companyFirstPage = $first.status -eq 200 -and $first.data.model -eq 'TURNOVERGERALEMPRESA' -and $first.items.Count -eq 1
if ($checks.companyFirstPage) {
    $row = $first.items[0].detail.items
    $fields = @('codPeriodo', 'totalTransferenciasSaida', 'totalTransferenciasEntrada', 'totalFuncionariosInicioMes',
        'totalFuncionariosAdmitidos', 'totalFuncionariosMes', 'totalFuncionariosDemitidos',
        'totalFuncionariosFinalMes', 'turnOverGeral', 'turnOverDemissoes')
    $checks.companyColumns = $null -ne $row -and @($fields | Where-Object { -not $row.PSObject.Properties[$_] }).Count -eq 0
    $checks.companyHasNext = $first.data.hasNextPage -eq $true
    if ($checks.companyHasNext) {
        $second = Invoke-TurnoverModel -Model 'TURNOVERGERALEMPRESA' -Page 2
        $checks.companySecondPage = $second.status -eq 200 -and $second.items.Count -eq 1 -and `
            $second.items[0].detail.items.codPeriodo -ne $row.codPeriodo
    } else {
        $checks.companySecondPage = $false
    }
} else {
    $checks.companyColumns = $false; $checks.companyHasNext = $false; $checks.companySecondPage = $false
}
$employee = Invoke-TurnoverModel -Model 'TURNOVERGERALFUNCIONARIOS' -Page 1
$checks.employeeFirstPage = $employee.status -eq 200 -and $employee.data.model -eq 'TURNOVERGERALFUNCIONARIOS' -and $employee.items.Count -eq 1
if ($checks.employeeFirstPage) {
    $row = $employee.items[0].detail.items
    $fields = @('codPeriodo', 'codFilial', 'codCentroDeCusto', 'codFuncao', 'codMatricula',
        'nomeFuncionario', 'dataAdmissao', 'totalFuncionariosMes', 'turnOverGeral')
    $checks.employeeColumns = $null -ne $row -and @($fields | Where-Object { -not $row.PSObject.Properties[$_] }).Count -eq 0
    $checks.employeeRecordHasNoError = $employee.items[0].detail.HasError -eq $false
} else {
    $checks.employeeColumns = $false; $checks.employeeRecordHasNoError = $false
}
foreach ($key in $checks.Keys) { Write-Host ("$key`: " + $(if ($checks[$key]) { 'PASS' } else { 'FAIL' })) }
$failed = @($checks.Values | Where-Object { -not $_ }).Count
Write-Host ("Turnover REST checks: $($checks.Count); failures=$failed; company HTTP=$($first.status); employee HTTP=$($employee.status)")
if ($failed) { exit 1 }
