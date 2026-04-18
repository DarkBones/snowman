# template/home/roles/dev.nix
#
# Example dev role. This lives in YOUR personal config repo
# (created from the Snowman template), not in the engine.
# Feel free to edit or delete it.

{
  lib,
  pkgs,
  pkgsUnstable,
  config,
  ...
}:
let
  cfg = config.roles.dev;
in
{
  options.roles.dev.enable = lib.mkEnableOption "Dev role";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgsUnstable; [
      neovim
      pkgs.git
      fzf
      cowsay
      pnpm
      docker
      gcc
    ];
  };
}
