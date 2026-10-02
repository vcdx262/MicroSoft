# Design Intent

The north star. If a proposed change conflicts with something here, stop and confirm with the
user before proceeding.

## Business context

- Owner: Steven Slocum, runs a **security consulting firm**.
- Headcount: **1–3 consultants now, scaling to ~50**.
- Purpose: give consultants a hardened, controlled **Azure Virtual Desktop (AVD)** workspace
  from which to do client/security work, with the firm's security posture enforced centrally.

## Non-negotiable constraints

1. **One isolated vNet per customer**, with **intentionally overlapping IP space**, so each
   vNet can later be peered/VPN'd into that customer's network. vNets are **never peered to
   each other or to a shared hub** — AVD Reverse Connect (outbound-only) makes the overlap safe.
2. **Per-customer file storage** the desktops reach out to, **encrypted at rest**.
3. **Zero inbound from the internet**; **no public IPs** on any VM. Secure **outbound** only.
4. **Windows + Kali** available to consultants in each zone.
5. Access via a **web portal**.
6. Each customer environment must be **repeatable** (clone per engagement).

## Identity & data-handling intent

- **Entra-ID-only** (cloud-only), no Active Directory / domain controllers.
- Consultants use their **M365 logins** in-session (Outlook, Office) — these must work.
- **OneDrive is treated as an exfil risk** and must not be a path to sync customer data out.

## Scope split

### rev0 (MVP — "get feet wet with AVD")
Isolated per-customer vNet · NAT egress / zero inbound · Azure Files (private endpoint,
encrypted at rest by default) · personal Win11 host pool · Kali VM · Entra-only sign-in ·
M365 in-session · OneDrive **sync client disabled** · Entra SSO as a toggle (default on).

**Deliberately deferred (NOT in rev0):** 2FA / Conditional Access MFA · Intune enrollment ·
customer-managed keys (CMK) · full egress/DLP (browser-upload blocking, clipboard lockdown).

### rev1 (next)
See [`status.md`](status.md) "Roadmap" and the rev1 ADR. The MFA script already exists but is
out of the MVP flow.

## Hard technical facts that shape the design (verified against Microsoft Learn)

- AVD **Reverse Connect** = no inbound ports, no public IP needed; only outbound 443 to the
  AVD service. This is what makes overlapping isolated vNets viable.
- **Entra-ID-only join** of session hosts is fully supported (no AD DS).
- **Azure Files + Entra Kerberos** supports cloud-only identities; **Azure NetApp Files does
  not** (it requires AD DS) — hence Azure Files.
- Azure Storage is **always** encrypted at rest (AES-256, Microsoft-managed keys); only CMK is optional.
- **Kali is not a supported AVD session-host OS** → it runs as a standalone Linux VM in the subnet.
