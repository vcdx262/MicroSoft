# Controls Catalog — Data Protection (the tracker)

Each candidate control: what it does, the layer, how to implement, cost/licensing, the vector it
closes, and a **status → test → decision**. We work these one at a time.

**Status legend:** `Proposed` · `Testing` · `Adopted` · `Deferred (rev1)` · `Rejected`
**Layers:** Session boundary · Network egress · Identity · Browser · Content (DLP) · Endpoint · Data residency

## Summary

| ID | Control | Layer | Addresses | Method | Cost/License | Status |
|---|---|---|---|---|---|---|
| **DP-01** | Disable **drive** redirection | Session | RK-2 | RDP `drivestoredirect:s:` | none | **Adopted** (in host pool RDP props) |
| **DP-02** | Restrict **clipboard** redirection | Session | RK-1 | RDP `redirectclipboard:i:0` (off), OR session-host directional/data-type policy for one-way paste-in only ([C-6](constraints.md)) | none | **Testing** (disabled fully on host pool 2026-06-18; user to verify) |
| **DP-03** | Disable **printer** redirection | Session | RK-3 | RDP `redirectprinters:i:0` | none | **Testing** (disabled on host pool 2026-06-18; user to verify) |
| **DP-04** | Disable **USB/device** redirection | Session | RK-4 | RDP `usbdevicestoredirect:s:` | none | **Adopted** (off by default; explicitly locked on host pool + Bicep 2026-06-18) |
| **DP-05** | **Screen Capture Protection** | Session | RK-5 | Session-host policy `fEnableScreenCaptureProtect=2` (client+server) | none | ⚠️ **Conflict — disabled on lab 2026-06-23.** Verified working (G-018) but SCP=2 **garbles GPU-accelerated Edge** (G-028). User chose **GPU-on + SCP=0** on lab. Prod IaC still `=2`; **platform decision pending** (SCP vs GPU-Edge UX) |
| **DP-06** | **Watermarking** | Session | RK-5 | Session-host policy `fEnableWatermarking=1` (+ QR tuning) | none | **Verified, OFF by choice** (QR too intrusive; re-enable via `fEnableWatermarking=1`) |
| **DP-07** | Disable **OneDrive sync client** | Endpoint/host | RK-7 | `DisableFileSyncNGSC` + `DisablePersonalSync` (CSE) | none | **Adopted** (in `ConfigureSessionHost`) |
| **DP-08** | **Browser URL blocklist** (consumer cloud / webmail) | Browser | RK-6 | Edge/Chrome `URLBlocklist` policy (registry/Intune) | none | Proposed |
| **DP-09** | **Egress allowlist** (deny-by-default FQDN filtering) | Network | RK-6 | Azure Firewall per vNet ([C-3](constraints.md)) | ~$ per vNet | Proposed — tension with [C-1](constraints.md) |
| **DP-10** | **Egress logging / monitoring** | Network | RK-6, R-5 | Azure Firewall logs / Defender web content filtering → Log Analytics | $ | Proposed |
| **DP-11** | **Tenant Restrictions v2** (block personal / other-tenant cloud sign-in) | Identity | RK-6, RK-8 | Entra Tenant Restrictions v2 + egress header injection | Entra config | ❌ **Tested, NOT adopted (2026-06-23)** — blocks personal MSA in **Edge** only; Chrome/Firefox/.NET bypass without `enforceFirewall`+App Control. Edge-only coverage rejected |
| **DP-12** | **CA app-enforced restrictions** (web-only / block download) on M365 | Identity | RK-9 | Conditional Access session controls | needs CA (rev1) | Deferred (rev1) |
| **DP-13** | **Purview DLP + sensitivity labels** (content-aware) | Content | RK-6, RK-9, RK-11 | Microsoft Purview | E5 / compliance | Deferred (rev1) |
| **DP-14** | **Defender for Endpoint + ASR + device control** | Endpoint | RK-10, RK-4, RK-11 | Defender for Endpoint onboarding + policies | Defender license | Deferred (rev1) |
| **DP-15** | **Confine persistent data to controlled Azure Files** | Data residency | R-2 | Storage is the only sanctioned store; review for other writable persistence | none | Proposed (principle — verify) |
| **DP-16** | **Third-party session/screen recording** | Endpoint / Audit | R-5, RK-11 | ISV agent on session host (image/Intune); AVD has no native video recording | ISV per-user license | Proposed (Phase 6) |

> **Active test plan:** [test-plan.md](test-plan.md) sequences the selected sets — A (DP-02/03/04),
> B (DP-05/06), E (DP-11), F (DP-13), G (DP-14), and DP-16 — one phase at a time. **C (DP-08)** and
> **D (DP-09/10)** are **not selected** for now (see the residual-gap note in the test plan).

## Test-and-decide log

Append a dated block per control as we test it. Template:

```
### DP-NN — <control>  · YYYY-MM-DD
- Test: what we changed and how we observed effect.
- Result: did it block the vector? side-effects on usability?
- Decision: Adopted | Deferred | Rejected — and why.
- Where it lives: file/host-pool property / IaC path (if adopted).
```

