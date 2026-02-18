# NixOS Raspberry Pi 4 Image Builder

Build reproducible, headless NixOS SD card images for Raspberry Pi 4 — entirely from macOS.

Images come pre-configured with WiFi, SSH key authentication, and your chosen packages. Just flash, boot, and `ssh` in.

## What you get

- **Headless WiFi** — connects to your network on first boot
- **SSH key auth** — password login disabled, secure by default
- **mDNS discovery** — reach your Pi as `<hostname>.local`
- **Reproducible** — pinned dependencies mean identical builds every time
- **No secrets in Git** — personal config lives in a gitignored `config.json`
- **Modular profiles** — compose feature modules into named images

## Prerequisites

- **macOS** on Apple Silicon (M1/M2/M3/M4)
- **Nix** — install with `curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install`
- An **SD card** (16GB or larger recommended)
- An **SSH key** — if you don't have one, run `ssh-keygen -t ed25519`

## Project structure

```
nixos-pi/
├── flake.nix               Nix entry point — defines profiles, packages, dev shell
├── flake.lock              Pinned dependency versions (committed for reproducibility)
├── shell.nix               nix-shell compatibility shim
├── local-config.nix        Reads config.json, applies personal settings (hostname, WiFi, SSH key)
├── build.sh                Builds an image for a given profile
├── generate-config.py      Interactive script that writes config.json
├── config.json             Your hostname, WiFi, SSH key (gitignored, generated)
├── modules/
│   ├── base.nix            Core system config: packages, SSH, firewall, boot
│   ├── docker.nix          Optional: Docker + docker-compose
│   └── tailscale.nix       Optional: Tailscale VPN
└── profiles/
    ├── base.nix            Minimal profile — base system only
    └── dev-box.nix         Development profile — base + Docker + Tailscale
```

## Step 1: Configure the Determinate Systems Linux builder

NixOS images target `aarch64-linux`, which macOS can't build natively. Determinate Systems Nix includes a native Linux builder powered by Apple Virtualization Framework.

