{
  # Used as system.stateVersion + HM stateVersion
  release = "25.05";

  hosts = {
    vm-snowman = {
      system = "x86_64-linux";
      mutableUsers = true;
      hostname = "vm-snowman";

      ############################################################
      ## Optional hardware description used by Snowman
      ##
      ## For most users you can leave this as-is or even remove it.
      ## If `hardware` is omitted, Snowman:
      ##   - imports your per-host hardware-configuration.nix, and
      ##   - does NOT touch bootloader settings (installer config stays).
      ##
      ## If you want Snowman (and later disko) to understand / own
      ## your disk + bootloader, fill this in correctly.
      ############################################################
      # hardware = {
      #   # Is this machine booting in "bios", "efi", or "none" mode?
      #   #
      #   #  - "bios" → Snowman configures GRUB on `bootDevice`.
      #   #  - "efi"  → Snowman configures systemd-boot.
      #   #  - "none" → Snowman does not touch bootloader settings.
      #   boot = { firmware = "bios"; }; # "bios" | "efi" | "none"
      #
      #   # The *disk* that contains your root partition (no partition number)
      #   bootDevice = "/dev/vda"; # e.g. /dev/sda, /dev/vda, /dev/nvme0n1
      #
      #   # Filesystem info for the root partition
      #   fs = {
      #     type = "ext4"; # e.g. "ext4", "btrfs"
      #     partition = 1; # e.g. /dev/vda1 → 1
      #     # swapGiB = 0;                # optional: swap size in GiB if you let Snowman/disko create it
      #   };
      # };

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

      # Optional per-host role filter:
      #
      # If omitted, all roles with `users.<name>.roles.<role>.enable = true`
      # are applied on this host.
      #
      # If set, only roles whose *names* appear in this list are applied.
      # This lets you reuse the same user across multiple machines, but
      # avoid running e.g. a `gaming` role on a work laptop or server.
      #
      # availableRoles = [ "bas" "ssh" "dev" "secrets" ];

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
    # work-laptop = {
    #   system = "x86_64-linux";
    #   users  = [ "alice" ];
    #
    #   # Optional advanced hardware inventory. If omitted, Snowman will
    #   # simply use the imported hardware-configuration.nix and not touch
    #   # bootloader settings.
    #   hardware = {
    #     boot = { firmware = "efi"; };   # "bios" | "efi" | "none"
    #     bootDevice = "/dev/nvme0n1";    # disk, no partition suffix
    #     fs = {
    #       type = "ext4";                # e.g. "ext4", "btrfs"
    #       partition = 1;                # /dev/nvme0n1p1 → 1
    #       # swapGiB = 8;                # optional swap on same disk
    #     };
    #   };
    #
    #   # Only allow a subset of roles on this host. For example,
    #   # skip a hypothetical `gaming` role here:
    #   #
    #   # availableRoles = [ "dev" "secrets" "ssh" "my_company" ];
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
      # sshPubKeys = [ "ssh-ed25519 AAAA... REPLACE_ME_WITH_YOUR_PUBLIC_KEY" ];

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
      initialPassword = "snowman";

      # Optional extra Home Manager config:
      # envFile = ./users/env/bas.nix;

      roles = {
        bas.enable = true;
        dev.enable = true;
        ssh.enable = false;    # defaults to true if omitted
        secrets.enable = true;

        # You can define more roles here, e.g.:
        # gaming.enable = true; # installs Steam, GPU drivers, etc.
        #
        # Then use `hosts.<host>.availableRoles` to choose which hosts
        # actually apply that role (e.g. gaming PC vs. work laptop).

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

          # PINNED MODE (reproducible; uses flake input)
          # default = "username" # Defaults to `home.username` if omitted
          # sourceKey = "bas";

          # GIT MODE (NON-REPRODUCIBLE)
          # Only used when pinned mode is NOT active.
          # repo = "git@github.com:DarkBones/.dotfiles.git";
          # dir = "Developer/dotfiles";
          # branch = "main";
          # sparse = [ "nvim" "zsh" ];

          ############################################################
          ## SHARED SETTINGS (BOTH MODES)
          ############################################################
          repo = "https://github.com/DarkBones/dotfiles.git";
          dir = "Developer/dotfiles";
          branch = "main";
          sparse = [ "nvim" "zsh" ];

          ############################################################
          ## SHARED SETTINGS (BOTH MODES)
          ############################################################
          linkMap = {
            ".config/nvim" = "nvim/.config/nvim";
            ".zsh" = "zsh/.zsh";
            ".zshrc" = "zsh/.zshrc";
          };
        };
      };
    };

    # alice = {
    #   uid = 1001;
    #   groups = [ "wheel" ];
    #   shell = "bash";
    #   sshPubKeyFiles = [ ./users/keys/alice.pub ];
    #
    #   roles = {
    #     dev.enable = true;
    #     ssh.enable = true;
    #     # gaming.enable = true;
    #   };
    # };
  };
}
