{
  # Used as system.stateVersion + HM stateVersion
  release = "25.05";

  ############################################################
  ## Optional: declarative Wi-Fi networks
  ##
  ## If you don't need inventory-driven Wi-Fi yet, leave
  ## this commented out and just use NetworkManager + nmtui.
  ##
  ## Secrets for these networks live in networks/secrets.yml.
  ############################################################
  # networks = {
  #   home = {
  #     ssid = "home_ssid";
  #     # YAML path in networks/secrets.yml:
  #     passwordSecret = "home/password";
  #   };
  #   work = {
  #     ssid = "work_ssid";
  #     passwordSecret = "work/password";
  #   };
  # };

  hosts = {
    vm-snowman = {
      system = "x86_64-linux";
      users  = [ "bas" ];

      # If omitted, defaults to true (you can still change passwords via `passwd`)
      mutableUsers = true;

      # Optional: override runtime hostname (defaults to the attr name: "vm-snowman")
      hostname = "vm-snowman";

      ########################################################
      ## Optional Wi-Fi configuration
      ##
      ## If you leave `wifi` unset, Snowman does NOT touch
      ## networking: NetworkManager / nmtui keep working.
      ########################################################

      # Recommended default for laptops / interactive machines:
      # wifi = {
      #   mode = "roaming";  # let NetworkManager handle Wi-Fi
      # };

      # Declarative/headless Wi-Fi (e.g. Pi/servers with no screen):
      # wifi = {
      #   mode = "static-wifi";
      #   # interface = "wlan0";  # defaults to "wlan0" if omitted
      #   # useDHCP  = true;      # defaults to true if omitted
      #   networks  = [ "home" ]; # names from the top-level `networks` attr
      # };

      ############################################################
      ## Optional per-host secrets (via sops-nix)
      ##
      ## You can define host-specific secrets here, e.g. VPN keys.
      ############################################################
      # secrets = {
      #   sopsFile = ./hosts/secrets/vm-snowman_secrets.yml;
      #   items = {
      #     # Example:
      #     # wireguard-private-key = {
      #     #   key   = "wireguard-private-key"; # YAML key
      #     #   owner = "root";
      #     #   group = "root";
      #     #   mode  = "0400";
      #     # };
      #   };
      # };

      ############################################################
      ## Optional per-host role filter
      ##
      ## If omitted, all roles with users.<name>.roles.<role>.enable
      ## set to true are applied on this host.
      ##
      ## If set, only roles whose *names* appear in this list are
      ## applied. This lets you reuse one user across many hosts
      ## but restrict e.g. gaming roles to a single machine.
      ############################################################
      # availableRoles = [ "bas" "ssh" "dev" "secrets" ];

      ############################################################
      ## Optional: USB bootstrap Age key ("Snowman Key")
      ##
      ## Lets a brand new machine decrypt secrets from a USB stick
      ## before its own Age key is enrolled.
      ############################################################
      bootstrap.usb = {
        enable = false;
        label  = "SNOWMANKEY";
        path   = "/mnt/snowman";
        keyFile = "snowman.key";
        fsType  = "vfat";
      };
    };

    # Example for a second host:
    # work-laptop = {
    #   system = "x86_64-linux";
    #   users  = [ "alice" ];
    #
    #   # Optional advanced hardware inventory. If omitted, Snowman will
    #   # simply use the imported hardware-configuration.nix and not touch
    #   # bootloader settings.
    #   # hardware = {
    #   #   boot = { firmware = "efi"; };   # "bios" | "efi" | "none"
    #   #   bootDevice = "/dev/nvme0n1";    # disk, no partition suffix
    #   #   fs = {
    #   #     type = "ext4";                # e.g. "ext4", "btrfs"
    #   #     partition = 1;                # /dev/nvme0n1p1 → 1
    #   #     # swapGiB = 8;                # optional swap on same disk
    #   #   };
    #   # };
    #
    #   # availableRoles = [ "dev" "secrets" "ssh" "my_company" ];
    #   # provision.disk.enable = true;
    # };
  };

  users = {
    bas = {
      uid    = 1000;
      groups = [ "wheel" ];
      shell  = "zsh";

      ########################################################
      ## Login method (required by Snowman)
      ##
      ## We can create a simple temporary password in plain text
      ########################################################
      initialPassword = "changeme";

      # QUESTION: Why do we need sshPubKeys? What does it do? Who'se key do you add?
      # Replace with your real SSH public key(s) if you want SSH:
      # sshPubKeys = [ "ssh-ed25519 AAAA... REPLACE_ME_WITH_YOUR_PUBLIC_KEY" ];
      #
      # Alternative file-based styles:
      # sshPubKeyFile  = ./users/keys/bas.pub;
      # sshPubKeyFiles = [ ./users/keys/bas-laptop.pub ./users/keys/bas-pc.pub ];

      ########################################################
      ## Optional per-user secrets (via sops-nix)
      ########################################################
      # secrets = {
      #   sopsFile = ./users/secrets/bas_secrets.yml;
      #   keys = [ "password_hash" "github_token" ];
      #   userPasswordHashKey = "password_hash"; # QUESTION: Is this sufficiently coverd in the documentation? It feels a bit disjointed from initialPassword, but that's okay as long as its documented (I do believe we have an assert also)
      # };

      ########################################################
      ## Optional extra Home Manager config for this user
      ########################################################
      # envFile = ./users/env/bas.nix;

      roles = {
        # Example of your own reusable Home Manager role
        bas.enable = true;

        # Example dev tool role (see home/roles/dev.nix)
        dev.enable = true;

        # Defaults to `true` if omitted
        # ssh.enable = true; 

        # Include sops CLI in the user environment
        secrets.enable = true; # QUESTION: Remind me why we have a `user.secrets` section and a `user.roles.secrets` role

        ########################################################
        ## Dotfiles ("head") role
        ##
        ## This role mounts your dotfiles repo into $HOME.
        ## Two modes:
        ##   - Pinned mode: through flake inputs (reproducible)
        ##   - Git mode: clone/pull on activation (non-reproducible)
        ##
        ## The template enables Git mode by default as a demo.
        ########################################################
        dotfiles = {
          enable = true;

          ####################################################
          ## PINNED MODE (reproducible; uses flake input)
          ##
          ## Requires your body flake to define dotfilesSources,
          ## e.g.:
          ##
          ##   dotfilesSources = {
          ##     bas = inputs.bas-dotfiles;
          ##   };
          ##
          ## and a flake input:
          ##
          ##   bas-dotfiles = {
          ##     url = "github:DarkBones/dotfiles";
          ##     flake = false;
          ##   };
          ####################################################
          # sourceKey = "bas"; # defaults to home.username if omitted

          ####################################################
          ## GIT MODE (NON-REPRODUCIBLE, but easy to start with)
          ##
          ## Only used when `sourceKey` is unset or doesn't
          ## resolve in dotfilesSources. # QUESTION: This is confusing. It mentions something happening when `sourceKey` is unset, but above it mentions that defaults to `home.username`
          ##
          ## By default this template config will pull *your*
          ## dotfiles repo as a demo.
          ####################################################
          repo   = "https://github.com/DarkBones/dotfiles.git";
          dir    = "Developer/dotfiles";
          branch = "main";
          sparse = [ "nvim" "zsh" ];

          ####################################################
          ## Shared settings for both modes:
          ## map $HOME/<target> → <path inside repo>
          ####################################################
          linkMap = {
            ".config/nvim" = "nvim/.config/nvim";
            ".zsh"         = "zsh/.zsh";
            ".zshrc"       = "zsh/.zshrc";
          };
        };
      };
    };

    # Example of a second user:
    # alice = {
    #   uid    = 1001;
    #   groups = [ "wheel" ];
    #   shell  = "bash";
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
