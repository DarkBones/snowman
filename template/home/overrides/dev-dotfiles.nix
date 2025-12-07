{ lib, config, ... }:
let
  # Get the roles configuration for the current user
  # We assume the user has enabled the dotfiles role
  dotfilesCfg = config.roles.dotfiles or { };

  mode = builtins.getEnv "SNOWMAN_DOTFILES_MODE";
  isDev = mode == "dev";

  # Get all targets defined in the user's linkMap
  # e.g. { ".config/nvim" = "..."; ".zshrc" = "..."; }
  targets = builtins.attrNames (dotfilesCfg.linkMap or { });
in {
  # In DEV mode:
  # Iterate over every target in the linkMap and force it to be unmanaged (enable = false).
  # This tells Home Manager: "Hands off these files, the user is managing them manually."
  home.file =
    lib.mkIf isDev (lib.genAttrs targets (target: { enable = false; }));
}
