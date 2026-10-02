// =============================================================================
// storage.bicep  —  Per-customer Azure Files (FSLogix profiles ONLY)
//
// Customer data now lives in device-gated OneDrive/SharePoint (ADR 0009), so the
// 'data' share is removed — this account exists solely for FSLogix profiles.
//
// Billing model: Provisioned v2 (PremiumV2_LRS / FileStorage). v2 lets capacity,
// IOPS and throughput scale independently and lowers the per-share floor to 32 GiB
// (v1 Premium was 100 GiB — proven 2026-06-22, see gotchas).
//
// Network: reached via a vNet SERVICE ENDPOINT (Microsoft.Storage) on snet-avd +
// storage firewall — NOT a private endpoint. Traffic stays on the Azure backbone
// (never the public internet); the firewall denies everything except snet-avd.
//
// NOTE: Entra Kerberos auth still cannot be enabled in ARM/Bicep — run the
// companion script scripts/enable-storage-kerberos.ps1 after this deploys.
// =============================================================================

@description('Globally-unique storage account name.')
param storageAccountName string
param location string
param profilesShareName string

@description('Resource ID of the AVD subnet (snet-avd) allowed through the storage firewall via its Microsoft.Storage service endpoint.')
param avdSubnetId string

@description('Provisioned v2 SSD. PremiumV2_LRS enables the 32 GiB floor + independent IOPS/throughput.')
param storageSku string = 'PremiumV2_LRS'

@description('Provisioned size (GiB) for the FSLogix profiles share. v2 minimum is 32.')
@minValue(32)
param profilesShareQuota int = 32

resource storageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageSku
  }
  kind: 'FileStorage'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    // Public endpoint stays Enabled but is locked to snet-avd by the firewall below;
    // reached over the Azure backbone via the subnet's Microsoft.Storage service endpoint.
    publicNetworkAccess: 'Enabled'
    supportsHttpsTrafficOnly: true
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      virtualNetworkRules: [
        {
          id: avdSubnetId
          action: 'Allow'
        }
      ]
    }
    encryption: {
      keySource: 'Microsoft.Storage'
      services: {
        file: {
          enabled: true
          keyType: 'Account'
        }
      }
    }
  }
}

resource fileServices 'Microsoft.Storage/storageAccounts/fileServices@2024-01-01' = {
  parent: storageAccount
  name: 'default'
}

resource profilesShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2024-01-01' = {
  parent: fileServices
  name: profilesShareName
  properties: {
    // Provisioned v2: 32 GiB floor. IOPS/throughput auto-baseline from size (can be raised later).
    shareQuota: profilesShareQuota
    enabledProtocols: 'SMB'
  }
}

output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
