# Test Plan — Data Protection Controls

We work the selected controls **one set (phase) at a time**: apply in a controlled/audit way →
observe effect + usability impact → record result in [controls-catalog.md](controls-catalog.md) →
make a decision (**Adopt / Defer / Reject**) at the phase gate → only then move to the next phase.
Adopted controls get implemented in IaC / the golden image and logged in
[../deployments/DEPLOYMENT-LOG.md](../deployments/DEPLOYMENT-LOG.md).

**Selected for testing (decision SD-4, 2026-06-18):** A, B, E, F, G + third-party screen recording.
**Not selected now:** C (browser URL blocklist), D (Azure Firewall egress) — see [residual gap](#residual-gap).

> **Progress (2026-06-21):** Phase 1 (A) ✅ done, Phase 2 (B) ✅ done (SCP adopted, watermark off),
> **scoped 2FA ✅ proven** (prereq). **Phase 3 (E) Tenant Restrictions 🔄 in progress** — baseline captured
> (lab1 can sign into a personal MSA = vector open); enforcement to be delivered via **Intune** (ADR 0008),
> currently **portal/SP-gated** (G-020). Phases 4–5 (F/G) licensed, not started; Phase 6 (recording) not started.
> Lab on **E5 trial**. Resume point in [../status.md](../status.md). See [../test-results-and-findings.md](../test-results-and-findings.md).

**Test bed:** `sh0-avd-cust0` is the pilot host; `steven@virtuallyhacked.com` the test user. Prefer
**audit/report-only modes** first to avoid lock-out. All Phase 1–2 controls are reversible config.

## Phase overview

| Phase | Set | Controls | Cost / prereq | Risk | Gate before next |
|---|---|---|---|---|---|
| **1** | A — Redirection lockdown | DP-02, DP-03, DP-04 | Free (config) | Low | Decide each |
| **2** | B — Capture protection + watermark | DP-05, DP-06 | Free (config) | Low–Med (client compat) | Decide each |
| **3** | E — Tenant Restrictions v2 | DP-11 | Entra **P1**; Windows-route enforcement free | Med (sign-in lockout) | Decide |
| **4** | F — Purview DLP + labels | DP-13 | **E5 / E5 Compliance** licensing | Med (false positives) | Decide |
| **5** | G — Defender for Endpoint + ASR + device control | DP-14 | **MDE** licensing | Med | Decide |
| **6** | Third-party screen recording | DP-16 | ISV licensing + privacy policy | Med (privacy/legal) | Decide vendor |

Sequencing rationale: free / low-risk / high-value config first (1–2), identity next (3), then the
licensed heavier layers that need procurement and (ideally) Intune for delivery (4–6).

---

## Phase 1 — Session redirection lockdown (A)
- **Goal:** stop data leaving the session to the endpoint via clipboard / printer / USB.
- **Controls:** DP-02 clipboard (test **one-way paste-in only** vs. fully off — [C-6](constraints.md)), DP-03 printer off, DP-04 USB/device off. (DP-01 drive already Adopted.)
- **How:** set host-pool RDP properties (`redirectclipboard`, `redirectprinters`, `usbdevicestoredirect`) and/or session-host policy; reconnect; attempt to copy/print/USB-copy out.
- **Success:** copy-out paths blocked; consultant workflow (incl. legit paste-in if chosen) still works.
- **Watch-outs:** over-tight clipboard hurts productivity; decide direction.
- **Status:** Not started.

## Phase 2 — Screen capture protection + watermarking (B)
- **Goal:** block screenshots/recording of the session (DP-05) and make screen-photos traceable (DP-06).
- **How:** AVD administrative template (`terminalserver-avd.admx`) via CSE/Intune → "Enable screen capture protection" (client, or client+server) and "Enable watermarking"; reconnect with a supported client.
- **Success:** screenshots show black; QR watermark visible and decodes to connection/device ID.
- **Watch-outs:** **watermarking blocks unsupported clients from connecting**; SCP vs. Teams screen-share compatibility; desktop-only (not RemoteApp). Test the clients your consultants actually use (Windows App, web).
- **Status:** Not started.

## Phase 3 — Tenant Restrictions v2 (E)
- **Goal:** block sign-in to personal Microsoft accounts / other tenants from these hosts.
- **Prereq:** Entra **P1**. Enforce via the **Windows device route** (GPO/registry signaling on the session host) — free for our Windows+Edge hosts; GSA route is licensed.
- **How:** author the TRv2 policy in Entra (default block + allow our tenant); enable signaling on `sh0`; run in **audit** first, then enforce; attempt personal-MSA and foreign-tenant sign-in.
- **Success:** personal/other-tenant auth blocked; corporate M365 unaffected.
- **Watch-outs:** consumer `onedrive.live.com` is **not** covered by TRv2 (legacy stack) — residual; would need C or F to fully close.
- **Status:** Not started.

## Phase 4 — Purview DLP + sensitivity labels (F)
- **Goal:** content-aware protection — classify customer data and block/audit it leaving (incl. Endpoint DLP: upload-to-cloud, USB, paste, print).
- **Prereq:** **E5 / E5 Compliance** licensing (confirm SKU); onboard `sh0` for Endpoint DLP.
- **How:** create a "Customer-Confidential" label + a DLP policy in **audit/test** mode; tag sample data; attempt egress; tune; then enforce.
- **Success:** labeled data blocked on disallowed egress paths; acceptable false-positive rate.
- **Watch-outs:** tuning effort; licensing cost; needs onboarding.
- **Status:** Not started (gated on licensing decision — [A-6](assumptions.md)).

## Phase 5 — Defender for Endpoint + ASR + device control (G)
- **Goal:** EDR + web content filtering + USB/device control + attack-surface-reduction.
- **Prereq:** **MDE** licensing; onboard `sh0`.
- **How:** onboard host; enable web content filtering (block personal-cloud categories), device control (block removable storage), and a few ASR rules in **audit → block**.
- **Success:** EDR reporting live; USB blocked; risky categories blocked; no workflow breakage.
- **Watch-outs:** ASR rules can break tooling — audit first (esp. for pentest tools).
- **Status:** Not started (gated on licensing).

## Phase 6 — Third-party screen recording (DP-16)
- **Goal:** record consultant desktop sessions for audit/accountability (AVD has no native video recording — Bastion recording doesn't cover reverse-connect AVD desktops).
- **How:** shortlist 1–2 ISVs (e.g., Teramind / Proofpoint-ObserveIT / Ekran / Veriato); PoC agent on a test host; evaluate capture fidelity, storage/SIEM integration, performance impact, **privacy/notification** requirements, and cost.
- **Success:** sessions recorded and reviewable; acceptable host performance; privacy notice/consent in place.
- **Watch-outs:** **legal/consent** obligations for recording staff; per-user licensing; agent footprint on pentest tooling.
- **Status:** Not started (vendor selection + privacy policy required).

---

## Residual gap
Skipping **C** (browser blocklist) and **D** (Azure Firewall) leaves the **arbitrary browser-upload /
general-internet egress** vector ([RK-6](risks.md)) only partially covered. It is **substantially**
addressed by **F (Endpoint DLP)** + **G (Defender web content filtering)** + **E (no personal-cloud
sign-in)** — so C/D become optional rather than essential **once F/G are adopted**. Until then, RK-6
remains open. Re-evaluate after Phase 5. (Consumer `onedrive.live.com` web specifically: closed by C or F.)

## Working loop (every phase)
1. Apply on `sh0` in audit/controlled mode.  2. Observe effect + usability.  3. Record in the
controls-catalog **test-and-decide log**.  4. Decision at the gate.  5. If Adopted → implement in
IaC/image, log in DEPLOYMENT-LOG, update risk residuals in [risks.md](risks.md).
