#!/bin/bash
# =========================================================
# build.sh — Build a NixOS SD card image for Raspberry Pi 4
# =========================================================
# This script:
#   1. Checks prerequisites (Nix, Lima builder VM)
#   2. Prompts for personal/secret configuration values
#   3. Auto-detects your SSH public key and WiFi credentials
#   4. Generates config.json (read by local-config.nix)
#   5. Builds the NixOS SD card image via the Lima VM
#   6. Copies the decompressed image to artifacts/
#
# Usage:
#   chmod +x build.sh
#   ./build.sh
#
# Prerequisites:
#   - Lima VM running (see setup-builder.sh)
#   - Nix installed on macOS
# =========================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ARTIFACTS_DIR="$SCRIPT_DIR/artifacts"
CONFIG_JSON="$SCRIPT_DIR/config.json"

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

# Check that a builder VM is running
if ! limactl list --json 2>/dev/null | grep -q '"status":"Running"'; then
  echo "ERROR: No Lima VM is running."
  echo "  Start your builder with: limactl start nixbuilder"
  echo "  Or run setup-builder.sh first."
  exit 1
fi

echo "  ✓ Nix found"
echo "  ✓ Builder VM running"
echo ""

# ---------------------------------------------------------
# Step 2: Generate config.json (or reuse existing)
# ---------------------------------------------------------
if [ -f "$CONFIG_JSON" ]; then
  echo "[2/5] Found existing config.json"

  # Extract values from JSON for display using python3
  # (python3 ships with macOS)
  PI_HOSTNAME=$(python3 -c "import json; print(json.load(open('$CONFIG_JSON'))['hostname'])")
  PI_USERNAME=$(python3 -c "import json; print(json.load(open('$CONFIG_JSON'))['username'])")

  echo "    Hostname: $PI_HOSTNAME"
  echo "    Username: $PI_USERNAME"
  echo ""
  read -r -p "  Regenerate? [y/N]: " REGEN
  REGEN="${REGEN:-N}"
else
  REGEN="Y"
fi

if [[ "$REGEN" =~ ^[Yy]$ ]]; then
  echo ""
  echo "[2/5] Gathering configuration..."
  echo ""

  # -- Hostname --
  read -r -p "  Hostname for the Pi [rpi]: " PI_HOSTNAME
  PI_HOSTNAME="${PI_HOSTNAME:-rpi}"

  # -- Username --
  read -r -p "  Username [alex]: " PI_USERNAME
  PI_USERNAME="${PI_USERNAME:-alex}"

  # -- WiFi SSID & Password --
  read -r -p "  Auto-detect WiFi from current connection? [Y/n]: " AUTO_WIFI
  AUTO_WIFI="${AUTO_WIFI:-Y}"

  if [[ "$AUTO_WIFI" =~ ^[Yy]$ ]]; then
    echo "  Detecting WiFi network..."
    CURRENT_SSID=$(networksetup -getairportnetwork en0 2>/dev/null | awk -F': ' '{print $2}')

    if [ -n "$CURRENT_SSID" ]; then
      echo "  ✓ Currently connected to: $CURRENT_SSID"
      WIFI_SSID="$CURRENT_SSID"
    else
      echo "  Could not detect current WiFi network. Falling back to manual entry."
      read -r -p "  WiFi network name (SSID): " WIFI_SSID
    fi

    if [ -z "$WIFI_SSID" ]; then
      echo "  ERROR: WiFi SSID is required for a headless WiFi setup."
      exit 1
    fi

    echo ""
    echo "  Retrieving WiFi password from macOS Keychain..."
    echo "  (You may be prompted for your macOS login password)"
    WIFI_PASSWORD=$(security find-generic-password -D "AirPort network password" -a "$WIFI_SSID" -w 2>/dev/null) || true

    if [ -n "$WIFI_PASSWORD" ]; then
      echo "  ✓ Password retrieved from Keychain"
    else
      echo "  Could not retrieve password from Keychain. Falling back to manual entry."
      read -r -s -p "  WiFi password: " WIFI_PASSWORD
      echo ""
    fi
  else
    read -r -p "  WiFi network name (SSID): " WIFI_SSID
    if [ -z "$WIFI_SSID" ]; then
      echo "  ERROR: WiFi SSID is required for a headless WiFi setup."
      exit 1
    fi

    read -r -s -p "  WiFi password: " WIFI_PASSWORD
    echo ""
  fi

  if [ -z "$WIFI_PASSWORD" ]; then
    echo "  ERROR: WiFi password is required."
    exit 1
  fi

  # -- SSH Public Key --
  echo ""
  echo "  Detecting SSH public key..."
  SSH_PUBKEY=""
  for keyfile in "$HOME/.ssh/id_ed25519.pub" "$HOME/.ssh/id_rsa.pub" "$HOME/.ssh/id_ecdsa.pub"; do
    if [ -f "$keyfile" ]; then
      SSH_PUBKEY=$(cat "$keyfile")
      echo "  ✓ Found: $keyfile"
      break
    fi
  done

  if [ -z "$SSH_PUBKEY" ]; then
    echo "  No SSH public key found in ~/.ssh/"
    echo "  Generate one with: ssh-keygen -t ed25519"
    exit 1
  fi

  echo ""
  echo "  Configuration summary:"
  echo "    Hostname:  $PI_HOSTNAME"
  echo "    Username:  $PI_USERNAME"
  echo "    WiFi SSID: $WIFI_SSID"
  echo "    WiFi Pass: ****"
  echo "    SSH Key:   ${SSH_PUBKEY:0:30}..."
  echo ""

  read -r -p "  Proceed? [Y/n]: " CONFIRM
  CONFIRM="${CONFIRM:-Y}"
  if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "  Aborted."
    exit 0
  fi

  # ---------------------------------------------------------
  # Step 3: Generate config.json
  # ---------------------------------------------------------
  echo ""
  echo "[3/5] Generating config.json..."

  # Use python3 to produce properly escaped JSON.
  # This is important because WiFi passwords or SSH keys
  # could contain characters that would break naive string
  # interpolation (quotes, backslashes, etc).
  python3 << PYEOF
