# Sovielproxmox — Homelab Infrastructure

Homelab-Setup mit WireGuard-Tunnel, Ollama (GPU), n8n, Open WebUI und Authelia.

## Architektur

```
Internet
  └─ VPS (öffentliche IP)
       └─ Traefik v3 + Let's Encrypt + Authelia (SSO)
            └─ WireGuard-Tunnel → VM (10.8.0.2)
                     └─ Docker:
                          ├─ Ollama (--gpus all)
                          ├─ WireGuard-Client
                          └─ Open WebUI, n8n, ...
```

## Repo-Struktur

```
.
├── CLAUDE.md                          # Architektur-Doku + Systemregeln
├── staging/
│   ├── docker-stacks/
│   │   ├── open-webui/                # Open WebUI (geplant)
│   │   └── n8n/                       # n8n Automation (geplant)
│   ├── n8n-flows/                     # Exportierte n8n-Workflows
│   └── web-projects/                  # Weitere Web-Projekte
├── tools/
│   ├── ollama/                        # Ollama LLM-Server (aktiv)
│   ├── wireguard-client/              # WireGuard VM→VPS (aktiv/nativ)
│   ├── authelia/                      # Authelia lokal (geplant)
│   └── helper-scripts/                # update.sh, backup.sh, gpu-check.sh
├── .gitignore
├── .env.example                       # Alle Variablen mit Dummy-Werten
└── README.md
```

## Schnellstart

### 1. Voraussetzungen prüfen

```bash
# GPU-Support testen
bash tools/helper-scripts/gpu-check.sh

# Docker-Netzwerk erstellen (einmalig)
docker network create n8n_backend
```

### 2. Umgebungsvariablen setzen

```bash
cp .env.example .env
# .env mit echten Werten befüllen (niemals committen!)
nano .env
```

### 3. Ollama starten

```bash
docker compose -f tools/ollama/docker-compose.yml up -d

# Modell laden
docker exec -it ollama ollama pull llama3.2
```

### 4. Alles aktualisieren

```bash
bash tools/helper-scripts/update.sh
```

### 5. Backup erstellen

```bash
bash tools/helper-scripts/backup.sh
```

## Sicherheitsregeln

- Keine `ports:`-Direktiven in Compose-Dateien — nur via Tunnel erreichbar
- Keine echten Secrets im Repo — nur `.env.example` mit Dummy-Werten
- WireGuard-Keys ausschließlich in `/etc/wireguard/wg0.conf` auf der VM
- `.env` ist in `.gitignore` — niemals `git add .env`

## Dokumentation

- Detaillierte Architektur: [CLAUDE.md](./CLAUDE.md)
- Ollama: [tools/ollama/README.md](./tools/ollama/README.md)
- WireGuard: [tools/wireguard-client/README.md](./tools/wireguard-client/README.md)
