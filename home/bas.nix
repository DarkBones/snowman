{ ... }: {
  imports = [ ./default.nix ];

  home.username = "bas";
  home.homeDirectory = "/home/bas";

  roles = {
    dev.enable = true;
    dotfiles = {
      enable = true;
      sparse = [ "nvim" ];
      linkMap = { ".config/nvim" = "nvim/.config/nvim"; };
    };
  };
}
