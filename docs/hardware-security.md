# Hardware-Sicherheit — Checkliste & Konventionen

> **Grundsatz:** Single-User-System — Sicherheit geht vor Komfort.
> Hardware-Sicherheit ist die Basis. Software-Sicherheit (Docker, WireGuard, Authelia)
> baut darauf auf — aber kann eine unsichere Hardware-Basis nicht kompensieren.
>
> Hardware-Referenz: `docs/infrastructure.md`

---

## GEFAHR — Falsche Zuweisung kann Hardware beschädigen

> Dieses System hat bekannte Risiken durch falsche PCIe / IOMMU / Passthrough-Konfigurationen.
> Folgende Fehler können zu dauerhaften Hardwareschäden führen — **vor jeder Änderung lesen.**

### K1X-spezifische Risiken

| Risiko | Was kann passieren | Bedingung |
|--------|--------------------|-----------|
| **OCuLink-Kabel trennen während VM läuft** | GPU-Absturz, Kernel-Panic, im schlimmsten Fall GPU-Schaden durch unterbrochene PCIe-Verbindung | Nie während Betrieb trennen |
| **Falsche IOMMU-Gruppe für GPU-Passthrough** | Andere Geräte im gleichen IOMMU-Kontext können GPU-Speicher lesen/schreiben — Datenverlust, Instabilität | Vor Passthrough Gruppen prüfen |
| **iGPU (Radeon 780M) und eGPU (RTX 5060 Ti) vertauscht** | Falsches Gerät an VM durchgereicht — Proxmox verliert Console-Zugriff, System nicht mehr administrierbar ohne Monitor | PCI-IDs vor Passthrough doppelt prüfen |
| **ACS Override aktiviert ohne Verständnis** | Schwächt IOMMU-Isolation aller PCIe-Geräte — nicht nur GPU betroffen | Nur als letztes Mittel, dokumentieren |
| **Gleichzeitiger Zugriff Host + VM auf GPU** | GPU-Treiber-Konflikt — GPU kann in einen defekten Zustand gebracht werden | Auf Host darf kein nvidia-Treiber geladen sein wenn GPU an VM durchgereicht |
| **NVMe-Passthrough: falsches Laufwerk** | Proxmox-System-SSD (SSD1) an VM gegeben → Host bootet nicht mehr | SSD-Slot/PCI-ID verifizieren, niemals SSD1 durchreichen |
| **GPU-Reset-Bug (NVIDIA):** VM hard-stoppen ohne Reset | GPU hängt nach VM-Neustart — erfordert Proxmox-Host-Reboot | vendor-reset oder ordentlichen VM-Shutdown nutzen |

### Pflicht-Checks vor jeder Passthrough-Konfiguration

```bash
# 1. Welche PCI-IDs hat die eGPU (RTX 5060 Ti)?
lspci | grep -i nvidia
# Beispielausgabe: 01:00.0 VGA ... RTX 5060
# → Diese ID merken — NUR diese an VM durchreichen

# 2. Welche PCI-ID hat die iGPU (Radeon 780M)?
lspci | grep -i "VGA\|Display\|Radeon"
# → Diese ID NIEMALS an eine VM durchreichen (Proxmox braucht sie für die Console)

# 3. IOMMU-Gruppe der RTX prüfen — ist sie alleine?
for d in /sys/kernel/iommu_groups/*/devices/*; do
  n=${d#*/iommu_groups/*}; n=${n%%/*}
  printf 'Group %s: ' "$n"; lspci -nns "${d##*/}"
done | grep -i nvidia
# → RTX soll in einer Gruppe sein die NUR die GPU (und ggf. HDMI-Audio) enthält

# 4. Auf Host ist KEIN nvidia-Treiber geladen?
lsmod | grep nvidia   # → muss leer sein vor Passthrough
lspci -k | grep -A2 -i nvidia | grep "Kernel driver"
# → "vfio-pci" ist korrekt, "nvidia" ist FALSCH
```

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

