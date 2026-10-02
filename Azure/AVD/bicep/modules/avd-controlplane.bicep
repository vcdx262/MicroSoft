// =============================================================================
// avd-controlplane.bicep  —  Host pool (Personal), Desktop app group, Workspace
//
// Personal/persistent desktops, Entra-joined, SSO enabled, Start-VM-on-Connect.
// Emits a host-pool registration token consumed by the session-hosts module.
// =============================================================================

param prefix string
param location string
param logAnalyticsWorkspaceId string

@description('Registration token expiry timestamp (ISO 8601).')
param tokenExpiration string

@description('Enable Entra single sign-on. true requires a one-time tenant step (scripts/enable-avd-sso.ps1); false = zero tenant changes but users re-enter their password at the session host / M365 apps.')
param enableSso bool = true

var hostPoolName = 'hp-${prefix}'
var appGroupName = 'dag-${prefix}-desktop'
var workspaceName = 'ws-${prefix}'

// Security-hardening RDP properties:
//   enablerdsaadauth:1  -> Entra SSO (smooth M365 sign-in); requires tenant SSO SPs.
//   drivestoredirect:s: -> local-drive redirection DISABLED (an exfil control).
//   redirections otherwise tuned per engagement in rev1.
var ssoRdp = enableSso ? 'enablerdsaadauth:i:1;' : ''
// redirectclipboard:i:0 — clipboard redirection disabled (DP-02, 2026-06-18). For one-way
// (paste-in only) use the session-host directional clipboard policy instead.
var customRdpProperty = '${ssoRdp}drivestoredirect:s:;redirectclipboard:i:0;audiocapturemode:i:0;redirectprinters:i:0;usbdevicestoredirect:s:;'

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2024-04-03' = {
  name: hostPoolName
  location: location
  properties: {
    hostPoolType: 'Personal'
    personalDesktopAssignmentType: 'Automatic'
    loadBalancerType: 'Persistent'
    preferredAppGroupType: 'Desktop'
    maxSessionLimit: 1
    startVMOnConnect: true
    validationEnvironment: false
    customRdpProperty: customRdpProperty
    registrationInfo: {
      expirationTime: tokenExpiration
      registrationTokenOperation: 'Update'
    }
  }
}

resource appGroup 'Microsoft.DesktopVirtualization/applicationGroups@2024-04-03' = {
  name: appGroupName
  location: location
  properties: {
    hostPoolArmPath: hostPool.id
    applicationGroupType: 'Desktop'
    friendlyName: 'Desktop'
  }
}

resource workspace 'Microsoft.DesktopVirtualization/workspaces@2024-04-03' = {
  name: workspaceName
  location: location
  properties: {
    friendlyName: prefix
    applicationGroupReferences: [
      appGroup.id
    ]
  }
}

// ---------------------------------------------------------------------------
// Diagnostics to the shared Log Analytics workspace (AVD Insights).
// ---------------------------------------------------------------------------
resource hostPoolDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag'
  scope: hostPool
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      { categoryGroup: 'allLogs', enabled: true }
    ]
  }
}

resource workspaceDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag'
  scope: workspace
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      { categoryGroup: 'allLogs', enabled: true }
    ]
  }
}

output hostPoolName string = hostPool.name
output appGroupName string = appGroup.name
output workspaceName string = workspace.name

@secure()
output registrationToken string = hostPool.listRegistrationTokens().value[0].token
