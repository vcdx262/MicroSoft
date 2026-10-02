# Assumptions — Data Protection

Taken as true for this design. **If one proves false, revisit the dependent controls/risks.**

| ID | Assumption | If false… |
|---|---|---|
| **A-1** | Consultants are **semi-trusted insiders** — controls target accidental leakage, casual exfil, and raising the bar; not a determined malicious admin (they hold local admin, [C-8](constraints.md)). | If insider threat is in scope, need least-privilege (remove local admin), stronger monitoring, and content-aware DLP as primary. |
| **A-2** | Customer data is primarily handled **inside the session** and on the **data share**, not pre-staged on consultant endpoints. | If data also lives on endpoints, endpoint DLP becomes in-scope. |
| **A-3** | **Corporate M365** (the firm's tenant) is inside the boundary and trusted; **personal** Microsoft/consumer cloud is outside. | If corporate M365 must also be restricted, add CA app-enforced restrictions / DLP on corporate OneDrive-SharePoint too. |
| **A-4** | Connecting **endpoints (consultant laptops) are not fully trusted/managed** yet. | If endpoints become managed/compliant, some boundary controls can relax (e.g., allow clipboard to compliant devices via CA device state). |
| **A-5** | Network access is **outbound-only via NAT**, no inbound, no public IPs (current design). | n/a unless network model changes. |
| **A-6** | The firm is willing to invest in **rev1 licensing** (E5/compliance, Intune) for the heavier controls when justified. | If not, content-aware DLP and Intune-based controls are off the table; rely on path/session controls only. |
| **A-7** | "Approved customer networks" reached via per-engagement peering are themselves **in-scope/secured** destinations. | If a customer network is untrusted, treat that peering as an egress path too. |
