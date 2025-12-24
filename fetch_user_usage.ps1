# fetch_user_usage.ps1
# Calculate the "from" and "to" date expressions in ISO 8601 format
$fromDate = (Get-Date).AddDays(-1).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$toDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

# Dynatrace Metrics API URL
$url = @"
https://etq84528.live.dynatrace.com/api/v2/metrics/query?metricSelector=(builtin:apps.web.activeUsersEst:filter(and(eq("User%20type","Real%20users"))):merge("dt.entity.application"):merge("User%20type"):merge(Users):sum:auto:sort(value(sum,descending))):limit(100):names:fold(max)&from=$fromDate&to=$toDate&resolution=1h&mzSelector=mzId(6099903660333152921)
"@

# Headers
$curlHeaders = @{
    "Authorization" = "Api-Token $env:DYNATRACE_API_TOKEN"
    "accept" = "application/json"
}

# Call Dynatrace
$response = Invoke-RestMethod -Uri $url -Headers $curlHeaders

# Calculate max user count
$values = $response.result[0].data[0].values
$maximumUserCount = $values | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum

# Format value
$formattedUserCount = "{0:N0} Users" -f $maximumUserCount

# -----------------------------
# SEXY Teams Adaptive Card 😎
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
            "text": "👥 **EU MLP PROD – Active Users Overview**",
            "weight": "bolder",
            "size": "medium",
            "wrap": true
          },
          {
            "type": "TextBlock",
            "text": "Maximum active users per hour (last 24 hours)",
            "isSubtle": true,
            "wrap": true
          },
          {
            "type": "TextBlock",
            "text": "$formattedUserCount",
            "size": "large",
            "weight": "bolder",
            "color": "good",
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

# Teams Webhook
$teamsWebhookUrl = "https://default38c3fde4197b47b99500769f547df6.98.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/a5ed6b5b6f254336b70189f20eb77911/triggers/manual/paths/invoke?api-version=1&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=donbHWX94SpUV8G3sNu8UKOOG3NiLz0rFxF4EF545oQ"

# Send to Teams
Invoke-RestMethod `
  -Uri $teamsWebhookUrl `
  -Method Post `
  -Body $adaptiveCardMessage `
  -ContentType "application/json"
