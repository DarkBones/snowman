{ lib, config, pkgs, ... }:
let cfg = config.roles.nvim;
in {
  options.roles.nvim.enable =
    lib.mkEnableOption "Neovim + required toolchain";
  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      neovim
      gcc
      gnumake
      pkg-config
      unzip
      git
      ripgrep

      fd
      fzf
      nodejs_20
      python3
      wl-clipboard
      xclip
    ];
  };
}
