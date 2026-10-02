# HyperV

Hyper-V host build-out, VM provisioning, and inventory/health reporting — a full working
toolkit plus two deployment runbooks and a test plan. CSV-driven where it creates objects;
every mutating script supports `-WhatIf`.

## Install / build
| Script | Purpose |
|---|---|
| `Install-HyperVHost.ps1` | Install the role + management tools; set VM/VHD paths, Enhanced Session Mode, NUMA, live migration |
| `Set-HyperVHostBaseline.ps1` | Apply an opinionated host best-practice baseline (before/after report) |
| `New-HyperVVMSwitch.ps1` | Create External/Internal/Private switches + SET teaming + VLAN from a CSV |
| `New-HyperVLabVM.ps1` | Build Gen2 VMs (dynamic memory, VHDX, VLAN, Secure Boot, vTPM) from a CSV |

## Inventory / health
| Script | Purpose |
|---|---|
| `Get-HyperVInventory.ps1` | VMs across hosts → CSV (config, storage, network, checkpoints, replication) |
| `Get-HyperVHostCapacity.ps1` | Per-host consolidation headroom: vCPU:pCPU, memory commit, VHDX overcommit |
| `Get-HyperVReplicationStatus.ps1` | Hyper-V Replica health; flags any VM not in Normal health |

## Guides / test plan
| File | Purpose |
|---|---|
| `Hyper-V-Standalone-Host-Deployment-Guide.md` | Bare metal → first VM runbook |
| `Hyper-V-Failover-Cluster-Deployment-Guide.md` | Two-node HA cluster (CSV, live migration, CAU) |
| `HyperV-Host-Buildout-Test-Plan.xlsx` | Phase-by-phase build validation tracker |

**Prerequisites:** elevated session on Windows Server with the Hyper-V PowerShell module.
