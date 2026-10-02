<#
.SYNOPSIS
  One-time tenant step to enable Microsoft Entra single sign-on for AVD.

.DESCRIPTION
  Entra SSO (the host pool's enablerdsaadauth:1 RDP property) requires two service
  principals to exist and be enabled in the tenant:
    • Microsoft Remote Desktop  (a4a365df-50f1-4397-bc59-1a1564b8bb9c)
    • Windows Cloud Login       (270efc09-cd0d-444b-a71f-39af4910ec45)
  This creates them if missing. SSO also gives the consultants seamless M365
  (Outlook/Office) sign-in inside the session.

  Run ONCE per tenant. Skip entirely if you deployed with enableSso = false.

.NOTES
  Requires: Microsoft.Graph PowerShell module and Application Administrator (or
  Cloud Application Administrator). This is a TENANT-level change.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Import-Module Microsoft.Graph.Applications -ErrorAction Stop
Connect-MgGraph -Scopes 'Application.ReadWrite.All' | Out-Null

$apps = @{
  'Microsoft Remote Desktop' = 'a4a365df-50f1-4397-bc59-1a1564b8bb9c'
  'Windows Cloud Login'      = '270efc09-cd0d-444b-a71f-39af4910ec45'
}

foreach ($name in $apps.Keys) {
  $appId = $apps[$name]
  $sp = Get-MgServicePrincipal -Filter "appId eq '$appId'" -ErrorAction SilentlyContinue
  if ($sp) {
    Write-Host "OK   : '$name' service principal already exists ($($sp.Id))."
  }
  else {
    $sp = New-MgServicePrincipal -AppId $appId
    Write-Host "ADDED: '$name' service principal created ($($sp.Id))."
  }
}

Write-Host ""
Write-Host "SSO service principals are in place. The host pool RDP property"
Write-Host "enablerdsaadauth:1 (set by avd-controlplane.bicep) will now take effect."
Write-Host "Optionally suppress the per-host-pool consent prompt by adding the host"
Write-Host "pool ID to each SP's remoteDesktopSecurityConfiguration (see AVD SSO docs)."
