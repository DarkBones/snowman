{
  # Used as system.stateVersion + HM stateVersion
  release = "25.05";

  hosts = {
    vm-snowman = {
      system = "x86_64-linux";
      mutableUsers = false;
      hostname = "vm-snowman";

      ############################################################
      ## Minimal hardware description used by Snowman
      ##
      ## Adjust these values to match your VM/disk layout.
      ############################################################
      hardware = {
        # Is this machine booting in "bios" or "efi" mode?
        boot = { firmware = "bios"; }; # or "efi"

        # The *disk* that contains your root partition (no partition number)
        bootDevice = "/dev/vda"; # e.g. /dev/sda, /dev/vda, /dev/nvme0n1

        # Filesystem info for the root partition
        fs = {
          type = "ext4"; # e.g. "ext4", "btrfs"
          partition = 1; # e.g. /dev/vda1 → 1
          # swapGiB = 0;                # optional: swap size in GiB if you let Snowman/disko create it
        };
      };

      # Reserved for future disko integration (uses `hardware.*` above)
      provision.disk.enable = false;

      # Networking: Snowman maps this to `networking.useDHCP` internally.
      # If omitted, DHCP defaults to true.
      # useDHCP = true;

      # Optional per-host secrets (via sops-nix)
      # secrets = {
      #   sopsFile = ./hosts/secrets/vm-snowman_secrets.yml;
      #   items = { };
      # };

      users = [ "bas" ];

      bootstrap.usb = {
        enable = false;
        label = "SNOWMANKEY";
        path = "/mnt/snowman";
        keyFile = "snowman.key";
        fsType = "vfat";
      };
    };

    # Example:
    # my-laptop = {
    #   system = "x86_64-linux";
    #   users  = [ "alice" ];
    #
    #   hardware = {
    #     boot = { firmware = "efi"; };   # "bios" or "efi"
    #     bootDevice = "/dev/nvme0n1";    # disk, no partition suffix
    #     fs = {
    #       type = "ext4";                # e.g. "ext4", "btrfs"
    #       partition = 1;                # /dev/nvme0n1p1 → 1
    #       # swapGiB = 8;                # optional swap on same disk
    #     };
    #   };
    #
    #   # provision.disk.enable = true;   # when you want Snowman+disko to own the disk
    # };
  };

  users = {
    bas = {
      uid = 1000;
      groups = [ "wheel" ];
      shell = "zsh";

      # Replace with your real SSH public key(s)
      sshPubKeys = [ "ssh-ed25519 AAAA... REPLACE_ME_WITH_YOUR_PUBLIC_KEY" ];

      # Alternative file-based styles:
      # sshPubKeyFile  = ./users/keys/bas.pub;
      # sshPubKeyFiles = [ ./users/keys/bas-laptop.pub ./users/keys/bas-pc.pub ];

      # Optional per-user secrets (via sops-nix)
      # secrets = {
      #   sopsFile = ./users/secrets/bas_secrets.yml;
      #   keys = [ "password_hash" "github_token" ];
      #   userPasswordHashKey = "password_hash";
      # };

      # Simple alternative for first install (not recommended long-term):
      # initialPassword = "changeme";

      # Optional extra Home Manager config:
      # envFile = ./users/env/bas.nix;

      roles = {
        dev.enable = true;
        # ssh.enable = true;    # defaults to true if omitted
        secrets.enable = true;

        dotfiles = {
          enable = false;

          # Pinned mode (flake input) — if set and found in dotfilesSources:
          # sourceKey = "bas";

          # Git mode (used when sourceKey is unset or not found):
          repo = "github:YourUser/dotfiles";
          dir = "Developer/dotfiles";
          branch = "main";
          sparse = [ "nvim" "zsh" ];

          linkMap = {
            # ".config/nvim" = "nvim/.config/nvim";
            # ".zsh"         = "zsh/.zsh";
            # ".zshrc"       = "zsh/.zshrc";
          };
        };
      };
    };

    # alice = {
    #   uid = 1001;
    #   groups = [ "wheel" ];
    #   shell = "bash";
    #   sshPubKeyFiles = [ ./users/keys/alice.pub ];
    #   roles.dev.enable = true;
    #   roles.ssh.enable = true;
    # };
  };
}
