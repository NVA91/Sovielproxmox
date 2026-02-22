# CLAUDE.md — Homelab System Rules & Architecture

## Systemregeln für Claude

- Alle Änderungen an produktiven Stacks vorher dokumentieren
- Niemals echte Secrets in dieses Repo committen — immer `.env.example` mit Dummy-Werten
- Compose-Dateien enthalten **keine** `ports:`-Direktiven für interne Dienste (nur via Tunnel/Proxy erreichbar)
- GPU-Support ist explizit per `deploy.resources.reservations` zu setzen (nicht per `runtime: nvidia`)
- Netzwerk `n8n_backend` ist das gemeinsame Backend-Netzwerk; bei Bedarf `external: true` setzen
- WireGuard-Keys und -Configs niemals im Klartext committen — nur maskierte Vorlagen

---

## Aktuelle Architektur (Stand: 2026-02)

```
Internet
  └─ VPS (öffentliche IP)
       └─ Traefik v3 (Reverse Proxy)
            ├─ Let's Encrypt (TLS-Terminierung)
            ├─ Authelia (SSO / 2FA — auf VPS)
            └─ WireGuard-Tunnel → VM (10.x.x.x / wg0)
                    └─ Docker-Daemon auf VM
                         ├─ WireGuard-Client (nativ oder dockerisiert)
                         ├─ Ollama (--gpus all, kein Port-Publish)
                         └─ geplant: Open WebUI, n8n, lokale Authelia-Instanz, ...
```

### Netzwerkpfade

| Quelle           | Ziel              | Protokoll         | Anmerkung                          |
|------------------|-------------------|-------------------|------------------------------------|
| Internet         | VPS:80/443        | HTTPS             | Traefik terminiert TLS             |
| VPS              | VM (wg0)          | WireGuard UDP     | Tunnel, verschlüsselt              |
| VM-Container     | Ollama            | HTTP intern       | Nur über `n8n_backend`-Netz        |
| VM-Container     | VPS-Traefik       | HTTP via Tunnel   | Labels nur auf VPS-Traefik-Seite   |

### IP-Bereiche (Beispiel — anpassen!)

| Segment        | Netz            |
|----------------|-----------------|
| WireGuard VPN  | 10.8.0.0/24     |
| Docker backend | 172.20.0.0/16   |
| VM-Host (wg0)  | 10.8.0.2/32     |
| VPS-Host (wg0) | 10.8.0.1/32     |

---

## Stack-Übersicht

| Verzeichnis                        | Dienst            | Status       |
|------------------------------------|-------------------|--------------|
| `tools/ollama/`                    | Ollama LLM        | aktiv        |
| `tools/wireguard-client/`          | WireGuard Client  | aktiv/nativ  |
| `tools/authelia/`                  | Authelia lokal    | geplant      |
| `staging/docker-stacks/open-webui` | Open WebUI        | geplant      |
| `staging/docker-stacks/n8n/`       | n8n Automation    | geplant      |

---

## Offene Punkte / Checkliste

- [ ] Ist WireGuard auf der VM nativ oder dockerisiert?
- [ ] NVIDIA Container Toolkit installiert und getestet?
      ```bash
      docker run --rm --gpus all nvidia/cuda:12.0-base-ubuntu22.04 nvidia-smi
      ```
- [ ] Gemeinsames Docker-Netzwerk `n8n_backend` erstellt?
      ```bash
      docker network create n8n_backend
      ```
- [ ] `.env`-Datei auf der VM aus `.env.example` befüllt?
- [ ] Traefik-Labels-Strategie für VM-Dienste festgelegt (via VPS-Traefik)?

---

## Konventionen

- **Volumes:** Named Volumes bevorzugen (kein Bind-Mount in `/root/`)
- **Restart-Policy:** `unless-stopped` für alle Produktiv-Dienste
- **Logging:** kein explizites Logging-Limit → Systemd-Journal oder `docker logs`
- **Updates:** `tools/helper-scripts/update.sh` nutzen
- **Backup:** `tools/helper-scripts/backup.sh` vor größeren Änderungen ausführen
