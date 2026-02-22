#!/usr/bin/env bash
# gpu-check.sh — NVIDIA GPU + Docker GPU-Support prüfen
set -euo pipefail

echo "=== GPU-Check: NVIDIA + Docker ==="
echo ""

# 1. nvidia-smi direkt auf dem Host
echo "[1/4] Host nvidia-smi:"
if command -v nvidia-smi &>/dev/null; then
    nvidia-smi --query-gpu=name,driver_version,memory.total,memory.free --format=csv,noheader
else
    echo "  WARNUNG: nvidia-smi nicht gefunden! NVIDIA-Treiber installiert?"
fi

echo ""

# 2. NVIDIA Container Toolkit prüfen
echo "[2/4] NVIDIA Container Toolkit (nvidia-ctk):"
if command -v nvidia-ctk &>/dev/null; then
    nvidia-ctk --version
else
    echo "  WARNUNG: nvidia-ctk nicht gefunden!"
    echo "  Installation: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html"
fi

echo ""

# 3. Docker GPU-Test
echo "[3/4] Docker GPU-Test (nvidia-smi im Container):"
if docker run --rm --gpus all nvidia/cuda:12.0-base-ubuntu22.04 nvidia-smi 2>/dev/null; then
    echo "  OK: Docker GPU-Support funktioniert!"
else
    echo "  FEHLER: Docker GPU-Test fehlgeschlagen."
    echo "  Tipps:"
    echo "    - sudo nvidia-ctk runtime configure --runtime=docker"
    echo "    - sudo systemctl restart docker"
fi

echo ""

# 4. Ollama-Container GPU prüfen (falls läuft)
echo "[4/4] Ollama GPU-Status (falls Container läuft):"
if docker ps --format '{{.Names}}' | grep -q '^ollama$'; then
    docker exec ollama nvidia-smi --query-gpu=name,memory.used,memory.free --format=csv,noheader 2>/dev/null \
        && echo "  OK: Ollama nutzt GPU!" \
        || echo "  Ollama läuft, aber kein GPU-Zugriff."
else
    echo "  Ollama-Container läuft nicht."
fi

echo ""
echo "=== Check abgeschlossen ==="
