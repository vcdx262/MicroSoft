// =============================================================================
// main.bicep  —  Per-customer AVD stack (one isolated vNet per customer)
// Scope: resourceGroup  (deploy into rg-avd-<customer>-cus)
//
// Delivers a self-contained, network-isolated AVD environment for one customer:
//   network -> storage -> AVD control plane -> session hosts -> Kali -> RBAC
//
// Cloning model: copy params/cust01.bicepparam, change customerName + userGroupObjectId
// (IP space may stay identical), deploy to a NEW resource group. The vNets are never
// peered to each other, so overlapping address space never conflicts.
// =============================================================================

targetScope = 'resourceGroup'

// ---------- Core ----------
@description('Short customer identifier, e.g. cust01. Used in all resource names.')
param customerName string

@description('Azure region for all resources in this stack.')
param location string = 'centralus'

@description('Resource ID of the shared Log Analytics workspace (from the platform stack).')
param logAnalyticsWorkspaceId string

// ---------- Network ----------
@description('vNet address space. Intentionally reusable across customers (isolated vNets).')
param vnetAddressSpace string = '10.10.0.0/16'

@description('Subnet for session hosts + Kali.')
param avdSubnetPrefix string = '10.10.1.0/24'

@description('Subnet for the Azure Files private endpoint.')
param peSubnetPrefix string = '10.10.2.0/24'

// ---------- Identity ----------
@description('Object ID of the Entra security group containing the consultants for this customer.')
param userGroupObjectId string

@description('Object ID of the Entra security group containing AVD admins (VM admin login).')
param adminGroupObjectId string

@description('Enable Entra SSO. true = smooth M365 sign-in but needs a one-time tenant step (enable-avd-sso.ps1); false = zero tenant changes.')
param enableSso bool = true

// ---------- Compute ----------
@description('Number of personal Windows session hosts (one per consultant).')
@minValue(1)
@maxValue(50)
param sessionHostCount int = 1

@description('VM size for Windows session hosts.')
param sessionHostVmSize string = 'Standard_D4s_v5'

@description('VM size for the Kali VM.')
param kaliVmSize string = 'Standard_D2s_v5'

@description('Local administrator username for session hosts.')
param sessionHostAdminUsername string = 'avdadmin'

@secure()
@description('Local administrator password for session hosts.')
param sessionHostAdminPassword string

@description('Admin username for the Kali VM. Azure disallows "admin"/"root"/etc. (gotcha G-012).')
param kaliAdminUsername string = 'kaliadmin'

@secure()
@description('Password for the Kali VM admin user (SSH password auth — MVP).')
param kaliAdminPassword string

@description('Deploy the Kali VM. Set false for lab / identity-only stacks.')
param deployKali bool = true

@description('Enrol session hosts in Intune (config-delivery plane, ADR 0008). Needs MDM scope + Intune licensing.')
param enableIntune bool = true

@description('Host pool registration token expiry (ISO 8601). Defaults to deployment time + 24h.')
param hostPoolTokenExpiration string = dateTimeAdd(utcNow(), 'PT24H')

// ---------- Naming ----------
var prefix = 'avd-${customerName}'
// 'fslogixv2' seed → a NEW deterministic name distinct from the original v1 account,
// so the v2 account can be created alongside v1 during the profile migration.
var storageAccountName = toLower('saavd${replace(customerName, '-', '')}${uniqueString(resourceGroup().id, 'fslogixv2')}')
var profilesShareName = 'profiles'

// =============================================================================
// Modules
// =============================================================================

module network 'modules/network.bicep' = {
  name: 'network'
  params: {
    prefix: prefix
    location: location
    vnetAddressSpace: vnetAddressSpace
    avdSubnetPrefix: avdSubnetPrefix
    peSubnetPrefix: peSubnetPrefix
  }
}

module storage 'modules/storage.bicep' = {
  name: 'storage'
  params: {
    storageAccountName: storageAccountName
    location: location
    profilesShareName: profilesShareName
    avdSubnetId: network.outputs.avdSubnetId
  }
}

module avd 'modules/avd-controlplane.bicep' = {
  name: 'avd-controlplane'
  params: {
    prefix: prefix
    location: location
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    tokenExpiration: hostPoolTokenExpiration
    enableSso: enableSso
  }
}

module sessionHosts 'modules/session-hosts.bicep' = {
  name: 'session-hosts'
  params: {
    prefix: prefix
    location: location
    count: sessionHostCount
    vmSize: sessionHostVmSize
    subnetId: network.outputs.avdSubnetId
    adminUsername: sessionHostAdminUsername
    adminPassword: sessionHostAdminPassword
    registrationToken: avd.outputs.registrationToken
    storageAccountName: storageAccountName
    profilesShareName: profilesShareName
    enableIntune: enableIntune
  }
}

module kali 'modules/kali.bicep' = if (deployKali) {
  name: 'kali'
  params: {
    prefix: prefix
    location: location
    vmSize: kaliVmSize
    subnetId: network.outputs.avdSubnetId
    adminUsername: kaliAdminUsername
    adminPassword: kaliAdminPassword
  }
}

module rbac 'modules/identity-rbac.bicep' = {
  name: 'identity-rbac'
  params: {
    userGroupObjectId: userGroupObjectId
    adminGroupObjectId: adminGroupObjectId
    desktopAppGroupName: avd.outputs.appGroupName
    storageAccountName: storageAccountName
  }
  dependsOn: [
    sessionHosts
    storage
  ]
}

// =============================================================================
// Outputs
// =============================================================================
output workspaceName string = avd.outputs.workspaceName
output hostPoolName string = avd.outputs.hostPoolName
output storageAccountName string = storageAccountName
output ssoEnabled bool = enableSso
output profilesUncPath string = '\\\\${storageAccountName}.file.${environment().suffixes.storage}\\${profilesShareName}'
output kaliPrivateIp string = kali.?outputs.privateIp ?? ''
