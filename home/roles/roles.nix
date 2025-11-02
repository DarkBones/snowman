{ lib, config, ... }:
let cfg = config.roles.dotfiles;
in {
  options.roles.dotfiles = {
    enable = lib.mkEnableOption "Dotfiles role";

    repo = lib.mkOption {
      type = lib.types.str;
      default =
        "github-dotfiles:DarkBones/dotfiles.git"; # TODO: Make configurable
    };
    branch = lib.mkOption {
      type = lib.types.str;
      default = "main";
    };
    dir = lib.mkOption {
      type = lib.types.str;
      default = "$HOME/.local/share/dotfiles";
    };
    sparse = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "nvim" ];
    };
    linkMap = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { ".config/nvim" = "nvim"; };
    };
  };

  config = lib.mkIf cfg.enable {
    snowman.dotfiles = {
      enable = true;
      inherit (cfg) repo branch dir sparse linkMap;
    };
  };
}
