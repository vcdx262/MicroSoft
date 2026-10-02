# 0009 · Customer data → device-gated OneDrive/SharePoint; Azure Files reduced to FSLogix-only (Provisioned v2, service endpoint)

- **Status:** Accepted
- **Date:** 2026-06-22

## Context
The original design (ADR 0003) put **customer engagement data** on a per-customer Azure Files `data`
share, reachable only via a private endpoint. Reviewing data-protection options, the team weighed Azure
Files vs OneDrive/SharePoint and concluded:

- **M365/Purview has materially richer data-centric security** than Azure Files: sensitivity labels,
  content-aware DLP, retention/eDiscovery, ransomware versioning. Azure Files has none of these natively.
- The original objection to OneDrive (an internet-reachable exfil surface — the reason OneDrive *sync* was
  disabled in ADR 0007) can be **closed with device-gated Conditional Access**: require a compliant/Entra-joined
  AVD host + per-site "block access from unmanaged devices" (`Set-SPOSite -ConditionalAccessPolicy`). That makes
  a SharePoint/OneDrive library reachable **only from inside the AVD session**, giving isolation-like access
  control *plus* Purview DLP.
- Storage cost/observation: Azure Files Premium **Provisioned v1** bills a **100 GiB minimum per share**
  (empirically proven 2026-06-22 — sub-100 GiB rejected with `InvalidHeaderValue`). **Provisioned v2** lowers the
  floor to **32 GiB** and decouples capacity/IOPS/throughput (also proven the same day).

## Decision
1. **Customer data moves to device-gated OneDrive/SharePoint.** Access gated by Conditional Access
   (compliant/managed AVD device) + per-site unmanaged-device block, so content is reachable only from the
   governed AVD session. Purview labels + Endpoint DLP govern the content.
2. **Azure Files is reduced to FSLogix profiles only.** The `data` share + its share-RBAC + `dataUncPath`
   output are **removed**.
3. **FSLogix profiles share moves to Provisioned v2** (`PremiumV2_LRS` / `FileStorage`) at **32 GiB**.
4. **Private endpoint → vNet service endpoint.** FSLogix reaches the account over a `Microsoft.Storage`
   service endpoint on `snet-avd` + storage firewall (deny-all except `snet-avd`). Backbone route, not the
   public internet; saves the PE cost + private-DNS complexity.

This **narrows** ADR 0003 (Azure Files + Entra Kerberos remains, for profiles) and is a **governed refinement**
of ADR 0007's OneDrive stance — the uncontrolled OneDrive *sync* vector stays blocked; a *device-gated* library
becomes the sanctioned store. ADR 0003 is not superseded.

## Alternatives considered
- **Keep customer data on Azure Files** (isolation-centric): structurally isolates per customer, but no
  content DLP/labels/eDiscovery; rejected as the primary store given the DLP gap, but Endpoint DLP at the host
  still covers any residual local data.
- **Azure NetApp Files / CIFS**: rejected again — ANF SMB needs AD DS (reverses ADR 0001) and has a ~1 TiB pool
  floor; "Azure CIFS" is just SMB, which Azure Files already provides. (See gotchas / reference-notes.)
- **Keep Provisioned v1 / private endpoint**: v1 forces the 100 GiB floor; PE adds ~$7–8/mo + DNS plumbing for
  reach we don't need (same VNet/region). Service endpoint keeps traffic off the internet without that overhead.

## Consequences
- **Enables** Purview DLP/labels on customer data + the "data only reachable from AVD" outcome, while
  shrinking the Azure Files footprint (one 32 GiB share vs two 100 GiB shares → ~$32/account → ~$5–6).
- **Requires** (gated on E3/E5 licensing): CA device-gating, an Intune **compliance policy** on the hosts, and
  per-site SharePoint unmanaged-device config. Cross-customer separation now rests on SharePoint permissions +
  device gating, **not** network isolation — must be configured carefully per engagement.
- **Migration:** v1→v2 cannot convert in place — a **new account** (new name via `uniqueString(...,'fslogixv2')`)
  is created and FSLogix repointed; existing profiles are AzCopy-migrated (cust01) or reset (lab). Old v1
  account + PE + private DNS zone are deleted after cutover.
- **Trade-off accepted:** the storage account's public endpoint is *enabled but firewalled* (service endpoint)
  rather than fully disabled (PE) — a marginally larger surface, mitigated by deny-all-except-`snet-avd`.
- `snet-pe` is retained (unused) until the old PE is removed; can be dropped from the template later.
