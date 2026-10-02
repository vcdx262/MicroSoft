<#
.SYNOPSIS
    Inventories Hyper-V VMs across one or more hosts and exports to CSV.
.DESCRIPTION
    For each host, enumerates every VM and reports configuration (generation, state,
    vCPU, memory min/startup/max and dynamic-memory flag), storage (VHDX path, size and
    current file size), networking (switch, VLAN, MAC, IP addresses), checkpoint count,
    integration services version and replication state. One row per VM.
.PARAMETER ComputerName
    One or more Hyper-V hosts to query. Defaults to the local host.
.PARAMETER Path
    Output CSV path. Default .\HyperV-Inventory.csv
.EXAMPLE
    .\Get-HyperVInventory.ps1
.EXAMPLE
    .\Get-HyperVInventory.ps1 -ComputerName hv01,hv02 -Path .\inv.csv
.NOTES
    Author : Steven Slocum
    Notes  : Read-only. Remote hosts require Hyper-V PowerShell remoting / RPC access.
#>

[CmdletBinding()]
param(

    [parameter(Mandatory = $false)]
    [string[]]$ComputerName = $env:COMPUTERNAME,

    [parameter(Mandatory = $false)]
    [string]$Path = '.\HyperV-Inventory.csv'

)

$results = @()

foreach ($c in $ComputerName) {

    $vms = Get-VM -ComputerName $c -ErrorAction SilentlyContinue

    foreach ($vm in $vms) {

        $obj = $null

        $drive = Get-VMHardDiskDrive -VM $vm -ErrorAction SilentlyContinue | Select-Object -First 1
        $vhd   = $null
        if ($drive) { $vhd = Get-VHD -ComputerName $c -Path $drive.Path -ErrorAction SilentlyContinue }
        $net   = Get-VMNetworkAdapter -VM $vm -ErrorAction SilentlyContinue | Select-Object -First 1

        $obj = [pscustomobject]@{
            Host               = $c
            VMName             = $vm.Name
            Generation         = $vm.Generation
            State              = $vm.State
            vCPU               = $vm.ProcessorCount
            DynamicMemory      = $vm.DynamicMemoryEnabled
            MemStartupMB       = [int]($vm.MemoryStartup / 1MB)
            MemMinimumMB       = [int]($vm.MemoryMinimum / 1MB)
            MemMaximumMB       = [int]($vm.MemoryMaximum / 1MB)
            MemAssignedMB      = [int]($vm.MemoryAssigned / 1MB)
            Switch             = $net.SwitchName
            VlanId             = ($net | Get-VMNetworkAdapterVlan -ErrorAction SilentlyContinue).AccessVlanId
            MacAddress         = $net.MacAddress
            IPAddresses        = ($net.IPAddresses -join '|')
            VhdPath            = $drive.Path
            VhdType            = $vhd.VhdType
            VhdProvisionedGB   = if ($vhd) { [math]::Round($vhd.Size / 1GB, 1) } else { $null }
            VhdCurrentGB       = if ($vhd) { [math]::Round($vhd.FileSize / 1GB, 1) } else { $null }
            Checkpoints        = (Get-VMSnapshot -VM $vm -ErrorAction SilentlyContinue | Measure-Object).Count
            IntegrationSvc     = $vm.IntegrationServicesVersion
            ReplicationState   = $vm.ReplicationState
            Uptime             = $vm.Uptime
            ConfigVersion      = $vm.Version
        }

        $results += $obj
    }
}

$results | Export-Csv -Path $Path -NoTypeInformation
Write-Verbose "Wrote $($results.Count) VM rows to $Path"
$results
