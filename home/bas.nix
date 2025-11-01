{ pkgs, ... }: {
  home.username = "bas";
  home.homeDirectory = "/home/bas";
  home.stateVersion = "25.05";

  programs.home-manager.enable = true;

  home.packages = with pkgs; [ git neovim ripgrep tree ];

  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;
}
