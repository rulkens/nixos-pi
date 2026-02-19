{ ... }:
let
  configPath = builtins.getEnv "NIXOS_PI_CONFIG";
  localCfg = builtins.fromJSON (builtins.readFile configPath);
in
{
  # A stable host key is baked into the image so the fingerprint never
  # changes across re-provisions. Without this, every flash triggers a
  # "REMOTE HOST IDENTIFICATION HAS CHANGED" warning on connecting clients.
  environment.etc."ssh/ssh_host_ed25519_key" = {
    mode = "0600";
    text = localCfg.hostKey;
  };
  environment.etc."ssh/ssh_host_ed25519_key.pub" = {
    text = localCfg.hostKeyPub;
  };

  services.openssh = {
    enable = true;

    hostKeys = [
      { type = "ed25519"; path = "/etc/ssh/ssh_host_ed25519_key"; }
    ];

    settings = {
      # Disable password authentication — only SSH keys allowed.
      # This is much more secure. If someone discovers your Pi
      # on the network, they can't brute-force a password.
      PasswordAuthentication = false;

      # Disable keyboard-interactive auth (another password method).
      KbdInteractiveAuthentication = false;

      # Don't allow root to log in via SSH. You'll log in as
      # your user and use sudo if you need root.
      PermitRootLogin = "no";
    };
  };

}
