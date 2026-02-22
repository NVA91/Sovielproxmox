# Hardware-Sicherheit — Checkliste & Konventionen

> **Grundsatz:** Single-User-System — Sicherheit geht vor Komfort.
> Hardware-Sicherheit ist die Basis. Software-Sicherheit (Docker, WireGuard, Authelia)
> baut darauf auf — aber kann eine unsichere Hardware-Basis nicht kompensieren.

---

## Sicherheits-Ebenen (von unten nach oben)

```
┌─────────────────────────────────────────────┐
│  5. Anwendungsebene   (Docker, n8n, Ollama)  │  ← am wenigsten kritisch
├─────────────────────────────────────────────┤
│  4. Netzwerkebene     (WireGuard, Firewall)  │
├─────────────────────────────────────────────┤
│  3. OS-Ebene          (Proxmox VE, SSH)      │
├─────────────────────────────────────────────┤
│  2. Firmware-Ebene    (BIOS/UEFI, Secure Boot│
├─────────────────────────────────────────────┤
│  1. Physische Ebene   (Zugang, Gehäuse)      │  ← wichtigste Ebene
└─────────────────────────────────────────────┘
```

---

## Checkliste: Physische Sicherheit

- [ ] Server steht in einem physisch gesicherten Bereich (verschlossener Raum / Rack)
- [ ] Keine Tastatur/Monitor dauerhaft angeschlossen (headless Betrieb)
- [ ] Nicht verwendete USB-Ports im BIOS deaktiviert oder physisch blockiert
- [ ] Gehäuse-Seitenblech mit Schloss gesichert (falls Tamper-Schutz gewünscht)
- [ ] Keine externe Speichermedien angeschlossen, die nicht explizit gebraucht werden

---

## Checkliste: BIOS / UEFI

- [ ] **BIOS/UEFI-Passwort gesetzt** — verhindert Boot-Reihenfolge-Änderung und Setup-Zugriff
- [ ] **Boot-Reihenfolge gesperrt** — nur von internem Laufwerk booten, kein USB-Boot
- [ ] **Secure Boot** aktiviert (oder bewusst deaktiviert + Begründung dokumentiert)
      > Proxmox 8.x unterstützt Secure Boot — bei Custom-Kernel ggf. deaktiviert
- [ ] **Intel VT-d / AMD-Vi (IOMMU) aktiviert** — Pflicht für PCIe-Passthrough-Isolation der GPU
      ```bash
      # Prüfen ob IOMMU aktiv ist (auf Proxmox-Host):
      dmesg | grep -e DMAR -e IOMMU | head -10

      # IOMMU-Gruppen anzeigen (GPU muss in eigener Gruppe sein!):
      for d in /sys/kernel/iommu_groups/*/devices/*; do
        n=${d#*/iommu_groups/*}; n=${n%%/*}
        printf 'IOMMU Group %s ' "$n"
        lspci -nns "${d##*/}"
      done
      ```
- [ ] **Wake-on-LAN deaktiviert** (falls nicht explizit gebraucht)
- [ ] **Intel ME / AMD PSP**: auf minimale Funktion reduzieren (falls Mainboard das erlaubt)

---

## Checkliste: Festplatte / Verschlüsselung

- [ ] **Proxmox-Host-Disk verschlüsselt (LUKS)**
      > Ohne Verschlüsselung: physischer Zugang = vollständiger Datenzugriff
      ```bash
      # Prüfen ob Root-Partition verschlüsselt ist:
      lsblk -o NAME,FSTYPE,MOUNTPOINT | grep crypt
      # oder:
      cryptsetup status /dev/mapper/pve-root 2>/dev/null
      ```
- [ ] **VM-Disks verschlüsselt** (Proxmox-Storage LUKS oder VM-internes LUKS)
- [ ] **LUKS-Key nicht auf dem selben System gespeichert** (TPM, USB-Key oder Passphrase)
- [ ] **Backup-Medien ebenfalls verschlüsselt** (borg/restic mit Passphrase, verschlüsselte USB-Disks)
- [ ] Keine Swap-Partition ohne Verschlüsselung (Swap kann Secrets aus RAM enthalten)
      ```bash
      # Verschlüsselter Swap in /etc/crypttab:
      # swap /dev/sdXY /dev/urandom swap,cipher=aes-xts-plain64,size=256
      ```

