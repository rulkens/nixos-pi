#!/bin/bash
# =========================================================
# backup-ha.sh — Back up Home Assistant state from a running Pi
# =========================================================
# Rsyncs /var/lib/hass/ (excluding the history database and
# caches) to backups/home-assistant/ in this project directory.
#
# Usage:
#   ./backup-ha.sh
#
# The backup folder is gitignored. See backups/.gitignore for
# which files are safe to commit if you want selective tracking.
# =========================================================
set -euo pipefail

source "$(dirname "$0")/common.sh"

DEPLOY_CONFIG="$SCRIPT_DIR/deploy-config.json"
BACKUP_DIR="$SCRIPT_DIR/backups/home-assistant"

if [ ! -f "$DEPLOY_CONFIG" ]; then
  echo "ERROR: deploy-config.json not found."
  echo "  Copy deploy-config.json.example and fill in your Pi's address:"
  echo "    cp deploy-config.json.example deploy-config.json"
  exit 1
fi

DEPLOY_HOST=$(python3 -c "import json; print(json.load(open('$DEPLOY_CONFIG'))['host'])")
DEPLOY_USER=$(python3 -c "import json; print(json.load(open('$DEPLOY_CONFIG'))['user'])")

mkdir -p "$BACKUP_DIR"

echo ""
echo "============================================"
echo "  Home Assistant — Backup"
echo "============================================"
echo ""
echo "  Source: ${DEPLOY_USER}@${DEPLOY_HOST}:/var/lib/hass/"
echo "  Target: backups/home-assistant/"
echo ""

rsync -avz --delete \
  --rsync-path="sudo rsync" \
  --exclude='home-assistant_v2.db*' \
  --exclude='tts/' \
  --exclude='deps/' \
  --exclude='logs/' \
  "${DEPLOY_USER}@${DEPLOY_HOST}:/var/lib/hass/" \
  "$BACKUP_DIR/"

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo ""
echo "============================================"
echo "  Backup complete — $TIMESTAMP"
echo "============================================"
echo ""
echo "  Files saved to: backups/home-assistant/"
echo "  Review backups/.gitignore before committing to git."
echo ""
