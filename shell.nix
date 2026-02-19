# Compatibility shim so that `nix-shell` gives the same environment as
# `nix develop`. Forwards to the devShell defined in flake.nix.
#
# nix-shell evaluates impurely by default, so builtins.getFlake can
# resolve the local path without needing --impure explicitly.
(builtins.getFlake (toString ./.)).devShells.${builtins.currentSystem}.default
