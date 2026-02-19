{ ... }:
{
  programs.fastfetch = {
    enable = true;
    settings = {
      logo = {
        source = "nixos";
        type = "builtin";
        padding = {
          right = 1;
        };
      };
    };
  };
}
