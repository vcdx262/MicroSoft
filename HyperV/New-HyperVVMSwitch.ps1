<#
.SYNOPSIS
    Creates Hyper-V virtual switches from a CSV definition.
.DESCRIPTION
    For each row in the CSV, creates a virtual switch of the requested type:
      - External : bound to one or more physical NICs. Two or more NICs create a
                   Switch Embedded Team (SET).
      - Internal : host + guests, no uplink.
      - Private  : guests only.
    Optionally tags a management OS vNIC with a VLAN and applies minimum-bandwidth mode.
    Idempotent: a switch that already exists by name is skipped.

    CSV columns:
      SwitchName, Type (External|Internal|Private), NetAdapters (semicolon list,
      External only), AllowManagementOS (true|false), VlanId (0 = untagged),
      BandwidthMode (Weight|Absolute|None)
.PARAMETER Csv
    Path to the switch-definition CSV.
.EXAMPLE
    .\New-HyperVVMSwitch.ps1 -Csv .\switches.csv -WhatIf
.NOTES
    Author : Steven Slocum
    Notes  : Elevated session required. Creating an External switch on the NIC you are
             managing the host through can briefly drop connectivity — prefer a
             dedicated adapter. Lab/production safe with -WhatIf.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(

    [parameter(Mandatory = $true)]
    [string]$Csv

)

#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

$switches = Import-Csv -Path $Csv

foreach ($s in $switches) {

    #Zero per-row state
    $name          = $null
    $type          = $null
    $adapters      = $null
    $allowMgmtOS   = $null

    $name          = $s.SwitchName
    $type          = $s.Type
    $allowMgmtOS   = [bool]::Parse($s.AllowManagementOS)

    if (Get-VMSwitch -Name $name -ErrorAction SilentlyContinue) {
        Write-Verbose "Switch '$name' already exists — skipping."
        continue
    }

    switch ($type) {

        'External' {
            $adapters = @($s.NetAdapters -split ';' | Where-Object { $_ })
            if ($PSCmdlet.ShouldProcess($name, "Create External switch on: $($adapters -join ', ')")) {
                if ($adapters.Count -gt 1) {
                    #Two or more NICs => Switch Embedded Team
                    New-VMSwitch -Name $name -NetAdapterName $adapters -EnableEmbeddedTeaming $true -AllowManagementOS $allowMgmtOS | Out-Null
                }
                else {
                    New-VMSwitch -Name $name -NetAdapterName $adapters[0] -AllowManagementOS $allowMgmtOS | Out-Null
                }
            }
        }

        'Internal' {
            if ($PSCmdlet.ShouldProcess($name, 'Create Internal switch')) {
                New-VMSwitch -Name $name -SwitchType Internal | Out-Null
            }
        }

        'Private' {
            if ($PSCmdlet.ShouldProcess($name, 'Create Private switch')) {
                New-VMSwitch -Name $name -SwitchType Private | Out-Null
            }
        }

        default { Write-Warning "Row '$name': unknown Type '$type' — skipped." ; continue }
    }

    #Optional VLAN tag on the management OS vNIC
    if ([int]$s.VlanId -gt 0 -and $allowMgmtOS) {
        if ($PSCmdlet.ShouldProcess($name, "Tag management vNIC VLAN $($s.VlanId)")) {
            Set-VMNetworkAdapterVlan -ManagementOS -VMNetworkAdapterName $name -Access -VlanId ([int]$s.VlanId)
        }
    }

    #Optional minimum-bandwidth mode (set at creation in real builds; shown here for completeness)
    if ($s.BandwidthMode -and $s.BandwidthMode -ne 'None') {
        Write-Verbose "Switch '$name' requested BandwidthMode=$($s.BandwidthMode); set at creation time via -MinimumBandwidthMode if required."
    }
}

#Report the resulting switches
Get-VMSwitch | Select-Object Name, SwitchType, NetAdapterInterfaceDescription, AllowManagementOS
