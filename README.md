# NixOS Raspberry Pi 4 Image Builder

Build a reproducible, headless NixOS SD card image for Raspberry Pi 4 — entirely from macOS.

The image comes pre-configured with WiFi, SSH key authentication, and your chosen packages. Just flash, boot, and `ssh` in.

## What you get

- **Headless WiFi** — connects to your network on first boot
- **SSH key auth** — password login disabled, secure by default
- **mDNS discovery** — reach your Pi as `<hostname>.local`
- **Reproducible** — pinned dependencies mean identical builds every time
- **No secrets in Git** — personal config lives in a gitignored `config.json`

## Prerequisites

- **macOS** on Apple Silicon (M1/M2/M3/M4)
- **Homebrew** — [brew.sh](https://brew.sh)
- **Nix** — install with `curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install`
- An **SD card** (16GB or larger recommended)
- An **SSH key** — if you don't have one, run `ssh-keygen -t ed25519`

## Project structure

```
nixos-rpi/
├── .gitignore              Keeps secrets and build output out of git
├── nixbuilder.yaml         Lima VM definition (Ubuntu + Nix)
├── setup-builder.sh        One-time VM setup script
├── flake.nix               Nix build entry point, pins nixpkgs 24.11
├── flake.lock              Exact dependency versions (committed for reproducibility)
├── configuration.nix       System config: packages, SSH, firewall, boot
├── local-config.nix        Reads config.json, applies personal settings
├── build.sh                Builds the image and extracts it
└── config.json             Your hostname, WiFi, SSH key (gitignored, generated)
```

## Step 1A: Set up the build VM

@NOTE: not needed any more if using determinate.systems nix

NixOS images target `aarch64-linux`, which macOS can't build natively. We use a lightweight Linux VM via Lima to handle the build.

```bash
chmod +x setup-builder.sh
./setup-builder.sh
```

This creates an Ubuntu VM with Nix installed, configured as an `aarch64-linux` builder. It takes a few minutes on first run while the VM image downloads and Nix installs.

You can verify the VM is running:

```bash
limactl list
```

# Step 1B: Configure Determinate Systems Nix

The build with determinate systems nix needs to have linux-builders installed.
For this, you unfortunately create an account on Flakehub and send an email
with your username to support@flakehub.com. They will enable linux-builders for you. This runs on Apple virtualization framework.

Next up you need to make sure to give the builder enough memory (it runs on a
virtual filesystem) to build the image. In my setup, 32GB was needed.

For this you need to edit the file /etc/determinate/config.json (you might need to create it) and add the following:

(see more info on https://docs.determinate.systems/determinate-nix/#determinate-nixd-configuration)

```json
{
  "garbageCollector": {
    "strategy": "automatic"
  },
  "builder": {
    "state": "enabled",
    "memoryBytes": 34359738368,
    "cpuCount": 1
  }
}
```

And reboot the daemon:

    sudo pkill determinate-nixd
    determinate-nixd version

When you see:

The following features are enabled:

- lazy-trees
- native-linux-builder <----- THIS SHOULD BE PRESENT
- parallel-evaluation

You are good to go for the next step!

## Step 2: Build the image

```bash
chmod +x build.sh
./build.sh
```

The script will prompt you for:

- **Hostname** — how your Pi identifies itself on the network (default: `rpi`)
- **Username** — your login user (default: `alex`)
- **WiFi credentials** — auto-detected from your current connection, or entered manually. The password is retrieved from the macOS Keychain (you may be prompted for your macOS password)
- **SSH public key** — auto-detected from `~/.ssh/`

These values are saved to `config.json` (gitignored). On subsequent runs, the script will ask if you want to reuse the existing config or regenerate it.

The first build takes 10–30 minutes as packages are downloaded from the NixOS binary cache. Subsequent builds are much faster.

The final image is saved to `artifacts/<hostname>.img`.

## Step 3: Flash to SD card

Insert your SD card and identify it:

```bash
diskutil list
```

Look for your SD card — it will be something like `/dev/disk4`. Be careful to identify the correct disk.

Unmount, flash, and eject:

```bash
diskutil unmountDisk /dev/disk4
sudo dd if=artifacts/rpi.img of=/dev/rdisk4 bs=4m status=progress
diskutil eject /dev/disk4
```

Replace `/dev/diskN` with your actual disk (e.g., `/dev/disk4`). Note the `r` prefix in `rdiskN` — this uses the raw device for significantly faster writes.

The flash takes a few minutes depending on your SD card speed.

## Step 4: Boot and connect

1. Insert the SD card into your Raspberry Pi 4
2. Connect power
3. Wait about 30–60 seconds for the Pi to boot and connect to WiFi
4. Connect via SSH:

```bash
ssh <username>@<hostname>.local
```

For example, with the defaults:

```bash
ssh alex@rpi.local
```

If `.local` resolution doesn't work immediately, give it another minute — the Avahi mDNS service needs a moment to advertise. You can also find the Pi's IP address from your router's admin page and connect directly:

```bash
ssh alex@192.168.1.xxx
```

## Customizing your Pi

### Adding packages

Edit `configuration.nix` and add packages to the `environment.systemPackages` list:

```nix
environment.systemPackages = with pkgs; [
  vim
  git
  htop
  curl
  wget
  nodejs
  python3        # add new packages here
  docker
];
```

Then rebuild and reflash.

### Enabling services

NixOS has modules for hundreds of services. Add them to `configuration.nix`:

```nix
# Example: enable Docker
virtualisation.docker.enable = true;

# Example: enable Tailscale
services.tailscale.enable = true;
```

### Changing timezone

Edit the `time.timeZone` line in `configuration.nix`:

```nix
time.timeZone = "America/New_York";
```

Run `timedatectl list-timezones` for all options.

### Adding another WiFi network

Edit `local-config.nix` to add more NetworkManager profiles, or add them on the running Pi:

```bash
sudo nmcli device wifi connect "OtherNetwork" password "password123"
```

## Rebuilding

After making changes to `configuration.nix` or `local-config.nix`:

```bash
./build.sh
```

The build reuses cached packages, so only changed components are rebuilt. Flash the new image to your SD card following step 3.

Note that reflashing replaces the entire system — any state on the Pi (files you created, packages installed at runtime) will be lost. This is by design: the NixOS configuration is the source of truth.

## Troubleshooting

### Can't find the Pi on the network

- Make sure the Pi has power and the SD card is seated properly
- Wait 60 seconds after power-on for WiFi and mDNS to initialize
- Check your router's connected devices list for the Pi's IP
- Verify the WiFi credentials in `config.json` are correct
- Try connecting by IP instead of `.local` hostname

### Build fails with "dirty Git tree"

Nix flakes require files to be tracked by Git. Make sure your Nix files are committed:

```bash
git add flake.nix configuration.nix local-config.nix
```

Note: `config.json` should NOT be committed (it contains secrets), but it's read by `local-config.nix` via `builtins.readFile` which works outside of Git tracking.

### Build fails with module errors

If you see errors about missing kernel modules (like `sun4i-drm`), make sure `configuration.nix` includes the `boot.initrd.availableKernelModules` override with `lib.mkForce`. The generic ARM SD image module tries to include drivers for non-Pi hardware.

### SSH connection refused

- The Pi's SSH server only accepts key-based authentication
- Make sure the SSH key in `config.json` matches your private key
- Verify with `ssh -v alex@rpi.local` for detailed connection info

## How it works

The build pipeline is:

1. **`build.sh`** gathers your personal config and writes `config.json`
2. **`flake.nix`** defines the NixOS system, pulling in `configuration.nix` (system setup) and `local-config.nix` (which reads `config.json`)
3. **`nix build`** runs inside the Lima VM, evaluating the full NixOS configuration and producing an SD card image with the correct partition layout, bootloader, kernel, and root filesystem
4. The compressed image is copied back to your Mac and decompressed to `artifacts/`

All packages come from the NixOS 24.11 stable channel, pinned to a specific commit in `flake.lock`. To update to newer package versions:

```bash
nix flake update
./build.sh
```
