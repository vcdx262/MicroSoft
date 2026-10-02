// =============================================================================
// identity-rbac.bicep  —  Entra-only access model (no AD DS)
//
//  • Consultants  -> Virtual Machine User Login (sign in to session hosts)
//                 -> Desktop Virtualization User (launch the published desktop)
//                 -> Storage File Data SMB Share Contributor (FSLogix profiles share)
//  • Admins       -> Virtual Machine Administrator Login (local admin on hosts)
// =============================================================================

param userGroupObjectId string
param adminGroupObjectId string
param desktopAppGroupName string
param storageAccountName string

// Built-in role definition IDs.
var roleVmUserLogin = 'fb879df8-f326-4884-b1cf-06f3ad86be52'
var roleVmAdminLogin = '1c0163c0-47e6-4577-8991-ea5c82e286e4'
var roleDesktopVirtUser = '1d18fff3-a72a-46b5-b4a9-0b38a3cd7e63'
var roleSmbShareContributor = '0c867c2a-1d8c-454a-a3db-ab2ea1bdc8bb'

resource appGroup 'Microsoft.DesktopVirtualization/applicationGroups@2024-04-03' existing = {
  name: desktopAppGroupName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

// ---- VM sign-in (resource-group scope covers all session hosts + Kali) ----
resource vmUserLogin 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, userGroupObjectId, roleVmUserLogin)
  scope: resourceGroup()
  properties: {
    principalId: userGroupObjectId
    principalType: 'Group'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleVmUserLogin)
  }
}

resource vmAdminLogin 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, adminGroupObjectId, roleVmAdminLogin)
  scope: resourceGroup()
  properties: {
    principalId: adminGroupObjectId
    principalType: 'Group'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleVmAdminLogin)
  }
}

// ---- AVD desktop access (application-group scope) ----
resource desktopAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(appGroup.id, userGroupObjectId, roleDesktopVirtUser)
  scope: appGroup
  properties: {
    principalId: userGroupObjectId
    principalType: 'Group'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDesktopVirtUser)
  }
}

// ---- Azure Files share-level access (storage-account scope) ----
resource smbShareAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, userGroupObjectId, roleSmbShareContributor)
  scope: storageAccount
  properties: {
    principalId: userGroupObjectId
    principalType: 'Group'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleSmbShareContributor)
  }
}
