# Security Design — Data Protection (working set)

Working documentation for the **data-protection / data-egress** security design of the AVD
platform. Purpose: stop customer data flowing from the AVD session to anything **outside our
security posture**, while keeping the desktops usable for security-consulting work.

This is a **living set**. We test each candidate control, record what happened, and make a
decision. Nothing here is "done" until it has a recorded decision in [`controls-catalog.md`](controls-catalog.md)
and (if adopted) an entry in the main [deployment log](../deployments/DEPLOYMENT-LOG.md) / IaC.

## The security boundary

> **Inside the boundary** (trusted / "secured by our posture"):
> the AVD session host, our **per-customer Azure Files** storage, our **Entra/M365 tenant**, and
> **approved customer networks** (the vNet we deliberately peer per engagement).
>
> **Outside the boundary** (untrusted): the user's local endpoint, the open internet, **personal**
> Microsoft accounts and consumer cloud storage, any other tenant, removable media.

The design goal is to **close or govern every path data can take from inside → outside**.

## Files in this set

| File | What it holds |
|---|---|
| [requirements.md](requirements.md) | What the design must achieve (R-IDs) |
| [constraints.md](constraints.md) | Hard limits we must design within (C-IDs) |
| [assumptions.md](assumptions.md) | What we're taking as true (A-IDs) — revisit if they change |
| [risks.md](risks.md) | Exfiltration vectors as a risk register (RK-IDs) |
| [controls-catalog.md](controls-catalog.md) | **The tracker** — each control (DP-IDs): method, status, test, decision |
| [test-plan.md](test-plan.md) | **Phased plan** to test the selected controls one set at a time (A, B, E, F, G + screen recording) |
| [track1-lab-plan.md](track1-lab-plan.md) | **Scoped test-lab** build + teardown plan (isolated lab users/host for testing E/F/G/2FA safely) |
| [decisions.md](decisions.md) | Security design decisions log (SD-IDs) |

## How we work this set (test-and-decide loop)

1. A control starts as **Proposed** in the catalog.
2. We **test** it (apply in a controlled way, observe effect + side-effects on usability).
3. We record the result and set a status: **Adopted**, **Deferred (rev1)**, or **Rejected**.
4. Adopted controls get implemented in IaC/host config and logged in the main deployment log;
   the catalog links to where they live.

Status legend: `Proposed` · `Testing` · `Adopted` · `Deferred` · `Rejected`.

## Relationship to the rest of the docs
- Architectural decisions live in [../decisions/](../decisions/) (ADRs); **security control** decisions
  live here in [decisions.md](decisions.md).
- Operational traps go in [../gotchas.md](../gotchas.md); deploy outcomes in [../deployments/](../deployments/).
