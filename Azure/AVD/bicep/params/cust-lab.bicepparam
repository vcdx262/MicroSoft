using '../main.bicep'

// ---- Scoped TEST LAB stack (isolated; see docs/security-design/track1-lab-plan.md) ----
param customerName = 'lab'
param location = 'centralus'

// Dedicated lab Log Analytics workspace (in rg-avd-lab-cus)
param logAnalyticsWorkspaceId = '/subscriptions/<subscription-id>/resourceGroups/rg-avd-lab-cus/providers/Microsoft.OperationalInsights/workspaces/log-avd-lab'

// Distinct IP range from production (clarity; isolated anyway)
param vnetAddressSpace = '10.20.0.0/16'
param avdSubnetPrefix = '10.20.1.0/24'
param peSubnetPrefix = '10.20.2.0/24'

// Lab consultant group; reuse existing admins group for VM admin login
param userGroupObjectId = '<grp-avd-lab-users-object-id>'
param adminGroupObjectId = '<grp-avd-admins-object-id>'

// One small session host, no Kali
param sessionHostCount = 1
param sessionHostVmSize = 'Standard_D2s_v4'
param sessionHostAdminUsername = 'avdadmin'
param sessionHostAdminPassword = readEnvironmentVariable('AVD_SH_ADMIN_PASSWORD', '')
param deployKali = false
// Required param even though Kali isn't deployed; unused.
param kaliAdminPassword = readEnvironmentVariable('KALI_ADMIN_PASSWORD', '')

param enableSso = true
