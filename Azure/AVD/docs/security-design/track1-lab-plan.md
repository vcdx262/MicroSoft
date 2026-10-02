# Track 1 — Scoped Test Lab Plan (build + teardown)

**Status: BUILT 2026-06-18.** Lab live in `rg-avd-lab-cus` — host `sh0-avd-lab` Available, group
`grp-avd-lab-users` ((object-id redacted)), users lab1/lab2, storage `saavdlabgu5uvgyrcrhko` (Entra Kerberos on).
**Pending:** acquire/assign 2× M365 E5, then run scoped control tests. **Teardown plan below stays current.**

## Objective
Test security controls (2FA/Conditional Access, Tenant Restrictions v2, Defender for Endpoint,
Purview DLP + labels, secure email) against **isolated test users + a test host** in the **existing**
`virtuallyhacked.com` tenant / "Steven" subscription, **without any risk to** `steven@virtuallyhacked.com`,
the production AVD (`cust01` / `sh0`), or production policies.

## Isolation principle (the invariant)
> Everything lab is **scoped to `grp-avd-lab-users` and the lab host `vm-avd-lab-sh0`**, lives in a
> **dedicated resource group `rg-avd-lab-cus`**, and uses a **`lab` naming prefix**. `steven` is **never**
> added to a lab group. Production CA/DLP policies are **never edited** — only **new lab-scoped** policies
> are created. Tenant Restrictions is enforced **only on the lab host** (device-scoped signaling), never
> tenant-wide. Result: teardown = delete one RG + 2 users + a handful of named policies.

## Licensing (decision needed)
- To test **E + F + G**, lab users need **full M365 E5** (E5 Compliance alone omits Defender for
  Endpoint P2 → can't test G). Plan assumes **2 × M365 E5** (~$57/user/mo ≈ **$114/mo** while active).
- Cheaper-but-partial alt: **E3 + E5 Compliance add-on** (tests E + F, not G).
- Trial option: **M365 E5 trial** (free, 30 days, up to 25 users) to start at $0, convert to paid if kept.

## Components to create

### Identity (Entra — scoped)
| Object | Name | Notes |
|---|---|---|
| Test users (cloud-only) | `lab1@virtuallyhacked.com`, `lab2@virtuallyhacked.com` | **Not** steven; new accounts |
| Security group | `grp-avd-lab-users` | members: lab1, lab2 — the scope target for ALL lab policies |
| Licenses | 2 × M365 E5 | assigned to lab1/lab2 only |

### Azure infra (dedicated RG → single-delete teardown)
Reuse `main.bicep` with a new `cust-lab` parameter file. Distinct IP range for clarity.

| Resource | Name | Notes |
|---|---|---|
| Resource group | `rg-avd-lab-cus` | **the Azure teardown unit** |
| Log Analytics (dedicated) | `log-avd-lab` | in the lab RG so it's deleted on teardown |
| vNet + subnets | `vnet-avd-lab` `10.20.0.0/16` (avd `10.20.1.0/24`, pe `10.20.2.0/24`) | distinct range to avoid confusion |
| NSG / NAT / DNS | `nsg/natgw/...-avd-lab` | same hardened pattern as prod |
| Storage | `saavdlab<unique>` | FSLogix + data share for DLP testing |
| Host pool / app group / workspace | `hp-avd-lab` / `dag-avd-lab-desktop` / `ws-avd-lab` | personal pool |
| Session host (1) | `vm-avd-lab-sh0` | **`Standard_D2s_v4` (2 vCPU)** to fit quota |
| Kali | **none** | lab doesn't need it |

**Quota check:** prod uses 6 vCPU (sh0 D4s_v4=4 + kali D2s_v4=2). Lab adds **2 vCPU** → **8 of 10**. Fits. ✅

### Required IaC change before build
- Add a **`deployKali bool = true`** parameter to `main.bicep`; set **`false`** in `cust-lab.bicepparam`
  so the lab skips Kali (saves 2 vCPU, simpler teardown).
- New `bicep/params/cust-lab.bicepparam`: `customerName='lab'`, lab IP range, `sessionHostCount=1`,
  `sessionHostVmSize='Standard_D2s_v4'`, `userGroupObjectId=<grp-avd-lab-users>`, `enableSso=true`,
  `logAnalyticsWorkspaceId=<log-avd-lab id>`, `deployKali=false`.

## Build sequence
1. **Decide licensing** (E5 trial vs paid; 1 vs 2 users) and confirm E5 seats available.
2. **Identity:** create `lab1`/`lab2`, create `grp-avd-lab-users`, add the two users, assign E5. (steven excluded.)
3. **Lab Log Analytics:** create `log-avd-lab` in `rg-avd-lab-cus`.
4. **IaC:** add `deployKali` toggle to `main.bicep`; author `cust-lab.bicepparam`; `az bicep build` to validate.
5. **Deploy lab stack:** `deploy.ps1 -CustomerParam cust-lab.bicepparam -CustomerRg rg-avd-lab-cus`.
6. **Post-deploy:** enable Entra Kerberos on lab storage; SSO SPs already exist tenant-wide; verify
   `lab1` can sign into `hp-avd-lab` (Windows App).
7. **Test controls — one at a time, scoped, audit/report-only first** (record each in `controls-catalog.md`):
   1. **2FA / Conditional Access** — new policy "LAB - Require MFA" scoped to `grp-avd-lab-users`.
   2. **Tenant Restrictions v2** — author policy; enable **GPO/registry signaling on `vm-avd-lab-sh0` ONLY**;
      verify `lab1` is blocked from a **personal Microsoft account** + another tenant; confirm `sh0`/steven unaffected.
   3. **Defender for Endpoint** — onboard `vm-avd-lab-sh0` only; web filtering + device control + a few ASR rules (audit→block).
   4. **Purview DLP + labels** — scope DLP policy + a "Lab-Confidential" label to `grp-avd-lab-users`; Endpoint DLP on lab host.
   5. **Secure email (OME)** — send encrypted mail from `lab1`; verify external open + Do-Not-Forward.

## Cost while active
- 2 × E5 ≈ **$114/mo** (or $0 on E5 trial). Lab host (D2s_v4, start-on-connect) + storage + NAT + LA
  ingestion ≈ **$30–60/mo** depending on uptime. **Total ≈ $120–175/mo**, ends at teardown.

---

# Teardown / Destroy Plan

Run when testing is complete. **Order matters** — remove scoped policies first (so they don't reference
deleted objects), then Azure infra, then identity, then licensing. Each step has a production-safety check.

### Step 1 — Remove scoped policies (before deleting their targets)
- [ ] Delete the **"LAB - Require MFA"** Conditional Access policy.
- [ ] **Tenant Restrictions v2:** remove TRv2 enforcement/signaling from the lab host; delete any lab partner
      policy; **revert the cross-tenant access default if it was changed**. ⚠️ *Verify steven can still access
      external/B2B resources and personal-tenant scenarios you rely on.*
- [ ] **Defender:** off-board `vm-avd-lab-sh0`; delete lab Defender/ASR/device-control policy assignments.
- [ ] **Purview:** delete the lab DLP policy; unpublish the "Lab-Confidential" label from `grp-avd-lab-users`
      (delete the label if lab-only).
- [ ] Delete the lab **OME**/mail-flow rule if one was created.

### Step 2 — Delete Azure infrastructure
- [ ] `az group delete -n rg-avd-lab-cus --yes` — removes vNet, NSG, NAT, public IP, storage + private
      endpoint + DNS zone, host pool, app group, workspace, session-host VM + disks + NIC, and `log-avd-lab`.
- [ ] Remove the lab host's **Entra device object** (Entra-joined device isn't auto-deleted with the VM):
      Entra ID → Devices → delete `vm-avd-lab-sh0`. Remove its **Intune record** if it was enrolled.
