# AVD Security-Consulting Platform — MVP

Infrastructure-as-Code for a hardened, network-isolated Azure Virtual Desktop (AVD)
environment for security consulting. Each customer gets its own isolated vNet with
its own storage, Windows session hosts, and a Kali VM. The stack is **Entra-ID-only**
(no Active Directory), **outbound-only** (zero inbound from the internet, no public
IPs on VMs), and accessed via the **AVD web portal**.

The full design rationale lives in the decision records ([`docs/decisions/`](docs/decisions/)) and
full design rationale.

> **Project documentation lives in [`docs/`](docs/README.md)** — design intent, decision
> records (ADRs), current status, the gotchas knowledge base, and the change + deployment logs.
> Read [`docs/README.md`](docs/README.md) first; it is the source of truth and explains the
> update discipline for tracking every change, deploy attempt, and fix.

## MVP scope (rev0) vs. rev1

**In the MVP:** isolated per-customer vNet, NAT egress / zero inbound, Azure Files
storage (private endpoint, encrypted at rest by default), personal Win11 host pool,
Kali VM, Entra-only sign-in, **M365 access** (Outlook/Office work in-session), and
**OneDrive sync disabled** as an exfil control. Entra SSO is on by default (toggle).

**Deferred to rev1:** 2FA / Conditional Access MFA, Intune enrollment, customer-managed
keys (CMK) for storage, and full egress/DLP controls (e.g. blocking browser-based cloud
uploads, locking down clipboard). The scripts for MFA exist in `scripts/` but are not
part of the MVP deploy flow.

> Note: Azure Storage is **always** encrypted at rest (AES-256, Microsoft-managed keys) —
> that cannot be disabled. Only *customer-managed keys* were deferred; your data is still
> encrypted in the MVP.

### M365 & OneDrive

Consultants sign in to the desktop with their Entra/M365 account, so **Outlook and other
M365 services work** (reached over the NAT egress on 443). The **OneDrive sync client is
disabled** (`DisableFileSyncNGSC` + `DisablePersonalSync`) so it can't auto-sync customer
data to the cloud. Local-drive redirection is also off. Browser-based uploads to cloud
storage are *not* blocked yet — that's an egress/DLP control for rev1.

## Why this design

- **One vNet per customer with intentionally overlapping IP space.** AVD uses *Reverse
  Connect* — session hosts only make *outbound* 443 connections to the Microsoft-managed
  control plane and have no inbound listener. So customer vNets are isolated islands that
  are never peered to each other, and overlapping ranges never conflict. When an engagement
  needs customer connectivity, you peer/VPN *that one vNet* and resolve overlap then.
- **Azure Files + Entra Kerberos** (not NetApp Files, which would force AD DS) for both the
  FSLogix profile share and the per-customer data share. Encrypted at rest by default.
