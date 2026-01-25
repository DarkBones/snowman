{
  # Used as system.stateVersion + HM stateVersion
  release = "25.11";

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
    vm = {
      hostname = "vm-snowman";
      system = "x86_64-linux";
      users = [ "bas" ];

      # If omitted, defaults to true (you can still change passwords via `passwd`)
      mutableUsers = true;

      ########################################################
      ## Optional: Compatibility Layer (nix-ld)
      ##
      ## Enable this to run unpatched Linux binaries (like
      ## VSCode Servers, Mason LSPs, or proprietary agents)
      ## that expect /lib64/ld-linux-x86-64.so.2 to exist.
      ########################################################
      # compatibility = true;

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
      #   # useDHCP   = true;       # defaults to true if omitted
      #   # networks  = [ "home" ]; # names from the top-level `networks` attr
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
        label = "SNOWMANKEY";
        path = "/mnt/snowman";
        keyFile = "snowman.key";
        fsType = "vfat";
      };
    };

    # Example for a second host:
    # work-laptop = {
    #   hostname = "work-laptop";
    #   system = "x86_64-linux";
    #   users  = [ "alice" ];
    #
    #   # availableRoles = [ "dev" "secrets" "ssh" "my_company" ];
    # };
  };

  users = {
    bas = {
      uid = 1000;
      groups = [ "wheel" ];
      shell = "zsh";

      # face = ./path/to/avatar.png # Optional
      # isNormalUser = true # true by default
      # isSystemUser = false # false by default

      ########################################################
      ## Login method (required by Snowman)
      ##
      ## For the template we keep a simple temporary password
      ## so the config works out-of-the-box. Replace this with
      ## something real, or move to sops-based password hashes.
      ########################################################
      initialPassword = "changeme";

      ########################################################
      ## SSH public keys for logging in as this user
      ##
      ## These keys are written to ~/.ssh/authorized_keys for
      ## `bas` on every host that lists `bas` in hosts.<host>.users.
      ##
      ## You normally put the public keys of the machines you
      ## SSH *from* here (laptop, work PC, YubiKey-backed key…),
      ## not the host’s own key.
      ########################################################
      # sshPubKeys = [ "ssh-ed25519 AAAA... REPLACE_ME_WITH_YOUR_PUBLIC_KEY" ];
      #
      # Alternative file-based styles:
      # sshPubKeyFile  = ./users/keys/bas.pub;
      # sshPubKeyFiles = [ ./users/keys/bas-laptop.pub ./users/keys/bas-pc.pub ];

      ########################################################
      ## Optional per-user secrets (via sops-nix)
      ##
      ## Use this when you want the user's password hash and
      ## other secrets (tokens, API keys) managed by sops.
      ##
      ## - `keys` declares which YAML keys become secrets.
      ## - `userPasswordHashKey` says which one is the password
      ##   hash for this user (used as hashedPasswordFile).
      ##
      ## This is the "real" long-term version of login, as
      ## opposed to the simple `initialPassword` above.
      ########################################################
      # secrets = {
      #   sopsFile = ./users/secrets/bas_secrets.yml;
      #   keys = [ "password_hash" "github_token" ];
      #   userPasswordHashKey = "password_hash";
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

        ####################################################
        ## "secrets" role: user environment
        ##
        ## This is separate from `users.bas.secrets` above:
        ##
        ## - `users.bas.secrets`  → what secrets exist, how
        ##   they are stored (sops-nix, password hash, files).
        ##
        ## - roles.secrets.enable → whether this user should
        ##   have the sops CLI & helpers in their $PATH.
        ####################################################
        secrets.enable = true;

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
          ##
          ## When active, Snowman will try to resolve:
          ##   - `sourceKey` if set
          ##   - otherwise `home.username`
          ## in `dotfilesSources`. If that lookup succeeds,
          ## pinned mode is used.
          ####################################################
          # sourceKey = "bas"; # defaults to home.username if omitted

          ####################################################
          ## GIT MODE (NON-REPRODUCIBLE, but easy to start with)
          ##
          ## Used when no usable pinned source can be found:
          ## - `sourceKey` is unset AND no dotfilesSources[home.username]
          ##   entry exists, OR
          ## - `sourceKey` is set but doesn't resolve in dotfilesSources.
          ##
          ## By default this template config will pull *your*
          ## dotfiles repo as a demo.
          ####################################################
          repo = "https://github.com/DarkBones/dotfiles.git";
          dir = "Developer/dotfiles";
          branch = "stable";
          sparse = [ "nvim" "zsh" ];

          ####################################################
          ## Shared settings for both modes:
          ## map $HOME/<target> → <path inside repo>
          ####################################################
          linkMap = {
            ".config/nvim" = "nvim/.config/nvim";
            ".zsh" = "zsh/.zsh";
            ".zshrc" = "zsh/.zshrc";
          };
        };
      };
    };

    # Example of a second user:
    # alice = {
    #   uid     = 1001;
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
