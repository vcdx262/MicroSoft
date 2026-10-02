# 0008 · Adopt Microsoft Intune as the session-host configuration-delivery plane
- **Status:** Accepted
- **Date:** 2026-06-21
- **Supersedes part of:** ADR 0007 (rev0 deferred Intune)

## Context
rev0 delivered all in-guest host configuration (Screen Capture Protection, redirection, FSLogix, OneDrive
disable, Cloud Kerberos) via a **Custom Script Extension + registry**, applied per host at deploy time, and
**deliberately removed Intune enrollment** (stripped `mdmId`). While testing **Tenant Restrictions v2**, the
owner pushed back on per-instance registry hardening and asked for controls to be managed **at the platform
level**, not custom-hardened on each instance.

## Decision
Adopt **Microsoft Intune** as the configuration-delivery plane for AVD session hosts going forward (rev1):
- **Device controls via Intune** (Settings Catalog / config profiles assigned to device groups): Screen
  Capture Protection + Watermarking (AVD admin template), redirection (RDS policies), FSLogix (ADMX),
  OneDrive disable (ADMX), Cloud Kerberos, **Tenant Restrictions v2 enforcement** (`ConfigureTenantRestrictions`
  CSP), and Defender for Endpoint onboarding/ASR/device control.
- **Identity controls stay in Entra**: 2FA / **Conditional Access** is an identity-plane policy (already
  platform-level) — not Intune. Purview DLP is configured in the Purview portal (Endpoint DLP integrates with
  the enrolled device).
- **Re-enable Intune enrollment** on session hosts (reverses the rev0 `mdmId` removal) via an `enableIntune`
  toggle (default true).

## Alternatives considered
- **Custom Script Extension / registry (rev0 approach):** consistent via the pipeline but per-instance,
  deploy-time only, no live management plane. Kept only for *bootstrap* (AVD agent install, FSLogix install).
- **Global Secure Access — Universal Tenant Restrictions:** purest (identity-plane, no device config) but
  needs **Entra Suite / GSA licensing** (not in E5). Revisit if licensed.
- **AD Group Policy:** N/A (Entra-only, no AD).

## Consequences
- Session hosts must be **Entra-joined + Intune-enrolled** (MDM auto-enrollment scope in Entra). The
  enrolling identity needs an **Intune license** — included in **M365 E3 / E5 / Business Premium**, but **NOT
  Business Standard** (so production tier must include Intune; lab uses E5).
- Existing CSE/registry controls get **migrated to Intune policies** over time; the CSE `setupScript` shrinks
  to bootstrap-only (agent + FSLogix install).
- Config becomes **fleet-managed** (device groups) rather than baked per host — the platform model the owner wants.
- New dependency: Intune config profiles + assignments (managed via Graph `deviceManagement` or the portal).
