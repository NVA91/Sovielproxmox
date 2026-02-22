# Sovielproxmox

Configuration and setup scripts for a Proxmox VE host with an NVIDIA RTX 5060 Ti connected as an eGPU via OCuLink, passed through to an Ubuntu Server VM.

## Hardware

| Component | Details |
|-----------|---------|
| Hypervisor | Proxmox VE (latest) |
| eGPU | NVIDIA GeForce RTX 5060 Ti |
| Connection | OCuLink (PCIe x4) |
| VM OS | Ubuntu Server 24.04 LTS |

## Repository Layout

```
proxmox/
  setup-iommu.sh       # Run once on the Proxmox host to enable IOMMU/VFIO
  vm-config/
    ubuntu-egpu.conf   # Proxmox VM configuration for Ubuntu Server + GPU passthrough
ubuntu-vm/
  setup-gpu.sh         # Run inside the Ubuntu Server VM to install NVIDIA drivers
```

## Quick Start

### 1. Proxmox Host – Enable IOMMU and VFIO

> Run as root on the Proxmox host **before** creating the VM.

```bash
bash proxmox/setup-iommu.sh
```

The script will:
- Detect whether the host CPU is Intel or AMD and add the correct IOMMU kernel parameter
- Load the required `vfio` kernel modules at boot
- Blacklist the NVIDIA / Nouveau drivers on the host so the GPU is reserved for the VM
- Prompt you to confirm the detected PCI IDs of the RTX 5060 Ti before writing `/etc/modprobe.d/vfio.conf`
- Rebuild the initramfs and remind you to reboot

After rebooting, verify IOMMU is active:

```bash
dmesg | grep -e DMAR -e IOMMU
```

### 2. Create the Ubuntu Server VM

Import or apply the supplied Proxmox VM configuration:

```bash
cp proxmox/vm-config/ubuntu-egpu.conf /etc/pve/qemu-server/<VMID>.conf
```

Replace `<VMID>` with the VM ID you want to use (e.g. `100`).  
Adjust the `hostpci0` PCI address to match the actual address of your RTX 5060 Ti (find it with `lspci | grep -i nvidia`).

### 3. Ubuntu Server VM – Install NVIDIA Drivers

Boot the VM, then run:

```bash
bash ubuntu-vm/setup-gpu.sh
```

## Notes

- OCuLink is electrically standard PCIe x4, so no special host configuration is needed beyond normal VFIO passthrough.
- Use `iommu=pt` (pass-through mode) for best PCIe performance.
- The VM machine type must be `q35` and firmware must be `OVMF` (UEFI) for GPU passthrough to work reliably.
- If the GPU and its HDMI audio controller share an IOMMU group with other devices you need, you may have to pass through the entire group.