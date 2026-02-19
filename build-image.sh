#!/bin/bash
# =========================================================
# build-image.sh — Build a NixOS SD card image for Raspberry Pi 4
# =========================================================
# Usage:
#   ./build-image.sh              # builds "base" profile (default)
#   ./build-image.sh dev-box      # builds "dev-box" profile
# =========================================================
set -euo pipefail

source "$(dirname "$0")/common.sh"

PROFILE="${1:-base}"
validate_profile "$PROFILE"
mkdir -p "$ARTIFACTS_DIR"

echo ""
echo "============================================"
echo "  NixOS Raspberry Pi 4 — Image Builder"
echo "============================================"
echo ""

echo "[1/3] Checking prerequisites..."
check_prerequisites

echo "[2/3] Gathering configuration..."
load_config "$PROFILE"

echo ""
echo "[3/3] Building NixOS SD card image (profile: $PROFILE)..."
echo "  This will take a while on first build (10-30 minutes)."
echo "  Subsequent builds will be much faster due to caching."
echo ""

NIXOS_PI_CONFIG="$CONFIG_JSON" nix build ".#packages.aarch64-linux.${PROFILE}" \
  --impure \
  --out-link "$ARTIFACTS_DIR/result-${PROFILE}" \
  -L

echo ""
echo "  ✓ Build complete"

IMG=$(find -L "$ARTIFACTS_DIR/result-${PROFILE}/sd-image/" -name '*.img' | head -1)

if [ -z "$IMG" ]; then
  echo "  ERROR: Could not find .img in build output."
  exit 1
fi

ln -sf "$IMG" "$ARTIFACTS_DIR/${PI_HOSTNAME}.img"

IMG_SIZE=$(du -h "$ARTIFACTS_DIR/${PI_HOSTNAME}.img" | awk '{print $1}')

echo ""
echo "============================================"
echo "  Build Complete!"
echo "============================================"
echo ""
echo "  Profile: $PROFILE"
echo "  Image:   $ARTIFACTS_DIR/${PI_HOSTNAME}.img ($IMG_SIZE)"
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