import json, sys

config = {
    "hostname": "$PI_HOSTNAME",
    "username": "$PI_USERNAME",
    "sshPubKey": "$SSH_PUBKEY",
    "wifi": {
        "ssid": "$WIFI_SSID",
        "password": "$WIFI_PASSWORD"
    }
}

with open("$CONFIG_JSON", "w") as f:
    json.dump(config, f, indent=2)

print("  \u2713 config.json generated")
PYEOF

else
  echo "  Using existing config.json"
fi

# ---------------------------------------------------------
# Step 4: Build the SD card image inside the Lima VM
# ---------------------------------------------------------
echo ""
echo "[4/5] Building NixOS SD card image..."
echo "  This will take a while on first build (10-30 minutes)."
echo "  Subsequent builds will be much faster due to caching."
echo ""

# We build inside the Lima VM directly rather than using Nix's
# remote builder mechanism. This avoids the complexity of
# configuring the Nix daemon's SSH access to the VM.
#
# How it works:
#   - Lima mounts your home directory into the VM (read-only)
#   - The VM can see all project files at the same path
#   - We run 'nix build' inside the VM, where it builds natively
#     as aarch64-linux
#   - The result symlink goes to /tmp/lima (writable) since
#     the home directory mount is read-only
#   - We copy the image file back to your Mac via /tmp/lima
VM_NAME="nixbuilder"
limactl shell "$VM_NAME" -- bash -lc "cd '$SCRIPT_DIR' && nix build .#packages.aarch64-linux.sdImage --out-link /tmp/lima/result -L"

echo ""
echo "  ✓ Build complete"

# ---------------------------------------------------------
# Step 5: Copy image to artifacts/
# ---------------------------------------------------------
echo ""
echo "[5/5] Extracting SD card image..."

mkdir -p "$ARTIFACTS_DIR"

# The build produced a result symlink in the project directory.
# The build output is a .img.zst file (zstandard compressed).
# We copy the compressed file to the Mac first, then decompress
# locally. This is much faster than decompressing through the
# shared VM mount (which has to push 6GB+ through virtiofs).

# Find the compressed image path inside the VM
IMG_ZST=$(limactl shell "$VM_NAME" -- bash -lc "find -L /tmp/lima/result/sd-image/ -name '*.img.zst' | head -1")

if [ -z "$IMG_ZST" ]; then
  echo "  ERROR: Could not find .img.zst in build output."
  exit 1
fi

echo "  Copying compressed image..."
cp "/tmp/lima/result/sd-image/$(basename "$IMG_ZST")" "$ARTIFACTS_DIR/${PI_HOSTNAME}.img.zst"

echo "  Decompressing locally..."
nix shell nixpkgs#zstd -c zstd -d "$ARTIFACTS_DIR/${PI_HOSTNAME}.img.zst" -o "$ARTIFACTS_DIR/${PI_HOSTNAME}.img" --force

# Clean up the compressed file
rm -f "$ARTIFACTS_DIR/${PI_HOSTNAME}.img.zst"

# Get the image size for display
IMG_SIZE=$(du -h "$ARTIFACTS_DIR/${PI_HOSTNAME}.img" | awk '{print $1}')

echo "  ✓ Image saved to artifacts/${PI_HOSTNAME}.img ($IMG_SIZE)"

echo ""
echo "============================================"
echo "  Build Complete!"
echo "============================================"
echo ""
echo "  Image: $ARTIFACTS_DIR/${PI_HOSTNAME}.img"
echo "  Size:  $IMG_SIZE"
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