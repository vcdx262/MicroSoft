# Gotchas & Workarounds

Knowledge base of traps hit on this project and how they were resolved. **Check here before
debugging.** Add a new entry the moment a problem is solved or worked around.

Entry format: **Symptom → Cause → Fix**, plus date and where it bit us.

---

## G-001 · Bicep single-quote escaping (`''` is invalid)
- **Symptom:** `az bicep build` errors `BCP071: Expected 1 argument, but got 2` and `BCP236`.
- **Cause:** A `@description('…customer''s…')` used doubled single-quotes to escape an apostrophe.
  Bicep does **not** use `''`; single-quoted strings escape with `\'`.
- **Fix:** Reword to avoid the apostrophe, or use `\'`. (We reworded.) — `bicep/main.bicep`, 2026-06-18.

## G-002 · Several controls are NOT expressible in ARM/Bicep
- **Symptom:** Looking for a Bicep resource to enable Entra Kerberos / Conditional Access / AVD SSO.
- **Cause:** These are Entra/Graph or storage-plane operations, not ARM resources.
- **Fix:** Handle via companion scripts after `main.bicep` deploys:
  - Entra Kerberos on storage + admin consent → `scripts/enable-storage-kerberos.ps1`
  - AVD SSO service principals (tenant) → `scripts/enable-avd-sso.ps1`
  - Conditional Access MFA (rev1) → `scripts/conditional-access-mfa.ps1`
  - FSLogix in-guest registry → Custom Script Extension in `session-hosts.bicep` (+ standalone `configure-fslogix.ps1`).

## G-003 · Azure NetApp Files cannot do cloud-only identities
- **Symptom:** Considered ANF for FSLogix profiles.
- **Cause:** ANF requires Kerberos via **AD DS / Entra Domain Services**; it does not support Entra-only (cloud-only) identities.
- **Fix:** Use **Azure Files + Entra Kerberos**, which supports cloud-only. See ADR 0003.

## G-004 · FSLogix may not be preinstalled on the base image
- **Symptom:** FSLogix registry set but service absent.
- **Cause:** AVD-optimized Marketplace images ship FSLogix; the plain `windows-11` Enterprise image may not.
- **Fix:** Use an AVD-optimized/golden image with FSLogix, or have the CSE install it (logic in `scripts/configure-fslogix.ps1` downloads from `https://aka.ms/fslogix_download`).

## G-005 · Kali Marketplace image needs terms acceptance + a `plan` block
- **Symptom:** Kali VM deploy fails on Marketplace purchase/terms.
- **Cause:** Marketplace images require one-time terms acceptance (subscription-level) and a `plan{}` in the VM resource.
- **Fix:** `az vm image terms accept --publisher kali-linux --offer kali --plan kali-2024-2` (match the SKU in `kali.bicep`, which already includes the `plan` block).

## G-006 · AVD DSC agent artifacts URL is versioned
- **Symptom:** Session host registration fails / agent install errors.
- **Cause:** `avdAgentArtifactsUrl` points at a versioned `galleryartifacts/Configuration_*.zip` that Microsoft rotates.
- **Fix:** Update the param to the current Configuration zip URL if registration fails. — `bicep/main.bicep`.

## G-007 · Storage is always encrypted at rest — don't try to "turn it off"
- **Symptom:** Asked to drop "encrypted storage" for the MVP.
- **Cause:** Azure Storage encryption at rest (AES-256, Microsoft-managed keys) is mandatory and free; it cannot be disabled.
- **Fix:** Keep it. Only **customer-managed keys (CMK)** are optional — that's the only thing deferrable (deferred to rev1).

## G-008 · Entra Kerberos storage app must not require MFA
- **Symptom:** Kerberos ticket acquisition for the file share would fail with MFA enforced.
- **Cause:** Tickets are acquired silently at logon — there is no interactive step-up UX.
- **Fix:** Exclude the storage app from MFA / keep per-user MFA off for it. Noted in `enable-storage-kerberos.ps1`.

