<#
.SYNOPSIS
    Installs AD DS and promotes a new forest root domain controller.
.DESCRIPTION
    A parameterized, repeatable version of a new-forest build: installs the AD-Domain-
    Services role (and DNS), then promotes the host to the forest root DC. The DSRM
    (Safe Mode) password is prompted for as a SecureString — never passed in clear text.
    The server reboots automatically on success.

    Hardened over an ad-hoc build: typed parameters, functional/forest level selectable,
    -WhatIf support, and no plaintext secrets.
.PARAMETER DomainName
    FQDN of the new forest root domain (e.g. lab.local).
.PARAMETER NetbiosName
    NetBIOS domain name. Defaults to the first label of DomainName, upper-cased.
.PARAMETER ForestMode
    Forest functional level. Default WinThreshold (2016+).
.PARAMETER DomainMode
    Domain functional level. Default WinThreshold (2016+).
.PARAMETER DatabasePath
    NTDS database path. Default C:\Windows\NTDS.
.EXAMPLE
    .\Install-ADDSForest.ps1 -DomainName lab.local -WhatIf
.EXAMPLE
    .\Install-ADDSForest.ps1 -DomainName corp.example.com -NetbiosName CORP
.NOTES
    Author : Steven Slocum
    Notes  : Elevated session on a fresh Windows Server. Hardens the lab-era
             Install-DNS-AD build. The host reboots on successful promotion.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(

    [parameter(Mandatory = $true)]
    [string]$DomainName,

    [parameter(Mandatory = $false)]
    [string]$NetbiosName,

    [parameter(Mandatory = $false)]
    [ValidateSet('Win2012R2', 'WinThreshold')]
    [string]$ForestMode = 'WinThreshold',

    [parameter(Mandatory = $false)]
    [ValidateSet('Win2012R2', 'WinThreshold')]
    [string]$DomainMode = 'WinThreshold',

    [parameter(Mandatory = $false)]
    [string]$DatabasePath = 'C:\Windows\NTDS'

)

#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

if (-not $NetbiosName) { $NetbiosName = ($DomainName -split '\.')[0].ToUpper() }

#Prompt for the DSRM password as a SecureString (never plaintext)
$dsrmPassword = Read-Host -Prompt 'DSRM (Directory Services Restore Mode) password' -AsSecureString

#Install roles
if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Install AD-Domain-Services + DNS roles')) {
    Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools | Out-Null
}

Import-Module ADDSDeployment -ErrorAction Stop

#Promote to forest root DC
if ($PSCmdlet.ShouldProcess($DomainName, "Promote new forest root ($NetbiosName)")) {
    Install-ADDSForest `
        -DomainName                    $DomainName `
        -DomainNetbiosName             $NetbiosName `
        -ForestMode                    $ForestMode `
        -DomainMode                    $DomainMode `
        -DatabasePath                  $DatabasePath `
        -InstallDns:$true `
        -SafeModeAdministratorPassword $dsrmPassword `
        -NoRebootOnCompletion:$false `
        -Force:$true
}