---

## Checkliste: Proxmox-Host Härtung

- [ ] **SSH-Root-Login deaktiviert**
      ```bash
      # /etc/ssh/sshd_config:
      PermitRootLogin no
      PasswordAuthentication no   # nur SSH-Keys erlauben
      # Danach: systemctl restart sshd
      ```
- [ ] **SSH nur auf WireGuard-Interface lauschen** (nicht auf öffentlicher IP)
      ```bash
      # /etc/ssh/sshd_config:
      ListenAddress 10.8.0.2    # nur WireGuard-IP
      ```
- [ ] **Proxmox Web-UI nicht direkt aus Internet erreichbar**
      - Entweder: firewall.rules blockiert Port 8006 von extern
      - Oder: Zugang nur via WireGuard-Tunnel
- [ ] **Proxmox-Firewall aktiviert** (Datacenter → Firewall → Enable)
      ```
      Empfohlene Regeln auf Host-Ebene:
      - IN: SSH (22) von WireGuard-IP (10.8.0.1) → ACCEPT
      - IN: WireGuard (51820/UDP) → ACCEPT (falls WG auf Host)
      - IN: Proxmox-UI (8006) von WireGuard-IP → ACCEPT
      - IN: alles andere → DROP
      ```
- [ ] **fail2ban installiert** für SSH-Brute-Force-Schutz
      ```bash
      apt install fail2ban
      # /etc/fail2ban/jail.local: [sshd] enabled = true
      ```
- [ ] **Proxmox-Updates regelmäßig einspielen**
      ```bash
      apt update && apt full-upgrade
      ```
- [ ] **Nicht verwendete Dienste / Pakete entfernt**
      ```bash
      systemctl disable --now postfix   # falls kein lokaler Mail-Versand nötig
      ```

---

## Checkliste: GPU / PCIe-Passthrough (RTX via OCuLink)

- [ ] **IOMMU-Isolation verifiziert**: GPU muss in eigener IOMMU-Gruppe liegen
      > Teilt die GPU eine Gruppe mit anderen Geräten, können diese auf GPU-Speicher zugreifen
- [ ] **VFIO-Treiber korrekt konfiguriert** (GPU nicht vom Host genutzt, nur von VM)
      ```bash
      # GPU darf auf Host NICHT mit nvidia-Treiber gebunden sein:
      lspci -k | grep -A3 -i nvidia
      # → "Kernel driver in use: vfio-pci" ist korrekt
      ```
- [ ] **ACS Override Patch**: nur aktivieren wenn IOMMU-Gruppierung es erfordert
      > ACS Override schwächt Isolation ab — nur als letztes Mittel
- [ ] **GPU-Reset-Bug**: Bei bestimmten NVIDIA-GPUs muss `vendor-reset` oder ein
      entsprechender Patch genutzt werden, sonst hängt die GPU nach VM-Neustart

---

## Checkliste: Netzwerk-Härtung (Hardware-nah)

- [ ] **Kein WiFi** auf dem Server (falls vorhanden: deaktivieren oder entfernen)
- [ ] **Nur ein Netzwerk-Interface aktiv** (kein ungenutztes NIC ohne Firewall)
- [ ] **Managed Switch** zwischen Internet-Router und Server (VLAN-Isolation möglich)
- [ ] **Internet-Router**: UPnP deaktiviert, keine Port-Weiterleitungen außer WireGuard (UDP 51820) auf VPS
      > Dieser Server hat keine öffentliche IP → auf VM-Seite keine Ports offen

---

## Referenzen

- [Proxmox VE Security Guide](https://pve.proxmox.com/wiki/Security)
- [Proxmox IOMMU/PCIe Passthrough](https://pve.proxmox.com/wiki/PCI_Passthrough)
- [LUKS Encryption](https://wiki.archlinux.org/title/dm-crypt/Encrypting_an_entire_system)
- [CIS Benchmarks Linux](https://www.cisecurity.org/cis-benchmarks/) (kostenlos registrieren)