## G-009 · `no-hardcoded-env-urls` lint on the AVD agent URL
- **Symptom:** Bicep lint warning for `core.windows.net` in the agent artifacts URL.
- **Cause:** The URL is a fixed Microsoft endpoint; `environment()` can't express it.
- **Fix:** `#disable-next-line no-hardcoded-env-urls` above the param. — `bicep/main.bicep`.

## G-010 · OneDrive block covers the sync client only
- **Symptom:** Expectation that disabling OneDrive stops all exfil.
- **Cause:** `DisableFileSyncNGSC` / `DisablePersonalSync` disable the **sync client**; browser uploads to cloud storage are unaffected.
- **Fix (current):** Sync client disabled in `session-hosts.bicep`. Full coverage (browser uploads, clipboard) is a rev1 egress/DLP task. Local-drive redirection is already off.

## G-011 · April 2026 Kerberos hardening (RC4 → AES-SHA1)
- **Symptom:** N/A for fresh builds; relevant for older FSLogix-on-SMB setups.
- **Cause:** Windows default Kerberos enc type changed to AES-SHA1 (April 2026 update).
- **Fix:** We deploy fresh post-change, so AES-SHA1 is used from the start. No action needed; noted for awareness.

## G-021 · Apply the AVD Windows license benefit (`licenseType`) or you pay the full Windows rate (~2×)
- **Symptom:** a `Standard_D4s_v4` session host bills ~**$0.40/hr** in Central US — about double the expected
  base compute (~$0.19/hr). `az vm show … --query licenseType` returns **null**.
- **Cause:** session hosts created via **IaC (outside the AVD portal flow)** do **not** get the AVD Windows
  license benefit automatically — so Azure charges the **Windows-licensed** rate (base compute **+** Windows
  license uplift, ~$0.046/vCPU/hr).
- **Fix:** set **`licenseType: 'Windows_Client'`** on the Win10/11 session-host VMs (now in `session-hosts.bicep`;
  for existing VMs: `az vm update -g <rg> -n <vm> --set licenseType=Windows_Client`). Drops to base compute
  (~$0.19/hr for D4s_v4), removing the uplift. (Use `Windows_Server` for Server OS / Azure Hybrid Benefit.)
- **Eligibility (compliance):** the benefit is only valid if connecting users hold an **eligible license**
  (M365 E3/E5, Windows E3/E5, or Business Premium). Applied to the **lab host** (lab1 = E5 ✓). **Not** applied
  to **prod** — steven is on **Business Standard**, which isn't AVD-eligible, so prod must move to a qualifying
  license first. Linux hosts (Kali) have no Windows uplift.

## G-020 · The `az` CLI Graph token is scope-limited — not your full Global-Admin reach
- **Symptom:** `az rest` to Microsoft Graph returns **`Forbidden`** for some operations even though you're
  signed in as Global Admin — e.g., **Intune** (`DeviceManagement*` scopes), reading **Security Defaults**
  (`identitySecurityDefaultsEnforcementPolicy`, needs `Policy.Read.All`), and the cross-tenant access policy.
- **Cause:** `az rest` presents the **Azure CLI first-party app's** token, which carries only the delegated
  Graph scopes that app holds — **not** the full power of your directory role. Graph authorizes by **token
  scope**, not by who you are.
- **What DID work via the az token:** create users/groups, **assign licenses**, create/enable/patch
  **Conditional Access** policies, `revokeSignInSessions`, role assignments.
- **What's Forbidden:** **Intune** (managed devices, config profiles), Security Defaults policy read,
  cross-tenant access default write.
