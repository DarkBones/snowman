{
  release = "25.05";

  hosts = {
    vm-snowman = {
      system = "x86_64-linux";
      hostname = "vm-snowman"; # Optional, defaults to hosts.[name]
      # useDHCP = true; # Default if omitted
      hardware = {
        boot = { firmware = "bios"; }; # "bios" | "efi"
        disk = { device = "/dev/vda"; }; # VM disk
        fs = {
          type = "btrfs";
          rootLabel = "nixos";
          swapGiB = 0;
        };
      };
      users = [ "bas" ];
    };
    # macs later via nix-darwin
  };
  users = {
    bas = {
      uid = 1000;
      groups = [ "wheel" ];
      shell = "zsh";
      sshPubKeyFile = ./users/keys/bas.pub; # TODO: Key management
      initialPassword = "changeme";
      passwordSecret = ./secrets/bas-password.age; # TODO: Implement later as an optional
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
