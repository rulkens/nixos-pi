#!/bin/bash
# =========================================================
# common.sh — Shared functions for build-image.sh and deploy.sh
# =========================================================
# Sourced by other scripts, not executed directly.
# Provides: check_prerequisites, validate_profile, load_config
# Sets: SCRIPT_DIR, ARTIFACTS_DIR, CONFIG_JSON
# =========================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARTIFACTS_DIR="$SCRIPT_DIR/artifacts"
CONFIG_JSON="$SCRIPT_DIR/config.json"

check_prerequisites() {
  if ! command -v nix &> /dev/null; then
    echo "ERROR: Nix is not installed."
    exit 1
  fi

  if ! command -v python3 &> /dev/null; then
    echo "ERROR: python3 is not installed."
    exit 1
  fi

  if ! command -v determinate-nixd &> /dev/null; then
    echo "ERROR: Determinate Nix is not installed."
    echo "  Install it from https://docs.determinate.systems/"
    exit 1
  fi

  if ! determinate-nixd version 2>&1 | grep -q "native-linux-builder"; then
    echo "ERROR: Determinate Nix does not have 'native-linux-builder' enabled."
    echo "  This feature is required to cross-compile aarch64-linux images on macOS."
    echo "  See the README for setup instructions."
    exit 1
  fi

  echo "  ✓ Nix found"
  echo "  ✓ python3 found"
  echo "  ✓ Determinate Nix (native-linux-builder enabled)"
  echo ""
}

validate_profile() {
  local profile="$1"
  if [ ! -f "$SCRIPT_DIR/profiles/${profile}.nix" ]; then
    echo "ERROR: Unknown profile '${profile}'."
    echo ""
    echo "Available profiles:"
    for f in "$SCRIPT_DIR/profiles/"*.nix; do
      basename "$f" .nix | sed 's/^/  - /'
    done
    exit 1
  fi
}

read_config() {
  local profile="$1"

  if [ ! -f "$CONFIG_JSON" ]; then
    echo "ERROR: config.json not found. Run ./build-image.sh first to generate it."
    exit 1
  fi

  PI_HOSTNAME=$(python3 -c "import json; print(json.load(open('$CONFIG_JSON'))['hostname'])")
  PI_USERNAME=$(python3 -c "import json; print(json.load(open('$CONFIG_JSON'))['username'])")
  WIFI_COUNT=$(python3 -c "import json; print(len(json.load(open('$CONFIG_JSON'))['wifi']))")

  echo "  Config: $PI_HOSTNAME / $PI_USERNAME ($WIFI_COUNT WiFi networks) / profile: $profile"
  echo ""
}

load_config() {
  local profile="$1"

  if [ -f "$CONFIG_JSON" ]; then
    PI_HOSTNAME=$(python3 -c "import json; print(json.load(open('$CONFIG_JSON'))['hostname'])")
    PI_USERNAME=$(python3 -c "import json; print(json.load(open('$CONFIG_JSON'))['username'])")
    WIFI_COUNT=$(python3 -c "import json; print(len(json.load(open('$CONFIG_JSON'))['wifi']))")

    echo "  Found existing config.json"
    echo "    Hostname:      $PI_HOSTNAME"
    echo "    Username:      $PI_USERNAME"
    echo "    WiFi networks: $WIFI_COUNT"
    echo "    Profile:       $profile"
    echo ""
    read -r -p "  Regenerate? [y/N]: " REGEN
    REGEN="${REGEN:-N}"
  else
    REGEN="Y"
  fi

  if [[ "$REGEN" =~ ^[Yy]$ ]]; then
    python3 "$SCRIPT_DIR/generate-config.py" "$CONFIG_JSON"
  fi

  PI_HOSTNAME=$(python3 -c "import json; print(json.load(open('$CONFIG_JSON'))['hostname'])")
  PI_USERNAME=$(python3 -c "import json; print(json.load(open('$CONFIG_JSON'))['username'])")
}
