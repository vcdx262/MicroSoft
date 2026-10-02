<#
.SYNOPSIS
    Bulk-submits Azure compute quota increase requests across multiple regions.
.DESCRIPTION
    Iterates a list of regions and quota targets (VM family vCPU limits) and submits an
    'az quota update' request for each, logging every submission and the final request
    status to a timestamped JSONL audit trail. The subscription id is read from
    $env:AZURE_SUBSCRIPTION_ID.
.NOTES
    Author : Steven Slocum
    Notes  : Portfolio copy of a real-world script. Lab values and placeholder
             secrets substituted for any originals.
    Requires the Az CLI with the quota extension. Edit the $regions and $quotaTargets
    arrays for your needs.
#>

$ErrorActionPreference = "Continue"

$subscriptionId = $env:AZURE_SUBSCRIPTION_ID
if (-not $subscriptionId) { throw "Set AZURE_SUBSCRIPTION_ID or pass -SubscriptionId." }
$regions = @(
    "westeurope",
    "northeurope",
    "francecentral",
    "swedencentral",
    "germanywestcentral",
    "japaneast",
    "southeastasia",
    "koreacentral"
)

$quotaTargets = @(
    [pscustomobject]@{ ResourceName = "cores"; Limit = 50; Label = "Total Regional vCPUs" },
    [pscustomobject]@{ ResourceName = "Standard NCASv3_T4 Family"; Limit = 8; Label = "NCASv3 T4 Family" },
    [pscustomobject]@{ ResourceName = "StandardNVADSA10v5Family"; Limit = 36; Label = "NVads A10 v5 Family" },
    [pscustomobject]@{ ResourceName = "StandardNCADSA100v4Family"; Limit = 24; Label = "NCads A100 v4 Family" }
)

$runId = Get-Date -Format "yyyyMMdd-HHmmss"
$logPath = Join-Path $PSScriptRoot "gpu-quota-$runId.jsonl"
$statusPath = Join-Path $PSScriptRoot "gpu-quota-$runId-status.json"
$pidPath = Join-Path $PSScriptRoot "active.pid"
$latestPath = Join-Path $PSScriptRoot "latest-run.txt"

$PID | Set-Content -LiteralPath $pidPath
$logPath | Set-Content -LiteralPath $latestPath

[pscustomobject]@{
    timestamp = (Get-Date).ToString("o")
    event = "batch-started"
    subscriptionId = $subscriptionId
    regions = $regions
    quotasPerRegion = $quotaTargets
} | ConvertTo-Json -Compress -Depth 6 | Add-Content -LiteralPath $logPath

foreach ($region in $regions) {
    $scope = "/subscriptions/$subscriptionId/providers/Microsoft.Compute/locations/$region"

    foreach ($quota in $quotaTargets) {
        $output = & az quota update `
            --resource-name $quota.ResourceName `
            --scope $scope `
            --limit-object "value=$($quota.Limit)" `
            --resource-type dedicated `
            --no-wait true `
            --output json 2>&1
        $exitCode = $LASTEXITCODE

        [pscustomobject]@{
            timestamp = (Get-Date).ToString("o")
            event = "request-submitted"
            region = $region
            resourceName = $quota.ResourceName
            label = $quota.Label
            requestedLimit = $quota.Limit
            exitCode = $exitCode
            cliOutput = ($output -join "`n")
        } | ConvertTo-Json -Compress -Depth 6 | Add-Content -LiteralPath $logPath

        Start-Sleep -Seconds 2
    }
}

Start-Sleep -Seconds 30

$snapshots = foreach ($region in $regions) {
    $scope = "/subscriptions/$subscriptionId/providers/Microsoft.Compute/locations/$region"
    $output = & az quota request status list --scope $scope --output json 2>&1

    [pscustomobject]@{
        region = $region
        exitCode = $LASTEXITCODE
        statusOutput = ($output -join "`n")
    }
}

$snapshots | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $statusPath

[pscustomobject]@{
    timestamp = (Get-Date).ToString("o")
    event = "batch-finished"
    statusSnapshot = $statusPath
} | ConvertTo-Json -Compress | Add-Content -LiteralPath $logPath

Remove-Item -LiteralPath $pidPath -ErrorAction SilentlyContinue
