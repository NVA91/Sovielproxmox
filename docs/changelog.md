# Changelog — Kurz-Doku aller Änderungen

> Format: Datum · Was · Getestet · Offen
> Kein Roman — nur das Wesentliche. Ziel: in 6 Monaten noch nachvollziehbar.

---

## 2026-02

### 2026-02-22 — Repo-Grundgerüst erstellt

```
Was:      Repo-Struktur angelegt: CLAUDE.md, staging/, tools/, docs/
          Ollama, WireGuard-Client, n8n, Open WebUI, Authelia als Compose-Vorlagen
          Hardware-Dokumentation: infrastructure.md, hardware-security.md
Getestet: Nur Datei-Ebene (kein Live-Deployment) — Repo ist Vorlage, nicht aktiv
Offen:    - WireGuard: nativ oder dockerisiert? (noch nicht entschieden)
          - IOMMU / AMD-Vi auf K1X noch nicht verifiziert
          - LUKS auf Host-Disk noch nicht bestätigt
          - NVIDIA Container Toolkit auf VM noch nicht getestet
```

---

### 2026-02-22 — Arbeitsweise + Simulator-Workflow verankert

```
Was:      6-Schritt-Workflow in CLAUDE.md (Planen→Testen→Verifizieren→Deployen→Altlasten→Doku)
          Proxmox-Test-Controller-Simulator als Pflicht-Teststufe eingetragen (Repo-Link TODO)
          GEFAHR-Sektion: iGPU/eGPU-Verwechslung, OCuLink, falscher NVMe-Passthrough
          SUPER-NXXX korrigiert: SFTP+Passkey, kein WireGuard, isolierter Bereich
          Übergabeprotokoll erstellt: docs/next-session.md
Getestet: Nur Dokumentation — kein Live-Deployment
Offen:    Simulator-Repo-URL eintragen, Hardware-Checkliste K1X abarbeiten
```

---

<!-- Neue Einträge oben einfügen — neueste zuerst -->

<!-- Vorlage:
### YYYY-MM-DD — [Kurztitel]

```
Was:
Getestet:
Offen:
```
-->
