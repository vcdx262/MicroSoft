# AVD Platform — Documentation

Design documentation for the hardened, network-isolated Azure Virtual Desktop platform.
This is the published subset: design intent, the decision records, the security design,
and the gotchas knowledge base. Point-in-time operational logs (per-deploy logs, status
dashboards, change logs) are kept out of the public repository.

## Start here

1. [`design-intent.md`](design-intent.md) — what the platform is and why it's built this way.
2. [`decisions/`](decisions/) — the architecture decision records (ADR 0001–0009): Entra-only
   identity, per-customer isolated vNets, Azure Files + Entra Kerberos, NAT-gateway egress,
   personal host pool, Bicep IaC in Central US, Intune config plane, OneDrive/FSLogix data plane.
3. [`security-design/`](security-design/) — requirements, assumptions, constraints, risks, the
   controls catalog, and the test plan.
4. [`gotchas.md`](gotchas.md) — hard-won operational learnings (app IDs, role assignments,
   licensing dependencies, deployment races).
5. [`../AVD-Deployment-Guide.md`](../AVD-Deployment-Guide.md) — the step-by-step deploy runbook.

## How to deploy

See [`../AVD-Deployment-Guide.md`](../AVD-Deployment-Guide.md). Infrastructure is Bicep
([`../bicep/`](../bicep/)); identity, FSLogix and storage-Kerberos helpers are in
([`../scripts/`](../scripts/)); Intune configuration profiles are in ([`../intune/`](../intune/)).
