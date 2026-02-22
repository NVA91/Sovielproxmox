#!/usr/bin/env bash
# update.sh — Alle Docker-Stacks aktualisieren
# Zieht neue Images, recreated geänderte Container, behält Volumes
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

STACKS=(
    "tools/ollama"
    "tools/wireguard-client"
    "staging/docker-stacks/open-webui"
    "staging/docker-stacks/n8n"
    # "tools/authelia"    # bei Bedarf einkommentieren
)

echo "=== Homelab Update — $(date '+%Y-%m-%d %H:%M:%S') ==="
echo "Repo-Root: $REPO_ROOT"
echo ""

for stack in "${STACKS[@]}"; do
    stack_path="$REPO_ROOT/$stack"

    if [[ ! -f "$stack_path/docker-compose.yml" ]]; then
        echo "[$stack] Übersprungen (keine docker-compose.yml)"
        continue
    fi

    echo "[$stack] Pulling neue Images..."
    docker compose -f "$stack_path/docker-compose.yml" pull --quiet

    echo "[$stack] Recreating geänderte Container..."
    docker compose -f "$stack_path/docker-compose.yml" up -d --remove-orphans

    echo "[$stack] OK"
    echo ""
done

# Veraltete Images aufräumen
echo "Veraltete Images entfernen (dangling)..."
docker image prune -f --filter "dangling=true"

echo ""
echo "=== Update abgeschlossen ==="
