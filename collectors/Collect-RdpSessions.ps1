# Collect RDP session and logon events and append rows to rdp_events.csv.
#
# Two sources:
#   - Microsoft-Windows-TerminalServices-LocalSessionManager/Operational
#     (session logon/logoff/disconnect/reconnect — IDs 21, 23, 24, 25)
#   - Security log, events 4624 (logon success) / 4625 (logon failure),
#     filtered to LogonType 10 (RemoteInteractive = RDP)
#
# The Security log requires admin rights to read, so this needs to run
# as SYSTEM (see the scheduled task setup).

. (Join-Path $PSScriptRoot "../lib/Config.ps1")
$config = Get-GatewayConfig

$dataDir   = Join-Path (Split-Path $PSScriptRoot -Parent) $config.dataDir
$csvPath   = Join-Path $dataDir "rdp_events.csv"
$stateFile = Join-Path $dataDir ".rdp-last-run"

$now = (Get-Date).ToUniversalTime()

# Look back to the last run, with a generous fallback so a first run (or a
# missed schedule) doesn't silently skip events.
if (Test-Path $stateFile) {
    $sinceTime = [datetime]::Parse((Get-Content $stateFile -Raw).Trim()).ToUniversalTime()
} else {
    $sinceTime = $now.AddMinutes(-$config.rdpLookbackMinutesDefault)
}

function ConvertTo-EventDataMap {
    param($EventRecord)
    $xml = [xml]$EventRecord.ToXml()
    $map = @{}
    foreach ($data in $xml.Event.EventData.Data) {
        if ($data.Name) { $map[$data.Name] = $data.'#text' }
    }
    return $map
}

$rows = New-Object System.Collections.Generic.List[object]

# Terminal Services session events 
$tsEventTypes = @{ 21 = "SessionLogon"; 23 = "SessionLogoff"; 24 = "SessionDisconnect"; 25 = "SessionReconnect" }

try {
    $tsEvents = Get-WinEvent -FilterHashtable @{
        LogName   = "Microsoft-Windows-TerminalServices-LocalSessionManager/Operational"
        Id        = 21, 23, 24, 25
        StartTime = $sinceTime
    } -ErrorAction Stop
} catch [Exception] {
    $tsEvents = @()
    if ($_.Exception -isnot [System.Diagnostics.Eventing.Reader.EventLogNotFoundException] -and
        $_.Exception.Message -notmatch "No events were found") {
        Write-Warning "TerminalServices log read failed: $($_.Exception.Message)"
    }
}

foreach ($evt in $tsEvents) {
    $fields = ConvertTo-EventDataMap $evt
    $rows.Add([pscustomobject]@{
        Timestamp = $evt.TimeCreated.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        EventType = $tsEventTypes[$evt.Id]
        Account   = $fields["User"]
        SourceIP  = $fields["Address"]
        Success   = $true
    })
}

# Security log: RDP logon success / failure (LogonType 10) 
try {
    $secEvents = Get-WinEvent -FilterHashtable @{
        LogName   = "Security"
        Id        = 4624, 4625
        StartTime = $sinceTime
    } -ErrorAction Stop
} catch [Exception] {
    $secEvents = @()
    if ($_.Exception -isnot [System.Diagnostics.Eventing.Reader.EventLogNotFoundException] -and
        $_.Exception.Message -notmatch "No events were found") {
        Write-Warning "Security log read failed: $($_.Exception.Message)"
    }
}

foreach ($evt in $secEvents) {
    $fields = ConvertTo-EventDataMap $evt
    if ($fields["LogonType"] -ne "10") { continue }  # RemoteInteractive = RDP

    $rows.Add([pscustomobject]@{
        Timestamp = $evt.TimeCreated.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        EventType = if ($evt.Id -eq 4624) { "RdpLogonSuccess" } else { "RdpLogonFailed" }
        Account   = $fields["TargetUserName"]
        SourceIP  = $fields["IpAddress"]
        Success   = $evt.Id -eq 4624
    })
}

# Append to CSV (header written only the first time) 
if ($rows.Count -gt 0) {
    $rows = $rows | Sort-Object Timestamp
    $fileExists = Test-Path $csvPath
    $rows | Export-Csv -Path $csvPath -NoTypeInformation -Append:$fileExists -Encoding UTF8
}

Set-Content -Path $stateFile -Value $now.ToString("o")

Write-Host "Done. Collected $($rows.Count) RDP event(s)."
