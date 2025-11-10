{
  release = "25.05";

  hosts = {
    vm-snowman = {
      system = "x86_64-linux";
      mutableUsers = false; # Defaults to `true` if omitted
      hostname = "vm-snowman"; # Optional, defaults to hosts.[name]
      provision.disk.enable = false;
      # useDHCP = true; # Default if omitted

      secrets = {
        sopsFile = ./hosts/secrets/vm-snowman_secrets.yml;

        items = {
          test = {
            # path inside the YAML
            key = "test";
            # file owner/group/mode for the concrete secret file
            owner = "root";
            group = "root";
            mode = "0400";
          };

          wireguard-private-key = {
            key = "wireguard-private-key";
            owner = "root";
            group = "root";
            mode = "0400";
          };
        };
      };

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
        enable = true;
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

      # sopsSecretsFile = ./users/secrets/bas_secrets.yml;
      # sopsSecretKeys = [ "password_hash" "test" ];
      # sopsPasswordHashKey = "password_hash";
      secrets = {
        sopsFile = ./users/secrets/bas_secrets.yml;
        keys = [ "password_hash" "test" ];
        userPasswordHashKey = "password_hash";
      };

      envFile = ./users/env/bas.nix;

      roles = {
        dev.enable = true;
        ssh.enable = true;
        secrets.enable = true;

        dotfiles = {
          enable = true;

          ############################################################
          ## MODE SELECTION
          ##
          ## If `sourceKey` resolves in dotfilesSources (specialArgs),
          ## we use *pinned mode* (flake input in the Nix store).
          ##
          ## If `sourceKey` is null or doesn't resolve, we fall back
          ## to *git mode* (clone/pull at activation time).
          ############################################################

          # Pinned mode (reproducible; uses flake input)
          # default = home.username if omitted
          # sourceKey = "bas";

          ############################################################
          ## GIT MODE (NON-REPRODUCIBLE)
          ##
          ## Only used when pinned mode is not active.
          ############################################################
          repo = "git@github.com:DarkBones/.dotfiles.git";
          dir = "Developer/dotfiles";
          branch = "nix"; # TODO: Make `main` default later
          sparse = [ "nvim" "zsh" ];

          ############################################################
          ## SHARED SETTINGS (BOTH MODES)
          ############################################################
          linkMap = {
            ".config/nvim" = "nvim/.config/nvim";
            ".zsh" = "zsh/.zsh";
            ".zshrc" = "zsh/.zshrc";
          };

          # TODO (future): deployTokenKey / deployKeySecret for private SSH access
        };
      };
    };
  };
}
