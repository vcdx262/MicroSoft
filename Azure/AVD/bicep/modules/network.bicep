// =============================================================================
// network.bicep  —  Isolated customer vNet, NSG (zero inbound), NAT egress, DNS
// =============================================================================

@description('Resource name prefix, e.g. avd-cust01.')
param prefix string
param location string
param vnetAddressSpace string
param avdSubnetPrefix string
param peSubnetPrefix string

var nsgName = 'nsg-${prefix}-avd'
var natGwName = 'natgw-${prefix}'
var natPipName = 'pip-${prefix}-natgw'
var vnetName = 'vnet-${prefix}'

// ---------------------------------------------------------------------------
// NSG for the session-host / Kali subnet.
// Reverse Connect means AVD needs NO inbound from the internet. We deny it
// explicitly and only permit intra-vNet traffic + required outbound.
// ---------------------------------------------------------------------------
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      // ---- Inbound ----
      {
        name: 'Allow-Intra-Vnet-Inbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '*'
        }
      }
      {
        name: 'Deny-All-Inbound-From-Internet'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      // ---- Outbound (lock egress to what AVD needs) ----
      {
        name: 'Allow-AVD-ServiceTag-Outbound'
        properties: {
          priority: 100
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'WindowsVirtualDesktop'
          destinationPortRange: '443'
        }
      }
      {
        name: 'Allow-AzureCloud-443-Outbound'
        properties: {
          priority: 110
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'AzureCloud'
          destinationPortRange: '443'
        }
      }
      {
        // FSLogix reaches Azure Files over SMB (445) via the storage SERVICE ENDPOINT,
        // i.e. the storage PUBLIC IP in the Storage service tag — NOT intra-vNet (no PE
        // anymore). Region-pinned to keep egress tight (Central US, ADR 0006). Without
        // this, profiles fail with 445 blocked by the deny-all-internet rule (G-026).
        name: 'Allow-Storage-SMB-Outbound'
        properties: {
          priority: 115
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'Storage.CentralUS'
          destinationPortRange: '445'
        }
      }
      {
        name: 'Allow-Intra-Vnet-Outbound'
        properties: {
          priority: 120
          direction: 'Outbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRange: '*'
        }
      }
      {
        // General web browsing for consultants (secure internet via NAT GW).
        name: 'Allow-Web-Outbound'
        properties: {
          priority: 200
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'Internet'
          destinationPortRanges: [
            '80'
            '443'
          ]
        }
      }
      {
        name: 'Deny-All-Other-Outbound-Internet'
        properties: {
          priority: 4096
          direction: 'Outbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'Internet'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// NAT Gateway: outbound-only SNAT. No inbound path exists through it.
// ---------------------------------------------------------------------------
resource natPip 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: natPipName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource natGateway 'Microsoft.Network/natGateways@2023-11-01' = {
  name: natGwName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    idleTimeoutInMinutes: 4
    publicIpAddresses: [
      {
        id: natPip.id
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// vNet + subnets.
// ---------------------------------------------------------------------------
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressSpace
      ]
    }
    subnets: [
      {
        name: 'snet-avd'
        properties: {
          addressPrefix: avdSubnetPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
          natGateway: {
            id: natGateway.id
          }
          // Service endpoint = backbone route + identity for the storage firewall
          // (replaces the private endpoint for FSLogix; data plane moved to OneDrive).
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
          ]
        }
      }
      {
        name: 'snet-pe'
        properties: {
          addressPrefix: peSubnetPrefix
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

// Private DNS zone + private endpoint removed — FSLogix now reaches Azure Files
// over the snet-avd Microsoft.Storage service endpoint (public DNS, backbone route,
// firewall-restricted). snet-pe is retained (unused) until the old PE is cleaned up.

output vnetId string = vnet.id
output avdSubnetId string = vnet.properties.subnets[0].id
output peSubnetId string = vnet.properties.subnets[1].id
