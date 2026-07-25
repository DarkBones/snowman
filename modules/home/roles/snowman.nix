{
  lib,
  config,
  pkgs,
  currentHost,
  ...
}:
let
  cfg = config.roles.snowman;
  username = config.home.username;
  configName = "${username}@${currentHost}";
  isDarwin = pkgs.stdenv.isDarwin;
in
{
  options.roles.snowman = {
    enable = lib.mkEnableOption "Snowman CLI for standalone home-manager";
    flakePath = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/snowman-config";
      description = "Default path to the snowman flake";
    };
  };

  # Only apply on Darwin (macOS) - on NixOS, the system module provides snowman
  config = lib.mkIf (cfg.enable && isDarwin) {
    home.file.".config/snowman/flake".text = cfg.flakePath + "\n";

    home.packages = [
      (import ../../../lib/snowman-cli.nix {
        inherit pkgs;
        variant = "home-manager";
        target = configName;
        modeFile = "$HOME/.config/snowman/dotfiles-mode";
        flakeFile = "$HOME/.config/snowman/flake";
        fallbackFlake = cfg.flakePath;
        extraPath = "/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin";
      })
    ];
  };
}
