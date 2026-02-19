# NixOS Raspberry Pi 4 Image Builder for macOS

> **macOS only.** This project uses the Determinate Systems native Linux builder, which relies on Apple Virtualization Framework. It will not work on Linux or Windows.

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
- **Determinate Systems Nix** — this project requires it specifically, as it includes the native Linux builder needed to cross-compile for `aarch64-linux`:
  ```bash
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
  ```
- An **SD card** (16 GB or larger recommended)
- An **SSH key** — if you don't have one, run `ssh-keygen -t ed25519`

## Project structure

```
nixos-pi/
├── flake.nix                    Entry point — profiles, packages, dev shell
├── flake.lock                   Pinned dependency versions (committed for reproducibility)
├── shell.nix                    nix-shell compatibility shim
├── build-image.sh               Build an SD card image for a profile
├── deploy.sh                    Deploy a config change to a running Pi over SSH
├── common.sh                    Shared functions used by build and deploy scripts
├── generate-config.py           Interactive script that writes config.json
├── deploy-config.json.example   Template for deploy-config.json
├── config.json                  Your secrets: hostname, WiFi, SSH key (gitignored)
├── modules/
│   ├── default.nix              Root module — imports all sub-trees
│   ├── home/                    Home-manager user environment
│   │   ├── default.nix          Enables zsh as login shell
│   │   ├── zsh.nix              oh-my-zsh with plugins
│   │   └── fastfetch.nix        System info on login
│   ├── services/                Opt-in service modules
│   │   ├── avahi.nix            mDNS / .local discovery
│   │   ├── docker.nix           Docker + docker-compose
│   │   ├── mosquitto.nix        MQTT broker
│   │   ├── samba.nix            SMB file share
│   │   ├── tailscale.nix        Tailscale VPN
│   │   └── zigbee2mqtt.nix      Zigbee coordinator bridge
│   └── system/                  Base system configuration
│       ├── boot.nix             Bootloader, kernel, initrd
│       ├── i18n.nix             Timezone and locale
│       ├── nix.nix              Nix daemon settings and garbage collection
│       ├── packages.nix         System-wide packages
│       ├── user.nix             User account and sudo
│       ├── graphics/
│       │   └── headless-gl.nix  Xvfb + OpenGL for off-screen rendering
│       └── networking/
│           ├── firewall.nix     Firewall rules
│           ├── networkmanager.nix  Hostname and WiFi profiles
│           └── openssh.nix      SSH daemon and host key
└── profiles/
    ├── base.nix                 Minimal headless Pi
    └── home-automation.nix      MQTT, Zigbee2MQTT, Samba, headless GL, home-manager
```

## Step 1: Configure the Determinate Systems Linux builder

NixOS images target `aarch64-linux`, which macOS can't build natively. Determinate Systems Nix includes a native Linux builder powered by Apple Virtualization Framework.

