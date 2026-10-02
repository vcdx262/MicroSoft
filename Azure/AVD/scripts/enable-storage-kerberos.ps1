<#
.SYNOPSIS
  Enable Microsoft Entra Kerberos auth on the per-customer Azure Files storage
  account so cloud-only (Entra-joined) session hosts can mount FSLogix profiles
  and the data share without AD DS.

.DESCRIPTION
  Steps that cannot be expressed in Bicep/ARM:
    1. Enable Entra Kerberos on the storage account (AES-SHA1).
    2. Grant tenant admin consent to the auto-created storage service principal.
    3. Disable MFA on the storage app (Kerberos tickets are acquired silently at
       logon; there is no step-up UX) — done via a Conditional Access exclusion.

  Share-level RBAC (Storage File Data SMB Share Contributor for the user group)
  is already assigned by identity-rbac.bicep. After running this, set the NTFS /
  directory-level FSLogix permissions per:
  https://learn.microsoft.com/fslogix/fslogix-storage-config-ht

.NOTES
  Requires: Azure CLI (az), logged in with rights to update the storage account
  and grant admin consent.  Post-April-2026 the default Kerberos enc type is
  AES-SHA1 — no extra flag needed on a fresh account.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory)] [string] $ResourceGroup,
  [Parameter(Mandatory)] [string] $StorageAccountName
)

$ErrorActionPreference = 'Stop'

Write-Host "==> Enabling Entra Kerberos on $StorageAccountName ..."
az storage account update `
  --name $StorageAccountName `
  --resource-group $ResourceGroup `
  --enable-files-aadkerb true | Out-Null

Write-Host "==> Locating the auto-created storage service principal ..."
$spnName = "[Storage Account] $StorageAccountName.file.$((az cloud show --query 'suffixes.storageEndpoint' -o tsv))"
$appId = az ad sp list --display-name $spnName --query "[0].appId" -o tsv

if (-not $appId) {
  Write-Warning "Service principal '$spnName' not found yet. It can take a minute to appear; re-run if needed."
  return
}

Write-Host "==> Granting admin consent to $appId ..."
az ad app permission admin-consent --id $appId

Write-Host ""
Write-Host "Done. Remaining manual steps:"
Write-Host "  • Exclude the storage app ($appId) from MFA in Conditional Access,"
Write-Host "    OR keep per-user MFA disabled for the storage app."
Write-Host "  • Set FSLogix NTFS/directory permissions on the 'profiles' share."
