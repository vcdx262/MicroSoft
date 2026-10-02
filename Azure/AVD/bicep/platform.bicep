// =============================================================================
// platform.bicep  —  Shared services across all customers (deploy ONCE)
// Scope: resourceGroup  (deploy into rg-avd-platform-cus)
//
//   • Log Analytics workspace — AVD Insights + diagnostics for every customer
//   • Azure Compute Gallery   — home for golden Windows / Kali images later
// =============================================================================

targetScope = 'resourceGroup'

param location string = 'centralus'
param workspaceName string = 'log-avd-platform'
param galleryName string = 'gal_avd_platform'

@description('Log Analytics retention in days.')
param retentionInDays int = 30

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionInDays
  }
}

resource gallery 'Microsoft.Compute/galleries@2023-07-03' = {
  name: galleryName
  location: location
  properties: {
    description: 'Golden images for AVD security-consulting platform'
  }
}

output logAnalyticsWorkspaceId string = logAnalytics.id
output galleryId string = gallery.id
