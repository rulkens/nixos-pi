# =========================================================
# Home Assistant — home automation platform
# =========================================================
# Runs Home Assistant as a native NixOS service. Most
# integrations (devices, automations, dashboards) are
# configured through the web UI after first boot.
#
# Enable in a profile:
#
#   rpi.services.homeAssistant = {
#     enable = true;
#     port   = 8123;    # optional, this is the default
#
#     zha = {
#       enable = true;
#       device = "/dev/serial/by-id/usb-ITead_Sonoff_Zigbee-if00";
#     };
#   };
#
# First boot
# ----------
# Navigate to http://<hostname>.local:8123 and follow the
# onboarding wizard to create your admin account.
#
# ZHA (Zigbee Home Automation)
# ----------------------------
# When zha.enable = true, the ZHA Python packages are included
# and the hass user is added to the dialout group for USB access.
# To find the stable device path on a running Pi, run:
#
#   ls /dev/serial/by-id/
#
# Then configure ZHA in the HA UI:
# Settings → Devices & Services → Add Integration → Zigbee Home Automation
# and enter the device path when prompted.
#
# MQTT
# ----
# If the mosquitto module is also enabled, connect HA to it in
# the UI: Settings → Devices & Services → Add Integration → MQTT
# Broker: localhost, port: 1883, and use the credentials from config.json.
# =========================================================

{
  config,
  lib,
  ...
}:
let
  cfg = config.rpi.services.homeAssistant;
in
{
  options.rpi.services.homeAssistant = {
    enable = lib.mkEnableOption "Home Assistant home automation platform";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8123;
      description = "TCP port the Home Assistant web interface listens on.";
    };

    zha = {
      enable = lib.mkEnableOption "ZHA Zigbee Home Automation integration";

      device = lib.mkOption {
        type = lib.types.str;
        default = "/dev/ttyUSB0";
        description = ''
          Path to the Zigbee USB coordinator. The hass user is added to
          the dialout group so it can access the device. For a stable path
          that survives reboots, use /dev/serial/by-id/<device>.
        '';
        example = "/dev/serial/by-id/usb-ITead_Sonoff_Zigbee_3.0_USB_Dongle_Plus-if00-port0";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.home-assistant = {
      enable = true;

      # mqtt requires paho-mqtt and zha requires zigpy etc.
      # extraComponents pulls in the Python deps for each integration.
      extraComponents = [ "mqtt" "hue" ] ++ lib.optionals cfg.zha.enable [ "zha" ];

      # Minimal declarative configuration. All integrations,
      # automations, and dashboards are managed through the UI;
      # they are stored in /var/lib/hass/.storage/ and are not
      # affected by changes to this file.
      #
      # We list components explicitly instead of using default_config,
      # which would pull in integrations (otbr, thread, etc.) whose
      # Python packages aren't available, causing boot errors.
      config = {
        homeassistant = { };
        frontend = { };
        history = { };
        logbook = { };
        http = {
          server_port = cfg.port;
        };
      };
    };

    # The ZHA integration communicates with the Zigbee coordinator
    # over a serial USB device. Adding hass to dialout grants access
    # to /dev/ttyUSB* and /dev/ttyACM* without broad permissions.
    users.users.hass.extraGroups = lib.mkIf cfg.zha.enable [ "dialout" ];

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
