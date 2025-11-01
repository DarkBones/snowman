{ pkgs, lib, config, ... }:
let cfg = config.roles.dev;
in {
  options.roles.dev.enable = lib.mkEnableOption "Dev role";
  config = lib.mkIf cfg.enable {
    programs.home-manager.enable = true;
    home.packages = with pkgs; [ git neovim ripgrep tree ];
    programs.direnv.enable = true;
    programs.direnv.nix-direnv.enable = true;
  };
}