Gilt für: **K1X** (Proxmox-Host im Keller) — die einzige physische Hardware im Homelab.
VPS ist Cloud → physische Sicherheit liegt beim Rechenzentrum.

---

## Checkliste: Physische Sicherheit (K1X — Keller)

- [ ] Server steht in einem physisch gesicherten Bereich (Keller abgeschlossen)
- [ ] Keine Tastatur/Monitor dauerhaft angeschlossen (headless Betrieb)
- [ ] Nicht verwendete USB-Ports im BIOS deaktiviert oder physisch blockiert
      > K1X hat mehrere USB-A/C Ports — im BIOS auf das Minimum reduzieren
- [ ] Keine externen Speichermedien dauerhaft angeschlossen
- [ ] OCuLink-Kabel zum eGPU-Dock (DEG1) physisch gegen versehentliches Trennen gesichert
      > Verbindungsabbruch während GPU-Passthrough kann VM destabilisieren

---

## Checkliste: BIOS / UEFI (K1X — AMD Ryzen 7 H255)

- [ ] **BIOS/UEFI-Passwort gesetzt** — verhindert Boot-Reihenfolge-Änderung und Setup-Zugriff
- [ ] **Boot-Reihenfolge gesperrt** — nur von internem NVMe booten, kein USB-Boot
- [ ] **Secure Boot** aktiviert (oder bewusst deaktiviert + Begründung dokumentiert)
      > Proxmox 8.x unterstützt Secure Boot mit signiertem Kernel
      > Bei Custom-Kernel oder VFIO-Patches ggf. deaktiviert — dann dokumentieren
- [ ] **AMD-Vi (IOMMU) aktiviert** — Pflicht für PCIe-Passthrough-Isolation der RTX 5060 Ti
      ```bash
      # Prüfen ob AMD-Vi aktiv ist (auf Proxmox-Host):
      dmesg | grep -e AMD-Vi -e IOMMU | head -10

      # Erwartete Ausgabe:
      # AMD-Vi: AMD IOMMUv2 loaded and initialized
      # iommu: Default domain type: Translated

      # IOMMU-Gruppen anzeigen (RTX muss in eigener Gruppe sein!):
      for d in /sys/kernel/iommu_groups/*/devices/*; do
        n=${d#*/iommu_groups/*}; n=${n%%/*}
        printf 'IOMMU Group %s ' "$n"
        lspci -nns "${d##*/}"
      done | grep -i nvidia
      ```
- [ ] **AMD PSP (Platform Security Processor)** auf minimale Funktion (falls BIOS das erlaubt)
- [ ] **Wake-on-LAN deaktiviert** (falls kein Remote-Power-On nötig)
- [ ] **Wi-Fi 6E und Bluetooth 5.2 im BIOS deaktiviert**
      > K1X hat Wi-Fi 6E + BT 5.2 verbaut — auf einem Server nicht nötig und ein Angriffsvektor
      > Deaktivierung im BIOS bevorzugen; alternativ Treiber-Blacklist (schwächer)
      ```bash
      # Prüfen ob WLAN-Treiber geladen ist (sollte leer sein):
      lsmod | grep -i mt7921   # oder: iwlwifi, ath11k je nach Chip
      # WLAN-Interface sollte nicht auftauchen:
      ip link | grep wl
      ```

---

## Checkliste: Festplatte / Verschlüsselung (K1X — 3× NVMe)

> K1X hat 3 NVMe SSDs: SSD1 (System + VM), SSD2 (Storage), SSD3 (Storage/4 Partitionen)

- [ ] **SSD1: Proxmox-System-Partition verschlüsselt (LUKS)**
      > Ohne Verschlüsselung: physischer Zugang = vollständiger Datenzugriff auf alle VMs
      ```bash
      # Prüfen ob Root-Partition verschlüsselt ist:
      lsblk -o NAME,FSTYPE,MOUNTPOINT | grep crypt
      # oder:
      cryptsetup status /dev/mapper/pve-root 2>/dev/null
      ```
