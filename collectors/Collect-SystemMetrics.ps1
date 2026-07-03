# Collect host CPU/RAM/disk load and append one row to system_metrics.csv.

. (Join-Path $PSScriptRoot "../lib/Config.ps1")
$config = Get-GatewayConfig

$dataDir = Join-Path (Split-Path $PSScriptRoot -Parent) $config.dataDir
$csvPath = Join-Path $dataDir "system_metrics.csv"

# CPU: average a few samples — a single reading right after the counter opens
# tends to be noisy/inflated.
$cpuSamples = (Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 3).CounterSamples
$cpuPercent = [math]::Round(($cpuSamples | Measure-Object CookedValue -Average).Average, 2)

# RAM
$os = Get-CimInstance Win32_OperatingSystem
$ramPercent = [math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100, 2)

# Disk: free space on the system drive (where Windows/the gateway is installed)
$systemDriveLetter = $env:SystemDrive.TrimEnd(":")
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($systemDriveLetter):'"
$freeDiskPercent = [math]::Round(($disk.FreeSpace / $disk.Size) * 100, 2)

$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$row = [pscustomobject]@{
    Timestamp        = $timestamp
    CpuPercent       = $cpuPercent
    RamPercent       = $ramPercent
    FreeDiskPercent  = $freeDiskPercent
}

# Append to CSV (header written only the first time)
$fileExists = Test-Path $csvPath
$row | Export-Csv -Path $csvPath -NoTypeInformation -Append:$fileExists -Encoding UTF8

Write-Host "Done."
