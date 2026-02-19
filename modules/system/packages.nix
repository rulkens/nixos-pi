{ pkgs, ... }:
{
  # Packages installed into the system profile and available to all users.
  # This is the right place for tools that are part of the base system
  # experience — things you always expect to find regardless of which user
  # you are logged in as or which profile was built.
  #
  # Prefer adding personal or development tools to your home-manager
  # config instead, so they don't bloat images that don't need them.
  environment.systemPackages = with pkgs; [
    vim        # Text editor
    git        # Version control
    htop       # Interactive process viewer
    curl       # HTTP client
    wget       # File downloader
    nodejs_24  # Node.js runtime
  ];
}
