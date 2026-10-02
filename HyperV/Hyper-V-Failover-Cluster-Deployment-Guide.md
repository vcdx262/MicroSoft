# Hyper-V Failover Cluster Deployment Guide — two-node HA

**Why this exists:** the HA continuation of the
[standalone host guide](Hyper-V-Standalone-Host-Deployment-Guide.md). It takes two
already-built Hyper-V hosts to a validated two-node Failover Cluster with Cluster Shared
Volumes, highly-available VMs, live migration, and Cluster-Aware Updating.

> Elevated PowerShell throughout. Both nodes must be domain-joined, time-synced, and
> identically patched before you start. Preview with `-WhatIf` where supported.

---

## 0. Ground truth (fill in)

| | |
|---|---|
| Nodes | `hv01`, `hv02` — Windows Server 2022, domain-joined to `lab.local` |
| Cluster name / IP | `hvclus01` / `10.0.60.50` |
| Shared storage | iSCSI / SAN / Storage Spaces Direct LUN(s) presented to both nodes |
| Networks | Management, Live Migration, Cluster/CSV, (Storage if iSCSI) |
| Witness | File-share or cloud (Azure) witness |

## 1. Prerequisites on both nodes

```powershell
Install-WindowsFeature Failover-Clustering -IncludeManagementTools
# (Hyper-V role already installed per the standalone guide)
```

Confirm identical virtual switch names on both nodes — HA VMs require matching switch
names across the cluster:

```powershell
Invoke-Command hv01,hv02 { Get-VMSwitch | Select Name,SwitchType }
```

## 2. Validate before you cluster

```powershell
Test-Cluster -Node hv01,hv02 -Include 'Storage','Inventory','Network','System Configuration','Hyper-V Configuration'
```

Resolve every **error** (warnings are often acceptable) before continuing. The HTML report
path is printed by the cmdlet.

## 3. Create the cluster

```powershell
New-Cluster -Name hvclus01 -Node hv01,hv02 -StaticAddress 10.0.60.50 -NoStorage
Get-Cluster | Select Name,Domain
Get-ClusterNode | Select Name,State
```

## 4. Add storage + Cluster Shared Volumes

```powershell
Get-ClusterAvailableDisk | Add-ClusterDisk
# convert the cluster disk(s) to CSV:
Add-ClusterSharedVolume -Name 'Cluster Disk 1'
Get-ClusterSharedVolume | Select Name,State,OwnerNode    # mounts at C:\ClusterStorage\VolumeN
```

## 5. Quorum witness

```powershell
# file-share witness
Set-ClusterQuorum -FileShareWitness \\fs01\quorum-hvclus01
# or cloud witness (Azure Storage account)
Set-ClusterQuorum -CloudWitness -AccountName <storage-account> -AccessKey $env:WITNESS_KEY
```

## 6. Configure networks + live migration

Name the cluster networks by role and restrict live migration to the dedicated network:

```powershell
# label networks in Failover Cluster Manager or via (Get-ClusterNetwork)
# then set live-migration network preference on each node:
Set-VMHost -UseAnyNetworkForMigration $false
```

## 7. Make VMs highly available

Store HA VM files on a CSV path, then:

```powershell
New-VM -Name app01 -Path C:\ClusterStorage\Volume1 -Generation 2 -SwitchName vSwitch-External `
       -MemoryStartupBytes 4GB -NewVHDPath C:\ClusterStorage\Volume1\app01\app01.vhdx -NewVHDSizeBytes 100GB
Add-ClusterVirtualMachineRole -VirtualMachine app01
```

## 8. Validate HA behaviour

```powershell
# live migrate
Move-ClusterVirtualMachineRole -Name app01 -Node hv02 -MigrationType Live
# planned drain
Suspend-ClusterNode -Name hv01 -Drain
Resume-ClusterNode  -Name hv01
```

## 9. Cluster-Aware Updating

```powershell
Add-CauClusterRole -ClusterName hvclus01 -DaysOfWeek Sunday -IntervalWeeks 2 -MaxFailedNodes 0 -Force
Get-CauReport -ClusterName hvclus01 -Last
```

## 10. Verify + inventory

```powershell
.\Get-HyperVInventory.ps1   -ComputerName hv01,hv02 -Path .\HyperV-Inventory.csv
.\Get-HyperVHostCapacity.ps1 -ComputerName hv01,hv02 -Path .\HyperV-HostCapacity.csv
```

Record Expected vs. Actual in
**[HyperV-Host-Buildout-Test-Plan.xlsx](HyperV-Host-Buildout-Test-Plan.xlsx)** (Phase 4
covers live migration and replica).
