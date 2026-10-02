<#
.SYNOPSIS
    Installs and baselines the Hyper-V role on a Windows Server host.
.DESCRIPTION
    Installs the Hyper-V role and management tools, then applies a consistent host
    baseline: default VM and VHD storage paths, Enhanced Session Mode, NUMA spanning,
    and live migration (authentication + simultaneous-operation limits). A reboot is
    required after the role install; the script reports whether one is pending.

    Supports -WhatIf / -Confirm via SupportsShouldProcess so every change can be
    previewed before it is made.
.PARAMETER VmPath
    Default path for virtual machine configuration files. Created if missing.
.PARAMETER VhdPath
    Default path for virtual hard disks. Created if missing.
.PARAMETER LiveMigrationAuth
    Live migration authentication type: Kerberos (requires constrained delegation in AD)
    or CredSSP. Default Kerberos.
.PARAMETER MaxVirtualMigrations
    Maximum simultaneous live migrations. Default 2.
.PARAMETER SkipRoleInstall
    Skip the role install (use when the role is already present and only the baseline
    settings should be (re)applied).
.EXAMPLE
    .\Install-HyperVHost.ps1 -VmPath D:\Hyper-V\VMs -VhdPath D:\Hyper-V\VHDs -WhatIf
.EXAMPLE
    .\Install-HyperVHost.ps1 -VmPath E:\VMs -VhdPath E:\VHDs -LiveMigrationAuth CredSSP
.NOTES
    Author : Steven Slocum
    Notes  : Requires an elevated session on Windows Server. Lab/production safe; makes
             no network changes beyond enabling the live-migration feature.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(

    [parameter(Mandatory = $true)]
    [string]$VmPath,

    [parameter(Mandatory = $true)]
    [string]$VhdPath,

    [parameter(Mandatory = $false)]
    [ValidateSet('Kerberos', 'CredSSP')]
    [string]$LiveMigrationAuth = 'Kerberos',

    [parameter(Mandatory = $false)]
    [int]$MaxVirtualMigrations = 2,

    [parameter(Mandatory = $false)]
    [switch]$SkipRoleInstall

)

#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

#Install the Hyper-V role and management tools
if (-not $SkipRoleInstall) {
    if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Install Hyper-V role + management tools')) {
        $install = Install-WindowsFeature -Name Hyper-V -IncludeManagementTools
        Write-Verbose "Role install result: $($install.ExitCode); RestartNeeded=$($install.RestartNeeded)"
    }
}

#Create the default storage paths if they do not exist
foreach ($path in @($VmPath, $VhdPath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        if ($PSCmdlet.ShouldProcess($path, 'Create directory')) {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
    }
}

#Apply host baseline settings
if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Set Hyper-V host baseline')) {
    Set-VMHost -VirtualMachinePath            $VmPath `
               -VirtualHardDiskPath           $VhdPath `
               -EnableEnhancedSessionMode      $true `
               -NumaSpanningEnabled            $false `
               -VirtualMachineMigrationAuthenticationType $LiveMigrationAuth `
               -MaximumVirtualMachineMigrations          $MaxVirtualMigrations
}

#Enable live migration (host-level; cluster handles this itself when clustered)
if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Enable VM live migration')) {
    Enable-VMMigration
}

#Report final state and any pending reboot
$pendingReboot = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'

[pscustomobject]@{
    ComputerName        = $env:COMPUTERNAME
    HyperVInstalled     = [bool](Get-WindowsFeature -Name Hyper-V).Installed
    VirtualMachinePath  = (Get-VMHost).VirtualMachinePath
    VirtualHardDiskPath = (Get-VMHost).VirtualHardDiskPath
    EnhancedSessionMode = (Get-VMHost).EnableEnhancedSessionMode
    LiveMigration       = (Get-VMHost).VirtualMachineMigrationEnabled
    MigrationAuth       = (Get-VMHost).VirtualMachineMigrationAuthenticationType
    RebootPending       = $pendingReboot
}
