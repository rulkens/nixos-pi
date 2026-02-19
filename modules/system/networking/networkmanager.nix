{ ... }:
let
  configPath = builtins.getEnv "NIXOS_PI_CONFIG";
  localCfg = builtins.fromJSON (builtins.readFile configPath);
in
{
  # Hostname is set here alongside the network config since it is
  # announced on the local network and tightly coupled to mDNS/DHCP identity.
  networking.hostName = localCfg.hostname;

  # NetworkManager manages both wired and wireless connections and handles
  # automatic reconnection when a network becomes available again.
  networking.networkmanager.enable = true;

  # Bake WiFi credentials into the image using NetworkManager's
  # ensureProfiles mechanism. Profiles are written to
  # /etc/NetworkManager/system-connections/ at activation time and
  # connect automatically on boot.
  #
  # localCfg.wifi is a list of { ssid, password } objects from config.json.
  # builtins.listToAttrs converts it to the attrset that ensureProfiles
  # expects, keyed by SSID.
  networking.networkmanager.ensureProfiles.profiles = builtins.listToAttrs (
    map (network: {
      name = network.ssid;
      value = {
        connection = {
          id = network.ssid;
          type = "wifi";
          autoconnect = true;
          autoconnect-priority = 100;
        };
        wifi = {
          ssid = network.ssid;
          mode = "infrastructure";
        };
        wifi-security = {
          key-mgmt = "wpa-psk";
          psk = network.password;
        };
        ipv4.method = "auto";
        ipv6.method = "auto";
      };
    }) localCfg.wifi
  );
}
