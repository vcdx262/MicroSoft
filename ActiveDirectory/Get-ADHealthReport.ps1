<#
.SYNOPSIS
    Summarizes Active Directory domain controller health (dcdiag / repadmin / FSMO).
.DESCRIPTION
    Enumerates the domain controllers in the current (or specified) domain and, per DC,
    runs dcdiag and parses the pass/fail of each test, captures replication failures from
    repadmin, and records service state (NTDS, DNS, Netlogon, KDC) and time source. Also
    reports where each of the five FSMO roles currently lives. One row per DC, plus an
    FSMO summary object.
.PARAMETER Domain
    Target domain FQDN. Defaults to the current computer's domain.
.PARAMETER Path
    Output CSV path for the per-DC report. Default .\AD-Health.csv
.EXAMPLE
    .\Get-ADHealthReport.ps1
.EXAMPLE
    .\Get-ADHealthReport.ps1 -Domain lab.local -Path .\dc-health.csv
.NOTES
    Author : Steven Slocum
    Notes  : Read-only diagnostics. Requires the ActiveDirectory module and that dcdiag /
             repadmin are available (RSAT AD DS tools). Run with an account that can
             query the DCs remotely.
#>

[CmdletBinding()]
param(

    [parameter(Mandatory = $false)]
    [string]$Domain = $env:USERDNSDOMAIN,

    [parameter(Mandatory = $false)]
    [string]$Path = '.\AD-Health.csv'

)

Import-Module ActiveDirectory -ErrorAction Stop

$dcs     = Get-ADDomainController -Filter * -Server $Domain
$results = @()

foreach ($dc in $dcs) {

    $obj = $null
    $name = $dc.HostName

    #dcdiag — count passed/failed tests
    $dcdiagRaw   = & dcdiag /s:$name 2>&1
    $passed      = ($dcdiagRaw | Select-String 'passed test').Count
    $failed      = ($dcdiagRaw | Select-String 'failed test')
    $failedNames = ($failed | ForEach-Object { ($_ -replace '.*failed test\s+', '').Trim() }) -join '|'

    #repadmin — replication failures for this DC
    $replFail = (& repadmin /showrepl $name /csv 2>$null | ConvertFrom-Csv |
                    Where-Object { [int]$_.'Number of Failures' -gt 0 } | Measure-Object).Count

    #core service states
    $svc = @{}
    foreach ($s in 'NTDS', 'DNS', 'Netlogon', 'KDC') {
        $svc[$s] = (Get-Service -ComputerName $dc.HostName -Name $s -ErrorAction SilentlyContinue).Status
    }

    $obj = [pscustomobject]@{
        DomainController = $name
        Site             = $dc.Site
        IsGlobalCatalog  = $dc.IsGlobalCatalog
        OperatingSystem  = $dc.OperatingSystem
        DcdiagPassed     = $passed
        DcdiagFailed     = ($failed | Measure-Object).Count
        FailedTests      = $failedNames
        ReplFailures     = $replFail
        NTDS             = $svc['NTDS']
        DNS              = $svc['DNS']
        Netlogon         = $svc['Netlogon']
        KDC              = $svc['KDC']
        Healthy          = (($failed | Measure-Object).Count -eq 0 -and $replFail -eq 0)
    }

    $results += $obj
}

$results | Export-Csv -Path $Path -NoTypeInformation

#FSMO role holders
$forest = Get-ADForest $Domain
$dom    = Get-ADDomain -Server $Domain
$fsmo = [pscustomobject]@{
    SchemaMaster         = $forest.SchemaMaster
    DomainNamingMaster   = $forest.DomainNamingMaster
    PDCEmulator          = $dom.PDCEmulator
    RIDMaster            = $dom.RIDMaster
    InfrastructureMaster = $dom.InfrastructureMaster
}

$unhealthy = @($results | Where-Object { -not $_.Healthy })
if ($unhealthy.Count -gt 0) {
    Write-Warning "$($unhealthy.Count) DC(s) reporting failures: $($unhealthy.DomainController -join ', ')"
}

Write-Verbose "Per-DC health written to $Path"
$results
'--- FSMO role holders ---'
$fsmo
