# Registers the Windows scheduled task that runs Run-Collectors.ps1 every 15
# minutes as SYSTEM. Must be run once, elevated (as Administrator), on the
# Windows Server hosting the gateway.
#
# SYSTEM is required because Collect-RdpSessions.ps1 reads the Security event
# log, which is off-limits to regular accounts.

$taskName    = "PowerBI Gateway Monitor"
$scriptPath  = Join-Path $PSScriptRoot "Run-Collectors.ps1"

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Run this script as Administrator — registering a task to run as SYSTEM requires elevation."
}

$action = New-ScheduledTaskAction -Execute "pwsh.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes 15) `
    -RepetitionDuration ([TimeSpan]::MaxValue)

$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -ExecutionTimeLimit ([TimeSpan]::Zero)

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
    -Principal $principal -Settings $settings -Force | Out-Null

Write-Host "Scheduled task '$taskName' registered — runs Run-Collectors.ps1 every 15 minutes as SYSTEM."
