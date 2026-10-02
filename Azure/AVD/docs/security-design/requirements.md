# Requirements — Data Protection

What the data-protection design must achieve. Referenced by controls (DP-IDs) and risks (RK-IDs).

| ID | Requirement | Rationale |
|---|---|---|
| **R-1** | Customer data must not flow from the AVD session to destinations outside the security boundary (personal cloud, personal identity, the user's local endpoint, removable media, arbitrary internet upload). | Core goal of the design. |
| **R-2** | Persistent customer data lives **only** on controlled per-customer storage (Azure Files). No other sanctioned persistent store. | Keep data in one governed place. |
| **R-3** | Consultants retain the **outbound internet access needed for security work** (tooling, research, testing targets). | Hard usability requirement for pentest work — see [C-1](constraints.md). |
| **R-4** | Each customer's data stays within that customer's isolated environment (no cross-customer flow). | Already enforced by per-vNet isolation (ADR 0002). |
| **R-5** | Data-egress paths and attempts should be **auditable / monitorable**. | Detect and investigate; demonstrate control to customers. |
| **R-6** | Corporate M365 (mail, corporate OneDrive/SharePoint) is **inside** the boundary and remains usable; **personal** Microsoft/cloud accounts are **outside** and must be blocked. | Distinguish sanctioned cloud from exfil cloud. |
| **R-7** | Controls must be deliverable under the current identity model (Entra-only, no AD) and not depend on capabilities we've deferred unless explicitly moved to rev1. | Buildability — see [C-2](constraints.md), [C-4](constraints.md). |
| **R-8** | The data itself should be classifiable so protection can be **content-aware**, not only path-based (longer-term). | Path controls reduce vectors; only content-aware DLP governs the data regardless of channel. |
