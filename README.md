# MicroSoft

Windows, Active Directory, Hyper-V and Azure automation by **Steven Slocum** — PowerShell
tooling, Bicep infrastructure-as-code, deployment runbooks and Excel test plans drawn from
real engagements and a persistent lab. Sanitized for publication: lab values, placeholder
secrets, no tenant/subscription identifiers.

## Layout

| Folder | Contents |
|---|---|
| [HyperV](HyperV/) | **Full Hyper-V build-out** — host install + baseline, CSV-driven virtual-switch and Gen2 VM provisioning, inventory/capacity/replication reporting, two deployment runbooks, and a build test plan |
| [ActiveDirectory](ActiveDirectory/) | New-forest build, directory inventory (users/computers/groups/OUs/GPOs), DC health (dcdiag/repadmin/FSMO), and a build test plan |
| [Azure](Azure/) | **AVD platform** (Bicep IaC + identity/FSLogix/Kerberos scripts + Intune + ADRs + security design + deploy guide + validation plan), bulk quota automation, and subscription inventory |
| [DNS](DNS/) | Forward/reverse/CNAME record validation |
| [Windows](Windows/) | Host hardware/OS inventory, scheduled-task inventory |
| [Common](Common/) | Shared helpers (session TLS trust for lab endpoints) |

## Highlights

- **Hyper-V, end to end** ([HyperV](HyperV/)) — install and baseline a host, build switches
  and Gen2 VMs (Secure Boot + vTPM) from CSV, and report inventory, consolidation headroom
  and Replica health — with standalone and two-node failover-cluster runbooks.
- **AVD security-consulting platform** ([Azure/AVD](Azure/AVD/)) — a hardened, Entra-only,
  outbound-only AVD environment as Bicep IaC, with nine architecture decision records, a
  full security design, and a clean deployment guide.
- **AD build + audit** ([ActiveDirectory](ActiveDirectory/)) — repeatable forest promotion,
  a multi-class directory inventory (stale/privileged flags), and a DC health + FSMO report.
- **Excel test plans** — phase-by-phase validation trackers for the Hyper-V, AD DS and AVD
  builds, in a consistent `Phase / Step / Command / Expected / Actual / Rating` format.

## Conventions

- Every PowerShell script carries comment-based help — `Get-Help .\Script.ps1 -Full`.
- Mutating scripts support `-WhatIf`; secrets are parameters or `$env:` reads, never literals.
- CSV-driven inputs; the signature `$results`/`[pscustomobject]`/`Export-Csv` reporting pattern.
- **PSScriptAnalyzer: zero Error-severity findings.**
- Lab values (`lab.local`, RFC1918) are retained; tenant/subscription identifiers are
  replaced with placeholders. Only the author's own work is included.

## License

[MIT](LICENSE).
