{
  uid = 1001;
  groups = [ "wheel" ];
  shell = "zsh";
  sshPubKeyFile = ../keys/bob.pub;

  roles = {
    # dev.enable = true;
    # dotfiles = {
    #   enable = true;
    #   sparse = [ "nvim" ];
    #   linkMap = { ".config/nvim" = "nvim/.config/nvim"; };
    # };
  };
}
