# Runs all collectors in sequence. A failure in one collector is logged and
# does not stop the others from running (e.g. a Security log permission issue
# in Collect-RdpSessions.ps1 shouldn't prevent Collect-SystemMetrics.ps1 from
# still recording a row).

$collectorsDir = Join-Path $PSScriptRoot "collectors"
$collectors = @(
    "Collect-GatewayHealth.ps1"
    "Collect-RdpSessions.ps1"
    "Collect-SystemMetrics.ps1"
)

$failed = @()

foreach ($name in $collectors) {
    $path = Join-Path $collectorsDir $name
    Write-Host "== $name =="
    try {
        & $path
    } catch {
        Write-Warning "$name failed: $($_.Exception.Message)"
        $failed += $name
    }
}

if ($failed.Count -gt 0) {
    Write-Warning "Collector(s) failed: $($failed -join ', ')"
    exit 1
}

Write-Host "All collectors completed."
