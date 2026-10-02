<#
.SYNOPSIS
    Inventories an Active Directory domain and exports CSVs for the key object classes.
.DESCRIPTION
    Collects a domain inventory and writes one CSV per object class to an output folder:
      - Users     : enabled state, last logon, password age, lockout, privileged-group flags
      - Computers : OS/version, enabled state, last logon, stale flag
      - Groups    : category/scope and member count
      - OUs       : distinguished name and child counts
      - GPOs      : name, status, created/modified
    A VM/host is "stale" when it has not logged on within -StaleDays (default 90).
.PARAMETER SearchBase
    Optional OU distinguished name to scope the inventory. Defaults to the whole domain.
.PARAMETER OutputFolder
    Folder for the CSV output. Created if missing. Default .\AD-Inventory
.PARAMETER StaleDays
    Days without logon before a computer/user is flagged stale. Default 90.
.EXAMPLE
    .\Get-ADInventory.ps1 -OutputFolder .\AD-Inventory
.EXAMPLE
    .\Get-ADInventory.ps1 -SearchBase 'OU=Servers,DC=lab,DC=local' -StaleDays 60
.NOTES
    Author : Steven Slocum
    Notes  : Read-only. Requires the ActiveDirectory module (RSAT) and read access to
             the domain. GPO export additionally requires the GroupPolicy module.
#>

[CmdletBinding()]
param(

    [parameter(Mandatory = $false)]
    [string]$SearchBase,

    [parameter(Mandatory = $false)]
    [string]$OutputFolder = '.\AD-Inventory',

    [parameter(Mandatory = $false)]
    [int]$StaleDays = 90

)

Import-Module ActiveDirectory -ErrorAction Stop

if (-not (Test-Path -LiteralPath $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
}

$staleCutoff   = (Get-Date).AddDays(-$StaleDays)
$privGroups    = @('Domain Admins', 'Enterprise Admins', 'Schema Admins', 'Administrators')
$adAccountArgs = @{}
if ($SearchBase) { $adAccountArgs['SearchBase'] = $SearchBase }

#--- Users ---
$userResults = @()
$users = Get-ADUser @adAccountArgs -Filter * -Properties Enabled, LastLogonDate, PasswordLastSet,
    PasswordNeverExpires, LockedOut, MemberOf, Description
foreach ($u in $users) {
    $obj = $null
    $isPriv = $false
    foreach ($g in $privGroups) {
        if ($u.MemberOf -match "CN=$g,") { $isPriv = $true; break }
    }
    $obj = [pscustomobject]@{
        SamAccountName       = $u.SamAccountName
        Name                 = $u.Name
        Enabled              = $u.Enabled
        LastLogonDate        = $u.LastLogonDate
        PasswordLastSet      = $u.PasswordLastSet
        PasswordAgeDays      = if ($u.PasswordLastSet) { (New-TimeSpan -Start $u.PasswordLastSet -End (Get-Date)).Days } else { $null }
        PasswordNeverExpires = $u.PasswordNeverExpires
        LockedOut            = $u.LockedOut
        Privileged           = $isPriv
        Stale                = ($u.LastLogonDate -and $u.LastLogonDate -lt $staleCutoff)
        Description          = $u.Description
    }
    $userResults += $obj
}
$userResults | Export-Csv (Join-Path $OutputFolder 'Users.csv') -NoTypeInformation

#--- Computers ---
$computerResults = @()
$computers = Get-ADComputer @adAccountArgs -Filter * -Properties Enabled, OperatingSystem,
    OperatingSystemVersion, LastLogonDate, IPv4Address
foreach ($cpt in $computers) {
    $obj = $null
    $obj = [pscustomobject]@{
        Name            = $cpt.Name
        Enabled         = $cpt.Enabled
        OperatingSystem = $cpt.OperatingSystem
        OSVersion       = $cpt.OperatingSystemVersion
        IPv4Address     = $cpt.IPv4Address
        LastLogonDate   = $cpt.LastLogonDate
        Stale           = ($cpt.LastLogonDate -and $cpt.LastLogonDate -lt $staleCutoff)
    }
    $computerResults += $obj
}
$computerResults | Export-Csv (Join-Path $OutputFolder 'Computers.csv') -NoTypeInformation

#--- Groups ---
$groupResults = @()
foreach ($g in (Get-ADGroup @adAccountArgs -Filter * -Properties Members, GroupCategory, GroupScope)) {
    $obj = $null
    $obj = [pscustomobject]@{
        Name          = $g.Name
        Category      = $g.GroupCategory
        Scope         = $g.GroupScope
        MemberCount   = ($g.Members | Measure-Object).Count
    }
    $groupResults += $obj
}
$groupResults | Export-Csv (Join-Path $OutputFolder 'Groups.csv') -NoTypeInformation

#--- OUs ---
$ouResults = @()
foreach ($ou in (Get-ADOrganizationalUnit @adAccountArgs -Filter *)) {
    $obj = $null
    $obj = [pscustomobject]@{
        Name              = $ou.Name
        DistinguishedName = $ou.DistinguishedName
    }
    $ouResults += $obj
}
$ouResults | Export-Csv (Join-Path $OutputFolder 'OUs.csv') -NoTypeInformation

#--- GPOs (best-effort; GroupPolicy module) ---
if (Get-Module -ListAvailable GroupPolicy) {
    Import-Module GroupPolicy -ErrorAction SilentlyContinue
    $gpoResults = @()
    foreach ($gpo in (Get-GPO -All)) {
        $obj = $null
        $obj = [pscustomobject]@{
            DisplayName      = $gpo.DisplayName
            GpoStatus        = $gpo.GpoStatus
            CreationTime     = $gpo.CreationTime
            ModificationTime = $gpo.ModificationTime
        }
        $gpoResults += $obj
    }
    $gpoResults | Export-Csv (Join-Path $OutputFolder 'GPOs.csv') -NoTypeInformation
}
else {
    Write-Warning 'GroupPolicy module not available — skipping GPO export.'
}

Write-Verbose "AD inventory written to $OutputFolder"
[pscustomobject]@{
    Users     = $userResults.Count
    Computers = $computerResults.Count
    Groups    = $groupResults.Count
    OUs       = $ouResults.Count
    StaleUsers     = @($userResults     | Where-Object Stale).Count
    StaleComputers = @($computerResults | Where-Object Stale).Count
    OutputFolder   = (Resolve-Path $OutputFolder).Path
}
