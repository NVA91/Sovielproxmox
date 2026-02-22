# CLAUDE.md — Homelab System Rules & Architecture

## Systemprofil

| Eigenschaft | Wert |
|-------------|------|
| **Nutzermodell** | Single-User — kein Mehrbenutzerbetrieb |
| **Sicherheitspriorität** | **Hardware-Sicherheit zuerst** → dann Netzwerk → dann Software |
| **Vertrauensmodell** | Zero-Trust nach außen; intern minimal Attack Surface |

> **Grundregel:** Sicherheit geht vor Komfort — besonders auf Hardware-Ebene.
> Kein Dienst, kein Port, kein Feature wird aktiviert, der nicht explizit gebraucht wird.

---

## Systemregeln für Claude

- **Hardware-Sicherheit hat Vorrang** — vor jeder Software-Änderung prüfen, ob die Hardware-Basis sicher ist (siehe `docs/hardware-security.md`)
- **Single-User-System** — keine Mehrbenutzer-Konfigurationen, kein Sharing, keine Gast-Accounts
- Alle Änderungen an produktiven Stacks **vorher** dokumentieren (Abschnitt „Stack-Übersicht" aktuell halten)
- Niemals echte Secrets in dieses Repo committen — immer `.env.example` mit Dummy-Werten
- Compose-Dateien enthalten **keine** `ports:`-Direktiven für interne Dienste — alle Dienste sind ausschließlich über den WireGuard-Tunnel und das interne `n8n_backend`-Netzwerk erreichbar
- GPU-Support ist explizit per `deploy.resources.reservations.devices` zu setzen — **niemals** `runtime: nvidia` (deprecated, nicht Compose-V3-konform)
- Netzwerk `n8n_backend` ist das gemeinsame Backend-Netzwerk für alle VM-Dienste; immer `external: true` setzen
- WireGuard-Keys und echte `.conf`-Dateien niemals committen — nur maskierte `.example`-Vorlagen ins Repo
- Startup-Reihenfolge beachten (siehe Abschnitt unten) — falsche Reihenfolge führt zu Netzwerkfehlern

---

## Aktuelle Architektur (Stand: 2026-02)

> Hardware-Übersicht aller Systeme: **`docs/infrastructure.md`**

### Überblick

```
Internet
  └─ VPS (öffentliche IP — EDGE-Seite)
       ├─ Traefik v3 (Reverse Proxy, TLS-Terminierung)
       ├─ Let's Encrypt (automatische Zertifikate)
       ├─ Authelia (SSO / 2FA)
       ├─ n8n-Stack         [aktiv auf VPS]
       ├─ OCR-Stack         [aktiv auf VPS]
       └─ WireGuard-Server → UDP 51820
               │   (verschlüsselter Tunnel)
               └─ K1X · VM (10.8.0.2 / wg0) — GPU-PROCESSING-Seite
                    │   Proxmox-Gast auf Mini-PC (AMD Ryzen 7 H255)
                    │   eGPU: RTX 5060 Ti 16GB via OCuLink
                    ├─ WireGuard-Client (nativ oder dockerisiert)
                    ├─ Ollama  [GPU, kein Port-Publish — aktiv]
                    ├─ Open WebUI  [geplant, kein Port-Publish]
                    ├─ n8n + Postgres  [geplant — Migration von VPS]
                    └─ Authelia lokal  [optional, geplant]
```

### Rollen-Trennung

| Komponente | System | Aktueller Status | Aufgabe |
|------------|--------|-----------------|---------|
| Traefik v3 | VPS | aktiv | TLS-Terminierung, Routing, Rate-Limiting |
| Authelia   | VPS | aktiv | SSO / 2FA für alle externen Zugriffe |
| WireGuard-Server | VPS | aktiv | Tunnel-Endpunkt, UDP 51820 |
| n8n + Postgres | VPS | aktiv | Workflow-Automation (aktuell auf VPS) |
| OCR-Stack | VPS | aktiv | Texterkennung (aktuell auf VPS) |
| WireGuard-Client | K1X · VM | aktiv | Tunnel aufbauen → VPS |
| Ollama | K1X · VM | aktiv | LLM-Inferenz · RTX 5060 Ti via OCuLink |
| Open WebUI | K1X · VM | geplant | Web-Frontend → Ollama |
| n8n (Migration) | K1X · VM | geplant | n8n näher an Ollama (GPU-Zugriff) |

> **Wichtig:** K1X-VM hat **keine** öffentliche IP und publisht **keine** Ports nach außen.
> Alle Zugriffe laufen über den WireGuard-Tunnel zum VPS, der als einziger Ingress dient.

### Netzwerkpfade

| Quelle           | Ziel               | Protokoll       | Anmerkung                                      |
|------------------|--------------------|-----------------|-------------------------------------------------|
| Internet         | VPS:443            | HTTPS           | Traefik terminiert TLS                          |
| Internet         | VPS:51820          | WireGuard UDP   | Nur für WireGuard-Handshakes                    |
| VPS (Traefik)    | K1X-VM:wg0         | HTTP via Tunnel | Proxy-Pass zu internen Diensten auf der VM      |
| VPS n8n          | K1X-VM Ollama      | HTTP via Tunnel | n8n → Ollama für LLM-Calls (aktueller Pfad)    |
| K1X-VM-Container | Ollama             | HTTP intern     | Nur über `n8n_backend`-Netz (kein Publish)      |
| K1X-VM-Container | VPS/Internet       | HTTP via wg0    | Für Webhooks, API-Calls etc.                   |

### IP-Bereiche (Beispiel — in `.env` anpassen)

| Segment          | Netz / Adresse  | Anmerkung                          |
|------------------|-----------------|------------------------------------|
| WireGuard VPN    | 10.8.0.0/24     | Tunnel-Subnetz                     |
| VPS (wg0)        | 10.8.0.1/32     | Tunnel-Endpunkt VPS                |
| VM (wg0)         | 10.8.0.2/32     | Tunnel-Endpunkt VM                 |
| Docker n8n_backend | 172.20.0.0/16 | Internes Container-Netz auf der VM |

---

## Startup-Reihenfolge (zwingend einhalten)

Dienste haben Abhängigkeiten — **in dieser Reihenfolge starten**:

```
1. WireGuard-Client          → Tunnel muss stehen, bevor irgendwas nach außen kommuniziert
2. (Optional) Authelia lokal → falls VM-seitige Auth benötigt wird
3. Ollama                    → GPU-Dienst, Basis für Open WebUI und n8n
4. n8n + Postgres            → Postgres muss vor n8n bereit sein (depends_on in compose)
5. Open WebUI                → hängt von Ollama ab (OLLAMA_BASE_URL muss erreichbar sein)
```

**Stopp-Reihenfolge:** umgekehrt (zuerst UI, zuletzt WireGuard).

```bash
# Starten (Beispiel):
docker compose -f tools/wireguard-client/docker-compose.yml up -d
docker compose -f tools/ollama/docker-compose.yml up -d
docker compose -f staging/docker-stacks/n8n/docker-compose.yml up -d
docker compose -f staging/docker-stacks/open-webui/docker-compose.yml up -d
```

---

## GPU-Konvention (Pflicht)

Immer `deploy.resources.reservations.devices` verwenden — **niemals** `runtime: nvidia`:

```yaml
# RICHTIG:
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          count: all
          capabilities: [gpu]

# FALSCH (deprecated, nicht nutzen!):
# runtime: nvidia
```

Grund: `runtime: nvidia` ist nicht Compose-V3-kompatibel und funktioniert nicht mit
`docker compose` (nur mit dem alten `docker-compose` binary).

---

## Ports-Konvention (Pflicht)

**Keine `ports:`-Direktiven** in Compose-Dateien für VM-seitige Dienste.

```yaml
# RICHTIG — Dienst nur intern erreichbar:
services:
  ollama:
    image: ollama/ollama:latest
    networks:
      - backend
    # ports:  ← auskommentiert lassen!

# FALSCH — würde Port auf dem VM-Host binden:
# ports:
#   - "11434:11434"
```

Ausnahme: WireGuard-Server auf dem VPS (UDP 51820) — aber das liegt nicht in diesem Repo.

---

## Stack-Übersicht

| Verzeichnis                          | Dienst           | Status       | Abhängigkeit      |
|--------------------------------------|------------------|--------------|-------------------|
| `tools/wireguard-client/`            | WireGuard Client | aktiv/nativ  | —                 |
| `tools/ollama/`                      | Ollama LLM       | aktiv        | WireGuard, GPU    |
| `tools/authelia/`                    | Authelia lokal   | geplant      | —                 |
| `staging/docker-stacks/n8n/`         | n8n + Postgres   | geplant      | WireGuard         |
| `staging/docker-stacks/open-webui/`  | Open WebUI       | geplant      | Ollama            |

---

## Offene Punkte / Checkliste

### Priorität 1 — Hardware-Sicherheit (vor allem anderen!)

- [ ] BIOS/UEFI-Passwort gesetzt und Boot-Reihenfolge gesperrt?
- [ ] Secure Boot aktiv (oder bewusst deaktiviert + dokumentiert)?
- [ ] Proxmox-Host-Disk verschlüsselt (LUKS) oder physisch gesichert?
- [ ] IOMMU (VT-d / AMD-Vi) im BIOS aktiviert? → Pflicht für PCIe-Passthrough-Isolation
      ```bash
      # Prüfen auf Proxmox-Host:
      dmesg | grep -e DMAR -e IOMMU | head -5
      ```
- [ ] Kein SSH-Root-Login auf Proxmox-Host? (`PermitRootLogin no` in `/etc/ssh/sshd_config`)
- [ ] Proxmox-Web-UI nicht direkt aus Internet erreichbar (nur via VPN/WireGuard)?
- [ ] Firewall auf Proxmox-Host: alle Ports außer SSH + WireGuard gesperrt?
- [ ] Physischer Zugang zum Server gesichert (Rack / abgesperrter Raum)?

→ Vollständige Hardware-Sicherheits-Checkliste: **`docs/hardware-security.md`**

### Priorität 2 — Software / Docker

- [ ] Ist WireGuard auf der VM nativ (`/etc/wireguard/wg0.conf`) oder dockerisiert?
- [ ] NVIDIA Container Toolkit installiert und getestet?
      ```bash
      docker run --rm --gpus all nvidia/cuda:12.0-base-ubuntu22.04 nvidia-smi
      ```
- [ ] Gemeinsames Docker-Netzwerk `n8n_backend` erstellt?
      ```bash
      docker network create n8n_backend
      ```
- [ ] `.env`-Datei aus `.env.example` befüllt (alle Dummies ersetzt)?
- [ ] Traefik-Routing auf dem VPS für die VM-Tunnel-IP konfiguriert?
- [ ] Startup-Reihenfolge getestet und dokumentiert (nativ oder Systemd-Units)?

---

## Konventionen

- **Volumes:** Named Volumes bevorzugen — kein Bind-Mount in `/root/` oder Homedir
- **Restart-Policy:** `unless-stopped` für alle Produktiv-Dienste
- **Logging:** kein explizites `logging:`-Limit in Compose → Systemd-Journal oder `docker logs`
- **Images:** immer explizite Tags nutzen (kein implizites `:latest` in Produktion)
- **Updates:** `tools/helper-scripts/update.sh` nutzen
- **Backup:** `tools/helper-scripts/backup.sh` vor größeren Änderungen ausführen
- **GPU-Test:** `tools/helper-scripts/gpu-check.sh` nach Kernel-Updates ausführen
