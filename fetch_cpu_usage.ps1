# fetch_cpu_usage.ps1

$url = "https://etq84528.live.dynatrace.com/api/v2/metrics/query?metricSelector=(builtin:containers.cpu.usagePercent:filter(and(eq(Container,hybris-storefront))):merge(Container,%22dt.entity.container_group_instance%22):max):limit(100):names:fold(max)&from=-5m&to=now&mzSelector=mzId(-1680102141339355738)"

$curlHeaders = @{
    "Authorization" = "Api-Token dt0c01.ZPRK2U62OYFD6F7KTXFBDA4K.Y5QZRDBZS7LL4WVE4QSJ5HRYIPHF7CWCPX5MBGXRLD3ZK3OWLLQFHOLYK7A72ARP"
    "accept" = "application/json"
}

$response = Invoke-RestMethod -Uri $url -Headers $curlHeaders

$values = $response.result[0].data[0].values

if ($values -is [array] -and $values.Count -gt 0) {
    $value = $values[0]
    $formattedMemoryUsage = "{0:N2}%" -f $value
} else {
    $formattedMemoryUsage = "Data not available"
}

$adaptiveCardMessage = @{
    "type" = "message"
    "attachments" = @(
        @{
            "contentType" = "application/vnd.microsoft.card.adaptive"
            "content" = @{
                "type" = "AdaptiveCard"
                "version" = "1.0"
                "body" = @(
                    @{
                        "type" = "TextBlock"
                        "text" = "**Initiating commands...**"
                        "wrap" = $true
                    },
                    @{
                        "type" = "TextBlock"
                        "text" = "**Fetching Details from EU PROD SF Nodes CPU Consumption Stats for last 5 Minutes.**"
                        "wrap" = $true
                    },
                    @{
                        "type" = "TextBlock"
                        "text" = "**The Current Maximum SF Nodes CPU Usage is:**"
                        "wrap" = $true
                        "weight" = "bolder"
                    },
                    @{
                        "type" = "TextBlock"
                        "text" = $formattedMemoryUsage
                        "wrap" = $true
                        "size" = "extraLarge"
                        "weight" = "bolder"
                        "color" = "warning"
                    }
                )
            }
        }
    )
}

$adaptiveCardMessageJson = $adaptiveCardMessage | ConvertTo-Json -Depth 5
$teamsWebhookUrl = "https://prod-106.westus.logic.azure.com:443/workflows/c4fbfc5e883c49b79101f8800094bf82/triggers/manual/paths/invoke?api-version=2016-06-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=cRx9Bc_8eYcTFiW8Cqm8FF4KXsa3_EIaHSdQY9drNYs"

Invoke-RestMethod -Uri $teamsWebhookUrl -Method Post -Body $adaptiveCardMessageJson -ContentType "application/json"
