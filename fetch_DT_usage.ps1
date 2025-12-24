# fetch_DT_usage.ps1
# Fetch maximum Storefront (SF) memory usage and post clean summary to Teams

# -----------------------------
# Dynatrace Metrics API URL
# -----------------------------
$url = "https://etq84528.live.dynatrace.com/api/v2/metrics/query?metricSelector=(builtin:containers.memory.usagePercent:filter(and(eq(Container,hybris-sfapi))):merge(Container,%22dt.entity.container_group_instance%22):max):limit(100):names:fold(max)&from=-5m&to=now&mzSelector=mzId(6099903660333152921)"

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
# Extract memory value
# -----------------------------
$values = $response.result[0].data[0].values
$maximumMemoryUsage = $values | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum

$formattedMemoryUsage = "{0:N2} %" -f $maximumMemoryUsage

# -----------------------------
# Custom threshold-based color
# -----------------------------
if ($maximumMemoryUsage -gt 95) {
    $color = "attention"   # 🔴 Red
}
elseif ($maximumMemoryUsage -ge 85) {
    $color = "warning"     # 🟡 Amber
}
else {
    $color = "good"        # 🟢 Green
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
            "text": "🧠 **EU PROD – Storefront Memory Usage**",
            "weight": "bolder",
            "size": "medium",
            "wrap": true
          },
          {
            "type": "TextBlock",
            "text": "Maximum memory usage (last 5 minutes)",
            "isSubtle": true,
            "wrap": true
          },
          {
            "type": "TextBlock",
            "text": "$formattedMemoryUsage",
            "size": "large",
            "weight": "bolder",
            "color": "$color",
            "spacing": "small",
            "wrap": true
          },
          {
            "type": "TextBlock",
            "text": "🕒 Data source: Dynatrace | Scope: EU PROD",
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
$teamsWebhookUrl = "https://default38c3fde4197b47b99500769f547df6.98.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/e941a7c6ab93463da52f3466eca7e2ff/triggers/manual/paths/invoke?api-version=1&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=EgFxhM8PNavCZ1WF3WpjuYi0Q2v0E546j-XaFpMkiuU"

Invoke-RestMethod `
  -Uri $teamsWebhookUrl `
  -Method Post `
  -Body $adaptiveCardMessage `
  -ContentType "application/json"
