# Hyper-V Standalone Host Deployment Guide — bare metal to first VM

**Why this exists:** a single-page, repeatable path from a freshly-installed Windows Server
to a running Generation 2 VM on a hardened Hyper-V host, using the scripts in this folder.
Every step has a verification, and the whole thing is driven from CSV so it reproduces the
same way each time.

> Run everything from an **elevated** PowerShell session. Preview any change-making step
> with `-WhatIf` before running it for real — all the `Install-`/`New-`/`Set-` scripts here
> support it.

---

## 0. Ground truth (fill in for your build)

| | |
|---|---|
| Host | `hv01` — Windows Server 2022, SLAT-capable CPU |
| Storage | `D:\Hyper-V\VMs` (configs), `D:\Hyper-V\VHDs` (disks) |
| Management NIC | dedicated — **not** the NIC used for the External switch |
| Switch uplink NIC(s) | `Ethernet 2` (+ `Ethernet 3` for a SET team) |
| Live migration | Kerberos (needs AD constrained delegation) or CredSSP |

## 1. Pre-flight

```powershell
systeminfo | Select-String 'Hyper-V'          # all requirements = Yes
Get-ComputerInfo | Select WindowsProductName,OsBuildNumber
```

## 2. Install the role + baseline (reboots once)

```powershell
.\Install-HyperVHost.ps1 -VmPath D:\Hyper-V\VMs -VhdPath D:\Hyper-V\VHDs -WhatIf   # preview
.\Install-HyperVHost.ps1 -VmPath D:\Hyper-V\VMs -VhdPath D:\Hyper-V\VHDs           # apply
# reboot, then:
Get-WindowsFeature Hyper-V      # Installed = True
```

Apply the opinionated baseline (NUMA spanning off, Enhanced Session Mode, migration perf):

```powershell
.\Set-HyperVHostBaseline.ps1 -WhatIf
.\Set-HyperVHostBaseline.ps1
```

## 3. Create the virtual switch(es)

Define them in `switches.csv`:

```csv
SwitchName,Type,NetAdapters,AllowManagementOS,VlanId,BandwidthMode
vSwitch-External,External,Ethernet 2;Ethernet 3,true,0,Weight
vSwitch-Internal,Internal,,true,0,None
```

```powershell
.\New-HyperVVMSwitch.ps1 -Csv .\switches.csv -WhatIf
.\New-HyperVVMSwitch.ps1 -Csv .\switches.csv
Test-NetConnection hv01 -Port 5985    # confirm management connectivity survived
```

> Two or more `NetAdapters` creates a **Switch Embedded Team (SET)**. Prefer a dedicated
> uplink so management connectivity is never at risk.

## 4. Build VMs

Define them in `vms.csv`:

```csv
VmName,Cpu,MemoryStartupMB,MemoryMinimumMB,MemoryMaximumMB,VhdSizeGB,SwitchName,VlanId,BootIsoPath,EnableTpm
lab-dc01,2,2048,1024,4096,80,vSwitch-External,0,C:\ISO\WS2022.iso,true
lab-app01,4,4096,2048,8192,100,vSwitch-External,10,C:\ISO\WS2022.iso,true
```

```powershell
.\New-HyperVLabVM.ps1 -Csv .\vms.csv -WhatIf
.\New-HyperVLabVM.ps1 -Csv .\vms.csv
Get-VM | Select Name,State,ProcessorCount,DynamicMemoryEnabled,Generation
```

## 5. Verify + baseline inventory

```powershell
.\Get-HyperVInventory.ps1   -Path .\HyperV-Inventory.csv
.\Get-HyperVHostCapacity.ps1 -Path .\HyperV-HostCapacity.csv
```

Run the matching **[HyperV-Host-Buildout-Test-Plan.xlsx](HyperV-Host-Buildout-Test-Plan.xlsx)**
to record Expected vs. Actual for each step.

## Next

For a two-node HA build (Failover Clustering + CSV + live migration + cluster-aware
updating), continue with the
**[Failover Cluster Deployment Guide](Hyper-V-Failover-Cluster-Deployment-Guide.md)**.
