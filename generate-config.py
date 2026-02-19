#!/usr/bin/env python3
# =========================================================
# generate-config.py — Collect and write config.json
# =========================================================
# Prompts for personal configuration values, auto-detects
# SSH public key and WiFi credentials, and writes config.json
# which is read by local-config.nix at build time.
#
# Called by build.sh. Writes config.json to the path given
# as the first argument (defaults to ./config.json).
#
# Usage:
#   python3 generate-config.py [/path/to/config.json]
# =========================================================

import json
import os
import subprocess
import sys
from pathlib import Path


# ---------------------------------------------------------
# Helpers
# ---------------------------------------------------------

def prompt(message, default=None):
    """Prompt the user for input, showing the default value."""
    if default:
        display = f"  {message} [{default}]: "
    else:
        display = f"  {message}: "
    value = input(display).strip()
    return value if value else default


def prompt_secret(message):
    """Prompt for a secret value without echoing input."""
    import getpass
    return getpass.getpass(f"  {message}: ").strip()


def detect_current_ssid():
    """Return the SSID of the currently connected WiFi network on macOS."""
    try:
        result = subprocess.run(
            ["networksetup", "-getairportnetwork", "en0"],
            capture_output=True, text=True
        )
        # Output is like: "Current Wi-Fi Network: MyNetwork"
        parts = result.stdout.strip().split(": ", 1)
        if len(parts) == 2:
            return parts[1]
    except FileNotFoundError:
        pass
    return None


def get_keychain_password(ssid):
    """Retrieve a WiFi password from the macOS Keychain."""
    try:
        result = subprocess.run(
            ["security", "find-generic-password",
             "-D", "AirPort network password", "-a", ssid, "-w"],
            capture_output=True, text=True
        )
        if result.returncode == 0:
            return result.stdout.strip()
    except FileNotFoundError:
        pass
    return None


def detect_ssh_pubkey():
    """Return the first SSH public key found in ~/.ssh/."""
    candidates = [
        Path.home() / ".ssh" / "id_ed25519.pub",
        Path.home() / ".ssh" / "id_rsa.pub",
        Path.home() / ".ssh" / "id_ecdsa.pub",
    ]
    for path in candidates:
        if path.exists():
            return path.read_text().strip(), str(path)
    return None, None


# ---------------------------------------------------------
# Collection functions
# ---------------------------------------------------------

def collect_wifi_network():
    """Prompt for a single WiFi network, returning {ssid, password}."""
    auto = prompt("Auto-detect WiFi from current connection? [Y/n]", default="Y")

    ssid = None
    if auto.upper() != "N":
        ssid = detect_current_ssid()
        if ssid:
            print(f"  ✓ Currently connected to: {ssid}")
        else:
            print("  Could not detect current WiFi. Falling back to manual entry.")

    if not ssid:
        ssid = prompt("WiFi network name (SSID)")
        if not ssid:
            print("  ERROR: SSID cannot be empty.")
            return None

    print()
    print("  Retrieving WiFi password from macOS Keychain...")
    print("  (You may be prompted for your macOS login password)")
    password = get_keychain_password(ssid)

    if password:
        print(f"  ✓ Password retrieved from Keychain")
    else:
        print("  Could not retrieve from Keychain. Falling back to manual entry.")
        password = prompt_secret("WiFi password")
        if not password:
            print("  ERROR: Password cannot be empty.")
            return None

    return {"ssid": ssid, "password": password}


def collect_wifi_networks():
    """Collect one or more WiFi networks in a loop."""
    networks = []
    while True:
        network = collect_wifi_network()
        if network:
            networks.append(network)
            print(f"  ✓ Added: {network['ssid']}")
        print()
        add_more = prompt("Add another WiFi network? [y/N]", default="N")
        if add_more.upper() != "Y":
            break
    return networks


# ---------------------------------------------------------
# Main
# ---------------------------------------------------------

def main():
    config_path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("config.json")

    print()
    print("[2/5] Gathering configuration...")
    print()

    hostname = prompt("Hostname for the Pi", default="rpi")
    username = prompt("Username", default="pi")

    print()
    networks = collect_wifi_networks()
    if not networks:
        print("  ERROR: At least one WiFi network is required.")
        sys.exit(1)

    print()
    print("  Detecting SSH public key...")
    pubkey, keyfile = detect_ssh_pubkey()
    if not pubkey:
        print("  No SSH public key found in ~/.ssh/")
        print("  Generate one with: ssh-keygen -t ed25519")
        sys.exit(1)
    print(f"  ✓ Found: {keyfile}")

    # --- Samba password ---
    print()
    samba_password = prompt_secret("Samba share password")

    # -- Summary --
    print()
    print("  Configuration summary:")
    print(f"    Hostname:  {hostname}")
    print(f"    Username:  {username}")
    print(f"    SSH Key:   {pubkey[:30]}...")
    print(f"    WiFi networks:")
    for n in networks:
        print(f"      - {n['ssid']}")
    print()

    confirm = prompt("Proceed? [Y/n]", default="Y")
    if confirm.upper() == "N":
        print("  Aborted.")
        sys.exit(0)

    config = {
        "hostname": hostname,
        "username": username,
        "sshPubKey": pubkey,
        "wifi": networks,
        "sambaPassword": samba_password,
    }

    config_path.write_text(json.dumps(config, indent=2))
    print()
    print(f"  ✓ config.json written to {config_path}")


if __name__ == "__main__":
    main()