To enable it, you need a Flakehub account — sign up at [flakehub.com](https://flakehub.com) and email your username to support@flakehub.com to have linux-builders enabled.

Then configure the builder with enough memory (the image build needs ~32 GB):

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
nix develop
```

Running `nix develop` will print available commands and profiles.

## Step 3: Build the image

```bash
./build-image.sh                   # builds the "base" profile (default)
./build-image.sh base              # same as above
./build-image.sh home-automation   # builds the home automation profile
```

The script will prompt you for:

- **Hostname** — how your Pi identifies itself on the network (default: `rpi`)
- **Username** — your login user
- **WiFi credentials** — auto-detected from your current connection, or entered manually. The password is retrieved from the macOS Keychain (you may be prompted for your macOS password)
- **SSH public key** — auto-detected from `~/.ssh/`
- **Service passwords** — Samba, MQTT, and Zigbee2MQTT credentials (only prompted for services enabled in the profile)

These values are saved to `config.json` (gitignored). On subsequent runs the script will ask if you want to reuse the existing values or update them.

> **Security notice:** All secrets are baked into the SD card image at build time. Treat a built image with the same care as a password export — do not share it or store it in an untrusted location.

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
ssh <username>@192.168.1.xxx
```

## Deploying config changes to a running Pi

Once a Pi is running, you don't need to reflash for config changes. Use `deploy.sh` to apply changes over SSH:

```bash
# Copy deploy-config.json.example and fill in your Pi's address
cp deploy-config.json.example deploy-config.json

./deploy.sh base                       # deploy without regenerating config
./deploy.sh --reconfigure base         # prompt to update config.json first
```

`deploy-config.json` holds the target host and user for SSH — it is gitignored since it may contain a local IP address.

## Profiles

Profiles compose feature modules into named images. Two are included out of the box:

| Profile | What's included |
|---|---|
| `base` | Minimal headless Pi — SSH, WiFi, mDNS, standard packages |
| `home-automation` | Mosquitto MQTT, Zigbee2MQTT, Samba file share, headless GL, zsh + fastfetch |

Build any profile:

```bash
./build-image.sh base
./build-image.sh home-automation
```

To add a new profile, create `profiles/myprofile.nix` and add `"myprofile"` to the `profiles` list in `flake.nix`.

## Adding a new service module

1. Create `modules/services/myservice.nix`:

```nix
{ config, pkgs, lib, ... }:
{
  options.rpi.services.myservice.enable =
    lib.mkEnableOption "short description";

  config = lib.mkIf config.rpi.services.myservice.enable {
    services.myservice.enable = true;
    networking.firewall.allowedTCPPorts = [ 1234 ];
  };
}
```

2. Add `./myservice.nix` to the imports in `modules/services/default.nix`
3. Enable it in a profile: `rpi.services.myservice.enable = true;`

See `modules/services/default.nix` for a full guide on the module authoring pattern.

## Customizing

### Adding system packages

Edit `modules/system/packages.nix`:

```nix
environment.systemPackages = with pkgs; [
  vim git htop curl wget nodejs_24
  python3  # add here
];
```

### Changing timezone or locale

Edit `modules/system/i18n.nix`:

```nix
time.timeZone = "America/New_York";
i18n.defaultLocale = "en_US.UTF-8";
```

Run `timedatectl list-timezones` for all timezone options.

### Adding another WiFi network

Add networks when running `./build-image.sh` (the script will prompt), or on the running Pi:

```bash
sudo nmcli device wifi connect "OtherNetwork" password "password123"
```

### Keeping packages up to date

```bash
nix flake update
./build-image.sh [profile]
```

## Rebuilding and reflashing

After changing any `.nix` file, rebuild and reflash:

```bash
./build-image.sh [profile]
```

The build reuses cached packages, so only changed components are rebuilt. Reflash the new image following step 4.

**Note:** reflashing replaces the entire system — any state on the Pi (files you created, runtime-installed packages) will be lost. The NixOS configuration is the source of truth. For config-only changes on a running Pi, use `deploy.sh` instead.

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

`config.json` must NOT be committed — it contains secrets and is read at build time outside of Git tracking.

### Build fails with module errors

If you see errors about missing kernel modules (like `sun4i-drm`), make sure `modules/system/boot.nix` includes the `boot.initrd.availableKernelModules` override with `lib.mkForce`. The generic ARM SD image module tries to include drivers for non-Pi hardware.

### SSH connection refused

- The Pi's SSH server only accepts key-based authentication
- Make sure the SSH key in `config.json` matches your private key
- Verify with `ssh -v <user>@<hostname>.local` for detailed connection info

## How it works

1. **`build-image.sh`** calls `generate-config.py` to collect personal config and write `config.json`, then calls `nix build --impure`
2. **`flake.nix`** maps each profile name to a `nixosSystem` call, combining the SD card base module and the profile file (which imports feature modules from `modules/`)
3. **Feature modules** read secrets from `config.json` at evaluation time via `builtins.getEnv "NIXOS_PI_CONFIG"` — this is why `--impure` is required
4. **`nix build`** runs via the Determinate Systems Linux builder, producing a `.img` file
5. The image is symlinked into `artifacts/<hostname>.img`

All packages come from NixOS 25.05 stable, pinned to a specific commit in `flake.lock`.

---

*This repository was built with the assistance of [Claude](https://claude.ai) (Anthropic).*
