# ------------------------------------------------------------
# fetch_rds_usage.ps1
# Fetch ALL RDS CPU usage (native RDS + custom devices)
# and post results to Microsoft Teams
# ------------------------------------------------------------

# -----------------------------
# Dynatrace URLs
# -----------------------------

$urlRds = "https://etq84528.live.dynatrace.com/api/v2/metrics/query?metricSelector=builtin:cloud.aws.rds.cpu.usage:splitBy(%22dt.entity.relational_database_service%22):avg:sort(value(avg,descending)):limit(50)&from=-10m&to=now&mzSelector=mzId(6099903660333152921)"

$urlCustom = "https://etq84528.live.dynatrace.com/api/v2/metrics/query?metricSelector=(ext:cloud.aws.rds.cpuUtilization:filter(and(or(in(%22dt.entity.custom_device%22,entitySelector(%22type(custom_device),entityName(~%22amstack-prod01-m1peu-prod-~%22)%22))))):splitBy(%22dt.entity.custom_device%22):avg:sort(value(avg,descending)):limit(20)):limit(100):names&from=-10m&to=now&mzSelector=mzId(6099903660333152921)"

# -----------------------------
# Headers
# -----------------------------
$headers = @{
    "Authorization" = "Api-Token $env:DYNATRACE_API_TOKEN"
    "accept"        = "application/json"
}

# -----------------------------
# Call Dynatrace
# -----------------------------
$responseRds    = Invoke-RestMethod -Uri $urlRds    -Headers $headers
$responseCustom = Invoke-RestMethod -Uri $urlCustom -Headers $headers

# -----------------------------
# Collect all readings
# -----------------------------
$allReadings = @()

# ---- Native RDS ----
if ($responseRds.result.Count -gt 0) {
    foreach ($series in $responseRds.result[0].data) {
        if ($series.values) {
            $max = ($series.values | Measure-Object -Maximum).Maximum
            if ($max -ne $null) {
                $allReadings += [PSCustomObject]@{
                    Name = $series.dimensions[0]
                    Cpu  = [math]::Round($max, 2)
                }
            }
        }
    }
}

# ---- Custom Devices ----
if ($responseCustom.result.Count -gt 0) {
    foreach ($series in $responseCustom.result[0].data) {
        if ($series.values) {
            $max = ($series.values | Measure-Object -Maximum).Maximum
            if ($max -ne $null) {
                $allReadings += [PSCustomObject]@{
                    Name = $series.dimensions[0]
                    Cpu  = [math]::Round($max, 2)
                }
            }
        }
    }
}

# Sort descending CPU
$allReadings = $allReadings | Sort-Object Cpu -Descending

# -----------------------------
# Build Teams message text
# -----------------------------
if ($allReadings.Count -gt 0) {
    $cpuText = ($allReadings | ForEach-Object {
        "• **$($_.Name)** → $($_.Cpu)%"
    }) -join "`n"
} else {
    $cpuText = "No CPU data available."
}

# -----------------------------
# Adaptive Card payload
# -----------------------------
$adaptiveCard = @{
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
                        "text" = "**EU PROD RDS CPU Usage (Last 10 Minutes)**"
                        "wrap" = $true
                        "weight" = "bolder"
                        "size" = "medium"
                    },
                    @{
                        "type" = "TextBlock"
                        "text" = $cpuText
                        "wrap" = $true
                    }
                )
            }
        }
    )
}

$adaptiveCardJson = $adaptiveCard | ConvertTo-Json -Depth 6

# -----------------------------
# Teams Webhook
# -----------------------------
$teamsWebhookUrl = "https://default38c3fde4197b47b99500769f547df6.98.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/2524323df8414212a93071eee322d1a2/triggers/manual/paths/invoke?api-version=1&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=8Gn0w5i0gxaXsSSjym6HVeMon0rCwGnhI5qKaZt8gYw"

Invoke-RestMethod `
    -Uri $teamsWebhookUrl `
    -Method Post `
    -Body $adaptiveCardJson `
    -ContentType "application/json"
