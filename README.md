# Sovielproxmox — Homelab VM-Seite

Dieses Repo enthält alle Docker-Compose-Konfigurationen, Vorlagen und Hilfsskripte
für die **VM-Seite** eines Homelabs hinter einem WireGuard-Tunnel.

| Eigenschaft | Wert |
|-------------|------|
| **Nutzermodell** | Single-User |
| **Sicherheitspriorität** | Hardware zuerst → Netzwerk → Software |
| **Exponierte Ports** | Keine — alles nur via WireGuard-Tunnel |

**Wichtig:** Dieses Repo enthält ausschließlich Vorlagen und Konfigurationsgerüste —
keine echten Secrets, keine automatisch startenden Dienste. Alles muss manuell
aktiviert und befüllt werden.

> Vor dem ersten Start unbedingt `docs/hardware-security.md` durcharbeiten —
> Software-Sicherheit ist wertlos ohne sichere Hardware-Basis.

---

## Architektur-Überblick

```
Internet
  └─ VPS (öffentliche IP — EDGE)
       └─ Traefik v3 + Let's Encrypt  ← TLS-Terminierung
            ├─ Authelia  ← SSO / 2FA (läuft nur auf VPS)
            └─ WireGuard-Server (UDP 51820)
                    │   verschlüsselter Tunnel
                    └─ VM (Proxmox-Gast, keine öffentliche IP — PROCESSING)
                         ├─ WireGuard-Client  → Tunnel zum VPS
                         ├─ Ollama            → LLM-Inferenz mit GPU
                         ├─ Open WebUI        → Web-Frontend (geplant)
                         ├─ n8n + Postgres    → Automation (geplant)
                         └─ Authelia lokal    → optional (geplant)
```

**Kernprinzip:** Die VM publisht **keine** Ports nach außen. Alle Zugriffe laufen
über den WireGuard-Tunnel zum VPS, der als einziger Ingress dient.
Alle VM-Dienste kommunizieren intern über das Docker-Netzwerk `n8n_backend`.

---

## Repo-Struktur

```
.
├── CLAUDE.md                              # Architektur-Doku, Konventionen, Checkliste
├── .env.example                           # Alle Variablen mit sicheren Dummy-Werten
├── .gitignore
├── README.md                              # Diese Datei
│
├── tools/                                 # Produktive Dienste auf der VM
│   ├── ollama/
│   │   ├── docker-compose.yml             # GPU, kein Port-Publish, n8n_backend
│   │   └── README.md
│   ├── wireguard-client/
│   │   ├── docker-compose.yml             # Client-Modus (falls dockerisiert)
│   │   ├── wg0.conf.example              # Maskierte Konfig-Vorlage
│   │   └── README.md
│   ├── authelia/
│   │   ├── docker-compose.yml             # Lokale Authelia (optional)
│   │   ├── config/configuration.yml.example
│   │   └── README.md
│   └── helper-scripts/
│       ├── gpu-check.sh                   # NVIDIA + Docker GPU-Test
│       ├── update.sh                      # Alle Stacks updaten
│       └── backup.sh                      # Volumes sichern
│
└── staging/                               # Geplante / in Entwicklung befindliche Stacks
    ├── docker-stacks/
    │   ├── open-webui/
    │   │   ├── docker-compose.yml
    │   │   └── README.md
    │   └── n8n/
    │       ├── docker-compose.yml
    │       └── README.md
    ├── n8n-flows/                         # Exportierte n8n-Workflow-JSONs
    └── web-projects/                      # Weitere Web-Projekte
```

---

## Voraussetzungen auf der VM

> **Zuerst:** Hardware-Sicherheits-Checkliste in [`docs/hardware-security.md`](./docs/hardware-security.md)
> durcharbeiten — BIOS, LUKS, IOMMU, SSH-Härtung — bevor Docker auch nur gestartet wird.

Danach Folgendes sicherstellen:

### 1. Docker + Compose Plugin

```bash
# Prüfen:
docker --version          # ≥ 24.x empfohlen
docker compose version    # Compose Plugin (nicht docker-compose binary!)
```

### 2. NVIDIA Container Toolkit

```bash
# Prüfen (muss GPU-Infos ausgeben, kein Fehler):
docker run --rm --gpus all nvidia/cuda:12.0-base-ubuntu22.04 nvidia-smi

# Falls nicht vorhanden:
# https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html
# Danach: sudo nvidia-ctk runtime configure --runtime=docker && sudo systemctl restart docker
```

Oder das Hilfsskript nutzen:

```bash
bash tools/helper-scripts/gpu-check.sh
```

### 3. WireGuard-Tunnel zum VPS steht

