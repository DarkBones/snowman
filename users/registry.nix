{
  bas = {
    uid = 1000;
    groups = [ "wheel" ];
    shell = "zsh";
    sshPubKeyFile = ../keys/bas.pub;
    passwordSecret = ../secrets/bas-password.age;

    roles = {
      dev.enable = true;
      dotfiles = {
        enable = true;
        sparse = [ "nvim" ];
        linkMap = { ".config/nvim" = "nvim/.config/nvim"; };
      };
    };
  };
}
