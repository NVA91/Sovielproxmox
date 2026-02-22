#!/usr/bin/env bash
# setup-gpu.sh
# Installs the NVIDIA drivers and CUDA toolkit inside the Ubuntu Server VM.
# Run as a user with sudo privileges after first boot.

set -euo pipefail

echo "=== NVIDIA RTX 5060 Ti – Ubuntu Server driver setup ==="

# ---------------------------------------------------------------------------
# 1. Verify the GPU is visible inside the VM
# ---------------------------------------------------------------------------
if ! lspci | grep -qi nvidia; then
  echo "ERROR: No NVIDIA device detected. Check that PCIe passthrough is" >&2
  echo "       configured correctly on the Proxmox host." >&2
  exit 1
fi

echo "GPU detected:"
lspci | grep -i nvidia

# ---------------------------------------------------------------------------
# 2. Update the package index
# ---------------------------------------------------------------------------
sudo apt-get update

# ---------------------------------------------------------------------------
# 3. Install prerequisites
# ---------------------------------------------------------------------------
sudo apt-get install -y \
  build-essential \
  dkms \
  linux-headers-"$(uname -r)"

# ---------------------------------------------------------------------------
# 4. Add the Ubuntu graphics-drivers PPA for the latest stable NVIDIA driver
# ---------------------------------------------------------------------------
sudo apt-get install -y software-properties-common
sudo add-apt-repository -y ppa:graphics-drivers/ppa
sudo apt-get update

# ---------------------------------------------------------------------------
# 5. Install the recommended NVIDIA driver
#    ubuntu-drivers will pick the latest driver compatible with the 5060 Ti.
# ---------------------------------------------------------------------------
sudo apt-get install -y ubuntu-drivers-common
sudo ubuntu-drivers install

# ---------------------------------------------------------------------------
# 6. Install CUDA toolkit (optional – remove if not needed)
# ---------------------------------------------------------------------------
read -r -p "Install CUDA toolkit as well? [y/N] " install_cuda
if [[ "${install_cuda,,}" == "y" ]]; then
  sudo apt-get install -y nvidia-cuda-toolkit
  echo "CUDA toolkit installed."
fi

# ---------------------------------------------------------------------------
# 7. Done
# ---------------------------------------------------------------------------
echo ""
echo "Driver installation complete."
echo "Please REBOOT the VM and then verify with:"
echo "  nvidia-smi"
