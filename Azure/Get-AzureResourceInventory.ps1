<#
.SYNOPSIS
    Inventories all resources in an Azure subscription to CSV, with a JSONL audit log.
.DESCRIPTION
    Enumerates every resource in the target subscription via the Az CLI, flattens the key
    fields (name, type, resource group, location, SKU and tags) to a CSV, and writes a
    timestamped JSONL run log plus a per-resource-type summary — the same
    run-id + JSONL audit pattern used by the Azure quota-request tooling in this repo.
.PARAMETER SubscriptionId
    Target subscription. Defaults to $env:AZURE_SUBSCRIPTION_ID, then the az default.
.PARAMETER OutputFolder
    Folder for the CSV / JSONL output. Created if missing. Default .\Azure-Inventory
.EXAMPLE
    $env:AZURE_SUBSCRIPTION_ID = '<subscription-id>'
    .\Get-AzureResourceInventory.ps1
.EXAMPLE
    .\Get-AzureResourceInventory.ps1 -SubscriptionId <subscription-id> -OutputFolder .\inv
.NOTES
    Author : Steven Slocum
    Notes  : Read-only. Requires the Az CLI (`az login` completed). No secrets are stored;
             the subscription id is read from the environment or the az context.
#>

[CmdletBinding()]
param(

    [parameter(Mandatory = $false)]
    [string]$SubscriptionId = $env:AZURE_SUBSCRIPTION_ID,

    [parameter(Mandatory = $false)]
    [string]$OutputFolder = '.\Azure-Inventory'

)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
}

$runId     = Get-Date -Format 'yyyyMMdd-HHmmss'
$csvPath   = Join-Path $OutputFolder "azure-inventory-$runId.csv"
$jsonlPath = Join-Path $OutputFolder "azure-inventory-$runId.jsonl"

#Resolve subscription
if (-not $SubscriptionId) { $SubscriptionId = (az account show --query id -o tsv) }
az account set --subscription $SubscriptionId

[pscustomobject]@{
    timestamp      = (Get-Date).ToString('o')
    event          = 'inventory-started'
    subscriptionId = $SubscriptionId
    runId          = $runId
} | ConvertTo-Json -Compress | Add-Content -LiteralPath $jsonlPath

#Pull every resource
$raw       = az resource list --subscription $SubscriptionId -o json | ConvertFrom-Json
$results   = @()

foreach ($r in $raw) {
    $obj = $null
    $obj = [pscustomobject]@{
        Name          = $r.name
        Type          = $r.type
        ResourceGroup = $r.resourceGroup
        Location      = $r.location
        Sku           = $r.sku.name
        Tags          = if ($r.tags) { ($r.tags.PSObject.Properties | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ';' } else { '' }
    }
    $results += $obj

    #Per-resource JSONL audit line
    [pscustomobject]@{
        timestamp = (Get-Date).ToString('o')
        event     = 'resource'
        name      = $r.name
        type      = $r.type
        rg        = $r.resourceGroup
        location  = $r.location
    } | ConvertTo-Json -Compress | Add-Content -LiteralPath $jsonlPath
}

$results | Export-Csv -Path $csvPath -NoTypeInformation

[pscustomobject]@{
    timestamp     = (Get-Date).ToString('o')
    event         = 'inventory-finished'
    resourceCount = $results.Count
    csv           = $csvPath
} | ConvertTo-Json -Compress | Add-Content -LiteralPath $jsonlPath

Write-Verbose "Wrote $($results.Count) resources to $csvPath"

#Summary by resource type
$results | Group-Object Type | Sort-Object Count -Descending |
    Select-Object Count, @{ n = 'ResourceType'; e = { $_.Name } }
