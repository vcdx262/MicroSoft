<#
.SYNOPSIS
  Create a Conditional Access policy that requires MFA for Azure Virtual Desktop
  (the "web portal with 2FA"), scoped to a customer's consultant group.

.DESCRIPTION
  Targets the Azure Virtual Desktop cloud app (9cdead84-a844-4324-93f2-b2e6bb768d07)
  for Browser + desktop/mobile clients. Optionally enforces a sign-in frequency.

  IMPORTANT for Entra-joined hosts: keep the legacy per-user MFA method disabled,
  and if you restrict to strong auth, exclude the "Azure Windows VM Sign-In" app
  (372140e0-b3b7-4226-8ef9-d57986796201) from this policy.

.NOTES
  Requires: Microsoft.Graph PowerShell module and a Conditional Access Administrator.
  Created DISABLED ('enabledForReportingButNotEnforced') — review, then set to 'enabled'.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory)] [string] $UserGroupObjectId,
  [string] $PolicyName = 'AVD - Require MFA (cust01)',
  [int]    $SignInFrequencyHours = 8
)

$ErrorActionPreference = 'Stop'

Import-Module Microsoft.Graph.Identity.SignIns -ErrorAction Stop
Connect-MgGraph -Scopes 'Policy.ReadWrite.ConditionalAccess','Policy.Read.All' | Out-Null

$avdAppId = '9cdead84-a844-4324-93f2-b2e6bb768d07'

$params = @{
  displayName = $PolicyName
  state       = 'enabledForReportingButNotEnforced'   # report-only; flip to 'enabled' after review
  conditions  = @{
    clientAppTypes = @('browser','mobileAppsAndDesktopClients')
    applications   = @{ includeApplications = @($avdAppId) }
    users          = @{ includeGroups = @($UserGroupObjectId) }
  }
  grantControls = @{
    operator        = 'OR'
    builtInControls = @('mfa')
  }
  sessionControls = @{
    signInFrequency = @{
      isEnabled = $true
      type      = 'hours'
      value     = $SignInFrequencyHours
    }
  }
}

$policy = New-MgIdentityConditionalAccessPolicy -BodyParameter $params
Write-Host "Created policy '$($policy.DisplayName)' (id $($policy.Id)) in REPORT-ONLY mode."
Write-Host "Validate in Entra sign-in logs, then set state to 'enabled'."
