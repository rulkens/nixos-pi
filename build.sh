#!/bin/bash
# =========================================================
# build.sh — Build a NixOS SD card image for Raspberry Pi 4
# =========================================================
# This script:
#   1. Checks prerequisites (Nix, python3)
#   2. Runs generate-config.py to collect personal/secret
#      configuration values and write config.json
#   3. Builds the NixOS SD card image using the Determinate
#      Systems Linux builder
#   4. Links the image into artifacts/
#
# Usage:
#   ./build.sh              # builds "base" profile (default)
#   ./build.sh base         # builds "base" profile
#   ./build.sh dev-box      # builds "dev-box" profile
#
# Prerequisites:
#   - Determinate Systems Nix installed on macOS
#   - Linux builder enabled: sudo nix daemon linux-builder enable
# =========================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ARTIFACTS_DIR="$SCRIPT_DIR/artifacts"
CONFIG_JSON="$SCRIPT_DIR/config.json"

# ---------------------------------------------------------
# Profile selection and validation
# ---------------------------------------------------------
PROFILE="${1:-base}"

if [ ! -f "$SCRIPT_DIR/profiles/${PROFILE}.nix" ]; then
  echo "ERROR: Unknown profile '${PROFILE}'."
  echo ""
  echo "Available profiles:"
  for f in "$SCRIPT_DIR/profiles/"*.nix; do
    basename "$f" .nix | sed 's/^/  - /'
  done
  exit 1
fi

mkdir -p "$ARTIFACTS_DIR"

echo ""
echo "============================================"
echo "  NixOS Raspberry Pi 4 — Image Builder"
echo "============================================"
echo ""

# ---------------------------------------------------------
# Step 1: Check prerequisites
# ---------------------------------------------------------
echo "[1/5] Checking prerequisites..."

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

# ---------------------------------------------------------
# Step 2: Generate config.json (or reuse existing)
# ---------------------------------------------------------
if [ -f "$CONFIG_JSON" ]; then
  echo "[2/5] Found existing config.json"

  PI_HOSTNAME=$(python3 -c "import json; print(json.load(open('$CONFIG_JSON'))['hostname'])")
  PI_USERNAME=$(python3 -c "import json; print(json.load(open('$CONFIG_JSON'))['username'])")
  WIFI_COUNT=$(python3 -c "import json; print(len(json.load(open('$CONFIG_JSON'))['wifi']))")

  echo "    Hostname:      $PI_HOSTNAME"
  echo "    Username:      $PI_USERNAME"
  echo "    WiFi networks: $WIFI_COUNT"
  echo "    Profile:       $PROFILE"
  echo ""
  read -r -p "  Regenerate? [y/N]: " REGEN
  REGEN="${REGEN:-N}"
else
  REGEN="Y"
fi

if [[ "$REGEN" =~ ^[Yy]$ ]]; then
  python3 "$SCRIPT_DIR/generate-config.py" "$CONFIG_JSON"
fi

# Read back hostname and username from the (possibly freshly written) config
PI_HOSTNAME=$(python3 -c "import json; print(json.load(open('$CONFIG_JSON'))['hostname'])")
PI_USERNAME=$(python3 -c "import json; print(json.load(open('$CONFIG_JSON'))['username'])")

# ---------------------------------------------------------
# Step 3: (handled by generate-config.py)
# ---------------------------------------------------------

# ---------------------------------------------------------
# Step 4: Build the SD card image
# ---------------------------------------------------------
echo ""
echo "[4/5] Building NixOS SD card image (profile: $PROFILE)..."
echo "  This will take a while on first build (10-30 minutes)."
echo "  Subsequent builds will be much faster due to caching."
echo ""

NIXOS_PI_CONFIG="$CONFIG_JSON" nix build ".#packages.aarch64-linux.${PROFILE}" \
  --impure \
  --out-link "$ARTIFACTS_DIR/result-${PROFILE}" \
  -L

echo ""
echo "  ✓ Build complete"

# ---------------------------------------------------------
# Step 5: Copy SD card image
# ---------------------------------------------------------
echo ""
echo "[5/5] Linking SD card image..."

IMG=$(find -L "$ARTIFACTS_DIR/result-${PROFILE}/sd-image/" -name '*.img' | head -1)

if [ -z "$IMG" ]; then
  echo "  ERROR: Could not find .img in build output."
  exit 1
fi

ln -sf "$IMG" "$ARTIFACTS_DIR/${PI_HOSTNAME}.img"

IMG_SIZE=$(du -h "$ARTIFACTS_DIR/${PI_HOSTNAME}.img" | awk '{print $1}')
echo "  ✓ Image saved to artifacts/${PI_HOSTNAME}.img ($IMG_SIZE)"

echo ""
echo "============================================"
echo "  Build Complete!"
echo "============================================"
echo ""
echo "  Profile: $PROFILE"
echo "  Image:   $ARTIFACTS_DIR/${PI_HOSTNAME}.img"
echo "  Size:    $IMG_SIZE"
echo ""
echo "  To flash to SD card:"
echo "    1. Insert SD card"
echo "    2. Run: diskutil list"
echo "    3. Find your SD card (e.g., /dev/disk4)"
echo "    4. Run: diskutil unmountDisk /dev/diskN"
echo "    5. Run: sudo dd if=$ARTIFACTS_DIR/${PI_HOSTNAME}.img of=/dev/rdiskN bs=4m status=progress"
echo "    6. Run: diskutil eject /dev/diskN"
echo ""
echo "  After booting the Pi, connect via:"
echo "    ssh $PI_USERNAME@${PI_HOSTNAME}.local"
echo ""
