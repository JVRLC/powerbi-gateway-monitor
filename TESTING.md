# Testing and running the project

Command reference. Important context: development happens on **macOS**, with no
Windows machine available. The collectors use Windows-only cmdlets (`Get-Service`,
`Get-WinEvent`) that don't exist in PowerShell Core on macOS/Linux — so they
**cannot** be run directly locally. That's why every collector has a mocked test
harness under `tests/`.

## Config

Collectors read `config/config.json` (service name, process name, output dir,
scheduled task interval...). This file is gitignored — on the real server, create
it once from the versioned example:

```powershell
Copy-Item config\config.example.json config\config.json
# then adjust the values if needed
```

Locally (mocks), if `config/config.json` is missing, `lib/Config.ps1` automatically
falls back to `config.example.json` with a warning — no need to create it to run
the tests.

## Prerequisites

PowerShell Core (`pwsh`) must be installed:

```bash
command -v pwsh || brew install --cask powershell
```

## Testing collectors locally (via mocks)

```bash
cd ~/Desktop/powerbi-gateway-monitor

# Gateway health — healthy scenario
pwsh ./tests/Test-GatewayHealth.Mock.ps1 -Scenario healthy

# Gateway health — down scenario
pwsh ./tests/Test-GatewayHealth.Mock.ps1 -Scenario down

# RDP sessions (logon/logoff, RDP success/failure)
pwsh ./tests/Test-RdpSessions.Mock.ps1

# System metrics (CPU/RAM/disk)
pwsh ./tests/Test-SystemMetrics.Mock.ps1

# Runner (all 3 collectors in sequence)
pwsh ./tests/Test-RunCollectors.Mock.ps1

# Runner — verifies error isolation (one collector fails, the others still run)
pwsh ./tests/Test-RunCollectors.Mock.ps1 -FailGateway
```

⚠️ Never run `pwsh ./collectors/Collect-GatewayHealth.ps1`,
`Collect-RdpSessions.ps1`, `Collect-SystemMetrics.ps1`, or `Run-Collectors.ps1`
directly on macOS — they'll fail with an error like `Get-Service: term not
recognized`. Always go through the scripts in `tests/`.

## Lint (PSScriptAnalyzer)

```bash
pwsh -NoProfile -Command 'Install-Module PSScriptAnalyzer -Scope CurrentUser -Force'

pwsh -NoProfile -Command '
Import-Module PSScriptAnalyzer
Get-ChildItem -Recurse -Filter "*.ps1" -Path . |
  Where-Object { $_.FullName -notmatch "/tests/" } |
  Invoke-ScriptAnalyzer -Severity Warning,Error -ExcludeRule PSAvoidUsingWriteHost
'
```

Also runs automatically in CI (GitHub Actions, `.github/workflows/lint.yml`) on
every push/PR to `main`. `PSAvoidUsingWriteHost` is excluded on purpose: the
collectors use `Write-Host` for their status messages, and `Write-Output` would
pollute the stream `Run-Collectors.ps1` relies on to detect errors.

## Checking a script's syntax without running it

```bash
pwsh -NoProfile -Command '
$errors = $null; $tokens = $null
[System.Management.Automation.Language.Parser]::ParseFile("collectors/FILE_NAME.ps1", [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count -gt 0) { $errors | ForEach-Object { Write-Host $_.Message } } else { Write-Host "No syntax errors" }
'
```

## Git

```bash
git status --short          # see what changed
git diff                    # see the detail of changes
git add <file>               # stage a specific file
git commit -m "message"     # create a commit
git log --oneline -5        # see the last commits
```

## On the real Windows server (once available)

Real execution of the collectors (the `PBIEgwService` service must be installed):

```powershell
.\Run-Collectors.ps1                   # runs all 3 collectors in sequence
.\collectors\Collect-GatewayHealth.ps1
.\collectors\Collect-RdpSessions.ps1   # needs admin rights (reads the Security log)
.\collectors\Collect-SystemMetrics.ps1
```

Scheduling (once, in an elevated **Administrator** PowerShell prompt):

```powershell
.\Register-ScheduledTask.ps1
```

⚠️ `Register-ScheduledTask.ps1` has no test harness — `Register-ScheduledTask`
doesn't exist at all on macOS/Linux, and a mock would be worthless (there's no
output/CSV to check, just an entry in the Windows task scheduler). Only validate
this on the real server.
