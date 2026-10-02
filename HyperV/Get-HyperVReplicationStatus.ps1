<#
.SYNOPSIS
    Reports Hyper-V Replica health for replicated VMs across one or more hosts.
.DESCRIPTION
    For each host, finds VMs participating in Hyper-V Replica (primary or replica) and
    reports replication mode, health, state, the configured frequency, last-replication
    time, average/last replication size and the count of pending-replication operations.
    Flags any VM whose health is not Normal. One row per replicated VM.
.PARAMETER ComputerName
    One or more Hyper-V hosts to query. Defaults to the local host.
.PARAMETER Path
    Output CSV path. Default .\HyperV-Replication.csv
.EXAMPLE
    .\Get-HyperVReplicationStatus.ps1 -ComputerName hv01,hv02
.NOTES
    Author : Steven Slocum
    Notes  : Read-only. Useful as a scheduled health check — non-Normal rows are the
             ones to action.
#>

[CmdletBinding()]
param(

    [parameter(Mandatory = $false)]
    [string[]]$ComputerName = $env:COMPUTERNAME,

    [parameter(Mandatory = $false)]
    [string]$Path = '.\HyperV-Replication.csv'

)

$results = @()

foreach ($c in $ComputerName) {

    $repl = Get-VMReplication -ComputerName $c -ErrorAction SilentlyContinue

    foreach ($r in $repl) {

        $obj = $null

        $obj = [pscustomobject]@{
            Host                 = $c
            VMName               = $r.Name
            Role                 = $r.ReplicationRelationshipType
            Mode                 = $r.ReplicationMode
            Health               = $r.ReplicationHealth
            State                = $r.ReplicationState
            FrequencySec         = $r.FrequencySec
            PrimaryServer        = $r.PrimaryServerName
            ReplicaServer        = $r.ReplicaServerName
            LastReplicationTime  = $r.LastReplicationTime
            AvgReplSizeMB        = if ($r.AverageReplicationSize) { [int]($r.AverageReplicationSize / 1MB) } else { $null }
            LastReplSizeMB       = if ($r.LastReplicationSize)    { [int]($r.LastReplicationSize / 1MB) }    else { $null }
            PendingOps           = $r.PendingReplicationOperations
            Healthy              = ($r.ReplicationHealth -eq 'Normal')
        }

        $results += $obj
    }
}

$results | Export-Csv -Path $Path -NoTypeInformation

$unhealthy = @($results | Where-Object { -not $_.Healthy })
if ($unhealthy.Count -gt 0) {
    Write-Warning "$($unhealthy.Count) replicated VM(s) not in Normal health: $($unhealthy.VMName -join ', ')"
}

$results
