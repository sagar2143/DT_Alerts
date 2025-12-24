# fetch_Solr_usage.ps1
# Fetch maximum Solr memory usage and post clean summary to Teams

# -----------------------------
# Dynatrace Metrics API URL
# -----------------------------
$url = @"
https://etq84528.live.dynatrace.com/api/v2/metrics/query?metricSelector=(builtin:containers.memory.usagePercent:filter(and(eq(Container,solr))):splitBy(Container,"dt.entity.container_group_instance"):avg:auto:sort(value(avg,descending))):limit(100):names:fold(max)&from=-5m&to=now&mzSelector=mzId(6099903660333152921)
"@

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
# Calculate max memory usage
# -----------------------------
$values = $response.result[0].data[0].values
$maximumMemoryUsage = $values | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum

$formattedMemoryUsage = "{0:N2} %" -f $maximumMemoryUsage

# -----------------------------
# Threshold-based color
# -----------------------------
if ($maximumMemoryUsage -ge 80) {
    $color = "attention"   # red
}
elseif ($maximumMemoryUsage -ge 60) {
    $color = "warning"     # yellow
}
else {
    $color = "good"        # green
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
            "text": "🧩 **EU PROD – Solr Memory Usage**",
            "weight": "bolder",
            "size": "medium",
            "wrap": true
          },
          {
            "type": "TextBlock",
            "text": "Maximum SOLR Memory Usage (last 5 minutes)",
            "isSubtle": true,
            "wrap": true
          },
          {
            "type": "TextBlock",
            "text": "$formattedMemoryUsage",
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
$teamsWebhookUrl = "https://default38c3fde4197b47b99500769f547df6.98.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/b233480aed58450382e1b6dadea48950/triggers/manual/paths/invoke?api-version=1&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=-TEYabjx2CIgo03jCIAZGWozAb3sWJ4u6UysOIlRbIc"

# Send to Teams
Invoke-RestMethod `
  -Uri $teamsWebhookUrl `
  -Method Post `
  -Body $adaptiveCardMessage `
  -ContentType "application/json"
