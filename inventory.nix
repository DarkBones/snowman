{
  release = "25.05";

  hosts = {
    vm-snowman = {
      system = "x86_64-linux";
      mutableUsers = false; # Defaults to `true` if omitted
      hostname = "vm-snowman"; # Optional, defaults to hosts.[name]
      provision.disk.enable = false;
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

      bootstrap.usb = {
        enable = false;
        label = "SNOWMANKEY";
        path = "/mnt/snowman";
        keyFile = "snowman.key";
        fsType = "vfat";
      };
    };
    # macs later via nix-darwin
  };
  users = {
    bas = {
      uid = 1000;
      homeManaged = true;
      groups = [ "wheel" ];
      shell = "zsh";
      sshPubKeys = [ (builtins.readFile ./users/keys/bas-arch.pub) ];

      sopsSecretsFile = ./users/secrets/bas_secrets.yml;
      sopsSecretKeys = [ "password" "password_test" ];

      # initialPassword = "changeme"; # default plain text password
      sopsPasswordKey =
        "password"; # <- The secret key used for initializing the user's password (must be one of the `sopSecretKeys`)

      roles = {
        dev.enable = true;
        ssh.enable = true;
        secrets.enable = true;
        dotfiles = {
          enable = true;
          repo = "git@github.com:DarkBones/.dotfiles.git";
          dir = "Developer/dotfiles";
          branch = "main";
          sparse = [ "nvim" ];
          # deployKeySecret = ./secrets/dotfiles-bas.age;
          linkMap = { ".config/nvim" = "nvim/.config/nvim"; };
        };
      };
    };
  };
}
