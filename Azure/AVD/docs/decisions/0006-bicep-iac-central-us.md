# 0006 · Bicep as IaC; Central US region
- **Status:** Accepted
- **Date:** 2026-06-18

## Context
The environment must be repeatable (clone per customer, ADR 0002) and built as code from day
one (user chose IaC over portal click-ops). A region must be fixed.

## Decision
- **Bicep** for all ARM resources (Azure-native, best AVD resource coverage, clean per-customer
  parameterization via `.bicepparam`, no state backend to manage for a small team).
- Region: **Central US**.
- Repo layout: shared `platform.bicep` (once) + per-customer `main.bicep` calling six modules;
  per-customer values in `params/<customer>.bicepparam`.

## Alternatives considered
- **Terraform:** viable and identical architecture, but adds state-backend management; no
  multi-cloud need here. Not chosen. (Could revisit if tooling standardizes on it.)
- **Portal click-ops:** rejected — not repeatable.

## Consequences
- Three things Bicep can't do are handled by companion PowerShell/Graph scripts (G-002).
- Cloning a customer = copy a bicepparam + deploy to a new RG.
- Bicep CLI version in use: 0.41.2 (validated `az bicep build` exit 0).
