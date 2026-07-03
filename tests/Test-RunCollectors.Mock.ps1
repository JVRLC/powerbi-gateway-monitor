# Runs Run-Collectors.ps1 with every Windows-only cmdlet mocked, so the whole chain
# can be exercised on macOS/Linux. Also proves error isolation: with -FailGateway,
# Get-Service throws an uncaught error inside Collect-GatewayHealth.ps1, and the
# script checks the other two collectors still ran and produced output.
#
# Usage:
#   pwsh ./tests/Test-RunCollectors.Mock.ps1
#   pwsh ./tests/Test-RunCollectors.Mock.ps1 -FailGateway

param([switch]$FailGateway)

function Get-Service {
    param([string]$Name)
    if ($FailGateway) { throw "Simulated: service control manager unreachable" }
    [pscustomobject]@{ Name = $Name; Status = "Running" }
}

function Get-Process {
    param([string]$Name, $ErrorAction)
    [pscustomobject]@{ Name = $Name; WorkingSet64 = 314572800 }
}

function New-FakeEvent {
    param([datetime]$TimeCreated, [int]$Id, [hashtable]$Data)
    $dataXml = ($Data.GetEnumerator() | ForEach-Object { "<Data Name='$($_.Key)'>$($_.Value)</Data>" }) -join ""
    $xml = "<Event><System></System><EventData>$dataXml</EventData></Event>"
    $evt = [pscustomobject]@{ TimeCreated = $TimeCreated; Id = $Id }
    Add-Member -InputObject $evt -MemberType ScriptMethod -Name ToXml -Value { $this.__xml }.GetNewClosure()
    Add-Member -InputObject $evt -MemberType NoteProperty -Name __xml -Value $xml
    return $evt
}

$fakeTsEvents  = @(New-FakeEvent -TimeCreated (Get-Date).ToUniversalTime() -Id 21 -Data @{ User = "CONTOSO\alice"; Address = "10.0.0.5" })
$fakeSecEvents = @(New-FakeEvent -TimeCreated (Get-Date).ToUniversalTime() -Id 4624 -Data @{ TargetUserName = "bob"; IpAddress = "203.0.113.9"; LogonType = "10" })

function Get-WinEvent {
    param([hashtable]$FilterHashtable, $ErrorAction)
    $events = if ($FilterHashtable.LogName -match "TerminalServices") { $fakeTsEvents } else { $fakeSecEvents }
    $events = $events | Where-Object { $FilterHashtable.Id -contains $_.Id }
    if (-not $events) { throw "No events were found that match the specified selection criteria." }
    return $events
}

function Get-Counter {
    param([string]$Counter, [int]$SampleInterval, [int]$MaxSamples)
    [pscustomobject]@{
        CounterSamples = 40.0, 41.0, 39.0 | ForEach-Object { [pscustomobject]@{ CookedValue = $_ } }
    }
}

function Get-CimInstance {
    param([string]$ClassName, [string]$Filter)
    if ($ClassName -eq "Win32_OperatingSystem") {
        [pscustomobject]@{ TotalVisibleMemorySize = 16777216; FreePhysicalMemory = 4194304 }
    } elseif ($ClassName -eq "Win32_LogicalDisk") {
        [pscustomobject]@{ Size = 214748364800; FreeSpace = 53687091200 }
    }
}

$env:SystemDrive = "C:"

$sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("run-collectors-test-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path (Join-Path $sandbox "collectors") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $sandbox "data") -Force | Out-Null

Copy-Item (Join-Path $PSScriptRoot "../Run-Collectors.ps1") (Join-Path $sandbox "Run-Collectors.ps1")
Copy-Item (Join-Path $PSScriptRoot "../collectors/Collect-GatewayHealth.ps1") (Join-Path $sandbox "collectors/")
Copy-Item (Join-Path $PSScriptRoot "../collectors/Collect-RdpSessions.ps1") (Join-Path $sandbox "collectors/")
Copy-Item (Join-Path $PSScriptRoot "../collectors/Collect-SystemMetrics.ps1") (Join-Path $sandbox "collectors/")

& (Join-Path $sandbox "Run-Collectors.ps1")
$exitCode = $LASTEXITCODE

Write-Host "`n--- data/ after run (exit code $exitCode) ---"
Get-ChildItem (Join-Path $sandbox "data") -Name

if ($FailGateway) {
    $gwAbsent = -not (Test-Path (Join-Path $sandbox "data/gateway_health.csv"))
    $rdpOk    = Test-Path (Join-Path $sandbox "data/rdp_events.csv")
    $sysOk    = Test-Path (Join-Path $sandbox "data/system_metrics.csv")
    if ($gwAbsent -and $rdpOk -and $sysOk -and $exitCode -eq 1) {
        Write-Host "PASS: gateway health collector failed but RDP and system metrics still ran, exit code was 1."
    } else {
        Write-Host "FAIL: error isolation did not behave as expected."
    }
}

Remove-Item $sandbox -Recurse -Force
