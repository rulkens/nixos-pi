{
  config,
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
  options.rpi.mosquitto = {
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

  config = lib.mkIf config.rpi.mosquitto.enable {
    services.mosquitto = {
      enable = true;
      listeners =
        let
          baseUsers = {
            ${mqttUser} = { password = mqttPassword; };
            client = { password = mqttClientPassword; };
          };
          extraUserAttrs = lib.mapAttrs (_: pass: { password = pass; }) config.rpi.mosquitto.extraUsers;
          allUsers = baseUsers // extraUserAttrs;
        in
        [
          {
            # Plain MQTT
            port = config.rpi.mosquitto.port;
            omitPasswordAuth = false;
            users = allUsers;
          }
          {
            # MQTT over WebSockets
            port = config.rpi.mosquitto.wsPort;
            omitPasswordAuth = false;
            users = allUsers;
            settings.protocol = "websockets";
          }
        ];
    };

    networking.firewall.allowedTCPPorts = [
      config.rpi.mosquitto.port
      config.rpi.mosquitto.wsPort
    ];
  };
}
