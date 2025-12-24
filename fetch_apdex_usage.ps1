# fetch_apdex_usage.ps1
# Fetch APDEX (Real Users) every 5 minutes and print sorted summary to Teams

# -----------------------------
# Dynatrace Metrics API URL
# -----------------------------
$url = @"
https://etq84528.live.dynatrace.com/api/v2/metrics/query?metricSelector=builtin:apps.web.apdex.userType:filter(eq("User%20type","Real%20users")):splitBy("dt.entity.application"):avg:sort(value(avg,descending)):limit(50)&from=-5m&to=now&resolution=Inf&mzSelector=mzId(6099903660333152921)
"@

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
$response = Invoke-RestMethod -Uri $url -Headers $headers

# -----------------------------
# Helper: APDEX emoji (YOUR RULES)
# -----------------------------
function Get-ApdexEmoji($value) {
    if ($value -ge 0.75) { "🟢" }
    elseif ($value -ge 0.60) { "🟡" }
    else { "🔴" }
}

# -----------------------------
# Collect & format output
# -----------------------------
$rows = @()

if ($response.result.Count -gt 0) {
    foreach ($series in $response.result[0].data) {
        if ($series.values -and $series.values.Count -gt 0) {
            $apdex = [math]::Round($series.values[0], 2)
            $app   = $series.dimensions[0]

            $rows += [PSCustomObject]@{
                App   = $app
                Apdex = $apdex
                Emoji = Get-ApdexEmoji $apdex
            }
        }
    }
}

# -----------------------------
# Sort GOOD → BAD
# -----------------------------
$rows = $rows | Sort-Object Apdex -Descending

# -----------------------------
# Build text block
# -----------------------------
if ($rows.Count -eq 0) {
    $linesText = "No APDEX data available."
}
else {
    $linesText = ($rows | ForEach-Object {
        "$($_.Emoji) $($_.App) → $($_.Apdex)"
    }) -join "  `n"
}

# -----------------------------
# Teams Adaptive Card
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
            "text": "📊 **EU MLP PROD – APDEX (Real Users)**",
            "weight": "bolder",
            "size": "medium",
            "wrap": true
          },
          {
            "type": "TextBlock",
            "text": "Last 5 minutes",
            "isSubtle": true,
            "wrap": true
          },
          {
            "type": "TextBlock",
            "text": "$linesText",
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
$teamsWebhookUrl = "https://default38c3fde4197b47b99500769f547df6.98.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/e8ceeb408a724650bd06a9c843d893be/triggers/manual/paths/invoke?api-version=1&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=7iZGnBXee4J8UmLNfvaE9I4BcWc6LIajZTOx909AVMY"

Invoke-RestMethod `
  -Uri $teamsWebhookUrl `
  -Method Post `
  -Body $adaptiveCardMessage `
  -ContentType "application/json"
