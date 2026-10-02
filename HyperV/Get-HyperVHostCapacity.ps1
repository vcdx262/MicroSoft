<#
.SYNOPSIS
    Reports Hyper-V host capacity and consolidation headroom.
.DESCRIPTION
    For each host, reports physical logical processors and the sum of assigned vCPU
    across running VMs (and the resulting vCPU:pCPU ratio), physical RAM vs. the sum of
    assigned/startup VM memory, current dynamic-memory pressure, and VHDX provisioned vs.
    actual on-disk size (thin-provisioning overcommit). One row per host — a quick read
    on how much more a host can take.
.PARAMETER ComputerName
    One or more Hyper-V hosts. Defaults to the local host.
.PARAMETER Path
    Output CSV path. Default .\HyperV-HostCapacity.csv
.EXAMPLE
    .\Get-HyperVHostCapacity.ps1 -ComputerName hv01,hv02
.NOTES
    Author : Steven Slocum
    Notes  : Read-only. vCPU:pCPU ratio and memory commit are the headline consolidation
             signals; VHDX provisioned-vs-actual surfaces thin overcommit risk.
#>

[CmdletBinding()]
param(

    [parameter(Mandatory = $false)]
    [string[]]$ComputerName = $env:COMPUTERNAME,

    [parameter(Mandatory = $false)]
    [string]$Path = '.\HyperV-HostCapacity.csv'

)

$results = @()

foreach ($c in $ComputerName) {

    $obj = $null

    $cs        = Get-CimInstance Win32_ComputerSystem -ComputerName $c -ErrorAction SilentlyContinue
    $os        = Get-CimInstance Win32_OperatingSystem -ComputerName $c -ErrorAction SilentlyContinue
    $logProcs  = (Get-CimInstance Win32_Processor -ComputerName $c -ErrorAction SilentlyContinue |
                    Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
    $vms       = Get-VM -ComputerName $c -ErrorAction SilentlyContinue
    $running   = @($vms | Where-Object { $_.State -eq 'Running' })

    $assignedVcpu = ($running | Measure-Object -Property ProcessorCount -Sum).Sum
    $assignedMem  = ($running | Measure-Object -Property MemoryAssigned -Sum).Sum
    $startupMem   = ($vms     | Measure-Object -Property MemoryStartup  -Sum).Sum

    #Sum VHDX provisioned vs. actual across all VM disks on the host
    $provGB = 0; $actualGB = 0
    foreach ($vm in $vms) {
        foreach ($d in (Get-VMHardDiskDrive -VM $vm -ErrorAction SilentlyContinue)) {
            $vhd = Get-VHD -ComputerName $c -Path $d.Path -ErrorAction SilentlyContinue
            if ($vhd) { $provGB += ($vhd.Size / 1GB); $actualGB += ($vhd.FileSize / 1GB) }
        }
    }

    $physMemGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)

    $obj = [pscustomobject]@{
        Host                 = $c
        LogicalProcessors    = $logProcs
        RunningVMs           = $running.Count
        TotalVMs             = $vms.Count
        AssignedVcpu         = $assignedVcpu
        VcpuPerPcpuRatio     = if ($logProcs) { [math]::Round($assignedVcpu / $logProcs, 2) } else { $null }
        PhysicalMemGB        = $physMemGB
        AssignedMemGB        = [math]::Round($assignedMem / 1GB, 1)
        StartupMemCommitGB   = [math]::Round($startupMem / 1GB, 1)
        FreePhysicalMemGB    = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
        MemCommitPct         = if ($physMemGB) { [math]::Round((($startupMem / 1GB) / $physMemGB) * 100, 0) } else { $null }
        VhdProvisionedGB     = [math]::Round($provGB, 1)
        VhdActualGB          = [math]::Round($actualGB, 1)
        VhdOvercommitGB      = [math]::Round($provGB - $actualGB, 1)
    }

    $results += $obj
}

$results | Export-Csv -Path $Path -NoTypeInformation
$results
