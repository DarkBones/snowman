{ lib, dotfilesSources, ... }:
let
  # This assumes you have an input named 'bas-dotfiles' or similar.
  # The template uses 'dotfilesSources' which is passed from flake.nix
  dotfilesProd = dotfilesSources.bas or null;

  mode = builtins.getEnv "SNOWMAN_DOTFILES_MODE";
  useDev = mode == "dev";
in {
  # In PROD mode, manage ~/.config/nvim from the Nix store.
  # In DEV mode, Home Manager leaves ~/.config/nvim alone so you can point it
  # at ~/Developer/dotfiles manually.

  # Only apply this if we actually have a prod source available
  config = lib.mkIf (dotfilesProd != null) {
    home.file = lib.mkIf (!useDev) {
      ".config/nvim" = lib.mkForce {
        source = "${dotfilesProd}/nvim/.config/nvim";
        recursive = true;
      };
    };
  };
}
