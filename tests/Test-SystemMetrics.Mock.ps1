# Runs Collect-SystemMetrics.ps1 with mocked Get-Counter / Get-CimInstance / $env:SystemDrive
# so it can be exercised on macOS/Linux, where those don't exist (or mean something else).
#
# Usage:
#   pwsh ./tests/Test-SystemMetrics.Mock.ps1

function Get-Counter {
    param([string]$Counter, [int]$SampleInterval, [int]$MaxSamples)
    # Simulate a noisy-then-settling CPU reading across samples.
    $values = 42.0, 38.5, 40.5
    [pscustomobject]@{
        CounterSamples = $values | ForEach-Object { [pscustomobject]@{ CookedValue = $_ } }
    }
}

function Get-CimInstance {
    param([string]$ClassName, [string]$Filter)
    if ($ClassName -eq "Win32_OperatingSystem") {
        # 16GB total, 4GB free -> 75% used
        [pscustomobject]@{ TotalVisibleMemorySize = 16777216; FreePhysicalMemory = 4194304 }
    } elseif ($ClassName -eq "Win32_LogicalDisk") {
        # 200GB disk, 50GB free -> 25% free
        [pscustomobject]@{ Size = 214748364800; FreeSpace = 53687091200 }
    }
}

$env:SystemDrive = "C:"

$sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("sysmetrics-test-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path (Join-Path $sandbox "collectors") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $sandbox "data") -Force | Out-Null

$collectorSrc = Join-Path $PSScriptRoot "../collectors/Collect-SystemMetrics.ps1"
$collectorCopy = Join-Path $sandbox "collectors/Collect-SystemMetrics.ps1"
Copy-Item $collectorSrc $collectorCopy

& $collectorCopy

Write-Host "`n--- system_metrics.csv ---"
Get-Content (Join-Path $sandbox "data/system_metrics.csv")

Remove-Item $sandbox -Recurse -Force
