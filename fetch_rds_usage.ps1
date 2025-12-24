# ============================================================
# fetch_rds_usage.ps1
# Clean & Grouped RDS CPU summary for Teams
# ============================================================

# -----------------------------
# CONFIG
# -----------------------------
$dtBaseUrl = "https://etq84528.live.dynatrace.com"
$mzId      = "6099903660333152921"   # <-- apna MZ ID

$teamsWebhookUrl = "https://default38c3fde4197b47b99500769f547df6.98.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/2524323df8414212a93071eee322d1a2/triggers/manual/paths/invoke?api-version=1&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=8Gn0w5i0gxaXsSSjym6HVeMon0rCwGnhI5qKaZt8gYw"

# -----------------------------
# Headers
# -----------------------------
$headers = @{
    "Authorization" = "Api-Token $env:DYNATRACE_API_TOKEN"
    "accept"        = "application/json"
}

# -----------------------------
# URLs
# -----------------------------
$urlRds = "$dtBaseUrl/api/v2/metrics/query?metricSelector=builtin:cloud.aws.rds.cpu.usage:splitBy(%22dt.entity.relational_database_service%22):avg:sort(value(avg,descending)):limit(50)&from=-10m&to=now&mzSelector=mzId($mzId)"

$urlCustom = "$dtBaseUrl/api/v2/metrics/query?metricSelector=ext:cloud.aws.rds.cpuUtilization:splitBy(%22dt.entity.custom_device%22):avg:sort(value(avg,descending)):limit(50)&from=-10m&to=now&mzSelector=mzId($mzId)"

# -----------------------------
# Entity cache + resolver
# -----------------------------
$entityCache = @{}

function Resolve-DtEntityName($entityId) {
    if ($entityCache.ContainsKey($entityId)) {
        return $entityCache[$entityId]
    }

    try {
        $resp = Invoke-RestMethod -Uri "$dtBaseUrl/api/v2/entities/$entityId" -Headers $headers
        $entityCache[$entityId] = $resp.displayName
        return $resp.displayName
    } catch {
        return $entityId
    }
}

# -----------------------------
# Helpers
# -----------------------------
function Get-CpuEmoji($cpu) {
    if ($cpu -ge 80) { "🔴" }
    elseif ($cpu -ge 60) { "🟡" }
    else { "🟢" }
}

function Get-Category($name) {
    $n = $name.ToLower()
    if ($n -match "wr|writer|primary") { "WRITE" }
    elseif ($n -match "rd|reader|replica") { "READ" }
    elseif ($n -match "-db") { "DB" }
    else { "OTHER" }
}

function Shorten-Name($name) {
    $name `
        -replace "amstack-prod01-mlpeu-prod-", "" `
        -replace "-db$", " DB"
}

# -----------------------------
# Fetch data
# -----------------------------
$responseRds    = Invoke-RestMethod -Uri $urlRds    -Headers $headers
$responseCustom = Invoke-RestMethod -Uri $urlCustom -Headers $headers

$allReadings = @()

foreach ($resp in @($responseRds, $responseCustom)) {
    if ($resp.result.Count -gt 0) {
        foreach ($series in $resp.result[0].data) {
            if ($series.values) {
                $max = ($series.values | Measure-Object -Maximum).Maximum
                if ($max -ne $null) {
                    $entityId = $series.dimensions[0]
                    $name = Resolve-DtEntityName $entityId

                    $allReadings += [PSCustomObject]@{
                        Name = $name
                        Cpu  = [math]::Round($max, 2)
                    }
                }
            }
        }
    }
}

# -----------------------------
# Grouping
# -----------------------------
$write = @()
$read  = @()
$dbs   = @()

foreach ($item in ($allReadings | Sort-Object Cpu -Descending)) {
    $emoji = Get-CpuEmoji $item.Cpu
    $short = Shorten-Name $item.Name
    $line  = "• $emoji $short → $($item.Cpu)%"

    switch (Get-Category $item.Name) {
        "WRITE" { $write += $line }
        "READ"  { $read  += $line }
        "DB"    { $dbs   += $line }
    }
}

# -----------------------------
# Build message text
# -----------------------------
$sections = @()

if ($write.Count -gt 0) {
    $sections += "🧠 **General Write CPU**`n" + ($write -join "`n")
}
if ($read.Count -gt 0) {
    $sections += "📊 **General Read CPU**`n" + ($read -join "`n")
}
if ($dbs.Count -gt 0) {
    $sections += "🗄️ **Application Databases**`n" + ($dbs -join "`n")
}

$cpuText = if ($sections.Count -gt 0) {
    $sections -join "`n`n"
} else {
    "No CPU data available."
}

# -----------------------------
# Teams Adaptive Card
# -----------------------------
$payload = @{
    type = "message"
    attachments = @(
        @{
            contentType = "application/vnd.microsoft.card.adaptive"
            content = @{
                type = "AdaptiveCard"
                version = "1.0"
                body = @(
                    @{
                        type = "TextBlock"
                        text = "**EU PROD RDS CPU Usage (Last 10 Minutes)**"
                        weight = "bolder"
                        size = "medium"
                        wrap = $true
                    },
                    @{
                        type = "TextBlock"
                        text = $cpuText
                        wrap = $true
                    }
                )
            }
        }
    )
}

Invoke-RestMethod `
    -Uri $teamsWebhookUrl `
    -Method Post `
    -Body ($payload | ConvertTo-Json -Depth 6) `
    -ContentType "application/json"
