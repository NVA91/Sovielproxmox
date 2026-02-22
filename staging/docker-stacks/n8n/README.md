# n8n — Workflow Automation

n8n ist eine Low-Code-Automation-Plattform. Hier läuft sie zusammen mit
Postgres als Backend-Datenbank im internen `n8n_backend`-Netzwerk auf der VM.

## Abhängigkeiten

| Voraussetzung | Warum |
|---------------|-------|
| `n8n_backend`-Netzwerk | Container-Kommunikation (Postgres, Ollama) |
| WireGuard-Tunnel steht | Webhooks und externe API-Calls laufen über Tunnel |
| `.env` befüllt | Postgres-Passwort, n8n Encryption Key, Domain |

## Konfiguration (`.env`)

Die folgenden Vars müssen in der Root-`.env` gesetzt sein:

```env
DOMAIN=deine-domain.tld
N8N_HOST=n8n.deine-domain.tld
N8N_ENCRYPTION_KEY=32-zeichen-zufaellig    # openssl rand -hex 16
POSTGRES_DB=n8n
POSTGRES_USER=n8n
POSTGRES_PASSWORD=starkes-passwort         # openssl rand -base64 24
TIMEZONE=Europe/Berlin
```

## Starten

```bash
# Aus Repo-Root:
docker compose -f staging/docker-stacks/n8n/docker-compose.yml up -d

# Reihenfolge: Postgres startet zuerst (depends_on in compose)
# Logs prüfen:
docker logs -f n8n_postgres
docker logs -f n8n
```

## Zugriff

Kein direkter Port-Zugriff von außen. n8n ist über den WireGuard-Tunnel und
den VPS-Traefik unter `https://n8n.deine-domain.tld` erreichbar.

Intern (andere Container im gleichen Netz): `http://n8n:5678`

## Wichtige Pfade

| Volume | Inhalt |
|--------|--------|
| `n8n_data` | Workflows, Credentials, Settings |
| `postgres_data` | Postgres-Datenbank |

## Ollama-Integration

n8n kann Ollama direkt ansprechen, da beide im `n8n_backend`-Netz laufen:

- Basis-URL in n8n: `http://ollama:11434`
- Community-Node oder HTTP-Request-Node nutzen

## Workflows exportieren

```bash
# Alle Workflows exportieren (für Versionierung in staging/n8n-flows/):
docker exec n8n n8n export:workflow --all --output=/home/node/.n8n/exported/
docker cp n8n:/home/node/.n8n/exported/. ./staging/n8n-flows/
```

## Backup

Volumes werden von `tools/helper-scripts/backup.sh` gesichert.
Vor größeren Änderungen manuell ausführen:

```bash
bash tools/helper-scripts/backup.sh
```

## Troubleshooting

```bash
# n8n kann Postgres nicht erreichen?
docker network inspect n8n_backend | grep -A5 n8n

# Encryption Key vergessen / geändert → Credentials verloren!
# → Backup einspielen oder Credentials neu anlegen

# Webhook-URL funktioniert nicht?
# → WEBHOOK_URL in compose prüfen (muss öffentliche Domain sein)
# → WireGuard-Tunnel zum VPS prüfen: ping 10.8.0.1
```
