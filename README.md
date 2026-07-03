<div align="center">

# 🛡️ Power BI Gateway Monitor

**The gateway that monitors itself.**
PowerShell collectors feed a Power BI dashboard that watches the very
On-premises Data Gateway serving it — health, RDP security, and host load.

![PowerShell](https://img.shields.io/badge/PowerShell-5391FE?style=flat&logo=powershell&logoColor=white)
![Power BI](https://img.shields.io/badge/Power_BI-F2C811?style=flat&logo=powerbi&logoColor=black)
![Windows Server](https://img.shields.io/badge/Windows_Server-0078D6?style=flat&logo=windows&logoColor=white)
![License: MIT](https://img.shields.io/badge/License-MIT-3da639?style=flat)

</div>

---

## Overview

Monitors a Microsoft **On-premises Data Gateway** running on a Windows Server.
PowerShell scripts run on a schedule and collect three data streams — gateway
health, RDP logons, machine load — into CSV files that Power BI turns into a
dashboard. The loop is the fun part: the gateway feeds a report that monitors the
gateway.

## Architecture

```
                Windows Server (Scaleway)
                          │
                          ▼
            ┌──────────────────────────────┐
            │  Scheduled Task — every 15m  │
            └───────────────┬──────────────┘
                            │ runs
                            ▼
            ┌──────────────────────────────┐
            │       Run-Collectors.ps1     │
            ├──────────────────────────────┤
            │  • Collect-GatewayHealth ────┼──►  gateway_health.csv
            │  • Collect-RdpSessions   ────┼──►  rdp_events.csv
            │  • Collect-SystemMetrics ────┼──►  system_metrics.csv
            └───────────────┬──────────────┘
                            │ read
                            ▼
                    ┌───────────────┐
                    │   Power BI    │ ──►  Dashboard
                    └───────────────┘      health · RDP · load
```

## Data model

| File | Fields |
|------|--------|
| `gateway_health.csv` | timestamp, service status, process running, memory, isHealthy |
| `rdp_events.csv` | timestamp, event type, account, source IP, success/fail |
| `system_metrics.csv` | timestamp, CPU %, RAM %, free disk % |

> Timestamps are always **UTC ISO 8601** so Power BI parses them without locale issues.

## Setup (Windows Server)

```powershell
# One-time: create the real config from the versioned example
Copy-Item config\config.example.json config\config.json
# adjust service name, data dir, schedule interval, etc. if needed

# One-time, elevated (Administrator): register the 15-minute scheduled task
.\Register-ScheduledTask.ps1

# Manual run / smoke test
.\Run-Collectors.ps1
```

`Register-ScheduledTask.ps1` runs the task as **SYSTEM**, since reading the Security
event log for RDP logon events requires admin rights.

## Testing without a Windows machine

Every collector has a mocked test harness under `tests/`, runnable on macOS/Linux
with PowerShell Core (`pwsh`) — see [TESTING.md](TESTING.md) for the full command
reference (mocked runs, PSScriptAnalyzer lint, syntax checks).

## Status

Collectors, runner, scheduling, and config are implemented and covered by mock
tests. The Power BI dashboard (build in Power BI Desktop, publish and schedule
refresh through the gateway) is manual GUI work, done directly in Power BI once
the CSVs are being collected.

---

<div align="center">

**License** · MIT

</div>
