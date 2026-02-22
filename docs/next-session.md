# Nächste Session — Übergabeprotokoll

```
Erstellt:  2026-02-22
Session:   Repo-Grundgerüst + Dokumentation (komplett)
Status:    Repo fertig, kein Live-Deployment — alles Vorbereitung
```

---

## Was diese Session erledigt wurde

- Repo-Struktur angelegt (`tools/`, `staging/`, `docs/`)
- Alle Docker-Compose-Vorlagen: Ollama, WireGuard-Client, n8n, Open WebUI, Authelia
- Dokumentation: `CLAUDE.md`, `README.md`, `docs/infrastructure.md`,
  `docs/hardware-security.md`, `docs/changelog.md`
- Arbeitsweise festgelegt: 6-Schritt-Workflow, Proxmox-Simulator als Pflicht-Teststufe
- Hardware korrekt dokumentiert: K1X (AMD Ryzen H255, RTX 5060 Ti via OCuLink),
  VPS, XMG, SUPER-NXXX (SFTP+Passkey, kein WireGuard)
- GEFAHR-Sektion: iGPU/eGPU-Verwechslung, falscher NVMe-Passthrough, OCuLink-Risiken

---

## Nächste Schritte (priorisiert)

### Schritt 1 — Simulator-Repo verlinken (5 Min, nur Doku)

```
Datei:  CLAUDE.md → Abschnitt "Proxmox-Test-Controller"
Aktion: Platzhalter ersetzen:
        NVA91/TODO_REPO_NAME_HIER_EINTRAGEN
        → echten Repo-Namen eintragen
```

---

### Schritt 2 — Hardware-Checkliste K1X abarbeiten (vor allem anderen!)

Reihenfolge einhalten — erst wenn diese Punkte grün sind, weiter mit Schritt 3:

- [ ] **BIOS-Passwort** gesetzt, Boot-Reihenfolge gesperrt
- [ ] **AMD-Vi (IOMMU)** im BIOS aktiviert → prüfen:
      `dmesg | grep -e AMD-Vi -e IOMMU`
- [ ] **Wi-Fi 6E + Bluetooth** im BIOS deaktiviert (Server braucht das nicht)
- [ ] **SSH** nur auf WireGuard-IP, Root-Login deaktiviert
- [ ] **Proxmox-Web-UI** nicht direkt erreichbar (nur via Tunnel)
- [ ] **LUKS** auf SSD1 (System) vorhanden?
      `lsblk -o NAME,FSTYPE,MOUNTPOINT | grep crypt`

Vollständige Checkliste: `docs/hardware-security.md`

---

### Schritt 3 — WireGuard entscheiden + einrichten

```
Entscheidung nötig: Nativ (/etc/wireguard/wg0.conf) oder dockerisiert?
→ Empfehlung: nativ (stabiler, weniger Overhead)

Danach testen:
  wg show
  ping 10.8.0.1   # VPS-Tunnel-IP muss antworten
```

Vorlage: `tools/wireguard-client/wg0.conf.example`

---

### Schritt 4 — Docker-Umgebung auf K1X-VM vorbereiten

```bash
# Docker-Netzwerk erstellen (einmalig):
docker network create n8n_backend

# NVIDIA Container Toolkit testen:
docker run --rm --gpus all nvidia/cuda:12.0-base-ubuntu22.04 nvidia-smi
# → muss RTX 5060 Ti anzeigen

# Hilfsskript:
bash tools/helper-scripts/gpu-check.sh
```

---

### Schritt 5 — Ollama starten + GPU verifizieren

```bash
# Erst: docker compose config prüfen (kein Live-Start ohne Check!)
docker compose -f tools/ollama/docker-compose.yml config

# Dann starten:
docker compose -f tools/ollama/docker-compose.yml up -d

# GPU-Nutzung prüfen:
docker exec ollama nvidia-smi

# Erstes Modell laden:
docker exec -it ollama ollama pull llama3.2
```

---

### Schritt 6 — Open WebUI (nach Ollama)

```bash
# Erst Ollama läuft → dann:
docker compose -f staging/docker-stacks/open-webui/docker-compose.yml up -d
docker logs -f open-webui
```

---

### Schritt 7 — n8n Migration planen (spätere Session)

```
Aktuell: n8n läuft auf VPS
Ziel:    n8n auf K1X-VM (näher an Ollama, GPU-Zugriff)
Vorbereitung: staging/docker-stacks/n8n/docker-compose.yml liegt bereit
Voraussetzung: Schritte 1-6 abgeschlossen, Tunnel stabil
```

---

## Offene Fragen für nächste Session

| Frage | Warum wichtig |
|-------|--------------|
| LUKS auf K1X SSD1 vorhanden oder nachzurüsten? | Datenschutz bei physischem Zugriff |
| WireGuard nativ oder Docker? | Entscheidung vor Schritt 3 |
| Proxmox-Simulator Repo-Name? | Platzhalter in CLAUDE.md ersetzen |
| GPU-Reset-Bug RTX 5060 Ti bekannt? | vendor-reset ggf. nötig nach VM-Neustart |
| n8n-Migration: wann? | Abhängig von K1X-Stabilität |

---

## Wichtige Dateien für den Einstieg

| Datei | Wann lesen |
|-------|-----------|
| `docs/hardware-security.md` | **Zuerst** — vor jedem Schritt |
| `CLAUDE.md` | Workflow, Konventionen, Architektur |
| `docs/infrastructure.md` | Hardware-Überblick K1X / VPS |
| `docs/changelog.md` | Was wann gemacht wurde |
