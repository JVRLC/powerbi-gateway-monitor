# Tester et exécuter le projet

Aide-mémoire des commandes utiles. Contexte important : le développement se fait sur
**macOS**, sans machine Windows disponible. Les collecteurs utilisent des cmdlets
Windows-only (`Get-Service`, `Get-WinEvent`) qui n'existent pas dans PowerShell Core
sur macOS/Linux — ils ne peuvent donc **pas** être exécutés directement en local.
C'est pour ça que chaque collecteur a un harnais de test mocké dans `tests/`.

## Prérequis

PowerShell Core (`pwsh`) doit être installé :

```bash
command -v pwsh || brew install --cask powershell
```

## Tester les collecteurs en local (via les mocks)

```bash
cd ~/Desktop/powerbi-gateway-monitor

# Gateway health — scénario sain
pwsh ./tests/Test-GatewayHealth.Mock.ps1 -Scenario healthy

# Gateway health — scénario en panne
pwsh ./tests/Test-GatewayHealth.Mock.ps1 -Scenario down

# Sessions RDP (logon/logoff, succès/échec RDP)
pwsh ./tests/Test-RdpSessions.Mock.ps1

# Métriques système (CPU/RAM/disque)
pwsh ./tests/Test-SystemMetrics.Mock.ps1

# Runner (les 3 collecteurs en séquence)
pwsh ./tests/Test-RunCollectors.Mock.ps1

# Runner — vérifie l'isolation d'erreur (un collecteur échoue, les autres tournent quand même)
pwsh ./tests/Test-RunCollectors.Mock.ps1 -FailGateway
```

⚠️ Ne jamais lancer directement `pwsh ./collectors/Collect-GatewayHealth.ps1`,
`Collect-RdpSessions.ps1`, `Collect-SystemMetrics.ps1` ou `Run-Collectors.ps1` sur
macOS — ils échoueront avec une erreur du type `Get-Service: term not recognized`.
Toujours passer par les scripts de `tests/`.

## Vérifier la syntaxe d'un script sans l'exécuter

```bash
pwsh -NoProfile -Command '
$errors = $null; $tokens = $null
[System.Management.Automation.Language.Parser]::ParseFile("collectors/NOM_DU_FICHIER.ps1", [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count -gt 0) { $errors | ForEach-Object { Write-Host $_.Message } } else { Write-Host "No syntax errors" }
'
```

## Git

```bash
git status --short          # voir ce qui a changé
git diff                    # voir le détail des changements
git add <fichier>           # stager un fichier précis
git commit -m "message"     # créer un commit
git log --oneline -5        # voir les derniers commits
```

## Sur le vrai serveur Windows (une fois disponible)

Exécution réelle des collecteurs (le service `PBIEgwService` doit être installé) :

```powershell
.\Run-Collectors.ps1                   # lance les 3 collecteurs en séquence
.\collectors\Collect-GatewayHealth.ps1
.\collectors\Collect-RdpSessions.ps1   # nécessite des droits admin (lecture du log Security)
.\collectors\Collect-SystemMetrics.ps1
```