To enable it, you need a Flakehub account — sign up at [flakehub.com](https://flakehub.com) and email your username to support@flakehub.com to have linux-builders enabled.

Then configure the builder with enough memory (the image build needs ~32GB):

Edit `/etc/determinate/config.json` (create it if it doesn't exist):

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

Restart the daemon:

```bash
sudo pkill determinate-nixd
determinate-nixd version
```

Confirm the output includes `native-linux-builder` in the enabled features list before proceeding.

See [Determinate Nix docs](https://docs.determinate.systems/determinate-nix/#determinate-nixd-configuration) for more details.

## Step 2: Enter the dev shell (optional)

The dev shell provides `python3`, `zstd`, and `git` if you don't have them on your system:

```bash
nix develop       # flake-based
# or
nix-shell         # classic nix-shell
```

## Step 3: Build the image

```bash
chmod +x build.sh
./build.sh                # builds the "base" profile (default)
./build.sh base           # same as above
./build.sh dev-box        # builds the "dev-box" profile (Docker + Tailscale)
```

The script will prompt you for:

- **Hostname** — how your Pi identifies itself on the network (default: `rpi`)
- **Username** — your login user (default: `alex`)
- **WiFi credentials** — auto-detected from your current connection, or entered manually. The password is retrieved from the macOS Keychain (you may be prompted for your macOS password)
- **SSH public key** — auto-detected from `~/.ssh/`

These values are saved to `config.json` (gitignored). On subsequent runs the script will ask if you want to reuse the existing config or regenerate it.

The first build takes 10–30 minutes as packages are downloaded from the NixOS binary cache. Subsequent builds are much faster.

The final image is saved to `artifacts/<hostname>.img`.

## Step 4: Flash to SD card

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

Replace `/dev/diskN` with your actual disk. Note the `r` prefix in `rdiskN` — this uses the raw device for faster writes.

## Step 5: Boot and connect

1. Insert the SD card into your Raspberry Pi 4
2. Connect power
3. Wait about 30–60 seconds for the Pi to boot and connect to WiFi
4. Connect via SSH:

```bash
ssh <username>@<hostname>.local
```

If `.local` resolution doesn't work immediately, wait another minute — the Avahi mDNS service needs time to advertise. You can also find the Pi's IP from your router's admin page:

```bash
ssh alex@192.168.1.xxx
```

## Profiles

Profiles compose feature modules into named images. Two are included out of the box:

| Profile | What's included |
|---------|----------------|
| `base` | Core system: WiFi, SSH, mDNS, standard packages |
| `dev-box` | Base + Docker + docker-compose + Tailscale VPN |

Build any profile:

```bash
./build.sh base
./build.sh dev-box
```

If you pass an unknown profile name, the script prints the available options and exits.

## Adding a new feature module

1. Create `modules/myfeature.nix` with an `options.rpi.myfeature.enable` option guarding all config behind `lib.mkIf`
2. Import it in a profile and set `rpi.myfeature.enable = true;`
3. If it's a new profile, add the name to the `profiles` list in `flake.nix`
4. Run `./build.sh myprofile`

Example module skeleton:

```nix
{ config, pkgs, lib, ... }:
{
  options.rpi.myfeature.enable = lib.mkEnableOption "My feature";

  config = lib.mkIf config.rpi.myfeature.enable {
    # services, packages, etc.
  };
}
```

## Customizing

### Adding packages

Edit `modules/base.nix` (or a profile-specific module) and add to `environment.systemPackages`:

```nix
environment.systemPackages = with pkgs; [
  vim git htop curl wget nodejs
  python3  # add here
];
```

### Changing timezone

Edit `time.timeZone` in `modules/base.nix`:

```nix
time.timeZone = "America/New_York";
```

Run `timedatectl list-timezones` for all options.

### Adding another WiFi network

Add networks when running `./build.sh` (the script will prompt), or on the running Pi:

```bash
sudo nmcli device wifi connect "OtherNetwork" password "password123"
```

### Keeping packages up to date

```bash
nix flake update
./build.sh
```

## Rebuilding

After changing any `.nix` file:

```bash
./build.sh [profile]
```

The build reuses cached packages, so only changed components are rebuilt. Reflash the new image following step 4.

Note: reflashing replaces the entire system — any state on the Pi (files you created, runtime-installed packages) will be lost. The NixOS configuration is the source of truth.

## Troubleshooting

### Can't find the Pi on the network

- Make sure the Pi has power and the SD card is seated properly
- Wait 60 seconds after power-on for WiFi and mDNS to initialize
- Check your router's connected devices list for the Pi's IP
- Verify the WiFi credentials in `config.json` are correct
- Try connecting by IP instead of `.local` hostname

### Build fails with "dirty Git tree"

Nix flakes require files to be tracked by Git. Stage any new files:

```bash
git add flake.nix modules/ profiles/
```

`config.json` must NOT be committed — it contains secrets, but it's read at build time via `builtins.readFile` outside of Git tracking.

### Build fails with module errors

If you see errors about missing kernel modules (like `sun4i-drm`), make sure `modules/base.nix` includes the `boot.initrd.availableKernelModules` override with `lib.mkForce`. The generic ARM SD image module tries to include drivers for non-Pi hardware.

### SSH connection refused

- The Pi's SSH server only accepts key-based authentication
- Make sure the SSH key in `config.json` matches your private key
- Verify with `ssh -v <user>@<hostname>.local` for detailed connection info

## How it works

1. **`build.sh`** gathers your personal config, writes `config.json`, then calls `nix build`
2. **`flake.nix`** maps each profile name to a `nixosSystem` call, combining the sd-card base module, the profile file (which imports feature modules), and `local-config.nix`
3. **`local-config.nix`** reads `config.json` at evaluation time and applies hostname, user account, WiFi credentials, and SSH key
4. **`nix build`** runs via the Linux builder, producing a compressed `.img.zst`
5. **`build.sh`** decompresses the image to `artifacts/<hostname>.img`

All packages come from NixOS 24.11 stable, pinned to a specific commit in `flake.lock`.
