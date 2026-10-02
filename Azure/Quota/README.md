# Azure / Quota

| File | Purpose |
|---|---|
| `Request-GpuQuotas.ps1` | Bulk-submit Azure compute-quota increases across regions/VM families, with a timestamped JSONL audit log |
| `arm.json` | Supporting ARM template |

Subscription id is read from `$env:AZURE_SUBSCRIPTION_ID`. Requires the Az CLI quota extension.
