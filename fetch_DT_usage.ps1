# fetch_DT_usage.ps1
# Define the URL for the cURL GET request
$url = "https://etq84528.live.dynatrace.com/api/v2/metrics/query?metricSelector=(builtin:containers.memory.usagePercent:filter(and(eq(Container,hybris-sfapi))):merge(Container,%22dt.entity.container_group_instance%22):max):limit(100):names:fold(max)&from=-5m&to=now&mzSelector=mzId(6099903660333152921)"

# Define the headers for the cURL request
$curlHeaders = @{
    "Authorization" = "Api-Token $env:DYNATRACE_API_TOKEN"
    "accept" = "application/json"
}

# Perform the cURL GET request and capture the response
$response = Invoke-RestMethod -Uri $url -Headers $curlHeaders

# Extract the "values" from the response
$values = $response.result[0].data[0].values
$maximumMemoryUsage = $values | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum

# Format the memory usage value with two decimal places and percentage symbol
$formattedMemoryUsage = "{0:N2}%" -f $maximumMemoryUsage

# Construct the Teams message in adaptive card format
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
            "text": "**Initiating commands...**",
            "wrap": true
          },
          {
            "type": "TextBlock",
            "text": "**Fetching Details from EU PROD SF Memory Consumption Stats for last 5 Minutes.**",
            "wrap": true
          },
          {
            "type": "TextBlock",
            "text": "**The Current Maximum Storefront Memory Usage is:**",
            "wrap": true,
            "weight": "bolder"
          },
          {
            "type": "TextBlock",
            "text": "$formattedMemoryUsage",
            "wrap": true,
            "size": "extraLarge",
            "weight": "bolder",
            "color": "warning"
          }
        ]
      }
    }
  ]
}
"@

# Construct the Teams webhook URL
$teamsWebhookUrl = "https://default38c3fde4197b47b99500769f547df6.98.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/e941a7c6ab93463da52f3466eca7e2ff/triggers/manual/paths/invoke?api-version=1&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=EgFxhM8PNavCZ1WF3WpjuYi0Q2v0E546j-XaFpMkiuU"

# Send the Adaptive Card payload to Teams
Invoke-RestMethod -Uri $teamsWebhookUrl -Method Post -Body $adaptiveCardMessage -ContentType "application/json"