- [ ] **SSD2 + SSD3: Storage-Partitionen verschlüsselt** (LUKS auf LVM oder ZFS native encryption)
- [ ] **VM-Disks verschlüsselt** — entweder via Proxmox-LUKS-Storage oder VM-internes LUKS
- [ ] **LUKS-Key-Management**: Key nicht auf demselben System gespeichert
      - Option A: Passphrase (manuell bei jedem Boot eingeben)
      - Option B: USB-Stick als Schlüsselträger (physisch sichern!)
      - Option C: TPM 2.0 (prüfen ob K1X ein TPM hat — `ls /dev/tpm*`)
- [ ] **Swap verschlüsselt** (Swap kann Secrets, Passwörter und GPU-Daten aus RAM enthalten)
      ```bash
      # /etc/crypttab — verschlüsselter Swap mit Zufallskey:
      # swap /dev/nvme0n1pX /dev/urandom swap,cipher=aes-xts-plain64,size=256
      ```
- [ ] **Backup-Medien verschlüsselt** (borg/restic mit Passphrase)

---

## Checkliste: Proxmox-Host Härtung (K1X)

- [ ] **SSH-Root-Login deaktiviert**
      ```bash
      # /etc/ssh/sshd_config:
      PermitRootLogin no
      PasswordAuthentication no   # nur SSH-Keys erlauben
      PubkeyAuthentication yes
      # Danach: systemctl restart sshd
      ```
- [ ] **SSH nur auf WireGuard-Interface lauschen** (nicht auf LAN-IP)
      ```bash
      # /etc/ssh/sshd_config:
      ListenAddress 10.8.0.2    # nur WireGuard-Tunnel-IP
      # → SSH nur erreichbar wenn Tunnel steht
      ```
- [ ] **Proxmox Web-UI (Port 8006) nicht direkt aus LAN/Internet erreichbar**
      - Nur via WireGuard-Tunnel zugreifbar
- [ ] **Proxmox-Firewall aktiviert** (Datacenter → Firewall → Enable)
      ```
      Empfohlene Regeln auf K1X Host-Ebene:
      - IN: SSH (22) von 10.8.0.1/32 (VPS via Tunnel) → ACCEPT
      - IN: Proxmox-UI (8006) von 10.8.0.1/32 → ACCEPT
      - IN: alles andere → DROP
      OUT: alles erlaubt (oder einschränken auf WireGuard + DNS)
      ```
- [ ] **fail2ban für SSH** (auch wenn SSH nur via Tunnel — Defense in depth)
      ```bash
      apt install fail2ban
      # /etc/fail2ban/jail.local:
      # [sshd]
      # enabled = true
      # maxretry = 3
      ```
- [ ] **Proxmox-Abonnement / Updates**: Community-Repo konfiguriert, Updates regelmäßig
      ```bash
      # Ohne Subscription (Community-Repo):
      # /etc/apt/sources.list.d/pve-enterprise.list → auskommentieren
      # /etc/apt/sources.list.d/pve-no-subscription.list → hinzufügen
      apt update && apt full-upgrade
      ```
- [ ] **Nicht verwendete Dienste deaktiviert**
      ```bash
      systemctl disable --now postfix     # kein lokaler Mail-Versand nötig
      # rpcbind, avahi-daemon prüfen: systemctl list-units --state=active
      ```
- [ ] **Realtek NICs (8125BG)**: beide LAN-Ports — nur das aktiv genutzte Interface hochfahren
      ```bash
      # Ungenutztes Interface deaktivieren:
      ip link set enp3s0 down             # Interface-Name anpassen
      # Dauerhaft: /etc/network/interfaces — ungenutztes Interface nicht konfigurieren
      ```

---

## Checkliste: GPU / PCIe-Passthrough (RTX 5060 Ti via OCuLink)