- **Fix for automation:** create a **dedicated app registration / service principal** with the specific Graph
  **application permissions** (admin-consented) and authenticate as it (client-credentials / `az login
  --service-principal`); OR do those actions in the **portal** (your GA browser session isn't scope-limited).
- **Don't confuse with the harness guardrail:** separately, a couple of high-severity actions (creating a
  Global Admin break-glass account, the tenant-wide cross-tenant policy change) were blocked by the **Claude
  Code auto-mode classifier** — that's a safety guardrail asking for explicit approval, *not* an Azure denial.

## G-019 · Start-VM-on-Connect needs the "Power On Contributor" role on the AVD service principal
- **Symptom:** After deallocating a session host, reconnecting from the AVD client errors — the host does
  **not** auto-start, despite `startVMOnConnect=true` on the host pool.
- **Cause:** Start-VM-on-Connect requires the **Azure Virtual Desktop** service principal
  (appId `9cdead84-a844-4324-93f2-b2e6bb768d07`) to hold the **`Desktop Virtualization Power On Contributor`**
  role at the subscription (or RG) scope so it can power the VM on. Our IaC set the flag but never granted the role.
- **Fix (one-time per subscription):**
  `az role assignment create --assignee-object-id <AVD-SP-objectId> --assignee-principal-type ServicePrincipal --role "Desktop Virtualization Power On Contributor" --scope /subscriptions/<sub>`
  (AVD SP objectId in this tenant: `<avd-sp-object-id-in-your-tenant>`.) Granted 2026-06-19.
- **Notes:** RBAC takes a few minutes to propagate. For **scaling plans** (which also power hosts *off*),
  use **`Desktop Virtualization Power On Off Contributor`** instead. Add this to the platform setup so new
  subscriptions get it. Manual workaround meanwhile: `az vm start -g <rg> -n <vm>`.

## G-018 · Screen Capture Protection registry value is `fEnableScreenCaptureProtect` (no "-ion")
- **Symptom:** SCP set but no effect — screenshots succeed on the host *and* inside the VDI, and the web
  client is still allowed (a correctly-enabled SCP **refuses** the web client).