- **Kali is a standalone Linux VM**, not an AVD host (Kali isn't a supported AVD OS). It
  lives in the same subnet and is reached privately from the Windows session (SSH / xrdp).

## Repository layout

```
bicep/
  platform.bicep            # shared: Log Analytics + Compute Gallery (deploy ONCE)
  main.bicep                # per-customer orchestrator
  modules/
    network.bicep           # vNet, NSG (zero inbound), NAT GW egress, Private DNS
    storage.bicep           # Azure Files (profiles + data), private endpoint
    avd-controlplane.bicep  # Personal host pool, app group, workspace, diagnostics
    session-hosts.bicep     # Win11 hosts: Trusted Launch, Entra join, AVD agent, FSLogix
    kali.bicep              # Kali Linux VM (no public IP, auto-shutdown)
    identity-rbac.bicep     # VM login + AVD desktop + SMB share role assignments
  params/
    platform.bicepparam
    cust01.bicepparam       # clone per customer
scripts/
  deploy.ps1                # deployment driver
  enable-storage-kerberos.ps1
  configure-fslogix.ps1     # standalone FSLogix + OneDrive-disable (golden image)
  enable-avd-sso.ps1        # one-time tenant SSO step (only if enableSso = true)
  conditional-access-mfa.ps1  # rev1 — NOT part of the MVP flow
```

## Prerequisites

- Azure CLI with the Bicep tooling (`az bicep version`), logged in (`az login`) to the
  target subscription.
- Two Entra security groups per customer: consultants (`grp-avd-cust01-users`) and admins
  (`grp-avd-admins`). Note their **object IDs**.
- Application Administrator rights **only if** `enableSso = true` (for the one-time SSO step).
- _(rev1 only)_ Entra ID **P1/P2** for Conditional Access MFA.
- Accept the Kali marketplace image terms once per subscription:
  `az vm image terms accept --publisher kali-linux --offer kali --plan kali-2024-2`
  (match the SKU in `kali.bicep`).

## Deploy

```powershell
# 1) Shared platform (once)
./scripts/deploy.ps1 -PlatformOnly

# Copy the logAnalyticsWorkspaceId output into params/cust01.bicepparam,
# and fill in the two group object IDs.

# 2) Per-customer stack
$env:AVD_SH_ADMIN_PASSWORD = '<complex-password>'   # Windows session-host local admin
# (Kali username/password are set in cust01.bicepparam for the MVP.)
./scripts/deploy.ps1 -CustomerParam ./bicep/params/cust01.bicepparam -CustomerRg rg-avd-cust01-cus

# 3) Enable Entra Kerberos on the storage account + admin consent
./scripts/enable-storage-kerberos.ps1 -ResourceGroup rg-avd-cust01-cus -StorageAccountName <saName>
#    Then set FSLogix NTFS/directory permissions on the 'profiles' share.

# 4) One-time tenant SSO step  (ONLY if you deployed with enableSso = true)
./scripts/enable-avd-sso.ps1

# (rev1) Conditional Access MFA — not part of the MVP:
#   ./scripts/conditional-access-mfa.ps1 -UserGroupObjectId <grp-avd-cust01-users-objectId>
```

## Cloning per customer

Copy `params/cust01.bicepparam` → `cust02.bicepparam`, change `customerName` and the group
object IDs (IP space may stay identical), then deploy to a new RG `rg-avd-cust02-cus`. The
vNets are never peered, so the overlap is harmless.

## Verification

1. Host pool → session hosts show **Available** in the portal.
2. Open the [AVD web client](https://client.wvd.microsoft.com/arm/webclient), sign in as a
   consultant (username/password only — no MFA in the MVP) → launch the desktop.
3. Confirm VM NICs have **no public IP** and the NSG denies inbound from Internet.
4. In-session: browse the web (egress via NAT GW), then `nslookup <sa>.file.core.windows.net`
   returns the **private** endpoint IP; open `\\<sa>...\data` and read/write a file.
5. Confirm the FSLogix profile VHDX exists on the `profiles` share.
6. **M365**: open Outlook / office.com and confirm email + Office apps work with the
   consultant's account (SSO if enabled, otherwise after a password prompt).
7. **OneDrive blocked**: launch OneDrive — it should refuse to sign in / sync
   ("your organization has disabled OneDrive"). Registry `HKLM\SOFTWARE\Policies\Microsoft\OneDrive\DisableFileSyncNGSC = 1`.
8. From the Windows session, SSH to the Kali VM's private IP; confirm Kali has outbound
   internet but no inbound.

## Known caveats / follow-ups

- **AVD DSC artifacts URL** in `main.bicep` (`avdAgentArtifactsUrl`) is versioned and changes
  over time — update to the current `galleryartifacts/Configuration_*.zip` if registration fails.
- **Kali image SKU** in `kali.bicep` must match a current Kali release and have its terms accepted.
- **FSLogix install**: AVD-optimized images ship with FSLogix; the plain `windows-11` Enterprise
  image may not. The session-host CSE only sets registry — use a golden image with FSLogix, or
  extend the CSE to install it (see `configure-fslogix.ps1`).
- **Entra Kerberos / SSO SPs / FSLogix permissions** are not ARM-expressible and are handled by
  the scripts above.
- **OneDrive control scope**: the disable applies to the *sync client* only. A determined user
  could still upload via a browser to personal cloud storage — closing that is an egress/DLP
  task for rev1 (see roadmap).

## Rev1 / production roadmap (out of MVP scope)

- **2FA** — Conditional Access MFA on the AVD app (`scripts/conditional-access-mfa.ps1`; needs Entra P1/P2).
- **Intune** — re-add the `mdmId` in `session-hosts.bicep` for MDM enrollment + policy baselines.
- **Customer-managed keys (CMK)** for storage (data is already encrypted at rest without this).
- **Egress / DLP** — per-vNet Azure Firewall (FQDN/L7 filtering) and blocking browser-based cloud
  uploads / clipboard lockdown to fully close exfil paths.
- **Golden image pipeline** (Azure Image Builder → Compute Gallery) with FSLogix + hardened toolset.
- **Defender for Cloud/Endpoint** baselines and **per-engagement customer connectivity**
  (S2S VPN with overlap resolution).
