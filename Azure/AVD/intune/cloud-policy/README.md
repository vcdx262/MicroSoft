# Tenant Restrictions v2 — Server-Side Cloud Policy

**Status: UNTESTED / build-only (Steven, 2026-06-22). Do NOT apply until reviewed and a test window is set.**

TRv2 has two halves that must agree:
1. **This cloud policy** (cross-tenant access *default* settings) — defines *what* is blocked. Creating it
   mints a **Policy ID (GUID)**.
2. **The device profile** [`../profiles/avd-tenant-restrictions-v2.json`](../profiles/avd-tenant-restrictions-v2.json)
   — pushes our **Tenant ID** + that **Policy GUID** to the host so Windows/Edge inject the TRv2 header.

Neither does anything alone: the cloud policy is inert until a device signals the header; the device profile
needs the GUID this policy generates.

## What `tenant-restrictions-default.json` does
Sets the **default** tenant restrictions to **block all external users/groups and all external applications**.
This is the vector we baselined (lab1 signing into a personal MSA in Edge) — default-block closes it.

## Apply procedure (when approved)
```powershell
# 1. Auth as avd-automation SP (needs Policy.ReadWrite.CrossTenantAccess - already consented).
#    (token fetch omitted; secret provided at runtime, never stored)

# 2. PATCH the default cross-tenant policy:
Invoke-RestMethod -Method Patch -Headers $h `
  -Uri 'https://graph.microsoft.com/beta/policies/crossTenantAccessPolicy/default' `
  -Body (Get-Content tenant-restrictions-default.json -Raw)   # strip the _comment line first

# 3. Read back the Policy ID (GUID):
Invoke-RestMethod -Headers $h -Uri 'https://graph.microsoft.com/beta/policies/crossTenantAccessPolicy/default' |
  ConvertTo-Json -Depth 8
#    Also visible in: Entra admin center > External Identities > Cross-tenant access settings >
#    Default settings > Tenant restrictions (pane shows Tenant ID + Policy ID).

# 4. Put that GUID into ../profiles/avd-tenant-restrictions-v2.json (REPLACE_WITH_POLICY_GUID...),
#    then create + assign that device profile to the AVD-hosts group and test in Edge.
```

## Caveats to validate before enabling (important)
- **Blocking all external apps by default breaks a few Microsoft flows** unless excepted (per cross-tenant
  access guidance):
  - **Office 365 Message Encryption (OME)** reading → allow app ID `00000012-0000-0000-c000-000000000000`.
  - **B2B MFA registration** → app ID `0000000c-0000-0000-c000-000000000000`; **Terms of Use** → `d52792f4-ba38-424d-8140-ada5b883f293`.
  - Our consultants sign in with *our* tenant identities, so internal access is unaffected — these only matter
    if external/B2B or OME scenarios are in play. Confirm during testing.
- **Consumer Microsoft accounts (MSA):** default-block covers them at the auth plane. For *granular* MSA control
  (allow specific apps), add an organization with tenant ID `9188040d-6c67-4c5b-b112-36a304b66dad`. Not needed
  for a pure block.
- **Firewall enforcement (`enforcefirewall`)** in the device profile is **False**: TRv2 natively covers Edge,
  Office, UWP and .NET. Chrome/Firefox can bypass unless set True (or simply don't install them on the host).
- **Verify on host:** Event Viewer → Applications and Services Logs → Microsoft > Windows > TenantRestrictions >
  Operational.

## Rollback
`POST https://graph.microsoft.com/beta/policies/crossTenantAccessPolicy/default/resetToSystemDefault`
(reverts to allow-all default), and unassign/delete the device profile.
