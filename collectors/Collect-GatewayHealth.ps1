# Collect On-premises data gateway health and append one row to gateway_health.csv.

. (Join-Path $PSScriptRoot "../lib/Config.ps1")
$config = Get-GatewayConfig

$dataDir = Join-Path (Split-Path $PSScriptRoot -Parent) $config.dataDir
$csvPath = Join-Path $dataDir "gateway_health.csv"

# 1. Read the service
$svc = Get-Service -Name $config.serviceName

# 2. Read the process
$proc = Get-Process -Name $config.processName -ErrorAction SilentlyContinue

# 3. Build the UTC timestamp
$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

# 4. Build the row
$isProcessRunning = $null -ne $proc
$isHealthy        = ($svc.Status -eq "Running") -and $isProcessRunning

$row = [pscustomobject]@{
    Timestamp        = $timestamp
    ServiceStatus    = $svc.Status
    ProcessRunning   = $isProcessRunning
    MemoryMB         = if ($isProcessRunning) { [math]::Round(($proc | Measure-Object WorkingSet64 -Sum).Sum / 1MB, 2) } else { 0 }
    IsHealthy        = $isHealthy
}

# 5. Append to CSV (header written only the first time)
$fileExists = Test-Path $csvPath
$row | Export-Csv -Path $csvPath -NoTypeInformation -Append:$fileExists -Encoding UTF8

Write-Host "Done."