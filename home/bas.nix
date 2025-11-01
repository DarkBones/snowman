{ ... }: {
  imports = [ ./default.nix ];

  home.username = "bas";
  home.homeDirectory = "/home/bas";
  home.stateVersion = "25.05";

  roles = { dev.enable = true; };
}