- [ ] ✅ *Verify `rg-avd-cust01-cus` and `rg-avd-platform-cus` are untouched* (`az group show` on each;
      `az resource list` counts unchanged).

### Step 3 — Identity cleanup
- [ ] Remove E5 license assignments from `lab1`/`lab2` (stops license consumption).
- [ ] Delete users `lab1`, `lab2` (and purge from the deleted-users bin if you want them fully gone).
- [ ] Delete group `grp-avd-lab-users` (+ any lab admin group).
- [ ] Remove any lab role assignments not already removed with the RG (subscription/tenant-scoped, if any).

### Step 4 — Licensing
- [ ] If **paid E5** was purchased: reduce/cancel the 2 E5 seats in M365 admin → Billing (stops recurring
      cost). If a **trial**, it auto-expires — optionally cancel early.

### Step 5 — Production-intact verification (must all pass)
- [ ] `steven` can still sign into AVD (`cust01`/`sh0`) and M365.
- [ ] Production Conditional Access policies unchanged; steven's external/B2B + personal-tenant access works
      (confirms TRv2 default was reverted).
- [ ] `rg-avd-cust01-cus` + `rg-avd-platform-cus` resource counts unchanged.
- [ ] No orphaned lab artifacts: Entra devices, service principals, DLP/label policies, CA policies, groups, users.

### Step 6 — Document
- [ ] Capture each control's test result in `controls-catalog.md` **before** destroying.
- [ ] Log the teardown in `../deployments/DEPLOYMENT-LOG.md` and `../changes/CHANGELOG.md`.

---

## Open decisions (need answers before build)
1. **Licensing:** full **M365 E5** (covers E+F+G) vs **E3 + E5 Compliance** (E+F only)? **Trial or paid?**
2. **How many lab users:** 1 or 2? (Plan assumes 2 — useful for testing user-to-user DLP/email scenarios.)
3. **Keep or skip a lab storage data share** (only needed if testing DLP on the file share).

## Guardrails / risks
- **TRv2 is the highest-risk control** — its policy is tenant-level. Mitigation: only **device-scoped
  enforcement on the lab host**; do **not** enable GSA universal tenant restrictions (tenant-wide); be
  deliberate with the cross-tenant **default** policy and revert it at teardown.
- **Don't enable Security Defaults** (tenant-global) — use scoped Conditional Access instead.
- **Never add steven to `grp-avd-lab-users`.**
