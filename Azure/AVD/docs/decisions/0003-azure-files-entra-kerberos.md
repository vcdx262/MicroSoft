# 0003 · Azure Files + Entra Kerberos for storage (reject NetApp)
- **Status:** Accepted
- **Date:** 2026-06-18

## Context
Each vNet needs file storage the desktops reach out to (FSLogix profile containers + a data
share), encrypted at rest, reachable only privately. Identity is Entra-only (ADR 0001).

## Decision
Use **Azure Files** (Premium FileStorage) with **Microsoft Entra Kerberos** authentication.
Public network access disabled; reachable only via a **private endpoint** in `snet-pe`.
Two shares: `profiles` (FSLogix) and `data`.

## Alternatives considered
- **Azure NetApp Files:** higher performance, but **requires AD DS / Entra Domain Services** —
  it does not support Entra-only (cloud-only) identities. Incompatible with ADR 0001. Rejected.
  (See gotcha G-003.)

## Consequences
- Encrypted at rest by default (AES-256, Microsoft-managed keys); CMK deferred to rev1 (ADR 0007).
- Entra Kerberos enable + admin consent are **not ARM-expressible** → `scripts/enable-storage-kerberos.ps1` (G-002).
- The storage app must not require MFA (silent ticket acquisition) — G-008.
- Private endpoint requires a `privatelink.file.*` private DNS zone linked to the vNet.
