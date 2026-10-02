# Architecture Decision Records (ADRs)

One file per significant decision. ADRs explain *why* — so a settled choice is **not
relitigated** in a later session. An Accepted ADR is immutable; to change a decision, write a
new ADR that **supersedes** it and mark the old one `Superseded by 00NN`.

### Index

| # | Decision | Status |
|---|---|---|
| [0001](0001-entra-only-identity.md) | Entra-ID-only identity (no AD DS) | Accepted |
| [0002](0002-vnet-per-customer-overlapping-ip.md) | One isolated vNet per customer with overlapping IP space | Accepted |
| [0003](0003-azure-files-entra-kerberos.md) | Azure Files + Entra Kerberos for storage (reject NetApp) | Accepted |
| [0004](0004-nat-gateway-egress.md) | NAT Gateway + NSG for egress (reject per-vNet Firewall in MVP) | Accepted |
| [0005](0005-personal-host-pool.md) | Personal/persistent host pool (reject pooled multi-session) | Accepted |
| [0006](0006-bicep-iac-central-us.md) | Bicep as IaC; Central US region | Accepted |
| [0007](0007-rev0-scope.md) | rev0 scope: defer 2FA/Intune/CMK; OneDrive sync off; SSO toggle | Accepted |
| [0008](0008-intune-config-delivery-plane.md) | Adopt Intune as the session-host config-delivery plane (rev1) | Accepted |
| [0009](0009-onedrive-data-plane-fslogix-v2.md) | Customer data → device-gated OneDrive; Azure Files → FSLogix-only (Provisioned v2, service endpoint) | Accepted |

### Template

```
# 00NN · <Title>
- **Status:** Proposed | Accepted | Superseded by 00MM
- **Date:** YYYY-MM-DD

## Context
What forces/constraints are at play.

## Decision
What we chose.

## Alternatives considered
What we rejected and why.

## Consequences
What this enables, costs, or obligates later.
```