```bash
# Nativ (empfohlen):
wg show           # muss wg0-Interface mit aktivem Peer zeigen
ping 10.8.0.1     # VPS-Tunnel-IP muss erreichbar sein
```

### 4. Docker-Netzwerk erstellen (einmalig)

```bash
docker network create n8n_backend
# Prüfen: docker network ls | grep n8n_backend
```

---

## Setup-Schritte (nach `git clone`)

### Schritt 1 — Umgebungsvariablen

```bash
cp .env.example .env
nano .env   # alle DUMMY-Werte durch echte ersetzen
```

Die `.env` wird von keinem Stack automatisch geladen — bei Bedarf in jedem
Compose-Verzeichnis verlinken oder die Vars manuell exportieren.

> **Niemals** `git add .env` — `.env` ist in `.gitignore`.

### Schritt 2 — WireGuard starten

**Nativ (empfohlen):**

```bash
# Echte Config einspielen (nicht aus Repo!):
sudo cp /pfad/zur/echten/wg0.conf /etc/wireguard/wg0.conf
sudo chmod 600 /etc/wireguard/wg0.conf
sudo systemctl enable --now wg-quick@wg0

# Test:
wg show && ping -c3 10.8.0.1
```

**Dockerisiert (Alternative):**

```bash
# Erst echte Config bereitstellen:
sudo install -m 600 /pfad/zur/wg0.conf /etc/wireguard/wg0.conf

docker compose -f tools/wireguard-client/docker-compose.yml up -d
docker exec wireguard-client wg show
```

### Schritt 3 — Ollama starten

```bash
docker compose -f tools/ollama/docker-compose.yml up -d

# GPU-Nutzung prüfen:
docker exec ollama nvidia-smi

# Erstes Modell laden:
docker exec -it ollama ollama pull llama3.2
# oder: mistral, gemma2, phi3, ...

# Verfügbare Modelle:
docker exec ollama ollama list
```

### Schritt 4 — n8n starten (geplant)

```bash
docker compose -f staging/docker-stacks/n8n/docker-compose.yml up -d

# Logs prüfen (Postgres muss zuerst ready sein):
docker logs n8n_postgres
docker logs n8n
```

### Schritt 5 — Open WebUI starten (geplant)

```bash
docker compose -f staging/docker-stacks/open-webui/docker-compose.yml up -d
```

> Open WebUI erwartet Ollama unter `http://ollama:11434` im gemeinsamen Netzwerk.
> Ollama muss also **vor** Open WebUI gestartet sein.

---

## Startup-Reihenfolge (Zusammenfassung)

```
WireGuard-Client  →  Ollama  →  n8n (+Postgres)  →  Open WebUI
```

Stopp-Reihenfolge: umgekehrt.

---

## Laufende Wartung

### Alle Stacks updaten

```bash
bash tools/helper-scripts/update.sh
```

### Backup vor größeren Änderungen

```bash
bash tools/helper-scripts/backup.sh
# Backups landen in /opt/homelab-backups/ (7 Tage Aufbewahrung)
```

### Logs

```bash
docker logs -f ollama
docker logs -f n8n
docker logs -f open-webui
```

---

## Sicherheitsregeln (Kurzfassung)

| Regel | Details |
|-------|---------|
| Kein `ports:` in Compose | Alle Dienste nur intern via `n8n_backend` |
| Keine Secrets im Repo | Nur `.env.example` mit Dummies — echte `.env` in `.gitignore` |
| WireGuard-Keys off-repo | Nur in `/etc/wireguard/wg0.conf` auf der VM |
| GPU via `deploy:` | Niemals `runtime: nvidia` |
| Named Volumes | Kein Bind-Mount in `/root/` oder Homedir |

---

## Weiterführende Doku

| Datei | Inhalt |
|-------|--------|
| [docs/infrastructure.md](./docs/infrastructure.md) | **Hardware-Grundkarte: K1X, VPS, XMG, Mobile** |
| [docs/hardware-security.md](./docs/hardware-security.md) | **Hardware-Sicherheit: BIOS, LUKS, AMD-Vi IOMMU, OCuLink** |
| [CLAUDE.md](./CLAUDE.md) | Vollständige Architektur, Konventionen, Checkliste |
| [tools/ollama/README.md](./tools/ollama/README.md) | Ollama: GPU, Modelle, Zugriff |
| [tools/wireguard-client/README.md](./tools/wireguard-client/README.md) | WireGuard: nativ vs. Docker |
| [tools/authelia/README.md](./tools/authelia/README.md) | Authelia: lokale Instanz |
| [staging/docker-stacks/n8n/README.md](./staging/docker-stacks/n8n/README.md) | n8n + Postgres |
| [staging/docker-stacks/open-webui/README.md](./staging/docker-stacks/open-webui/README.md) | Open WebUI |
