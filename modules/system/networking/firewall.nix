{ ... }:
{
  networking.firewall = {
    # NixOS ships with a firewall disabled by default. We enable it
    # so that only explicitly declared ports are reachable.
    enable = true;

    # Port 22 — SSH. Required for headless administration.
    #
    # Other modules open additional ports by appending to allowedTCPPorts
    # or allowedUDPPorts in their own files. The NixOS module system merges
    # all declarations, so there is no need to list them here:
    #
    #   mosquitto.nix   — 1883 (MQTT), 9001 (MQTT over WebSocket)
    #   zigbee2mqtt.nix — 8080 (web UI)
    #   samba.nix       — 139, 445 (SMB) via openFirewall = true
    #   tailscale.nix   — 41641/udp (WireGuard tunnel)
    allowedTCPPorts = [ 22 ];
  };
}
