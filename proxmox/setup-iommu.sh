#!/usr/bin/env bash
# setup-iommu.sh
# Configures the Proxmox VE host for PCIe passthrough of the NVIDIA RTX 5060 Ti
# connected via OCuLink. Run as root on the Proxmox host, then reboot.

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: This script must be run as root." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 1. Detect CPU vendor and set the correct IOMMU kernel parameter
# ---------------------------------------------------------------------------
if grep -q "GenuineIntel" /proc/cpuinfo; then
  IOMMU_PARAM="intel_iommu=on iommu=pt"
elif grep -q "AuthenticAMD" /proc/cpuinfo; then
  IOMMU_PARAM="amd_iommu=on iommu=pt"
else
  echo "ERROR: Unknown CPU vendor. Set the IOMMU parameter manually." >&2
  exit 1
fi

echo "Detected IOMMU parameter: $IOMMU_PARAM"

# Append to GRUB_CMDLINE_LINUX_DEFAULT if not already present
GRUB_FILE="/etc/default/grub"
if ! grep -q "iommu" "$GRUB_FILE"; then
  sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"$IOMMU_PARAM /" "$GRUB_FILE"
  echo "Updated $GRUB_FILE with IOMMU parameters."
else
  echo "$GRUB_FILE already contains an IOMMU parameter – skipping modification."
fi

update-grub

# ---------------------------------------------------------------------------
# 2. Load VFIO modules at boot
# ---------------------------------------------------------------------------
MODULES_FILE="/etc/modules"
for mod in vfio vfio_iommu_type1 vfio_pci; do
  if ! grep -qx "$mod" "$MODULES_FILE"; then
    echo "$mod" >> "$MODULES_FILE"
    echo "Added $mod to $MODULES_FILE"
  fi
done

# ---------------------------------------------------------------------------
# 3. Blacklist NVIDIA and Nouveau drivers on the host
# ---------------------------------------------------------------------------
BLACKLIST_FILE="/etc/modprobe.d/blacklist-nvidia.conf"
cat > "$BLACKLIST_FILE" << 'EOF'
# Prevent the host from loading NVIDIA / Nouveau drivers so the GPU is
# available exclusively for VFIO passthrough to the VM.
blacklist nouveau
blacklist nvidia
blacklist nvidia_drm
blacklist nvidia_modeset
blacklist nvidia_uvm
EOF
echo "Wrote $BLACKLIST_FILE"

# ---------------------------------------------------------------------------
# 4. Bind RTX 5060 Ti to vfio-pci by PCI IDs
# ---------------------------------------------------------------------------
echo ""
echo "Detecting NVIDIA PCI devices..."
NVIDIA_DEVS=$(lspci -nn | grep -i nvidia || true)

if [[ -z "$NVIDIA_DEVS" ]]; then
  echo "WARNING: No NVIDIA devices found via lspci."
  echo "         After rebooting and connecting the OCuLink eGPU, re-run this"
  echo "         script or manually create /etc/modprobe.d/vfio.conf."
else
  echo ""
  echo "Found NVIDIA devices:"
  echo "$NVIDIA_DEVS"
  echo ""

  # Extract the vendor:device ID pairs (e.g. 10de:2b85)
  IDS=$(echo "$NVIDIA_DEVS" | grep -oiP '\[\K[0-9a-fA-F]{4}:[0-9a-fA-F]{4}(?=\])' | tr '[:upper:]' '[:lower:]' | paste -sd ',' -)

  echo "The following PCI IDs will be bound to vfio-pci: $IDS"
  read -r -p "Proceed? [y/N] " confirm
  if [[ "${confirm,,}" != "y" ]]; then
    echo "Aborted. No changes made to vfio.conf."
    exit 0
  fi

  VFIO_CONF="/etc/modprobe.d/vfio.conf"
  cat > "$VFIO_CONF" << EOF
# Bind RTX 5060 Ti (and its HDMI audio function) to vfio-pci at boot.
options vfio-pci ids=$IDS
EOF
  echo "Wrote $VFIO_CONF"
fi

# ---------------------------------------------------------------------------
# 5. Rebuild initramfs
# ---------------------------------------------------------------------------
update-initramfs -u -k all
echo ""
echo "Done. Please REBOOT the Proxmox host to apply all changes."
echo "After rebooting, verify IOMMU is active with:"
echo "  dmesg | grep -e DMAR -e IOMMU"
