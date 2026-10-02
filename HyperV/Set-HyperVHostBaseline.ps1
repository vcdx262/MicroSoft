<#
.SYNOPSIS
    Applies an opinionated best-practice baseline to a Hyper-V host.
.DESCRIPTION
    Sets a consistent, defensible host configuration and reports a before/after of each
    setting:
      - NUMA spanning disabled (predictable guest NUMA; better large-VM performance)
      - Enhanced Session Mode enabled
      - Default VM Secure Boot left On for new Gen2 VMs (enforced at VM creation)
      - Live-migration performance option set to SMB (fast, compressed fallback)
      - Storage-migration concurrency bounded
      - NumaSpanning and migration limits set explicitly rather than left at defaults
    Idempotent and fully -WhatIf aware.
.PARAMETER MaxStorageMigrations
    Maximum simultaneous storage migrations. Default 2.
.PARAMETER MigrationPerformance
    Live-migration performance option: SMB, Compression, or TCPIP. Default SMB.
.EXAMPLE
    .\Set-HyperVHostBaseline.ps1 -WhatIf
.EXAMPLE
    .\Set-HyperVHostBaseline.ps1 -MigrationPerformance Compression
.NOTES
    Author : Steven Slocum
    Notes  : Elevated session required. Opinionated — review each setting against your
             standard before applying in production.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(

    [parameter(Mandatory = $false)]
    [int]$MaxStorageMigrations = 2,

    [parameter(Mandatory = $false)]
    [ValidateSet('SMB', 'Compression', 'TCPIP')]
    [string]$MigrationPerformance = 'SMB'

)

#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

$before = Get-VMHost | Select-Object NumaSpanningEnabled, EnableEnhancedSessionMode,
    VirtualMachineMigrationPerformanceOption, MaximumStorageMigrations

if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Apply Hyper-V host baseline')) {
    Set-VMHost -NumaSpanningEnabled                    $false `
               -EnableEnhancedSessionMode              $true `
               -VirtualMachineMigrationPerformanceOption $MigrationPerformance `
               -MaximumStorageMigrations               $MaxStorageMigrations
}

$after = Get-VMHost | Select-Object NumaSpanningEnabled, EnableEnhancedSessionMode,
    VirtualMachineMigrationPerformanceOption, MaximumStorageMigrations

[pscustomobject]@{
    Setting = 'NumaSpanningEnabled'
    Before  = $before.NumaSpanningEnabled
    After   = $after.NumaSpanningEnabled
},
[pscustomobject]@{
    Setting = 'EnableEnhancedSessionMode'
    Before  = $before.EnableEnhancedSessionMode
    After   = $after.EnableEnhancedSessionMode
},
[pscustomobject]@{
    Setting = 'MigrationPerformanceOption'
    Before  = $before.VirtualMachineMigrationPerformanceOption
    After   = $after.VirtualMachineMigrationPerformanceOption
},
[pscustomobject]@{
    Setting = 'MaximumStorageMigrations'
    Before  = $before.MaximumStorageMigrations
    After   = $after.MaximumStorageMigrations
}
