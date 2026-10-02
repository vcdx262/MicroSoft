# AVD Deployment Guide — isolated session host from zero

**Why this exists:** the single-page path from an empty subscription to a verified,
network-isolated Azure Virtual Desktop environment, using the Bicep and scripts in this
folder. Each customer gets an isolated vNet, Entra-only identity, outbound-only networking
(no public IPs, no inbound), Azure Files profiles with Entra Kerberos, and a personal
Windows 11 host pool reached through the AVD web/client. The design rationale is in
[`docs/decisions/`](docs/decisions/) and [`docs/security-design/`](docs/security-design/).

> Secrets are never hard-coded. Session-host and Kali admin passwords are read from
> environment variables (`AVD_SH_ADMIN_PASSWORD`, `KALI_ADMIN_PASSWORD`); object IDs and
> the subscription ID are parameters. Fill a copy of the `.bicepparam` for your tenant;
> read back the IDs Azure/Entra generate rather than hard-coding them.

---

## 0. Ground truth (fill in for your tenant)

| | |
|---|---|
| Subscription | `<subscription-id>` |
| Tenant | `<tenant-id>` (Entra-only; no AD DS) |
| Region | Central US (watch the Dsv5 → **Dsv4** quota note in `docs/gotchas.md`) |
| Entra groups | `grp-avd-<customer>-users`, `grp-avd-admins` (object IDs → params) |
| Identity model | Entra-ID join, SSO on by default |

## 1. Prerequisites

```powershell
az login
az account set --subscription <subscription-id>
az bicep version                       # Bicep CLI present
# Entra groups exist and their object IDs are in your .bicepparam
az vm list-usage -l centralus -o table # confirm Dsv4 cores available
```

## 2. Parameterize

Copy a params file and fill it in (see [`bicep/params/`](bicep/params/)):

```bicep
param customerName          = 'lab'
param location              = 'centralus'
param userGroupObjectId     = '<grp-users-object-id>'
param adminGroupObjectId    = '<grp-admins-object-id>'
param logAnalyticsWorkspaceId = '/subscriptions/<subscription-id>/resourceGroups/.../workspaces/...'
param sessionHostCount      = 1
param sessionHostVmSize     = 'Standard_D2s_v4'
param enableSso             = true
```

Set the admin password(s) in the environment (never in the file):

```powershell
$env:AVD_SH_ADMIN_PASSWORD = (Read-Host 'Session host admin password' -AsSecureString |
    ConvertFrom-SecureString -AsPlainText)
```

## 3. What-if, then deploy

```powershell
az deployment sub what-if -l centralus -f bicep/main.bicep -p bicep/params/cust-lab.bicepparam
az deployment sub create  -l centralus -f bicep/main.bicep -p bicep/params/cust-lab.bicepparam
```

The stack creates: resource group, isolated vNet + subnets, NSG (no inbound), NAT gateway
for egress, Log Analytics, Azure Files storage (private endpoint, Entra Kerberos), the
personal host pool / application group / workspace, and the session host(s).

## 4. Identity, SSO and (optional) MFA

```powershell
.\scripts\enable-avd-sso.ps1                 # SSO to the session hosts
.\scripts\conditional-access-mfa.ps1          # rev1 / requires Entra P1 — start report-only
```

## 5. Profiles (FSLogix on Azure Files + Entra Kerberos)

```powershell
.\scripts\enable-storage-kerberos.ps1         # Entra Kerberos on the storage account
.\scripts\configure-fslogix.ps1               # point session hosts at the profile share
```

## 6. Intune configuration plane (optional)

Import the profiles in [`intune/profiles/`](intune/profiles/) (host protections, cloud
Kerberos, tenant restrictions) and assign them to the AVD device group. See
[`intune/README.md`](intune/README.md).

## 7. Validate

Connect a test user through the AVD client / web portal: desktop launches, SSO works, the
FSLogix profile mounts from the share. Record Expected vs. Actual in
[`AVD-Deployment-Validation-Test-Plan.xlsx`](AVD-Deployment-Validation-Test-Plan.xlsx).

```powershell
Get-AzWvdSessionHost -HostPoolName hp-avd-<customer> | Select Name,Status,Session
```

## Teardown

Delete the resource group(s); Entra objects (groups, app registrations, CA policies)
persist and are reused on the next deploy. IDs that Azure/Entra regenerate on recreate
should be read back into the params, never hard-coded.
