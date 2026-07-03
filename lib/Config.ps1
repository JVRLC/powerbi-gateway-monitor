# Loads config/config.json, falling back to config.example.json if the real
# (gitignored) config hasn't been created yet on this machine.

function Get-GatewayConfig {
    $repoRoot    = Split-Path $PSScriptRoot -Parent
    $configPath  = Join-Path $repoRoot "config/config.json"
    $examplePath = Join-Path $repoRoot "config/config.example.json"

    if (-not (Test-Path $configPath)) {
        Write-Warning "config/config.json not found — copy config.example.json to config.json and adjust it. Using example values for now."
        $configPath = $examplePath
    }

    Get-Content $configPath -Raw | ConvertFrom-Json
}
