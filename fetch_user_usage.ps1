# fetch_user_usage.ps1
# Calculate the "from" and "to" date expressions in ISO 8601 format
$fromDate = (Get-Date).AddDays(-1).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$toDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

# Define the URL for the cURL GET request using a here-string with the modified "from" and "to" parameters
$url = @"
https://etq84528.live.dynatrace.com/api/v2/metrics/query?metricSelector=(builtin:apps.web.activeUsersEst:filter(and(eq("User%20type","Real%20users"))):merge("dt.entity.application"):merge("User%20type"):merge(Users):sum:auto:sort(value(sum,descending))):limit(100):names:fold(max)&from=$fromDate&to=$toDate&resolution=1h&mzSelector=mzId(-1680102141339355738)
"@

# Define the headers for the cURL request
$curlHeaders = @{
    "Authorization" = "Api-Token $env:DYNATRACE_API_TOKEN"
    "accept" = "application/json"
}

# Perform the cURL GET request and capture the response
$response = Invoke-RestMethod -Uri $url -Headers $curlHeaders

# Extract the "values" from the response
$values = $response.result[0].data[0].values
$maximumUserCount = $values | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum

# Format the user count value with a comma separator
$formattedMemoryUsage = "{0:N0} Users" -f $maximumUserCount

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
            "text": "**Fetching Details from EU PROD Maximum User Count Per Hour throughout Day.**",
            "wrap": true
          },
          {
            "type": "TextBlock",
            "text": "**The Current Maximum User Count Per Hour for today is:**",
            "wrap": true,
            "weight": "bolder"
          },
          {
            "type": "TextBlock",
            "text": "$formattedMemoryUsage",
            "wrap": true,
            "size": "extraLarge",
            "weight": "bolder",
            "color": "good"
          }
        ]
      }
    }
  ]
}
"@

# Construct the Teams webhook URL
$teamsWebhookUrl = "https://prod-111.westus.logic.azure.com:443/workflows/a5ed6b5b6f254336b70189f20eb77911/triggers/manual/paths/invoke?api-version=2016-06-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=BXx7KnkMKRNzs-eoQ1IQvXebK14Zi7NLDgaVC5YprG8"

# Send the Adaptive Card payload to Teams
Invoke-RestMethod -Uri $teamsWebhookUrl -Method Post -Body $adaptiveCardMessage -ContentType "application/json"