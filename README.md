# Power BI Gateway Monitor

> 🛡️ **The gateway that monitors itself.**
> Self-hosted PowerShell collectors feed a Power BI dashboard that watches the very
> On-premises Data Gateway serving it — health, RDP security, and host load.

**🌐 Language / Langue:** [English](#english) · [Français](#français)

---

## English

### What it does

This project monitors a Microsoft **On-premises Data Gateway** running on a Windows
Server. PowerShell scripts run on a schedule, collect data (gateway health, RDP
logons, machine load) into CSV files, and Power BI turns them into a dashboard.

The loop is the fun part: the gateway feeds a report that monitors the gateway.

### Architecture

Three **collectors** (one per data stream) → write to **CSV** → a **scheduled task**
re-runs them every few minutes → **Power BI** reads the CSVs → **dashboard**.
Shared logic (config loading, CSV append, timestamps) lives in a small common library
so the collectors stay DRY.

### Data model

| File | Fields |
|---|---|
| `gateway_health.csv` | timestamp, service status, process running, memory, isHealthy |
| `rdp_events.csv` | timestamp, event type, account, source IP, success/fail |
| `system_metrics.csv` | timestamp, CPU %, RAM %, free disk % |

Timestamps are always **UTC ISO 8601** so Power BI parses them without locale issues.

### Roadmap

**Step 0 — Structure.** Create your folders: one for collectors, one for the shared
library, one for config, one for output data. Add a `.gitignore` that excludes the
output CSVs and the real `config.json`.

**Step 1 — Gateway health collector** *(simplest — your starting point)*. Read the
state of the `PBIEgwService` service (`Get-Service`), check that the
`Microsoft.PowerBI.EnterpriseGateway` process is running (`Get-Process`), build one
row and append it to the CSV. Main gotcha: write the header only once.

**Step 2 — RDP collector.** Read the Windows event log (`Get-WinEvent`). Two sources:
the `TerminalServices-LocalSessionManager/Operational` log for connects/disconnects,
and the `Security` log (events 4624 success / 4625 failure) filtered on logon type 10
(= RDP) to catch failed attempts, i.e. brute-force attacks. Gotcha: extracting fields
from a Security event usually goes through its XML.

**Step 3 — System metrics collector.** Sample CPU (`Get-Counter`), RAM and disk
(`Get-CimInstance`), average a few samples, write one row. The most mechanical of the
three.

**Step 4 — The runner.** A small script that calls your three collectors in sequence,
catching errors so that one failing collector doesn't stop the others.

**Step 5 — Scheduling.** Create a Windows scheduled task (`Register-ScheduledTask`)
that runs the runner every 15 min. Important: run it as the **SYSTEM** account, since
reading the Security log requires admin rights.

**Step 6 — Config.** Move the values that change (service name, log path, interval,
output folder) into a `config.json` your scripts read. Ship a versioned
`config.example.json` and keep the real `config.json` out of the repo.

**Step 7 — Power BI dashboard.** In Power BI Desktop: load the three CSVs (Text/CSV
type, or the Folder connector for near real-time), force column types, build a
calendar table, then your measures (uptime %, outage count, failed RDP logons,
distinct attacker IPs, avg CPU/RAM). Three pages: gateway health, RDP security, host
load.

**Step 8 — Refresh.** Publish to the Power BI service and set up scheduled refresh…
through the gateway itself. The loop is closed.

**Step 9 (bonus) — Going further.** Email/webhook alert when the gateway goes down,
geo-IP enrichment of attackers for a map, move CSVs to a SQL database if volume grows,
and a PowerShell lint (PSScriptAnalyzer) in CI on GitHub.

---

## Français

### Ce que ça fait

Ce projet surveille une **passerelle de données locale (On-premises Data Gateway)** de
Microsoft installée sur un serveur Windows. Des scripts PowerShell tournent à
intervalle régulier, collectent des données (santé de la passerelle, connexions RDP,
charge machine) dans des fichiers CSV, et Power BI en fait un dashboard.

La boucle est le plus joli : la passerelle alimente un rapport qui la surveille.

### Architecture

Trois **collecteurs** (un par flux) → écrivent dans des **CSV** → une **tâche
planifiée** les relance toutes les quelques minutes → **Power BI** lit les CSV →
**dashboard**. Le code commun (lecture de config, écriture CSV, timestamps) vit dans
une petite librairie partagée pour éviter les répétitions.

### Modèle de données

| Fichier | Champs |
|---|---|
| `gateway_health.csv` | timestamp, état du service, processus actif, mémoire, isHealthy |
| `rdp_events.csv` | timestamp, type d'événement, compte, IP source, succès/échec |
| `system_metrics.csv` | timestamp, CPU %, RAM %, disque libre % |

Les timestamps sont toujours en **UTC ISO 8601** pour que Power BI les lise sans
problème de format français.

### Les étapes, dans l'ordre

**Étape 0 — La structure.** Crée tes dossiers : un pour les collecteurs, un pour la
librairie commune, un pour la config, un pour les données de sortie. Mets un
`.gitignore` qui exclut les CSV de sortie et le `config.json` réel.

**Étape 1 — Collecteur santé passerelle** *(le plus simple, ton point de départ)*. Lis
l'état du service `PBIEgwService` (`Get-Service`), vérifie que le processus
`Microsoft.PowerBI.EnterpriseGateway` tourne (`Get-Process`), construis une ligne et
ajoute-la au CSV en mode append. Piège principal : écrire l'en-tête une seule fois.

**Étape 2 — Collecteur RDP.** Lis le journal d'événements Windows (`Get-WinEvent`).
Deux sources : le log `TerminalServices-LocalSessionManager/Operational` pour les
connexions/déconnexions, et le log `Security` (events 4624 succès / 4625 échec) filtrés
sur le type de logon 10 (= RDP) pour repérer les tentatives échouées, donc les attaques
par force brute. Piège : extraire les champs d'un événement Security passe souvent par
son XML.

**Étape 3 — Collecteur métriques système.** Échantillonne le CPU (`Get-Counter`), la
RAM et le disque (`Get-CimInstance`), fais une moyenne sur quelques mesures, écris une
ligne. C'est le plus mécanique des trois.

**Étape 4 — Le lanceur.** Un petit script qui appelle tes trois collecteurs à la suite,
en attrapant les erreurs pour qu'un collecteur qui plante n'empêche pas les autres de
tourner.

**Étape 5 — La planification.** Crée une tâche planifiée Windows
(`Register-ScheduledTask`) qui lance le lanceur toutes les 15 min. Important : fais-la
tourner sous le compte **SYSTEM**, car lire le journal Security demande les droits
admin.

**Étape 6 — La config.** Sors les valeurs qui changent (nom du service, chemin des
logs, intervalle, dossier de sortie) dans un `config.json` que tes scripts lisent.
Fournis un `config.example.json` versionné, et garde le vrai `config.json` hors du
dépôt.

**Étape 7 — Le dashboard Power BI.** Dans Power BI Desktop : charge les trois CSV (type
Texte/CSV, ou connecteur Dossier pour du temps réel), force les types de colonnes, crée
une table calendrier, puis tes mesures (taux de dispo, nb de pannes, logons RDP
échoués, IP attaquantes distinctes, CPU/RAM moyens). Trois pages : santé passerelle,
sécurité RDP, charge machine.

**Étape 8 — Le rafraîchissement.** Publie sur le service Power BI et configure le
refresh planifié… via la passerelle elle-même. La boucle est bouclée.

**Étape 9 (bonus) — Pour aller plus loin.** Alerte e-mail/webhook quand la passerelle
tombe, enrichissement géo-IP des attaquants pour une carte, passage des CSV à une base
SQL si le volume grossit, et un lint PowerShell (PSScriptAnalyzer) en CI sur GitHub.

---

## License

MIT
