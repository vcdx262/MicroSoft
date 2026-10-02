# Intune Configuration Profiles

Platform-managed delivery of host controls (ADR 0008) — replaces per-instance registry hardening
done today via the Custom Script Extension in `bicep/modules/session-hosts.bicep`.

Profiles are authored here as **Microsoft Graph payloads** (the exact body POSTed to
`/beta/deviceManagement/configurationPolicies`) so they're reviewable, version-controlled, and
reproducible. Setting IDs were pulled live from this tenant's Settings Catalog.

## Profiles

| File | Controls | Tested? | Notes |
|---|---|---|---|
| `profiles/avd-host-protections.json` | Screen Capture Protection = **Block on client and server** (value 2); Watermarking = **Disabled** | ✅ proven in lab | AVD `terminalserver-avd` ADMX (in-box). Watermark uses the `avdv1.upadtes` namespace — see G-023. |
| `profiles/avd-cloud-kerberos.json` | Cloud Kerberos Ticket Retrieval = **Enabled** | ❌ untested | Build-only (Steven, 2026-06-22). Needed for Azure Files Entra Kerberos. Do not assign until tested. |
| `profiles/avd-tenant-restrictions-v2.json` | TRv2 device enforcement: Enable + Directory ID + Policy GUID (firewall enforce = False) | ❌ untested | Build-only. Settings Catalog `ConfigureTenantRestrictions` (in-box ADMX — *not* a custom OMA-URI). Pairs with the cloud policy below; **Policy GUID is a placeholder** until the cloud policy is created. |

**Paired cloud policy:** [`cloud-policy/`](cloud-policy/README.md) — the cross-tenant access *default* policy
(block all external accounts/apps) that mints the **Policy ID** the TRv2 device profile references. Authored as
a Graph payload + gated apply procedure; **not applied** (tenant-wide identity change, has OME/B2B caveats).

**Not here yet:**
- **OneDrive lockdown** — Windows OneDrive ADMX is **not** in the in-box Settings Catalog (only macOS prefs
  exist); see G-022. Needs ADMX ingestion or stays on the CSE registry delivery.

## How to apply (when ready)

Requires the `avd-automation` service principal (App ID `c54762ad-…`) — its secret is **not stored**; provide
it at runtime. Prerequisites before *assignment* takes effect: (1) MDM auto-enrollment scope enabled in Entra,
(2) a dynamic device group for AVD hosts (`device.displayName -startsWith "vm-avd"`), (3) the host enrolled in
Intune.

```powershell
# Get a token via client credentials, then for each profile:
Invoke-RestMethod -Method Post -Headers $h `
  -Uri 'https://graph.microsoft.com/beta/deviceManagement/configurationPolicies' `
  -Body (Get-Content profiles/avd-host-protections.json -Raw)
# Assignment is a separate POST to .../configurationPolicies/{id}/assign — omitted until controls are signed off.
```

Profiles are created **unassigned** first (inert), validated on a lab host, then assigned to the AVD-hosts
device group. See `docs/status.md` "▶ Resume here" for live state.