> OCuLink (Minisforum DEG1) = direkte PCIe Gen4 ×4 Verbindung.
> Die RTX 5060 Ti erscheint dem System wie eine eingesteckte PCIe-Karte.

- [ ] **AMD-Vi IOMMU aktiv** (siehe BIOS-Checkliste oben)
- [ ] **IOMMU-Isolation verifiziert**: RTX 5060 Ti muss in eigener IOMMU-Gruppe liegen
      > Teilt die GPU eine Gruppe mit anderen Geräten (z.B. USB-Controller),
      > können diese auf GPU-Speicher/DMA zugreifen — Sicherheitsrisiko
      ```bash
      # RTX IOMMU-Gruppe finden:
      for d in /sys/kernel/iommu_groups/*/devices/*; do
        n=${d#*/iommu_groups/*}; n=${n%%/*}
        printf 'Group %s: ' "$n"; lspci -nns "${d##*/}"
      done | grep -i nvidia
      # → GPU soll allein in ihrer Gruppe sein
      ```
- [ ] **VFIO-Treiber auf Host aktiv** (GPU nicht vom Proxmox-Host genutzt)
      ```bash
      lspci -k | grep -A3 -i "RTX\|NVIDIA"
      # Korrekt: "Kernel driver in use: vfio-pci"
      # Falsch:  "Kernel driver in use: nvidia" (Host würde GPU nutzen)
      ```
- [ ] **GRUB/Kernel-Parameter für AMD IOMMU gesetzt**
      ```bash
      # /etc/default/grub:
      GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt"
      # Danach: update-grub && reboot
      ```
- [ ] **VFIO-Module geladen**
      ```bash
      # /etc/modules:
      # vfio
      # vfio_iommu_type1
      # vfio_pci
      # vfio_virqfd
      lsmod | grep vfio
      ```
- [ ] **ACS Override**: nur aktivieren wenn IOMMU-Gruppierung es erfordert
      > ACS Override (`pcie_acs_override=downstream,multifunction`) schwächt die
      > IOMMU-Isolation ab — nur als letztes Mittel, nie für Production ohne Verständnis
- [ ] **GPU-Reset nach VM-Stopp prüfen**: Manche NVIDIA-GPUs hängen nach VM-Neustart
      ```bash
      # vendor-reset prüfen: https://github.com/gnif/vendor-reset
      # RTX 5060 Ti (Ada Lovelace) — Kompatibilität mit vendor-reset prüfen
      ```
- [ ] **OCuLink-Kabel nicht trennen während VM läuft** (kann zu Kernel-Panic führen)

---

## Checkliste: Netzwerk-Härtung (Hardware-nah, K1X)

- [ ] **Wi-Fi im BIOS deaktiviert** (K1X hat Wi-Fi 6E — auf Server nicht nötig!)
- [ ] **Bluetooth im BIOS deaktiviert** (K1X hat BT 5.2 — auf Server nicht nötig!)
- [ ] **Nur LAN 1 (2,5 GbE) aktiv** — LAN 2 nur bei VLAN-Bedarf
- [ ] **Managed Switch** zwischen Router und K1X (VLAN-Isolation Homelab-Traffic)
- [ ] **Router**: UPnP deaktiviert, keine Port-Weiterleitungen für K1X
      > K1X hat keine öffentliche IP — alle Dienste laufen über VPS+WireGuard

---

## Referenzen

- [Proxmox VE Security Guide](https://pve.proxmox.com/wiki/Security)
- [Proxmox PCI Passthrough (IOMMU)](https://pve.proxmox.com/wiki/PCI_Passthrough)
- [AMD IOMMU / AMD-Vi](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF#Setting_up_IOMMU)
- [LUKS / dm-crypt](https://wiki.archlinux.org/title/dm-crypt/Encrypting_an_entire_system)
- [VFIO-PCI Treiber](https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF)
- [vendor-reset (GPU-Reset-Bug)](https://github.com/gnif/vendor-reset)
