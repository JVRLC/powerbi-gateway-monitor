# Runs Collect-RdpSessions.ps1 with a mocked Get-WinEvent so it can be exercised on
# macOS/Linux, where that cmdlet doesn't exist. Covers: a normal session logon/logoff,
# a successful RDP logon (4624/LogonType 10), a failed RDP logon (4625/LogonType 10,
# brute-force signal), and a non-RDP logon (LogonType 3) that must be filtered out.
#
# Usage:
#   pwsh ./tests/Test-RdpSessions.Mock.ps1

function New-FakeEvent {
    param([datetime]$TimeCreated, [int]$Id, [hashtable]$Data)

    $dataXml = ($Data.GetEnumerator() | ForEach-Object {
        "<Data Name='$($_.Key)'>$($_.Value)</Data>"
    }) -join ""

    $xml = "<Event><System></System><EventData>$dataXml</EventData></Event>"

    $evt = [pscustomobject]@{ TimeCreated = $TimeCreated; Id = $Id }
    Add-Member -InputObject $evt -MemberType ScriptMethod -Name ToXml -Value { $this.__xml }.GetNewClosure()
    Add-Member -InputObject $evt -MemberType NoteProperty -Name __xml -Value $xml
    return $evt
}

$fakeTsEvents = @(
    New-FakeEvent -TimeCreated (Get-Date).ToUniversalTime().AddMinutes(-5) -Id 21 -Data @{ User = "CONTOSO\alice"; SessionID = "2"; Address = "10.0.0.5" }
    New-FakeEvent -TimeCreated (Get-Date).ToUniversalTime().AddMinutes(-2) -Id 23 -Data @{ User = "CONTOSO\alice"; SessionID = "2" }
)

$fakeSecEvents = @(
    New-FakeEvent -TimeCreated (Get-Date).ToUniversalTime().AddMinutes(-4) -Id 4624 -Data @{ TargetUserName = "bob"; IpAddress = "203.0.113.9"; LogonType = "10" }
    New-FakeEvent -TimeCreated (Get-Date).ToUniversalTime().AddMinutes(-3) -Id 4625 -Data @{ TargetUserName = "admin"; IpAddress = "198.51.100.23"; LogonType = "10" }
    New-FakeEvent -TimeCreated (Get-Date).ToUniversalTime().AddMinutes(-1) -Id 4624 -Data @{ TargetUserName = "svc-backup"; IpAddress = "10.0.0.9"; LogonType = "3" } # not RDP, must be filtered
)

function Get-WinEvent {
    param([hashtable]$FilterHashtable, $ErrorAction)

    if ($FilterHashtable.LogName -match "TerminalServices") {
        $events = $fakeTsEvents
    } else {
        $events = $fakeSecEvents
    }

    $events = $events | Where-Object { $FilterHashtable.Id -contains $_.Id }
    if (-not $events) { throw "No events were found that match the specified selection criteria." }
    return $events
}

$sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("rdp-test-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path (Join-Path $sandbox "collectors") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $sandbox "data") -Force | Out-Null

$collectorSrc = Join-Path $PSScriptRoot "../collectors/Collect-RdpSessions.ps1"
$collectorCopy = Join-Path $sandbox "collectors/Collect-RdpSessions.ps1"
Copy-Item $collectorSrc $collectorCopy

& $collectorCopy

Write-Host "`n--- rdp_events.csv ---"
Get-Content (Join-Path $sandbox "data/rdp_events.csv")

Remove-Item $sandbox -Recurse -Force
