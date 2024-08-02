# fetch_rds_usage.ps1
# Define the URL for the cURL GET request using a here-string
$url = @"
https://etq84528.live.dynatrace.com/api/v2/metrics/query?metricSelector=(ext:cloud.aws.rds.cpuUtilization:filter(and(or(in("dt.entity.custom_device",entitySelector("type(custom_device),entityName.contains(~"amstack-prod01-eu-prod-~")"))))):splitBy("dt.entity.custom_device"):sort(value(auto,descending))):limit(100):names:fold(max)&from=-5m&to=now&mzSelector=mzId(-1680102141339355738)
"@

# Define the headers for the cURL request
$curlHeaders = @{
    "Authorization" = "Api-Token dt0c01.ZPRK2U62OYFD6F7KTXFBDA4K.Y5QZRDBZS7LL4WVE4QSJ5HRYIPHF7CWCPX5MBGXRLD3ZK3OWLLQFHOLYK7A72ARP"
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
            "text": "**Fetching Details from EU PROD RDS(Database) Consumption Stats for Write Instance from last 5 Minutes.**",
            "wrap": true
          },
          {
            "type": "TextBlock",
            "text": "**The Current Maximum Usage for RDS(Database) of Write Instance is:**",
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
$teamsWebhookUrl = "https://prod-136.westus.logic.azure.com:443/workflows/2524323df8414212a93071eee322d1a2/triggers/manual/paths/invoke?api-version=2016-06-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=UUi1CuPM_oQ0iRCdfxqnnNWvcu7pQ6q9bfykYfE2Mck"

# Send the Adaptive Card payload to Teams
Invoke-RestMethod -Uri $teamsWebhookUrl -Method Post -Body $adaptiveCardMessage -ContentType "application/json"