- **Cause:** wrong registry value name. We first used `fEnableScreenCaptureProtection` (silently ignored).
- **Fix:** correct value is `HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\`**`fEnableScreenCaptureProtect`**
  (DWORD): `1` = block on client, `2` = client + server. **Reboot the session host** to engage (sign-out/in
  is not enough for SCP). Watermarking's value names (`fEnableWatermarking`, `Watermarking*`) were correct.
- **Confirm it's live:** the **web client should be refused** with a "screen capture is enabled" error, and
  screenshots (host + in-VDI) go black. Requires Win10/11 **22H2+** session host and the native Windows App.

## G-017 · Azure Files Entra Kerberos needs `CloudKerberosTicketRetrievalEnabled=1` on the host
- **Symptom:** From an Entra-joined session host, opening the `data` share (or FSLogix loading a profile)
  prompts for credentials or fails, even though Entra Kerberos is enabled + share RBAC is assigned.
- **Cause:** Entra-joined Windows clients don't request cloud Kerberos tickets by default. The Azure Files
  Entra Kerberos flow requires `HKLM\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters\CloudKerberosTicketRetrievalEnabled = 1`.
- **Fix:** Set that DWORD to 1 on each session host, then **sign out/in** (new logon retrieves the ticket).
  Now baked into the `ConfigureSessionHost` CSE in `session-hosts.bicep`, so future hosts get it automatically.
  Existing host (sh0) deployed 2026-06-18 needs it set manually (admin PowerShell) or re-run the extension.
- **Data share path:** `\\saavdcust01tl5bjo6libdui.file.core.windows.net\data` (user group has
  Storage File Data SMB Share Contributor → read/write).

## G-016 · `az desktopvirtualization …` needs a CLI extension; use `az rest` to check hosts
- **Symptom:** `az desktopvirtualization sessionhost list` → `'desktopvirtualization' is misspelled or not recognized`.
- **Cause:** The `desktopvirtualization` Azure CLI extension isn't installed in this environment.
- **Fix:** Either `az extension add -n desktopvirtualization`, or query via REST (no extension needed):
  `az rest --method get --url "https://management.azure.com/subscriptions/<sub>/resourceGroups/rg-avd-cust01-cus/providers/Microsoft.DesktopVirtualization/hostPools/hp-avd-cust01/sessionHosts?api-version=2024-04-03"`
  → look at `.value[].properties.status` (want `Available`).

## G-015 · AVD DSC agent extension fails on `aadJoin` parameter
- **Symptom:** `AVDAgent` (publisher `Microsoft.Powershell`, type `DSC`) extension fails:
  `The DSC Extension received an incorrect input: A parameter cannot be found that matches parameter name 'aadJoin'`.
- **Cause:** The unversioned `…/galleryartifacts/Configuration.zip` is an old DSC config that predates
  the `aadJoin` parameter; the versioned URLs that *do* support it rotate and 404 over time. Brittle.
- **Fix:** Don't use the DSC extension. Install the AVD agent + bootloader via a **Custom Script
  Extension** with `REGISTRATIONTOKEN` — the VM is already Entra-joined by the `AADLoginForWindows`
  extension, so the agent registers regardless of join type. Authoritative download links (Microsoft Learn):
  - Agent: `https://go.microsoft.com/fwlink/?linkid=2310011`
  - Bootloader: `https://go.microsoft.com/fwlink/?linkid=2311028`
  Implemented in `session-hosts.bicep` (`ConfigureSessionHost` CSE; script base64'd in protectedSettings).
  Note: only ONE CustomScriptExtension is allowed per VM — agent install + FSLogix + OneDrive are combined into it.

## G-014 · `DSv5` family has 0-core quota; total regional vCPU limit is 10
- **Symptom:** Deploy fails at preflight with `QuotaExceeded` for `standardDSv5Family` (Current Limit: 0).
- **Cause:** This subscription has **0 approved cores for the DSv5 family** in centralus. Separately,
  the **Total Regional vCPUs** limit is **10** — the real ceiling for the MVP footprint.
- **Fix:** Use the **Dsv4** family (`Standard_D4s_v4` session host + `Standard_D2s_v4` Kali = 6 vCPUs ≤ 10),
  which has a limit of 10 and supports Trusted Launch (required for Win11). Set in `cust01.bicepparam`.
- **If you scale up:** ~50 consultants on `D4s_v4` = 200 vCPUs — you'll need a **quota increase**
  (`az vm list-usage -l centralus`; request via the portal Quotas blade). The MVP (1 host + Kali) fits in 10.

## G-013 · Marketplace image SKUs and the AVD DSC URL go stale — pre-flight them
- **Symptom:** First deploy (2026-06-18) would have failed: `kali-2024-2` SKU no longer exists,
  `win11-23h2-ent` is superseded, and the **versioned** AVD DSC artifacts URL returned **404**.
- **Cause:** Marketplace SKUs are retired over time, and the `galleryartifacts/Configuration_<ver>.zip`
  URL is rotated by Microsoft.
- **Fix / always do before deploying:**
  - Kali SKUs: `az vm image list-skus --location centralus --publisher kali-linux --offer kali --query "[].name" -o tsv` → used **`kali-2026-1`**.
  - Win11 SKUs: same cmd with `--publisher MicrosoftWindowsDesktop --offer windows-11` → used **`win11-24h2-ent`**.
  - DSC URL: HEAD-check it. The **unversioned** `…/galleryartifacts/Configuration.zip` returns 200 and is stable → switched to it.
  - Accept Kali terms for the exact SKU: `az vm image terms accept --publisher kali-linux --offer kali --plan kali-2026-1`.

## G-012 · `admin` (and other names) disallowed as Azure VM admin username
- **Symptom:** Request to set Kali (or any VM) admin username to `admin`.
- **Cause:** Azure reserves a set of admin usernames for **both Windows and Linux** VMs:
  `administrator, admin, user, user1, test, admin1, root, guest, console, backup, sys, …`
  (verified in the `Microsoft.Compute/virtualMachines` template reference). Deployment is rejected.
- **Fix:** Use a compliant name — we use **`kaliadmin`** (password set via `$env:KALI_ADMIN_PASSWORD` for the MVP, set in
  `params/cust01.bicepparam`). Same rule applies to the Windows session-host admin (`avdadmin`).
  Note: password complexity = 3 of 4 (upper/lower/digit/special), 6–72 chars; a compliant lab password passes.

## G-022 · Windows OneDrive ADMX is NOT in the in-box Intune Settings Catalog
- **Symptom:** Trying to deliver OneDrive lockdown (`DisableFileSyncNGSC`, `DisablePersonalSync`) via Intune
  Settings Catalog. Searching the catalog (`/beta/deviceManagement/configurationSettings?$search="OneDrive"`)
  returns **only macOS** managed-preferences settings (`com.apple.managedclient.preferences_*`) — no Windows
  policy nodes. 2026-06-22.
- **Cause:** OneDrive's Windows settings come from `OneDrive.admx`, which Microsoft does **not** ship as one of
  the in-box ingested ADMX files in the Settings Catalog (unlike the AVD `terminalserver-avd` ADMX, which *is*
  in-box). There's also no OneDrive Policy-CSP area to target with a custom OMA-URI.
- **Fix / options:** (a) **Ingest `OneDrive.admx`** into Intune (`groupPolicyUploadedDefinitionFiles`) then build
  an Administrative-Templates profile referencing it; or (b) keep OneDrive lockdown as the current **CSE registry**
  delivery in `session-hosts.bicep` (`DisableFileSyncNGSC=1`/`DisablePersonalSync=1`) until ingestion is set up.
  Treat OneDrive as its own Intune sub-track, separate from the AVD/Kerberos Settings-Catalog profiles.

## G-023 · AVD watermarking Settings-Catalog namespace has a Microsoft typo (`avdv1.upadtes`)
- **Symptom:** Two "Enable watermarking" settings exist in the catalog; picking the obvious clean-spelled one
  silently uses a **deprecated** definition. 2026-06-22.
- **Cause:** The current AVD watermarking settings live under the (mis-spelled, but real) ADMX namespace
  `device_vendor_msft_policy_config_terminalserver-avdv1.upadtes~policy~...` ("upadtes" ≠ "updates"). The
  correctly-spelled `terminalserver-avdv1~policy~...avd_server_watermarking` set is flagged **[Deprecated]**.
- **Fix:** Use the `avdv1.upadtes` namespace for watermarking. (Screen Capture Protection is unaffected — it
  lives under the plain `terminalserver-avdv1~policy~...screen_capture_protection` namespace.) Setting IDs are
  captured verbatim in `intune/profiles/avd-host-protections.json`.

## G-024 · Azure Files provisioned-share floors: v1 = 100 GiB, v2 = 32 GiB; sub-floor = `InvalidHeaderValue`
- **Symptom:** Creating an Azure Files share below the minimum size fails with a cryptic
  `(InvalidHeaderValue) The value for one of the HTTP headers is not in the correct format` — **not** a
  helpful "minimum size is N GiB" message. 2026-06-22 (empirically tested).
- **Cause:** `shareQuota` is passed to the service as an internal `x-ms-share-quota` header. A value below the
  billing model's floor is rejected as a malformed header. Floors proven by test on the lab account:
  - **Provisioned v1** (`Premium_LRS` / `FileStorage`): **100 GiB** min — 10 GiB rejected, 100 GiB succeeded.
  - **Provisioned v2** (`PremiumV2_LRS` / `FileStorage`): **32 GiB** min — 10 GiB rejected, 32 GiB succeeded
    (and returned independent `provisionedIops`/`provisionedBandwidthMibps` — the v2 signature).
- **Fix:** Provision at/above the floor for the model. To go below 100 GiB you must be on **v2** (32 GiB). The
  error is size, not auth/network — don't chase a header/permission red herring.

## G-025 · Provisioned v1 → v2 is NOT an in-place conversion
- **Symptom:** Wanting to "switch" an existing Premium_LRS (v1) account to PremiumV2 (v2) by editing the SKU.
- **Cause:** The provisioned-v2 billing model is selected at **account creation**; Azure has no in-place
  v1→v2 conversion. The SKU enums (`Premium_LRS` vs `PremiumV2_LRS`) are different billing models, not a tier
  bump.
- **Fix:** Create a **new** v2 account and migrate. In this repo the v2 account gets a distinct deterministic
  name via `uniqueString(resourceGroup().id, 'fslogixv2')` so it can coexist with the v1 account during an
  **AzCopy** profile migration; the old v1 account is deleted after cutover. See ADR 0009.

## G-026 · Dropping the private endpoint breaks FSLogix SMB until the NSG allows 445 to the Storage tag
- **Symptom:** After moving Azure Files from a private endpoint to a **service endpoint**, FSLogix can't mount —
  from the host, `Test-NetConnection <sa>.file.core.windows.net -Port 445` = **False** (CloudKerberos=1, RBAC
  fine, share reachable on 443). 2026-06-22, lab.
- **Cause:** With a **private endpoint**, SMB (445) went to a **private IP intra-vNet** → allowed by the
  intra-vNet rule. With a **service endpoint**, the host reaches storage at its **public IP in the `Storage`
  service tag**, and the NSG only permitted **443** outbound to Azure (`Allow-AzureCloud-443`); 445 fell to the
  `Deny-All-Other-Outbound-Internet` rule.
- **Fix:** Add an outbound NSG rule **Allow 445 → `Storage.CentralUS`** (region-pinned to keep egress tight),
  priority below the deny. Now codified in `network.bicep` (`Allow-Storage-SMB-Outbound`, priority 115). Verified:
  445 went True and the share resolved to a public IP (service endpoint path, no private DNS). Region-scoped tag
  avoids opening SMB to all Azure storage globally.

## G-027 · Tenant Restrictions v2 — exact device-enforcement registry + Policy ID source
- **Context:** Applying TRv2 device enforcement WITHOUT Intune (lab test; host not Intune-enrolled). 2026-06-23.
- **Policy ID:** the `policyid` is the **`id` field from `GET /policies/crossTenantAccessPolicy/default`** (per
  the Policy CSP doc) — for this tenant **`<redacted-tenant-object-id>`**. The default already blocks all
  external users+apps (covers consumer MSA at the identity plane); `isServiceDefault:true` is fine — the id still
  works for enforcement.
- **Registry** (from `C:\Windows\PolicyDefinitions\TenantRestrictions.admx`, policy `trv2_payload`), key
  `HKLM\SOFTWARE\Policies\Microsoft\Windows\TenantRestrictions\Payload`, REG_SZ values:
  `tenantid` (required), `policyid` (required); optional `cloudid`, `enforceFirewall` (DWORD 1), multi-string
  `hostnames`/`subdomainSupportedHostnames`/`ipRanges`. Set the two required → restart → engaged.
- **Scope:** TRv2-on-Windows covers **Edge + Office web sign-ins**, **NOT Chrome/Firefox/.NET** (those need
  `enforceFirewall=1` + an App Control tagging policy). Header injected: `sec-Restrict-Tenant-Access-Policy:
  <tenantid>:<policyid>`. Events: Event Viewer → Apps and Services Logs → Microsoft > Windows >
  TenantRestrictions > Operational.
- **Prod delivery:** via the authored Intune Settings Catalog profile (`intune/profiles/avd-tenant-restrictions-v2.json`)
  once MDM auto-enrollment scope is enabled — the registry method here is the lab capability proof.

## G-028 · Screen Capture Protection `=2` garbles Edge (GPU compositor); browsers bypass TRv2
- **Symptom (rendering):** With `fEnableScreenCaptureProtect=2` ("block on client AND server"), Edge in the AVD
  session renders as a **garbled tiled/grid of blocks** — valid pages unreadable, browser ~unusable. Watermarking
  was OFF (`fEnableWatermarking=0`), so it's not the watermark. Win11 24H2 (build 26100). 2026-06-23, lab.
- **Cause:** SCP's server-side capture-protection collides with the browser's **GPU compositor** in the remote
  session, corrupting hardware-accelerated content. The `=2` (server) mode triggers it; `=1` (client only) usually
  doesn't.
- **Fix:** Disable the browser's GPU acceleration — Edge policy `HKLM\SOFTWARE\Policies\Microsoft\Edge` →
  `HardwareAccelerationModeEnabled=0` (DWORD), then fully relaunch Edge. Keeps SCP at `=2` (full protection)
  *and* fixes rendering. Alternative: drop SCP to `=1` (trades away server-side capture blocking). For prod,
  deliver the Edge setting via Intune alongside SCP.
- **Related TRv2 gap (confirmed same session):** TRv2-on-Windows blocked the personal MSA in **Edge** but does
  **NOT** cover **Chrome/Firefox/.NET** — those bypass it unless `enforceFirewall=1` + an App Control for Business
  tagging policy is deployed. Mitigation for the anti-exfil posture: don't install Chrome/Firefox on hosts, or add
  firewall enforcement. See ADR 0009 / the TRv2 cloud-policy README.

## G-029 · MDM auto-enrollment scope is portal-only — SP/app-only calls are unsupported
- **Symptom:** Trying to enable/read the **MDM user scope** (Entra → Mobility (MDM and WIP)) via Graph as the
  `avd-automation` SP returns `401 Unsupported app-only call` / `Resource not found for segment
  mobilityManagementPolicies`. 2026-07-08.
- **Cause:** `mobilityManagementPolicies` (the MDM/WIP enrollment-scope config) has **no application-permission
  surface** — it must be changed with a **delegated** admin in the **Entra portal**. There is no supported
  app-only path.
- **Fix:** Set it in the portal: Entra → **Mobility (MDM and WIP)** → Microsoft Intune → **MDM user scope** =
  the target group (we used **`grp-avd-lab-users`** to keep personal PC "bhag" out — NOT "All"). Gotchas that
  bit us doing this: the **Save** button greys out if **WIP user scope = Some** (WIP is deprecated — set it to
  **None**) and/or the **MDM URLs are blank** — click **"Restore default MDM URLs"** to repopulate them.
- **Teardown implication:** because it's portal-only, disabling the scope at teardown is a **manual portal step**,
  not scriptable.

## G-030 · The `az` CLI Graph token is Forbidden for Intune *app* operations — use the SP
- **Symptom:** `az rest … /deviceAppManagement/mobileApps …` returns **403 Forbidden**: "Application must have
  one of the following scopes: DeviceManagementApps.Read.All, DeviceManagementApps.ReadWrite.All." (Some other
  Intune endpoints return a *BadRequest* instead, which misleadingly looks like the token has access.) 2026-07-09.
- **Cause:** The first-party Azure CLI client's Graph token does not carry Intune app scopes (broader G-020: the
  `az` Graph token lacks Intune / Security-Defaults / cross-tenant scopes even for a Global Admin).
- **Fix:** Do Intune app CRUD through the **`avd-automation` SP** (client-credentials; app perm
  `DeviceManagementApps.ReadWrite.All` with admin consent). Re-provide its secret in-session (never stored). For
  ad-hoc/manual work, the **Intune portal** works with the delegated admin. This is why Intune app cleanup at the
  2026-07-09 teardown was left as a portal/SP step rather than an `az` command.
