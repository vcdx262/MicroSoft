# 0001 · Entra-ID-only identity (no AD DS)
- **Status:** Accepted
- **Date:** 2026-06-18

## Context
The platform must authenticate consultants and join session hosts. Options: stand up Active
Directory Domain Services (or Entra Domain Services), or use Entra-ID-only (cloud-only) join.
The firm has no existing AD and wants minimal infrastructure for the MVP.

## Decision
Use **Entra-ID-only**: session hosts are Entra-joined, users sign in with Entra/M365 accounts,
VM sign-in via the `Virtual Machine User Login` / `Virtual Machine Administrator Login` RBAC roles.

## Alternatives considered
- **AD DS / Entra Domain Services:** more moving parts (DCs, DNS, vNet line-of-sight), and would
  be required only if we used Azure NetApp Files (see ADR 0003). Rejected for the MVP.

## Consequences
- No domain controllers to run or secure.
- Storage must use Azure Files + Entra Kerberos (cloud-only), not NetApp (ADR 0003).
- FSLogix profiles work without DC line-of-sight.
- Some setup is Entra/Graph-side, not ARM (see gotcha G-002).
