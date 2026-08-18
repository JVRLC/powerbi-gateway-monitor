# Power BI Gateway Monitor

> Automated Windows Server monitoring that turns gateway health, security events, and infrastructure metrics into Power BI-ready data.

Power BI Gateway Monitor supervises a Microsoft On-premises Data Gateway. Scheduled PowerShell collectors produce structured datasets that Power BI can consume directly.

## Business problem

When reports stop refreshing, administrators may need to inspect the gateway service, CPU, memory, disk capacity, processes, and RDP events manually. This project automates that collection.

## What it delivers

- Gateway service, process, memory, and calculated health status
- Successful and failed RDP events with account and source information
- CPU, RAM, and free-disk metrics
- UTC ISO 8601 timestamps and Power BI-ready CSV datasets

## Architecture

```text
Windows Scheduled Task → Run-Collectors.ps1
                              ↓
        Gateway health / RDP events / System metrics
                              ↓
                         CSV → Power BI
```

## Result

Timestamped data helps identify downtime, track saturation, investigate access, observe trends, and build historical dashboards.

| Dataset | Main fields |
| --- | --- |
| `gateway_health.csv` | timestamp, service, process, memory, health |
| `rdp_events.csv` | timestamp, event, account, source IP, result |
| `system_metrics.csv` | timestamp, CPU, RAM, free disk |

## Quick demo

On Windows Server:

```powershell
git clone https://github.com/JVRLC/powerbi-gateway-monitor.git
cd powerbi-gateway-monitor
Copy-Item config\config.example.json config\config.json
.\Run-Collectors.ps1
.\Register-ScheduledTask.ps1 # Run once as Administrator
```

The scheduled task uses `SYSTEM` because reading the Security event log requires elevated permissions.

## Testing without Windows Server

```bash
pwsh ./tests/Test-GatewayHealth.Mock.ps1 -Scenario healthy
pwsh ./tests/Test-RdpSessions.Mock.ps1
pwsh ./tests/Test-SystemMetrics.Mock.ps1
pwsh ./tests/Test-RunCollectors.Mock.ps1
```

See [TESTING.md](TESTING.md) for syntax and PSScriptAnalyzer checks.

## Technologies

**PowerShell · Power BI · Windows Server · Task Scheduler · CSV · Infrastructure Monitoring · RDP Event Logs**

## Project status

Collectors, configuration, mocked tests, and scheduling are implemented. Building and publishing the dashboard remains a manual Power BI Desktop operation.

## About

This portfolio project demonstrates how I connect infrastructure-level automation and data collection to business-facing reporting.

Licensed under the MIT License.
