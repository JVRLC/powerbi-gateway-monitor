<div align="center">

# 🛡️ Power BI Gateway Monitor

**The gateway that monitors itself.**
PowerShell collectors feed a Power BI dashboard that watches the very
On-premises Data Gateway serving it — health, RDP security, and host load.

![PowerShell](https://img.shields.io/badge/PowerShell-5391FE?style=flat&logo=powershell&logoColor=white)
![Power BI](https://img.shields.io/badge/Power_BI-F2C811?style=flat&logo=powerbi&logoColor=black)
![Windows Server](https://img.shields.io/badge/Windows_Server-0078D6?style=flat&logo=windows&logoColor=white)
![License: MIT](https://img.shields.io/badge/License-MIT-3da639?style=flat)

[English](#-english) · [Français](#-français)

</div>

---

## 🇬🇧 English

### Overview

Monitors a Microsoft **On-premises Data Gateway** running on a Windows Server.
PowerShell scripts run on a schedule and collect three data streams — gateway
health, RDP logons, machine load — into CSV files that Power BI turns into a
dashboard. The loop is the fun part: the gateway feeds a report that monitors the
gateway.

### Architecture

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

### Data model

| File | Fields |
|------|--------|
| `gateway_health.csv` | timestamp, service status, process running, memory, isHealthy |
| `rdp_events.csv` | timestamp, event type, account, source IP, success/fail |
| `system_metrics.csv` | timestamp, CPU %, RAM %, free disk % |

> Timestamps are always **UTC ISO 8601** so Power BI parses them without locale issues.

### Roadmap

| Step | What you build |
|------|----------------|
| **0 — Structure** | Folders (collectors, lib, config, data) + a `.gitignore` excluding output CSVs and the real `config.json`. |
| **1 — Gateway health** | Read `PBIEgwService` state (`Get-Service`), check the `Microsoft.PowerBI.EnterpriseGateway` process (`Get-Process`), append one row to CSV. *Gotcha: write the header only once.* |
| **2 — RDP collector** | Read the event log (`Get-WinEvent`): `TerminalServices-LocalSessionManager/Operational` for connects/disconnects, and `Security` 4624/4625 with logon type 10 for RDP brute-force. *Gotcha: parse the event XML.* |
| **3 — System metrics** | Sample CPU (`Get-Counter`), RAM and disk (`Get-CimInstance`), average, write one row. |
| **4 — Runner** | Calls the three collectors in sequence, catching errors so one failure doesn't stop the rest. |
| **5 — Scheduling** | A scheduled task (`Register-ScheduledTask`) every 15 min, running as **SYSTEM** (the Security log needs admin rights). |
| **6 — Config** | Move changing values (service name, log path, interval, output dir) into `config.json`; ship a versioned `config.example.json`. |
| **7 — Dashboard** | In Power BI Desktop: load the CSVs, set column types, build a calendar table and measures (uptime %, outages, failed RDP logons, attacker IPs, avg CPU/RAM). Three pages. |
| **8 — Refresh** | Publish to the Power BI service, schedule refresh… through the gateway itself. The loop closes. |
| **9 — Bonus** | Down-alert (email/webhook), geo-IP map of attackers, CSV → SQL at scale, PSScriptAnalyzer lint in CI. |

---

## 🇫🇷 Français

### Aperçu

Surveille une **passerelle de données locale (On-premises Data Gateway)** Microsoft
installée sur un serveur Windows. Des scripts PowerShell tournent à intervalle régulier
et collectent trois flux — santé de la passerelle, connexions RDP, charge machine —
dans des CSV que Power BI transforme en dashboard. La boucle est le plus joli : la
passerelle alimente un rapport qui la surveille.

### Architecture

```
                Serveur Windows (Scaleway)
                          │
                          ▼
            ┌──────────────────────────────┐
            │  Tâche planifiée — 15 min     │
            └───────────────┬──────────────┘
                            │ lance
                            ▼
            ┌──────────────────────────────┐
            │       Run-Collectors.ps1     │
            ├──────────────────────────────┤
            │  • Collect-GatewayHealth ────┼──►  gateway_health.csv
            │  • Collect-RdpSessions   ────┼──►  rdp_events.csv
            │  • Collect-SystemMetrics ────┼──►  system_metrics.csv
            └───────────────┬──────────────┘
                            │ lit
                            ▼
                    ┌───────────────┐
                    │   Power BI    │ ──►  Dashboard
                    └───────────────┘      santé · RDP · charge
```

### Modèle de données

| Fichier | Champs |
|---------|--------|
| `gateway_health.csv` | timestamp, état du service, processus actif, mémoire, isHealthy |
| `rdp_events.csv` | timestamp, type d'événement, compte, IP source, succès/échec |
| `system_metrics.csv` | timestamp, CPU %, RAM %, disque libre % |

> Les timestamps sont toujours en **UTC ISO 8601** pour éviter les soucis de format français dans Power BI.

### Feuille de route

| Étape | Ce que tu construis |
|-------|---------------------|
| **0 — Structure** | Dossiers (collecteurs, lib, config, data) + un `.gitignore` excluant les CSV de sortie et le vrai `config.json`. |
| **1 — Santé passerelle** | Lis l'état de `PBIEgwService` (`Get-Service`), vérifie le processus `Microsoft.PowerBI.EnterpriseGateway` (`Get-Process`), ajoute une ligne au CSV. *Piège : écrire l'en-tête une seule fois.* |
| **2 — Collecteur RDP** | Lis le journal (`Get-WinEvent`) : `TerminalServices-LocalSessionManager/Operational` pour connexions/déconnexions, et `Security` 4624/4625 type de logon 10 pour le brute-force RDP. *Piège : parser le XML de l'événement.* |
| **3 — Métriques système** | Échantillonne CPU (`Get-Counter`), RAM et disque (`Get-CimInstance`), moyenne, écris une ligne. |
| **4 — Lanceur** | Appelle les trois collecteurs à la suite, en attrapant les erreurs pour qu'un plantage n'arrête pas les autres. |
| **5 — Planification** | Une tâche planifiée (`Register-ScheduledTask`) toutes les 15 min, sous le compte **SYSTEM** (le journal Security exige les droits admin). |
| **6 — Config** | Sors les valeurs changeantes (nom du service, chemin des logs, intervalle, dossier de sortie) dans `config.json` ; fournis un `config.example.json` versionné. |
| **7 — Dashboard** | Dans Power BI Desktop : charge les CSV, force les types, crée une table calendrier et les mesures (taux de dispo, pannes, logons RDP échoués, IP attaquantes, CPU/RAM moyens). Trois pages. |
| **8 — Rafraîchissement** | Publie sur le service Power BI, planifie le refresh… via la passerelle elle-même. La boucle est bouclée. |
| **9 — Bonus** | Alerte panne (e-mail/webhook), carte géo-IP des attaquants, CSV → SQL à grande échelle, lint PSScriptAnalyzer en CI. |

---

<div align="center">

**License** · MIT

</div>