### DP-01 — Disable drive redirection · 2026-06-18
- Test: set `drivestoredirect:s:` in the host pool `customRdpProperty` at deploy.
- Result: local drives not offered in session (to confirm on next interactive check).
- Decision: **Adopted** — included in `avd-controlplane.bicep`.
- Where it lives: `bicep/modules/avd-controlplane.bicep` (`customRdpProperty`).

### DP-07 — Disable OneDrive sync client · 2026-06-18
- Test: `DisableFileSyncNGSC=1` + `DisablePersonalSync=1` applied via `ConfigureSessionHost` CSE.
- Result: sync client blocked; **does not** stop browser uploads (gap → DP-08/DP-09/DP-11). See gotcha G-010.
- Decision: **Adopted** for the sync-client vector; browser vector tracked separately.
- Where it lives: `bicep/modules/session-hosts.bicep` (`setupScript`).

### DP-02 — Disable clipboard redirection · 2026-06-18
- Test: set host-pool `customRdpProperty` `redirectclipboard:i:1` → `i:0` via REST PATCH (verified on host pool). Also updated in `avd-controlplane.bicep` to prevent redeploy drift.
- Result: _pending user verification_ — reconnect (fresh session) then confirm copy-in-VDI → paste-local is blocked (and reverse).
- Decision: chosen **fully off** (not one-way) per user direction; confirm Adopt after verification.
- Where it lives: live host pool `hp-avd-cust01` + `bicep/modules/avd-controlplane.bicep`.

### DP-03 — Disable printer redirection · 2026-06-18
- Test: appended `redirectprinters:i:0` to host-pool `customRdpProperty` via REST PATCH (verified); matched in `avd-controlplane.bicep`.
- Result: _pending user verification_ — reconnect, confirm no local printers in session.
- Decision: confirm Adopt after verification.
- Where it lives: live host pool `hp-avd-cust01` + `bicep/modules/avd-controlplane.bicep`.

### DP-05 fix — correct SCP registry value name · 2026-06-18
- Issue: SCP had no effect (screenshots worked on host AND in-VDI; web client wasn't refused). Root cause: wrong registry value name `fEnableScreenCaptureProtection` — correct name is **`fEnableScreenCaptureProtect`** (gotcha G-018).
- Fix: set `fEnableScreenCaptureProtect=2` on sh0 + corrected `session-hosts.bicep`. **Reboot required** to engage.
- Verify after reboot: host screenshot black, in-VDI capture blocked, AND web client now **refused** (good signal SCP is active).

### DP-05 / DP-06 — Screen capture protection + watermarking · 2026-06-18
- Test: set `fEnableScreenCaptureProtect=2` (client+server) and `fEnableWatermarking=1` on sh0; rebooted.
- Result: **both verified working** —
  - **DP-05 (SCP):** screenshots blocked from the **host PC** (Snagit) *and* from **inside the VDI**; web client refused. **Adopted.**
  - **DP-06 (watermark):** QR overlay rendered correctly and traced to the session — feature **proven working**, but the QR was too intrusive for daily use.
- Decision: **DP-05 Adopted** (live + Bicep). **DP-06 verified then turned OFF by choice** (`fEnableWatermarking=0` on sh0 + Bicep); re-enable any time by flipping to `1` (optionally soften via opacity/spacing). Note: SCP alone keeps the **web client blocked**, so disabling watermark does not reopen web access.
- Where it lives: live `sh0` + `bicep/modules/session-hosts.bicep`.

### DP-11 — Tenant Restrictions v2 · 2026-06-23
- Test (lab): cross-tenant default policy blocks all external users+apps (Policy ID `<redacted-tenant-object-id>`,
  covers consumer MSA at the identity plane). Device enforcement applied to `vm-avd-lab-sh0` via registry
  (`…\TenantRestrictions\Payload` `tenantid`+`policyid`, G-027), host restarted. Delivered by registry because the
  host isn't Intune-enrolled (MDM scope off); prod path is the authored Intune profile.
- Result: **personal Microsoft account sign-in BLOCKED in Edge** (`account.microsoft.com` → tenant-restricted
  message); lab1 work account unaffected. **Capability proven.** Two findings:
  - **Coverage gap:** TRv2-on-Windows covers Edge + Office only; **Chrome/Firefox/.NET bypass** it unless
    `enforceFirewall=1` + an App Control for Business tagging policy is deployed (G-028).
  - **Side effect:** SCP=`2` garbles Edge GPU rendering; mitigated by disabling Edge hardware acceleration (G-028).
- **Decision (Steven, 2026-06-23): NOT adopted.** Edge-only enforcement is insufficient for the anti-exfil goal,
  and full coverage (App Control) is too heavy. Enforcement **removed** from the lab host. The *data* exfil concern
  is instead addressed by **device-gated OneDrive/SharePoint (ADR 0009)**; personal-account *login* blocking is
  dropped. (Could be revisited if hosts are made Edge-only — that would close the gap — but not pursued now.)
- Where it lives: removed from live host; cloud policy left inert (no device signals the header); authored Intune
  artifacts retained in `intune/` for reference, unassigned.

> Other DP-IDs are **Proposed/Deferred** — to be tested and decided. Add a block above when we do.
