# Risk Register — Data Egress

Exfiltration vectors (data leaving the boundary). Likelihood/Impact are pre-mitigation unless noted.
Each risk links to the control(s) that address it in [controls-catalog.md](controls-catalog.md).

| ID | Vector (how customer data leaves) | Likelihood | Impact | Current state | Controls |
|---|---|---|---|---|---|
| **RK-1** | **Clipboard** copy from session → local PC | High | Med | ⚠️ Open — clipboard redirection currently allowed | DP-02 |
| **RK-2** | **Local drive** redirection (copy files to endpoint) | High | High | ✅ Mitigated — drive redirection disabled | DP-01 |
| **RK-3** | **Printer** redirection / print-to-PDF on local device | Med | Med | ⚠️ Open | DP-03 |
| **RK-4** | **USB / device** redirection to endpoint | Med | High | ⚠️ Open | DP-04 |
| **RK-5** | **Screenshot / screen recording** of the session | Med | Med | ⚠️ Open | DP-05, DP-06 |
| **RK-6** | **Browser upload** to personal cloud / webmail / file-share | High | High | ⚠️ Open — broad 80/443 egress allowed ([C-9](constraints.md)) | DP-08, DP-09, DP-11 |
| **RK-7** | **OneDrive sync client** to personal/other account | Med | High | ✅ Mitigated — sync client disabled | DP-07 |
| **RK-8** | **Sign-in to personal / other-tenant** Microsoft cloud | Med | High | ⚠️ Open | DP-11 |
| **RK-9** | **Content leak via corporate channels** (email attachment, corporate OneDrive over-share) | Med | High | ⚠️ Open — no content-aware DLP | DP-13 |
| **RK-10** | **Malware / endpoint compromise** on the session host | Low–Med | High | ⚠️ Open — no EDR baseline yet | DP-14 |
| **RK-11** | **Malicious local admin** disables host controls then exfils ([C-8](constraints.md), [A-1](assumptions.md)) | Low | High | ⚠️ Accepted risk in rev0 (insider out of primary scope) | DP-13, DP-14, monitoring |
| **RK-12** | **Approved customer network** used as an exit to untrusted onward paths ([A-7](assumptions.md)) | Low | Med | ⚠️ Per-engagement review | (engagement-specific) |

> Residual risk after a control is **Adopted** should be re-noted here with the new likelihood/impact.
