# Runs Collect-GatewayHealth.ps1 with mocked Get-Service / Get-Process so it can be
# exercised on macOS/Linux, where those cmdlets don't exist. Useful when there's no
# Windows box handy to validate the collector logic against.
#
# Usage:
#   pwsh ./tests/Test-GatewayHealth.Mock.ps1 -Scenario healthy
#   pwsh ./tests/Test-GatewayHealth.Mock.ps1 -Scenario down

param(
    [ValidateSet("healthy", "down")]
    [string]$Scenario = "healthy"
)

function Get-Service {
    param([string]$Name)
    if ($Scenario -eq "healthy") {
        [pscustomobject]@{ Name = $Name; Status = "Running" }
    } else {
        [pscustomobject]@{ Name = $Name; Status = "Stopped" }
    }
}

function Get-Process {
    param([string]$Name, $ErrorAction)
    if ($Scenario -eq "healthy") {
        [pscustomobject]@{ Name = $Name; WorkingSet64 = 314572800 } # ~300MB
    } else {
        $null
    }
}

# Copy the real collector into a throwaway repo layout so its $PSScriptRoot-relative
# paths resolve without touching the real data/ folder.
$sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("gwhealth-test-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path (Join-Path $sandbox "collectors") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $sandbox "data") -Force | Out-Null

$collectorSrc = Join-Path $PSScriptRoot "../collectors/Collect-GatewayHealth.ps1"
$collectorCopy = Join-Path $sandbox "collectors/Collect-GatewayHealth.ps1"
Copy-Item $collectorSrc $collectorCopy

& $collectorCopy

Write-Host "`n--- gateway_health.csv ($Scenario) ---"
Get-Content (Join-Path $sandbox "data/gateway_health.csv")

Remove-Item $sandbox -Recurse -Force
