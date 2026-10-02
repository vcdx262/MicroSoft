// =============================================================================
// kali.bicep  —  Standalone Kali Linux VM (NOT an AVD session host)
//
// Kali isn't a supported AVD OS, so it runs as a plain Linux VM in snet-avd.
// No public IP; reached over the private vNet from the Windows session (SSH, or
// xrdp on 3389). The subnet NSG already denies inbound from the internet and
// permits intra-vNet traffic, so no per-NIC NSG is needed for the MVP.
//
// NOTE: the Kali marketplace image requires accepting plan terms once per
// subscription:  az vm image terms accept --publisher kali-linux --offer kali --plan <sku>
// =============================================================================

param prefix string
param location string
param vmSize string
param subnetId string

@description('Kali admin username. NOTE: Azure disallows "admin"/"root"/etc. (see gotcha G-012).')
param adminUsername string = 'kaliadmin'

@secure()
@description('Password for the Kali admin user (SSH password auth — MVP).')
param adminPassword string

@description('Kali marketplace image. Update sku to a current Kali release (see gotcha G-013).')
param imageReference object = {
  publisher: 'kali-linux'
  offer: 'kali'
  sku: 'kali-2026-1'
  version: 'latest'
}

@description('Auto-shutdown time (24h HHmm) and timezone for cost control.')
param autoShutdownTime string = '1900'
param autoShutdownTimeZone string = 'Central Standard Time'

var vmName = 'vm-${prefix}-kali'

resource nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: 'nic-${prefix}-kali'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource kaliVm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: vmName
  location: location
  plan: {
    name: imageReference.sku
    product: imageReference.offer
    publisher: imageReference.publisher
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: 'kali-${take(prefix, 10)}'
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        // Password auth over SSH (MVP). Reachable only from inside the vNet — never the internet.
        disablePasswordAuthentication: false
      }
    }
    storageProfile: {
      imageReference: imageReference
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

resource autoShutdown 'Microsoft.DevTestLab/schedules@2018-09-15' = {
  name: 'shutdown-computevm-${vmName}'
  location: location
  properties: {
    status: 'Enabled'
    taskType: 'ComputeVmShutdownTask'
    dailyRecurrence: {
      time: autoShutdownTime
    }
    timeZoneId: autoShutdownTimeZone
    targetResourceId: kaliVm.id
    notificationSettings: {
      status: 'Disabled'
    }
  }
}

output privateIp string = nic.properties.ipConfigurations[0].properties.privateIPAddress
output vmName string = kaliVm.name
