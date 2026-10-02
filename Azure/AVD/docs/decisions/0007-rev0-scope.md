# 0007 · rev0 scope — defer 2FA/Intune/CMK; OneDrive sync off; SSO toggle
- **Status:** Accepted
- **Date:** 2026-06-18

## Context
The user wants to "get feet wet with AVD" first and reduce moving parts in the MVP, while still
seeing real storage behavior and protecting customer data. They also want M365 (Outlook etc.)
usable in-session and OneDrive blocked as an exfil path.

## Decision
**rev0 (MVP) excludes:** 2FA / Conditional Access MFA, Intune enrollment, customer-managed keys.
**rev0 includes:** isolated vNet, NAT egress/zero inbound, Azure Files storage (encrypted at
rest, private endpoint), personal Win11 pool, Kali VM, Entra-only sign-in, **M365 in-session**,
**OneDrive sync client disabled** (`DisableFileSyncNGSC` + `DisablePersonalSync`), and **Entra
SSO as a toggle** (`enableSso`, default `true`).

## Alternatives considered
- **Keep 2FA/Intune in MVP:** more tenant changes + licensing (Entra P1/P2) up front; deferred.
- **Block OneDrive at the network:** would also break SharePoint Online / M365 save-to-cloud.
  Chose to disable the **sync client** via policy instead (G-010).
- **Force SSO on / off:** made it a parameter so the user can choose zero-tenant-change
  (`false`) vs. smooth M365 SSO (`true`, needs `enable-avd-sso.ps1`).

## Consequences
- MFA script (`conditional-access-mfa.ps1`) retained but out of the MVP deploy flow.
- Intune re-enabled in rev1 by restoring the `mdmId` in `session-hosts.bicep`.
- Storage stays encrypted (encryption can't be disabled; only CMK was deferred — G-007).
- OneDrive block covers the sync client only; browser-upload/clipboard DLP → rev1 (G-010).
- Tenant footprint in rev0 = Entra Kerberos storage app (+ SSO SPs only if `enableSso = true`).
