# Legacy Lima Builder

> **Note:** This approach is superseded by [Determinate Systems Nix](https://docs.determinate.systems/determinate-nix/), which provides a native `aarch64-linux` builder on Apple Silicon without needing a manually managed VM. See the root README for the current setup.

## What this is

Before Determinate Systems added native Linux builder support, building an `aarch64-linux` NixOS image on macOS required a Linux VM to act as the build host. This directory contains the scripts for that approach using [Lima](https://lima-vm.io/).

The VM runs Ubuntu 24.04 (ARM64) via Apple's Virtualization.framework, with Nix installed inside it. Your Mac's Nix delegates `aarch64-linux` builds to the VM over SSH.

## Files

| File | Purpose |
|------|---------|
| `nixbuilder.yaml` | Lima VM definition — Ubuntu 24.04 ARM64, 4 CPUs, 8 GB RAM, 60 GB disk, Nix installed on first boot |
| `setup-builder.sh` | One-time setup: creates the VM, starts it, waits for Nix to install, verifies the VM is ready |

## Usage

### Prerequisites

- Lima: `brew install lima`
- Nix installed on macOS

### One-time setup

```bash
chmod +x setup-builder.sh
./setup-builder.sh
```

This creates and starts a VM named `nixbuilder` (you can choose a different name). On first boot the VM installs Nix automatically — this takes a few minutes.

### Building inside the VM

Once the VM is running, `nix build` commands are run inside the VM via `limactl shell`. Your macOS home directory is mounted read-only into the VM, so it can access your project files directly.

```bash
limactl shell nixbuilder -- bash -lc "cd ~/path/to/nixos-pi && nix build .#packages.aarch64-linux.sdImage --impure"
```

### VM management

```bash
limactl list                  # show running VMs
limactl shell nixbuilder      # open a shell inside the VM
limactl stop nixbuilder       # shut down the VM
limactl start nixbuilder      # start it again
limactl delete nixbuilder     # remove it entirely
```

## Why Lima works for this

The Raspberry Pi 4 is `aarch64`. Apple Silicon Macs are also `aarch64`, so the VM runs natively — no emulation or cross-compilation. Lima uses Apple's Virtualization.framework (`vmType: vz`) for near-native performance.
