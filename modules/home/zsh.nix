{ ... }:
{
  programs.zsh = {
    enable = true;
    oh-my-zsh = {
      enable = true;
      theme = "crunch";
      plugins = [
        "git"  # git aliases and branch in prompt
        "sudo" # press ESC twice to prepend sudo
        "z"    # frecency-based cd
        "npm"  # npm aliases and completions
      ];
    };
  };
}
