#!/usr/bin/env bash
# backup.sh — Docker Volumes sichern
# Erstellt tar.gz-Archive aller wichtigen Volumes in $BACKUP_DIR
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/opt/homelab-backups}"
TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
BACKUP_PATH="$BACKUP_DIR/$TIMESTAMP"

# Volumes die gesichert werden sollen
VOLUMES=(
    "ollama_data"
    "n8n_data"
    "postgres_data"
    "open-webui"
    # "authelia_data"    # bei Bedarf einkommentieren
)

echo "=== Homelab Backup — $TIMESTAMP ==="
echo "Zielverzeichnis: $BACKUP_PATH"
echo ""

mkdir -p "$BACKUP_PATH"

for volume in "${VOLUMES[@]}"; do
    # Prüfen ob Volume existiert
    if ! docker volume ls --format '{{.Name}}' | grep -q "^${volume}$"; then
        echo "[$volume] Volume nicht gefunden, übersprungen."
        continue
    fi

    archive="$BACKUP_PATH/${volume}.tar.gz"
    echo "[$volume] Sicherung → $archive ..."

    docker run --rm \
        -v "${volume}:/data:ro" \
        -v "$BACKUP_PATH:/backup" \
        alpine:latest \
        tar czf "/backup/${volume}.tar.gz" -C /data .

    size="$(du -sh "$archive" | cut -f1)"
    echo "[$volume] OK ($size)"
done

echo ""
echo "Alte Backups aufräumen (behalte letzte 7 Tage)..."
find "$BACKUP_DIR" -maxdepth 1 -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true

echo ""
echo "=== Backup abgeschlossen: $BACKUP_PATH ==="
ls -lh "$BACKUP_PATH/"
