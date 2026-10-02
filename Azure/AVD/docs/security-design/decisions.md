# Security Design Decisions

Lightweight log of **security-control** decisions (SD-IDs). Architectural decisions live in the
ADRs ([../decisions/](../decisions/)); this is for the data-protection design specifically.
Newest at the top. Most controls are still **open** pending test (see [controls-catalog.md](controls-catalog.md)).

### Template
```
## SD-NN · YYYY-MM-DD · <decision>
- Context / options considered.
- Decision.
- Affects: DP-IDs / R-IDs / RK-IDs.
```

---

## SD-4 · 2026-06-18 · Selected control set + phased test plan
- Context: choosing which data-protection controls to trial first.
- Decision: test **A** (DP-02/03/04), **B** (DP-05/06), **E** (DP-11), **F** (DP-13), **G** (DP-14),
  and **third-party screen recording** (DP-16), **one phase at a time** per [test-plan.md](test-plan.md).
  **Not selected now:** C (DP-08 browser blocklist) and D (DP-09/10 Azure Firewall) — RK-6 to be
  re-evaluated after F/G (Phase 5), which substantially cover the browser-upload vector.
- Affects: DP-02/03/04/05/06/11/13/14/16; RK-6 (residual until Phase 5).

## SD-3 · 2026-06-18 · Favor session-boundary + identity/content controls over blanket egress denial
- Context: [C-1](constraints.md) — pentest work needs broad internet; a deny-by-default egress allowlist would impede it.
- Decision (provisional): primary strategy = tighten the **session boundary** (DP-01..06), govern **identity/content** (DP-11, DP-13), and **monitor** egress (DP-10) — rather than hard-block all outbound. A full allowlist (DP-09) is reserved for non-pentest analyst desktops or specific high-sensitivity engagements. To validate.
- Affects: DP-09, DP-10, R-1, R-3.

## SD-2 · 2026-06-18 · OneDrive sync client disabled (sync vector only)
- Decision: disable the OneDrive sync client on hosts (DP-07). Accept that this does **not** cover browser-based uploads — those are handled by DP-08/09/11.
- Affects: DP-07, RK-7. Implemented.

## SD-1 · 2026-06-18 · Local drive redirection disabled
- Decision: disable RDP drive redirection on the host pool (DP-01) as a baseline anti-exfil control.
- Affects: DP-01, RK-2. Implemented.

---

### Open decisions to make (as we test)
- **Clipboard** (DP-02): block entirely vs. keep on. Binary — no one-way option ([C-6](constraints.md)).
- **Printer / USB** redirection (DP-03/04): disable now?
- **Screen Capture Protection + Watermarking** (DP-05/06): adopt?
- **Browser blocklist scope** (DP-08): which domains; block personal cloud only, or corporate OneDrive too?
- **Egress posture** (DP-09/10): allowlist vs. monitor-only — gated by SD-3 validation and the rev1 firewall.
- **rev1 licensing** for DP-12/13/14 (CA, Purview DLP, Defender) — depends on [A-6](assumptions.md)/[C-5](constraints.md).
