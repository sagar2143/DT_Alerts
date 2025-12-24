# fetch_cpu_usage.ps1
# Fetch maximum SF Nodes CPU usage and post clean summary to Teams

# -----------------------------
# Dynatrace Metrics API URL
# -----------------------------
$url = "https://etq84528.live.dynatrace.com/api/v2/metrics/query?metricSelector=(builtin:containers.cpu.usagePercent:filter(and(eq(Container,hybris-sfapi))):merge(Container,%22dt.entity.container_group_instance%22):max):limit(100):names:fold(max)&from=-5m&to=now&mzSelector=mzId(6099903660333152921)"

# -----------------------------
# Headers
# -----------------------------
$curlHeaders = @{
    "Authorization" = "Api-Token $env:DYNATRACE_API_TOKEN"
    "accept"        = "application/json"
}

# -----------------------------
# Call Dynatrace
# -----------------------------
$response = Invoke-RestMethod -Uri $url -Headers $curlHeaders

# -----------------------------
# Extract CPU value
# -----------------------------
$values = $response.result[0].data[0].values

if ($values -is [array] -and $values.Count -gt 0) {
    $value = $values[0]
    $formattedCpuUsage = "{0:N2} %" -f $value
} else {
    $value = 0
    $formattedCpuUsage = "Data not available"
}

# -----------------------------
# Threshold-based color
# -----------------------------
if ($value -ge 80) {
    $color = "attention"   # 🔴
}
elseif ($value -ge 60) {
    $color = "warning"     # 🟡
}
else {
    $color = "good"        # 🟢
}

# -----------------------------
# Sexy Teams Adaptive Card 😎
# -----------------------------
$adaptiveCardMessage = @"
{
  "type": "message",
  "attachments": [
    {
      "contentType": "application/vnd.microsoft.card.adaptive",
      "content": {
        "type": "AdaptiveCard",
        "version": "1.0",
        "body": [
          {
            "type": "TextBlock",
            "text": "⚙️ **EU PROD – SF Nodes CPU Usage**",
            "weight": "bolder",
            "size": "medium",
            "wrap": true
          },
          {
            "type": "TextBlock",
            "text": "Maximum CPU usage (last 5 minutes)",
            "isSubtle": true,
            "wrap": true
          },
          {
            "type": "TextBlock",
            "text": "$formattedCpuUsage",
            "size": "extraLarge",
            "weight": "bolder",
            "color": "$color",
            "spacing": "small",
            "wrap": true
          },
          {
            "type": "TextBlock",
            "text": "🕒 Data source: Dynatrace | Scope: EU MLP PROD",
            "isSubtle": true,
            "spacing": "medium",
            "wrap": true
          }
        ]
      }
    }
  ]
}
"@

# -----------------------------
# Teams Webhook
# -----------------------------
$teamsWebhookUrl = "https://default38c3fde4197b47b99500769f547df6.98.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/c4fbfc5e883c49b79101f8800094bf82/triggers/manual/paths/invoke?api-version=1&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=emQrDOovh6pJ3FadjSvQLHSJBTGwvDsGZWRyXxFO3G4"

Invoke-RestMethod `
  -Uri $teamsWebhookUrl `
  -Method Post `
  -Body $adaptiveCardMessage `
  -ContentType "applicatio
