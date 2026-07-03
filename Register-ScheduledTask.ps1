# Registers the Windows scheduled task that runs Run-Collectors.ps1 on the
# interval set in config.json, as SYSTEM. Must be run once, elevated (as
# Administrator), on the Windows Server hosting the gateway.
#
# SYSTEM is required because Collect-RdpSessions.ps1 reads the Security event
# log, which is off-limits to regular accounts.

. (Join-Path $PSScriptRoot "lib/Config.ps1")
$config = Get-GatewayConfig

$taskName    = $config.scheduledTask.name
$scriptPath  = Join-Path $PSScriptRoot "Run-Collectors.ps1"

$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Run this script as Administrator — registering a task to run as SYSTEM requires elevation."
}

$action = New-ScheduledTaskAction -Execute "pwsh.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes $config.scheduledTask.intervalMinutes) `
    -RepetitionDuration ([TimeSpan]::MaxValue)

$taskPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -ExecutionTimeLimit ([TimeSpan]::Zero)

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
    -Principal $taskPrincipal -Settings $settings -Force | Out-Null

Write-Host "Scheduled task '$taskName' registered — runs Run-Collectors.ps1 every $($config.scheduledTask.intervalMinutes) minutes as SYSTEM."
