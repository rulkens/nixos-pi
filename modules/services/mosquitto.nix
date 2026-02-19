{
  config,
  pkgs,
  lib,
  ...
}:
let
  configPath = builtins.getEnv "NIXOS_PI_CONFIG";
  localCfg = builtins.fromJSON (builtins.readFile configPath);
  mqttUser = localCfg.username;
  mqttPassword = localCfg.mqtt.password;
  mqttClientPassword = localCfg.mqtt.clientPassword;

in
{
  options.rpi.services.mosquitto = {
    enable = lib.mkEnableOption "Mosquitto MQTT broker";
    port = lib.mkOption {
      type = lib.types.port;
      default = 1883;
      description = "Port for the plain MQTT listener.";
    };
    wsPort = lib.mkOption {
      type = lib.types.port;
      default = 9001;
      description = "Port for the MQTT-over-WebSockets listener.";
    };
    extraUsers = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional MQTT users (name → plaintext password) added to all listeners.";
    };
  };

  config = lib.mkIf config.rpi.services.mosquitto.enable {
    services.mosquitto = {
      enable = true;
      listeners =
        let
          baseUsers = {
            ${mqttUser} = {
              password = mqttPassword;
              acl = [ "readwrite #" ];
            };
            client = {
              password = mqttClientPassword;
              acl = [ "readwrite #" ];
            };
          };
          extraUserAttrs = lib.mapAttrs (_: pass: {
            password = pass;
            acl = [ "readwrite #" ];
          }) config.rpi.services.mosquitto.extraUsers;
          allUsers = baseUsers // extraUserAttrs;
        in
        [
          {
            # Plain MQTT
            port = config.rpi.services.mosquitto.port;
            omitPasswordAuth = false;
            users = allUsers;
          }
          {
            # MQTT over WebSockets
            port = config.rpi.services.mosquitto.wsPort;
            omitPasswordAuth = false;
            users = allUsers;
            settings.protocol = "websockets";
          }
        ];
    };

    # Restart mosquitto whenever its generated config files change.
    # Without this, NixOS won't restart the service when ACL or
    # password files are updated in place at their fixed /etc/ paths.
    systemd.services.mosquitto.restartTriggers = [
      mqttUser
      mqttPassword
      mqttClientPassword
      (builtins.toJSON config.rpi.services.mosquitto.extraUsers)
    ];

    # mosquitto_pub / mosquitto_sub CLI tools for debugging.
    environment.systemPackages = [ pkgs.mosquitto ];

    networking.firewall.allowedTCPPorts = [
      config.rpi.services.mosquitto.port
      config.rpi.services.mosquitto.wsPort
    ];
  };
}
