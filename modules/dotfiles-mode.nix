{ lib, ... }:
let
  rawMode = builtins.getEnv "SNOWMAN_DOTFILES_MODE";
  mode = if rawMode == "dev" || rawMode == "prod" then rawMode else "prod";
in
{
  options.snowman.dotfiles = {
    mode = lib.mkOption {
      type = lib.types.enum [
        "dev"
        "prod"
      ];
      readOnly = true;
      default = mode;
      description = "Resolved dotfiles mode for system modules.";
    };

    isDev = lib.mkOption {
      type = lib.types.bool;
      readOnly = true;
      default = mode == "dev";
      description = "Whether system dotfiles mode is dev.";
    };
  };
}
