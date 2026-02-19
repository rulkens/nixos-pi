#!/bin/bash
# =========================================================
# deploy.sh — Deploy NixOS configuration to a running Pi over SSH
# =========================================================
# Reads the target host and user from deploy-config.json.
# See deploy-config.json.example for the expected format.
#
# Usage:
#   ./deploy.sh                    # deploys "base" profile (default)
#   ./deploy.sh dev-box            # deploys "dev-box" profile
#   ./deploy.sh --reconfigure      # prompt to regenerate config.json first
#   ./deploy.sh --reconfigure dev-box
# =========================================================
set -euo pipefail

source "$(dirname "$0")/common.sh"

DEPLOY_CONFIG="$SCRIPT_DIR/deploy-config.json"
RECONFIGURE=false

if [[ "${1:-}" == "--reconfigure" ]]; then
  RECONFIGURE=true
  shift
fi

PROFILE="${1:-base}"

validate_profile "$PROFILE"
mkdir -p "$ARTIFACTS_DIR"

echo ""
echo "============================================"
echo "  NixOS Raspberry Pi 4 — Deploy"
echo "============================================"
echo ""

echo "[1/3] Checking prerequisites..."
check_prerequisites

echo "[2/3] Gathering configuration..."
if $RECONFIGURE; then
  load_config "$PROFILE"
else
  read_config "$PROFILE"
fi

if [ ! -f "$DEPLOY_CONFIG" ]; then
  echo "ERROR: deploy-config.json not found."
  echo "  Copy deploy-config.json.example and fill in your Pi's address:"
  echo "    cp deploy-config.json.example deploy-config.json"
  exit 1
fi

DEPLOY_HOST=$(python3 -c "import json; print(json.load(open('$DEPLOY_CONFIG'))['host'])")
DEPLOY_USER=$(python3 -c "import json; print(json.load(open('$DEPLOY_CONFIG'))['user'])")

echo ""
echo "[3/3] Deploying to ${DEPLOY_USER}@${DEPLOY_HOST} (profile: $PROFILE)..."
echo ""

NIXOS_PI_CONFIG="$CONFIG_JSON" nix run nixpkgs#nixos-rebuild -- switch \
  --flake ".#${PROFILE}" \
  --target-host "${DEPLOY_USER}@${DEPLOY_HOST}" \
  --sudo \
  --impure \
  -L

echo ""
echo "============================================"
echo "  Deploy Complete!"
echo "============================================"
echo ""
echo "  Profile: $PROFILE"
echo "  Target:  ${DEPLOY_USER}@${DEPLOY_HOST}"
echo ""
echo "  Connect via:"
echo "    ssh ${DEPLOY_USER}@${DEPLOY_HOST}"
echo ""
