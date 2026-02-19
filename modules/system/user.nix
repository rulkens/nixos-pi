{ ... }:
let
  configPath = builtins.getEnv "NIXOS_PI_CONFIG";
  localCfg = builtins.fromJSON (builtins.readFile configPath);
in
{
  users.users.${localCfg.username} = {
    isNormalUser = true;

    # "wheel" grants sudo access
    # "networkmanager" allows managing WiFi connections
    extraGroups = [
      "wheel"
      "networkmanager"
    ];

    # SSH public key — the only way to log in since password
    # auth is disabled in openssh.nix.
    openssh.authorizedKeys.keys = [ localCfg.sshPubKey ];
  };

  # Allow wheel group members to use sudo without a password.
  # Required since password auth is disabled.
  security.sudo.wheelNeedsPassword = false;
}
