# 0002 · One isolated vNet per customer with overlapping IP space
- **Status:** Accepted
- **Date:** 2026-06-18

## Context
Each engagement may need to integrate the consultant environment into the customer's network,
and customers commonly use the same RFC1918 ranges. The firm wants to reuse identical address
space per customer without future redesign.

## Decision
Give **each customer its own vNet** with **intentionally overlapping** address space
(e.g. `10.10.0.0/16` reused). vNets are **never peered to each other or to a shared hub**.
Each vNet is self-sufficient: own NAT egress, DNS, storage, hosts.

## Alternatives considered
- **Hub-spoke with a shared firewall:** requires peering, which is impossible with overlapping
  IPs and would couple customers together. Rejected.
- **Unique non-overlapping ranges per customer:** defeats the "integrate with customer who uses
  the same ranges" goal and adds IPAM overhead. Rejected.

## Consequences
- Works because AVD **Reverse Connect** is outbound-only (no inbound routing into the vNet
  needed) and the control plane is a managed SaaS — see design-intent.
- Egress/DNS/storage must be **per-vNet** (can't centralize behind a shared hub).
- Customer integration is done **per-vNet** (peer/VPN that one vNet, resolve overlap then).
- Cloning model: copy `params/cust01.bicepparam`, deploy to a new RG. See ADR 0006.
