{ config, pkgs, lib, ... }:
let
  configPath = builtins.getEnv "NIXOS_PI_CONFIG";
  localCfg = builtins.fromJSON (builtins.readFile configPath);
  mqttUser = localCfg.username;
  mqttPassword = localCfg.mqtt.password;
  mqttClientPassword = localCfg.mqtt.clientPassword;

  # Generate a per-user mosquitto passwd file at build time.
  # mosquitto_passwd -b -c produces a file in "user:$7$hash" format,
  # which is what services.mosquitto.listeners.*.users.*.passwordFile expects.
  mkPasswdFile = user: pass: pkgs.runCommand "mqtt-passwd-${user}" {
    nativeBuildInputs = [ pkgs.mosquitto ];
  } ''
    mosquitto_passwd -b -c "$out" '${user}' '${pass}'
  '';

  userPasswdFile   = mkPasswdFile mqttUser mqttPassword;
  clientPasswdFile = mkPasswdFile "client" mqttClientPassword;
in
{
  options.rpi.mosquitto.enable = lib.mkEnableOption "Mosquitto MQTT broker";

  config = lib.mkIf config.rpi.mosquitto.enable {
    services.mosquitto = {
      enable = true;
      listeners = [
        {
          # Plain MQTT
          port = 1883;
          omitPasswordAuth = false;
          users.${mqttUser} = { passwordFile = userPasswdFile; };
          users.client      = { passwordFile = clientPasswdFile; };
        }
        {
          # MQTT over WebSockets
          port = 9001;
          omitPasswordAuth = false;
          users.${mqttUser} = { passwordFile = userPasswdFile; };
          users.client      = { passwordFile = clientPasswdFile; };
          settings.protocol = "websockets";
        }
      ];
    };

    networking.firewall.allowedTCPPorts = [ 1883 9001 ];
  };
}
