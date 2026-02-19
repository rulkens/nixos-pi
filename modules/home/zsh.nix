{ config, lib, ... }:
{
  programs.zsh = {
    enable = true;
    loginExtra = lib.optionalString config.rpi.home.fastfetch.enable "fastfetch";
    oh-my-zsh = {
      enable = true;
      theme = "crunch";
      plugins = [
        "git" # git aliases and branch in prompt
        "sudo" # press ESC twice to prepend sudo
        "z" # frecency-based cd
        "npm" # npm aliases and completions
      ];
    };
  };
}
