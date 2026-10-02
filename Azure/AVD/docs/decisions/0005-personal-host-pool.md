# 0005 · Personal/persistent host pool (reject pooled multi-session)
- **Status:** Accepted
- **Date:** 2026-06-18

## Context
Consultants do security/pentest work, installing tools and carrying engagement state. Host pool
type must suit that working style at small scale (1–3 now).

## Decision
Use a **Personal (persistent)** host pool — one dedicated VM per consultant
(`personalDesktopAssignmentType = Automatic`, `loadBalancerType = Persistent`,
`maxSessionLimit = 1`), with **Start VM on Connect** for cost control.

## Alternatives considered
- **Pooled multi-session:** cheaper at scale, user data persists via FSLogix, but machine state
  is ephemeral — awkward for installed offensive tooling and per-box customization. Rejected for
  this use case.

## Consequences
- One VM per consultant; scale by increasing `sessionHostCount`.
- Pairs with FSLogix for profile roaming/backup even on personal desktops.
- Cost managed via Start-VM-on-Connect + (rev1) a personal-desktop scaling plan.
