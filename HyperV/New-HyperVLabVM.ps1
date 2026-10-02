<#
.SYNOPSIS
    Builds Generation 2 Hyper-V VMs from a CSV definition.
.DESCRIPTION
    For each row in the CSV, creates a Generation 2 VM with dynamic memory, a new
    dynamically-expanding VHDX, a connection to the named virtual switch (optional VLAN
    tag), processor count, Secure Boot, and an optional vTPM (via key protector). If a
    boot ISO is supplied it is attached to the DVD drive and placed first in the boot
    order. Idempotent: a VM that already exists by name is skipped.

    CSV columns:
      VmName, Cpu, MemoryStartupMB, MemoryMinimumMB, MemoryMaximumMB, VhdSizeGB,
      SwitchName, VlanId (0 = untagged), BootIsoPath (blank = none), EnableTpm (true|false)
.PARAMETER Csv
    Path to the VM-definition CSV.
.PARAMETER VhdRoot
    Directory in which each VM's VHDX is created. Defaults to the host's configured
    VirtualHardDiskPath.
.EXAMPLE
    .\New-HyperVLabVM.ps1 -Csv .\vms.csv -WhatIf
.EXAMPLE
    .\New-HyperVLabVM.ps1 -Csv .\vms.csv -VhdRoot D:\Hyper-V\VHDs
.NOTES
    Author : Steven Slocum
    Notes  : Elevated session required. Gen2 + Secure Boot + vTPM mirrors a modern
             Windows 11 / Server 2022 guest baseline. Lab/production safe with -WhatIf.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(

    [parameter(Mandatory = $true)]
    [string]$Csv,

    [parameter(Mandatory = $false)]
    [string]$VhdRoot

)

#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

if (-not $VhdRoot) { $VhdRoot = (Get-VMHost).VirtualHardDiskPath }
if (-not (Test-Path -LiteralPath $VhdRoot)) {
    if ($PSCmdlet.ShouldProcess($VhdRoot, 'Create VHD root directory')) {
        New-Item -ItemType Directory -Path $VhdRoot -Force | Out-Null
    }
}

$vms = Import-Csv -Path $Csv

foreach ($v in $vms) {

    #Zero per-row state
    $vmName   = $null
    $vhdPath  = $null

    $vmName  = $v.VmName
    $vhdPath = Join-Path $VhdRoot ("{0}.vhdx" -f $vmName)

    if (Get-VM -Name $vmName -ErrorAction SilentlyContinue) {
        Write-Verbose "VM '$vmName' already exists — skipping."
        continue
    }

    if (-not $PSCmdlet.ShouldProcess($vmName, 'Create Generation 2 VM')) { continue }

    #Create the VHDX and the VM
    New-VHD -Path $vhdPath -SizeBytes ([int64]$v.VhdSizeGB * 1GB) -Dynamic | Out-Null

    New-VM -Name $vmName `
           -Generation 2 `
           -MemoryStartupBytes ([int64]$v.MemoryStartupMB * 1MB) `
           -VHDPath $vhdPath `
           -SwitchName $v.SwitchName | Out-Null

    #Dynamic memory bounds
    Set-VMMemory -VMName $vmName `
                 -DynamicMemoryEnabled $true `
                 -MinimumBytes ([int64]$v.MemoryMinimumMB * 1MB) `
                 -StartupBytes ([int64]$v.MemoryStartupMB * 1MB) `
                 -MaximumBytes ([int64]$v.MemoryMaximumMB * 1MB)

    #Processor count
    Set-VMProcessor -VMName $vmName -Count ([int]$v.Cpu)

    #Optional VLAN tag
    if ([int]$v.VlanId -gt 0) {
        Set-VMNetworkAdapterVlan -VMName $vmName -Access -VlanId ([int]$v.VlanId)
    }

    #Optional boot ISO, placed first in boot order
    if ($v.BootIsoPath) {
        Add-VMDvdDrive -VMName $vmName -Path $v.BootIsoPath
        $dvd = Get-VMDvdDrive -VMName $vmName
        Set-VMFirmware -VMName $vmName -FirstBootDevice $dvd
    }

    #Secure Boot (Gen2 default) + optional vTPM
    Set-VMFirmware -VMName $vmName -EnableSecureBoot On
    if ([bool]::Parse($v.EnableTpm)) {
        $owner = Get-HgsGuardian -Name 'UntrustedGuardian' -ErrorAction SilentlyContinue
        if (-not $owner) { $owner = New-HgsGuardian -Name 'UntrustedGuardian' -GenerateCertificates }
        $kp = New-HgsKeyProtector -Owner $owner -AllowUntrustedRoot
        Set-VMKeyProtector -VMName $vmName -KeyProtector $kp.RawData
        Enable-VMTPM -VMName $vmName
    }
}

#Report the resulting VMs
Get-VM | Where-Object { $vms.VmName -contains $_.Name } |
    Select-Object Name, State, ProcessorCount,
        @{ n = 'StartupMemMB'; e = { [int]($_.MemoryStartup / 1MB) } },
        @{ n = 'DynamicMem';   e = { $_.DynamicMemoryEnabled } },
        Generation
