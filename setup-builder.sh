#!/bin/bash
# =======================================================
# setup-builder.sh
# =======================================================
# This script:
#   1. Creates a Lima VM from nixbuilder.yaml
#   2. Starts the VM (which triggers Nix installation)
#   3. Waits for Nix to be available inside the VM
#   4. Configures your Mac's Nix to use the VM as a
#      remote builder for aarch64-linux builds
#
# Usage:
#   chmod +x setup-builder.sh
#   ./setup-builder.sh
#
# Prerequisites:
#   - Lima installed (brew install lima)
#   - Nix installed on macOS
# =======================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Ask for VM name, with a default
read -r -p "Enter a name for the builder VM [nixbuilder]: " VM_NAME
VM_NAME="${VM_NAME:-nixbuilder}"

# Validate the name — Lima only allows alphanumeric characters, hyphens, and underscores
if [[ ! "$VM_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo "ERROR: VM name can only contain letters, numbers, hyphens, and underscores."
  exit 1
fi

# The YAML config file is expected to share the VM's name
YAML_FILE="$SCRIPT_DIR/${VM_NAME}.yaml"

echo ""
echo "============================================"
echo "  NixOS Builder VM Setup"
echo "============================================"
echo ""

# -------------------------------------------------
# Step 1: Check prerequisites
# -------------------------------------------------
echo "[1/5] Checking prerequisites..."

if ! command -v limactl &> /dev/null; then
  echo "ERROR: Lima is not installed. Run: brew install lima"
  exit 1
fi

if ! command -v nix &> /dev/null; then
  echo "ERROR: Nix is not installed."
  exit 1
fi

if [ ! -f "$YAML_FILE" ]; then
  echo "ERROR: $YAML_FILE not found."
  exit 1
fi

echo "  ✓ Lima found"
echo "  ✓ Nix found"
echo "  ✓ Config file found"
echo ""

# -------------------------------------------------
# Step 2: Create the VM (skip if it already exists)
# -------------------------------------------------
echo "[2/5] Creating Lima VM '$VM_NAME'..."

if limactl list --json 2>/dev/null | grep -q "\"name\":\"$VM_NAME\""; then
  echo "  VM '$VM_NAME' already exists, skipping creation."
else
  limactl create --name="$VM_NAME" --tty=false "$YAML_FILE"
  echo "  ✓ VM created"
fi
echo ""

# -------------------------------------------------
# Step 3: Start the VM
# -------------------------------------------------
echo "[3/5] Starting VM '$VM_NAME'..."
echo "  (This may take a few minutes on first boot — Nix is being installed)"

limactl start "$VM_NAME"
echo "  ✓ VM started"
echo ""

# -------------------------------------------------
# Step 4: Verify Nix is working inside the VM
# -------------------------------------------------
echo "[4/5] Verifying Nix installation inside VM..."

# Give the Nix daemon a moment to start
sleep 5

# Try running a Nix command inside the VM
# Lima's 'shell' command runs commands inside the VM via SSH
if limactl shell "$VM_NAME" -- bash -lc "nix --version" 2>/dev/null; then
  echo "  ✓ Nix is working inside the VM"
else
  echo ""
  echo "  Nix might still be installing. Waiting 30 more seconds..."
  sleep 30
  if limactl shell "$VM_NAME" -- bash -lc "nix --version" 2>/dev/null; then
    echo "  ✓ Nix is working inside the VM"
  else
    echo "  WARNING: Could not verify Nix. You may need to wait for"
    echo "  provisioning to finish. Check with:"
    echo "    limactl shell $VM_NAME -- bash -lc 'nix --version'"
  fi
fi
echo ""

# -------------------------------------------------
# Step 5: Verify the VM is usable as a builder
# -------------------------------------------------
echo "[5/5] Verifying builder VM..."

# We build inside the VM directly (via limactl shell) rather
# than using Nix's remote builder mechanism. This avoids
# configuring root SSH access and /etc/nix/machines entirely.
#
# Lima mounts your home directory into the VM, so the VM can
# access your project files. The build script (build.sh) will
# run 'nix build' inside the VM via 'limactl shell'.

# Verify the VM can see the home directory
if limactl shell "$VM_NAME" -- test -d "$HOME"; then
  echo "  ✓ Home directory accessible from VM"
else
  echo "  WARNING: Home directory not accessible from VM."
  echo "  Build script may not work. Check Lima mount configuration."
fi

# Verify Nix works inside the VM
if limactl shell "$VM_NAME" -- bash -lc "nix --version" &>/dev/null; then
  echo "  ✓ Nix is working inside the VM"
else
  echo "  ERROR: Nix not working inside the VM."
  exit 1
fi

echo ""
echo "============================================"
echo "  Setup Complete!"
echo "============================================"
echo ""
echo "Your Lima VM '$VM_NAME' is running and ready"
echo "to build NixOS images for aarch64-linux."
echo ""
echo "Builds run directly inside the VM — no root"
echo "SSH config or Nix daemon changes needed."
echo ""
echo "Useful commands:"
echo "  limactl shell $VM_NAME    # shell into the VM"
echo "  limactl stop $VM_NAME     # stop the VM"
echo "  limactl start $VM_NAME    # start it again"
echo "  limactl delete $VM_NAME   # remove it entirely"
echo ""
echo "Next step: build your NixOS Raspberry Pi image!"
echo ""