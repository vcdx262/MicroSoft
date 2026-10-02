// =============================================================================
// session-hosts.bicep  —  Windows 11 Enterprise personal session hosts
//
// Trusted Launch (Secure Boot + vTPM), Entra-joined, NO public IP. The AVD agent
// + bootloader are installed via a Custom Script Extension (registers using the
// host-pool token), which then configures FSLogix and disables OneDrive sync.
// Extension order: AAD join  ->  ConfigureSessionHost (CSE).  (See gotcha G-015.)
// =============================================================================

param prefix string
param location string

@minValue(1)
param count int

param vmSize string
param subnetId string
param adminUsername string

@secure()
param adminPassword string

@secure()
param registrationToken string

param storageAccountName string
param profilesShareName string

@description('Enrol session hosts in Intune (MDM auto-enrollment) — config-delivery plane, ADR 0008.')
param enableIntune bool = true

@description('Win11 multi-session-capable Enterprise marketplace image (single-session use).')
param imageReference object = {
  publisher: 'MicrosoftWindowsDesktop'
  offer: 'windows-11'
  sku: 'win11-24h2-ent'
  version: 'latest'
}

var profilesUnc = '\\\\${storageAccountName}.file.${environment().suffixes.storage}\\${profilesShareName}'

// Authoritative AVD agent + bootloader download links (Microsoft Learn, current).
var agentUrl = 'https://go.microsoft.com/fwlink/?linkid=2310011'
var bootLoaderUrl = 'https://go.microsoft.com/fwlink/?linkid=2311028'

// In-guest setup: install AVD agent + bootloader (register via token), FSLogix, OneDrive off.
var setupScript = '$ErrorActionPreference="Continue"\n$tmp=$env:TEMP\n$agent="$tmp\\RDAgent.msi"\n$boot="$tmp\\RDBootLoader.msi"\nInvoke-WebRequest -Uri "${agentUrl}" -OutFile $agent -UseBasicParsing\nInvoke-WebRequest -Uri "${bootLoaderUrl}" -OutFile $boot -UseBasicParsing\nStart-Process msiexec.exe -Wait -ArgumentList "/i $agent /quiet /norestart REGISTRATIONTOKEN=${registrationToken}"\nStart-Process msiexec.exe -Wait -ArgumentList "/i $boot /quiet /norestart"\ntry { Invoke-WebRequest -Uri "https://aka.ms/fslogix_download" -OutFile "$tmp\\fslogix.zip" -UseBasicParsing; Expand-Archive "$tmp\\fslogix.zip" "$tmp\\fslogix" -Force; Start-Process (Get-ChildItem "$tmp\\fslogix\\x64\\Release\\FSLogixAppsSetup.exe").FullName -Wait -ArgumentList "/install /quiet /norestart" } catch {}\n$k="HKLM:\\SOFTWARE\\FSLogix\\Profiles"\nNew-Item -Path $k -Force | Out-Null\nNew-ItemProperty -Path $k -Name Enabled -Value 1 -PropertyType DWORD -Force | Out-Null\nNew-ItemProperty -Path $k -Name VHDLocations -Value "${profilesUnc}" -PropertyType MultiString -Force | Out-Null\nNew-ItemProperty -Path $k -Name FlipFlopProfileDirectoryName -Value 1 -PropertyType DWORD -Force | Out-Null\nNew-ItemProperty -Path $k -Name VolumeType -Value "VHDX" -PropertyType String -Force | Out-Null\n$o="HKLM:\\SOFTWARE\\Policies\\Microsoft\\OneDrive"\nNew-Item -Path $o -Force | Out-Null\nNew-ItemProperty -Path $o -Name DisableFileSyncNGSC -Value 1 -PropertyType DWORD -Force | Out-Null\nNew-ItemProperty -Path $o -Name DisablePersonalSync -Value 1 -PropertyType DWORD -Force | Out-Null\n$kerb="HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Lsa\\Kerberos\\Parameters"\nNew-Item -Path $kerb -Force | Out-Null\nNew-ItemProperty -Path $kerb -Name CloudKerberosTicketRetrievalEnabled -Value 1 -PropertyType DWORD -Force | Out-Null\n$ts="HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows NT\\Terminal Services"\nNew-Item -Path $ts -Force | Out-Null\nNew-ItemProperty -Path $ts -Name fEnableScreenCaptureProtect -Value 2 -PropertyType DWORD -Force | Out-Null\nNew-ItemProperty -Path $ts -Name fEnableWatermarking -Value 0 -PropertyType DWORD -Force | Out-Null\nNew-ItemProperty -Path $ts -Name WatermarkingHeightFactor -Value 180 -PropertyType DWORD -Force | Out-Null\nNew-ItemProperty -Path $ts -Name WatermarkingOpacity -Value 2000 -PropertyType DWORD -Force | Out-Null\nNew-ItemProperty -Path $ts -Name WatermarkingQrScale -Value 4 -PropertyType DWORD -Force | Out-Null\nNew-ItemProperty -Path $ts -Name WatermarkingWidthFactor -Value 320 -PropertyType DWORD -Force | Out-Null\n'

resource nic 'Microsoft.Network/networkInterfaces@2023-11-01' = [for i in range(0, count): {
  name: 'nic-${prefix}-sh${i}'
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
          // No public IP property -> session hosts are never internet-reachable.
        }
      }
    ]
  }
}]

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = [for i in range(0, count): {
  name: 'vm-${prefix}-sh${i}'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    // AVD Windows license benefit — bills base compute instead of the Windows-licensed rate.
    // Requires connecting users to hold an eligible license (M365 E3/E5, Win E3/E5, Business Premium). See G-021.
    licenseType: 'Windows_Client'
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: 'sh${i}-${take(prefix, 9)}'
      adminUsername: adminUsername
      adminPassword: adminPassword
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
          id: nic[i].id
        }
      ]
    }
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}]

// 1) Entra join (+ Intune MDM auto-enrollment when enableIntune — ADR 0008: Intune is the
//    config-delivery plane). mdmId 0000000a-… = Microsoft Intune. Requires MDM auto-enrollment
//    scope enabled in Entra + the enrolling identity to hold an Intune license (E3/E5/Business Premium).
resource aadJoin 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = [for i in range(0, count): {
  parent: vm[i]
  name: 'AADLoginForWindows'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '2.2'
    autoUpgradeMinorVersion: true
    settings: enableIntune ? {
      mdmId: '0000000a-0000-0000-c000-000000000000'
    } : {}
  }
}]

// 2) Install AVD agent + bootloader (registers the host via the token), then
//    configure FSLogix and disable the OneDrive sync client. Single Custom Script
//    Extension; the script (incl. the registration token) is base64-encoded and
//    passed via protectedSettings so it never appears in plaintext.
resource configHost 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = [for i in range(0, count): {
  parent: vm[i]
  name: 'ConfigureSessionHost'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    protectedSettings: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -NoProfile -Command "$s=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(\'${base64(setupScript)}\')); $p=Join-Path $env:TEMP \'sh-setup.ps1\'; Set-Content -Path $p -Value $s -Encoding UTF8; powershell -ExecutionPolicy Unrestricted -NoProfile -File $p"'
    }
  }
  dependsOn: [
    aadJoin[i]
  ]
}]

output sessionHostIds array = [for i in range(0, count): vm[i].id]
