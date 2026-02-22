# Hardware-Infrastruktur — Grundkarte

> **Zweck dieser Datei:** Übersicht was existiert, wo es steht und welche Rolle es hat.
> Keine Treiber, keine Konfiguration, keine Netzwerk-Details — nur die Hardware-Basis.
> Details: `docs/hardware-security.md` (Sicherheit), `CLAUDE.md` (Software-Architektur).

---

## Systemübersicht

```
┌─────────────────────────────────────────────────────────────┐
│  K1X          Mini-PC / Proxmox-Host           [Keller]     │
│               AMD Ryzen 7 H255 · 32 GB DDR5                 │
│               3× NVMe SSD (5 TB gesamt)                     │
│               OCuLink → eGPU RTX 5060 Ti 16GB               │
└───────────────────────┬─────────────────────────────────────┘
                        │ WireGuard-Tunnel (verschlüsselt)
                        │
┌───────────────────────▼─────────────────────────────────────┐
│  VPS          Ubuntu Server / Docker-Host   [Rechenzentrum] │
│               4 vCPU AMD EPYC · 32 GB RAM · 200 GB SSD      │
│               Traefik · n8n · OCR · Reverse Proxy           │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  XMG          Hauptrechner / Workstation    [Arbeitsplatz]  │
│               NVIDIA RTX 3080 (intern)                      │
│               Eigenständig — kein Tunnel, keine eGPU        │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  SUPER-NXXX   Smartphone / Mobiles Endgerät  [Mobil]       │
│               Zugriff / Monitoring / Steuerung              │
└─────────────────────────────────────────────────────────────┘
```

---

## K1X — Proxmox-Server

**Standort:** Keller
**Typ:** Mini-PC (Virtualisierungshost)
**Zweck:** Zentrale Infrastruktur, VM-Host, eGPU-Anbindung für GPU-Workloads

### Prozessor & Arbeitsspeicher

| Komponente | Details |
|------------|---------|
| CPU | AMD Ryzen 7 H255 (ohne NPU) |
| iGPU | AMD Radeon 780M (Host-Anzeige / Proxmox-Console) |
| RAM | 32 GB DDR5 5600 MT/s |

### Speicher (3× NVMe M.2 SSD — gesamt 5 TB physisch)

| Nr. | Modell | Kapazität | Verwendung |
|-----|--------|-----------|------------|
| SSD 1 | WD Black NVMe PCIe 4.0 | 2 TB | 1 TB → Proxmox-System · 1 TB → VM-Bereich |
| SSD 2 | — | 2 TB | Storage: Daten / ISOs / Container |
| SSD 3 | — | 1 TB | Storage: 4 Partitionen |

### Konnektivität

| Schnittstelle | Details | Sicherheitshinweis |
|---------------|---------|-------------------|
| LAN 1 | 2,5 GbE (Realtek 8125BG) | Primäres Netzwerk-Interface |
| LAN 2 | 2,5 GbE (Realtek 8125BG) | Reserve / VLAN-Isolation möglich |
| Wi-Fi | Wi-Fi 6E | **Im Server-Betrieb deaktivieren** (→ `docs/hardware-security.md`) |
| Bluetooth | Bluetooth 5.2 | **Im Server-Betrieb deaktivieren** |

### eGPU-Anbindung (OCuLink)

| Komponente | Details |
|------------|---------|
| OCuLink-Port | PCIe Gen 4 × 4 (direkte PCIe-Verbindung, kein USB) |
| eGPU-Dock | Minisforum DEG1 |
| eGPU | **NVIDIA RTX 5060 Ti 16 GB** |
| Verbindungstyp | Vollständiges PCIe-Passthrough möglich (kein Thunderbolt-Overhead) |

> **Wichtig für IOMMU:** OCuLink ist eine direkte PCIe-Verbindung.
> Die GPU erscheint dem Prozessor wie eine eingesteckte PCIe-Karte → IOMMU-Gruppe prüfen.
> Details: `docs/hardware-security.md` → Abschnitt GPU/PCIe.

### Aktuelle VM-Belegung (Proxmox-Gäste)

| VM | Zweck | GPU |
|----|-------|-----|
| VM (wg0: 10.8.0.2) | WireGuard-Client + Ollama + zukünftige Dienste | RTX 5060 Ti (Passthrough) |
| *(weitere VMs nach Bedarf)* | | |

---

## VPS — Ubuntu Server

**Standort:** Externes Rechenzentrum (Cloud)
**Typ:** Virtueller Server
**Zweck:** Internet-Dienste, Docker-Host, zentrale externe Schnittstelle

### Hardware-Zuweisung (Cloud)

| Komponente | Details |
|------------|---------|
| vCPU | 4 Kerne (AMD EPYC) |
| RAM | 32 GB |
| SSD | 200 GB |
| Netzwerk | Öffentliche IP (einziger Ingress-Punkt) |

### Aktuell laufende Dienste

| Dienst | Rolle |
|--------|-------|
| Traefik v3 | Reverse Proxy, TLS-Terminierung, Let's Encrypt |
| Authelia | SSO / 2FA für alle externen Zugriffe |
| WireGuard-Server | Tunnel-Endpunkt → K1X (UDP 51820) |
| n8n-Stack | Workflow-Automation (aktuell auf VPS) |
| OCR-Stack | OCR-Dienst (aktuell auf VPS) |

> **Hinweis:** n8n und OCR laufen aktuell auf dem VPS. Eine Migration auf die K1X-VM
> (näher an Ollama) ist in `staging/docker-stacks/n8n/` vorbereitet, aber noch nicht aktiv.

---

## XMG — Hauptrechner

**Standort:** Arbeitsplatz / Workstation
**Typ:** Laptop / Desktop-Ersatz
**Zweck:** Primärer Arbeitsrechner

| Komponente | Details |
|------------|---------|
| GPU (intern) | NVIDIA RTX 3080 |
| Rolle | Eigenständiges System |
| eGPU | **Keine** — RTX 3080 ist intern fest verbaut |
| Tunnel | Kein WireGuard-Client in diesem Setup |

> XMG ist unabhängig vom Homelab-Stack. Kein Passthrough, kein Tunnel, kein Sharing.

---

## SUPER-NXXX — Mobiles Endgerät

**Standort:** Mobil
**Typ:** Smartphone
**Zweck:** Fernzugriff, Monitoring, Steuerung

| Verwendung | Details |
|------------|---------|
| Zugriff auf Homelab | Via WireGuard-App (Tunnel zum VPS) |
| Monitoring | Proxmox-App oder Webinterface via Tunnel |
| Steuerung | n8n-Webhooks, Open WebUI (geplant) |

---

## Abhängigkeiten zwischen Systemen

```
SUPER-NXXX ──WireGuard──► VPS ──Tunnel──► K1X-VM
                           │
                     Traefik/Authelia
                     n8n / OCR
                     WireGuard-Server
```

| Verbindung | Protokoll | Anmerkung |
|------------|-----------|-----------|
| SUPER-NXXX → VPS | WireGuard UDP | Mobiler Zugriff auf alle Dienste |
| XMG → VPS | HTTPS / WireGuard | Arbeitsplatz-Zugriff |
| VPS ↔ K1X-VM | WireGuard UDP | Verschlüsselter Tunnel (10.8.0.0/24) |
| K1X-VM intern | Docker `n8n_backend` | Ollama ↔ zukünftige Dienste |
