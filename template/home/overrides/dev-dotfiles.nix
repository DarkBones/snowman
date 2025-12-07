{ lib, config, dotfilesSources, ... }:
let
  cfg = config.roles.dotfiles or { };

  # 1. Determine Prod Source (Repo)
  # Try sourceKey first (e.g. "bas"), fallback to username
  sourceKey = cfg.sourceKey or config.home.username;
  dotfilesRepo = dotfilesSources.${sourceKey} or null;

  # 2. Determine Mode
  mode = builtins.getEnv "SNOWMAN_DOTFILES_MODE";
  isDev = mode == "dev";

in {
  # Only run if dotfiles role is enabled
  config = lib.mkIf (cfg.enable or false) {

    # Iterate over the linkMap from inventory
    # and generate the correct home.file logic for each file
    home.file = lib.mapAttrs (target: srcPath:
      if isDev then {
        enable = false;
      } else if dotfilesRepo != null then {
        source = "${dotfilesRepo}/${srcPath}";
        recursive =
          false; # Important: keep false to avoid overwriting repo in Dev mistakes
      } else
        { }) (cfg.linkMap or { });
  };
}
