{ ... }:
{
  imports = [ ../modules ];

  rpi = {
    services = {
      # mDNS — lets you reach the Pi as <hostname>.local on the local network.
      avahi.enable = true;

      # SMB file share — exposes the user's home directory on the
      # local network as \\<hostname>\<username>.
      samba.enable = true;

      # MQTT broker — listens on port 1883 (TCP) and 9001 (WebSocket).
      # Used as the message bus between home automation components.
      mosquitto.enable = true;

      # Zigbee coordinator bridge — translates between the Zigbee radio
      # and MQTT so that devices appear in Home Assistant and similar.
      zigbee2mqtt.enable = true;

      # Docker container runtime + docker-compose.
      # Run `docker ps` after boot to verify it is working.
      # docker.enable = true;

      # Tailscale VPN — run `sudo tailscale up` after first boot to
      # authenticate and join your tailnet.
      # tailscale.enable = true;
    };

    system = {
      # Headless OpenGL — installs Mesa / Xvfb so that GL applications
      # can render off-screen without a physical display attached.
      headlessGL.enable = true;
    };

    # Sets up the user's home with zsh + oh-my-zsh and fastfetch on login.
    home.enable = true;
  };
}
