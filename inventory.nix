{
  release = "25.05";

  hosts = {
    vm-snowman = {
      system = "x86_64-linux";
      hardware = "qemu"; # qemu | laptop | server
      hostname = "vm-snowman";
      users = [ "bas" ];
    };
    # macs later via nix-darwin
  };

  users = {
    bas = {
      uid = 1000;
      groups = [ "wheel" ];
      shell = "zsh";
      sshPubKeyFile = ./users/keys/bas.pub;
      passwordSecret = ./secrets/bas-password.age;
      roles = {
        dev.enable = true;
        dotfiles = {
          enable = true;
          linkMap = { ".config/nvim" = "nvim/.config/nvim"; };
          sparse = [ "nvim" ];
        };
      };
    };
  };
}
