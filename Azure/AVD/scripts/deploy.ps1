<#
.SYNOPSIS
  End-to-end deployment driver for the AVD security-consulting MVP.

.DESCRIPTION
  Deploys (1) the shared platform stack once, then (2) a per-customer stack.
  Run with -PlatformOnly the first time, then per customer with -CustomerParam.

.EXAMPLE
  # One-time shared platform:
  ./deploy.ps1 -PlatformOnly

  # Per customer (after editing params/cust01.bicepparam):
  $env:AVD_SH_ADMIN_PASSWORD = '<complex-password>'   # Windows session-host local admin
  ./deploy.ps1 -CustomerParam ../bicep/params/cust01.bicepparam -CustomerRg rg-avd-cust01-cus
  # (Kali username/password are set in cust01.bicepparam for the MVP.)
#>

[CmdletBinding(DefaultParameterSetName = 'Customer')]
param(
  [string] $Location = 'centralus',

  [Parameter(ParameterSetName = 'Platform')]
  [switch] $PlatformOnly,
  [string] $PlatformRg = 'rg-avd-platform-cus',

  [Parameter(ParameterSetName = 'Customer', Mandatory)]
  [string] $CustomerParam,
  [Parameter(ParameterSetName = 'Customer', Mandatory)]
  [string] $CustomerRg
)

$ErrorActionPreference = 'Stop'
$bicepRoot = Join-Path $PSScriptRoot '..\bicep'

if ($PlatformOnly) {
  Write-Host "==> Deploying shared platform stack to $PlatformRg ..."
  az group create -n $PlatformRg -l $Location | Out-Null
  az deployment group create `
    -g $PlatformRg -n platform `
    -f (Join-Path $bicepRoot 'platform.bicep') `
    -p (Join-Path $bicepRoot 'params\platform.bicepparam')
  Write-Host "Copy the logAnalyticsWorkspaceId output into your customer bicepparam."
  return
}

Write-Host "==> Deploying customer stack to $CustomerRg ..."
az group create -n $CustomerRg -l $Location | Out-Null
$deployJson = az deployment group create `
  -g $CustomerRg -n avd-customer `
  -f (Join-Path $bicepRoot 'main.bicep') `
  -p $CustomerParam -o json
if ($LASTEXITCODE -ne 0) { throw "Deployment failed." }

$out = ($deployJson | ConvertFrom-Json).properties.outputs
$storageAccountName = $out.storageAccountName.value
$ssoEnabled = [bool]$out.ssoEnabled.value

Write-Host ""
Write-Host "==> Deployment complete. Next steps:" -ForegroundColor Cyan
Write-Host "  1) Enable Entra Kerberos on the storage account + admin consent:"
Write-Host "       ./scripts/enable-storage-kerberos.ps1 -ResourceGroup $CustomerRg -StorageAccountName $storageAccountName"
Write-Host "     Then set FSLogix NTFS/directory permissions on the 'profiles' share."

if ($ssoEnabled) {
  Write-Host "  2) SSO is ENABLED (enableSso = true) — run the one-time TENANT step:"
  Write-Host "       ./scripts/enable-avd-sso.ps1"
} else {
  Write-Host "  2) SSO is DISABLED (enableSso = false) — no tenant SSO step needed."
  Write-Host "     Consultants will re-enter their password at the session host / M365 apps."
}

Write-Host "  (rev1) 2FA via Conditional Access is NOT part of the MVP."
