# fetch_rds_usage.ps1

# Define the URL for the cURL GET request
$url = "https://etq84528.live.dynatrace.com/api/v2/metrics/query?metricSelector=(builtin:cloud.aws.rds.cpu.usage:filter(and(or(in(%22dt.entity.relational_database_service%22,entitySelector(%22type(relational_database_service),entityName(~%22amstack-prod01-eu-prod-~%22)%22))))):splitBy(%22dt.entity.relational_database_service%22):avg:sort(value(avg,descending)):limit(20)):limit(100):names&from=-10m&to=now&mzSelector=mzId(6099903660333152921)"

# Define the headers for the cURL request
$curlHeaders = @{
    "Authorization" = "Api-Token $env:DYNATRACE_API_TOKEN"
    "accept" = "application/json"
}

# Perform the cURL GET request and capture the response
$response = Invoke-RestMethod -Uri $url -Headers $curlHeaders

# Extract the "values" from the response
$values = $response.result[0].data[0].values

# Check if values exist and format the maximum usage value
if ($values -is [array] -and $values.Count -gt 0) {
    $maximumMemoryUsage = $values | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum
    $formattedMemoryUsage = "{0:N2}%" -f $maximumMemoryUsage
} else {
    $formattedMemoryUsage = "Data not available"
}

# Construct the Adaptive Card message
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
                        "text" = "**Fetching Details from EU PROD RDS(Database) Consumption Stats for Write Instance from the last 10 Minutes.**"
                        "wrap" = $true
                    },
                    @{
                        "type" = "TextBlock"
                        "text" = "**The Current Maximum Usage for RDS(Database) of Write Instance is:**"
                        "wrap" = $true
                        "weight" = "bolder"
                    },
                    @{
                        "type" = "TextBlock"
                        "text" = $formattedMemoryUsage
                        "wrap" = $true
                        "size" = "extraLarge"
                        "weight" = "bolder"
                        "color" = "good"
                    }
                )
            }
        }
    )
}

# Convert the message to JSON format
$adaptiveCardMessageJson = $adaptiveCardMessage | ConvertTo-Json -Depth 5

# Construct the Teams webhook URL
$teamsWebhookUrl = "https://default38c3fde4197b47b99500769f547df6.98.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/2524323df8414212a93071eee322d1a2/triggers/manual/paths/invoke?api-version=1&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=8Gn0w5i0gxaXsSSjym6HVeMon0rCwGnhI5qKaZt8gYw"

# Send the Adaptive Card payload to Teams
Invoke-RestMethod -Uri $teamsWebhookUrl -Method Post -Body $adaptiveCardMessageJson -ContentType "application/json"
