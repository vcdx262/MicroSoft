# 0004 · NAT Gateway + NSG for egress (reject per-vNet Firewall in MVP)
- **Status:** Accepted
- **Date:** 2026-06-18

## Context
Requirement: secure outbound internet, zero inbound. Because vNets are isolated with
overlapping IPs (ADR 0002), egress filtering cannot be centralized behind a shared hub
firewall — any egress appliance must be per-vNet.

## Decision
MVP egress = **NAT Gateway** (outbound-only SNAT, no inbound path) + an **NSG** that denies all
inbound from Internet and scopes outbound to AVD service tags + 443. No public IPs on any VM.

## Alternatives considered
- **Azure Firewall per vNet:** FQDN/L7 filtering + threat intel, but ~$400–1200/mo **per vNet**
  (no sharing possible due to overlap). Overkill for "get feet wet." Deferred to rev1.

## Consequences
- Egress cost stays to ~tens of $/mo.
- No FQDN/L7 filtering yet — general web (80/443) is allowed outbound, which is what lets M365
  work in-session. Tightening this is a rev1 egress/DLP task (ADR 0007).
- Each new customer vNet provisions its own NAT Gateway + Public IP.
