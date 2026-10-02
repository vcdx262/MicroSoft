# Azure

Azure automation and infrastructure-as-code.

| Item | Purpose |
|---|---|
| [`AVD/`](AVD/) | **Hardened, network-isolated Azure Virtual Desktop platform** — Bicep IaC, identity/FSLogix/storage-Kerberos scripts, Intune profiles, decision records, security design, deployment guide, validation test plan |
| [`Quota/`](Quota/) | Bulk `az quota` increase automation with a JSONL audit trail |
| `Get-AzureResourceInventory.ps1` | Subscription-wide resource inventory → CSV + JSONL run log |

**Prerequisites:** Az CLI (`az login`). The subscription id is read from
`$env:AZURE_SUBSCRIPTION_ID` or the current `az` context; no secrets are stored.
