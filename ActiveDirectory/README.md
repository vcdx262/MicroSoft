# ActiveDirectory

Active Directory build, inventory, and health tooling.

| Script / File | Purpose |
|---|---|
| `Install-ADDSForest.ps1` | Install AD DS + DNS and promote a new forest root (prompts for DSRM password; `-WhatIf` aware) |
| `Get-ADInventory.ps1` | Inventory users/computers/groups/OUs/GPOs → per-class CSVs, with stale/privileged flags |
| `Get-ADHealthReport.ps1` | Per-DC dcdiag/repadmin/service health + FSMO role summary |
| `Enumerate-LocalGroups.ps1` | Local group membership enumeration (per-host privilege audit) |
| `ADDS-Buildout-Test-Plan.xlsx` | Phase-by-phase forest build validation tracker |

**Prerequisites:** RSAT ActiveDirectory module (and GroupPolicy module for GPO export);
`Install-ADDSForest.ps1` requires an elevated session on a fresh Windows Server.
