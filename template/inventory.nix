# template/inventory.nix
#
# This is YOUR Snowman inventory.
#
# It describes:
#   - Which hosts you manage (and their hardware / profiles)
#   - Which users exist on those hosts
#   - Optional secrets, bootstrap USB, and dotfiles roles
#
# The default example is a single VM host `vm-snowman` with one user `bas`.
# You should:
#   - Rename `vm-snowman` to your own host name
#   - Rename `bas` to your own user name
#   - Replace the SSH key below with your own
#   - (Optionally) enable secrets, bootstrap USB, and pinned dotfiles later

{
  # This doubles as:
  #   - NixOS release for system.stateVersion
  #   - Home Manager stateVersion
  release = "25.05";

  ##########################################################################
  ## HOSTS
  ##
  ## Each key under `hosts` is a machine you manage with Snowman.
  ## Minimal required fields per host:
  ##   - system       : NixOS system (e.g. "x86_64-linux")
  ##   - users        : list of user names for this host
  ##
  ## Optional (but recommended):
  ##   - mutableUsers : whether you can change users via `passwd` etc.
  ##   - hostname     : overrides the key name as the system hostname
  ##   - hardware.*   : describes how to mount root and install bootloader
  ##   - profiles     : NixOS profile modules (e.g. "qemu-guest")
  ##   - bootstrap.usb: optional "Snowman Key" for early secrets bootstrap
  ##   - secrets      : per-host secrets (WireGuard keys, etc.) managed by sops-nix
  ##########################################################################
  hosts = {
    vm-snowman = {
      # Architecture of this machine
      system = "x86_64-linux";

      # If false, users are only managed via Nix (no `passwd` changes).
      # If omitted, defaults to `true`.
      mutableUsers = false;

      # Optional, defaults to the attribute name `vm-snowman`
      hostname = "vm-snowman";

      # BETA: Disk provisioning (via disko)
      # If you set this to `true`, Snowman will import the `disko` module.
      # You must also provide an actual disko config elsewhere.
      provision.disk.enable = false;

      # Networking:
      # By default Snowman sets useDHCP = true if this is omitted.
      # useDHCP = true;

      ############################################################
      ## Host secrets (optional, via sops-nix)
      ##
      ## Uncomment & adapt when you are ready to use sops-nix for
      ## per-host secrets (e.g. WireGuard private key, API tokens).
      ##
      ## The file path should point to a sops-encrypted YAML file.
      ############################################################
      # secrets = {
      #   # sops-encrypted host secrets file
      #   sopsFile = ./hosts/secrets/vm-snowman_secrets.yml;
      #
      #   # Expose keys from that YAML as concrete files on disk
      #   items = {
      #     # Example:
      #     # wireguard-private-key = {
      #     #   key = "wireguard-private-key"; # YAML key path
      #     #   owner = "root";
      #     #   group = "root";
      #     #   mode = "0400";
      #     # };
      #   };
      # };

      ############################################################
      ## Profiles
      ##
      ## Profiles are NixOS modules from nixpkgs, imported by name.
      ## Examples include "qemu-guest", "lenovo-thinkpad", etc.
      ##
      ## For bare metal, you can usually omit this.
      ############################################################
      # profiles = [
      #   "qemu-guest" # ONLY for VMs. On normal machines, omit this.
      # ];

      # ############################################################
      # ## Hardware description (Advanced)
      # ##
      # ## Snowman uses this to:
      # ##   - define the root filesystem
      # ##   - configure the bootloader
      # ##
      # ## Minimal working example: a single ext4 root partition.
      # ############################################################
      # hardware = {
      #   # The disk that holds your NixOS installation.
      #   # For example: "/dev/sda", "/dev/nvme0n1", "/dev/vda", ...
      #   bootDevice = "/dev/vda";
      #
      #   fs = {
      #     # Filesystem type for "/"
      #     type = "ext4";
      #
      #     # Example 1: root is /dev/vda1
      #     partition = 1;
      #
      #     # Alternative examples:
      #     # device = "/dev/disk/by-label/ROOT";
      #     # rootLabel = "ROOT";
      #     # rootUuid = "11111111-2222-3333-4444-555555555555";
      #
      #     # Optional swap size in GiB (only used if you later enable
      #     # disko-based provisioning)
      #     # swapGiB = 0;
      #   };
      # };
      #
      ############################################################
      ## Users enabled on this host
      ##
      ## These must match keys under `users` below.
      ############################################################
      users = [ "bas" ];

      ############################################################
      ## Optional: USB bootstrap Age key ("Snowman Key")
      ##
      ## This allows a completely new machine to decrypt secrets
      ## from a USB stick before it has its own Age key enrolled.
      ##
      ## You can enable this for your *first* install and then
      ## disable it again once the host's SSH key has been turned
      ## into an Age recipient and added to `.sops.yaml`.
      ############################################################
      bootstrap.usb = {
        enable = false; # Set to true if you actually use this
        label = "SNOWMANKEY"; # Filesystem label of the USB stick
        path = "/mnt/snowman"; # Where it will be mounted
        keyFile = "snowman.key"; # Private Age key stored on the USB
        fsType = "vfat";
      };
    };

    # Add more hosts here:
    #
    # my-laptop = {
    #   system = "x86_64-linux";
    #   users = [ "alice" ];
    #   hardware = {
    #     bootDevice = "/dev/nvme0n1";
    #     fs = {
    #       type = "btrfs";
    #       rootLabel = "NIXOSROOT";
    #     };
    #   };
    # };
    #
  };

  ##########################################################################
  ## USERS
  ##
  ## Each key under `users` describes:
  ##   - UID, groups, shell
  ##   - SSH login keys
  ##   - Optional sops-managed secrets
  ##   - Optional extra home-manager config via envFile
  ##   - Home roles (dev, ssh, secrets, dotfiles, ...)
  ##
  ## IMPORTANT:
  ##   - For each host, `hosts.<host>.users` must reference defined users.
  ##   - Each user that appears on a host must have:
  ##       - at least one SSH key (sshPubKeys / sshPubKeyFile / sshPubKeyFiles), OR
  ##       - a password (via sops-managed password_hash or initialPassword)
  ##
  ## The module asserts this and will fail if neither is configured.
  ##########################################################################
  users = {
    bas = {
      # Numeric user id on the system
      uid = 1000;

      # System groups (must exist or be created via NixOS config)
      groups = [ "wheel" ];

      # Login shell: either a nixpkgs attribute name ("zsh", "fish", ...)
      # or an absolute path ("/run/current-system/sw/bin/bash").
      shell = "zsh";

      ############################################################
      ## SSH login keys
      ##
      ## You have three options:
      ##
      ## 1. Inline keys           : sshPubKeys = [ "ssh-ed25519 AAAA... user@host" ];
      ## 2. Single key file       : sshPubKeyFile = ./users/keys/bas.pub;
      ## 3. Multiple key files    : sshPubKeyFiles = [ ./users/keys/bas-laptop.pub ./users/keys/bas-pc.pub ];
      ##
      ## All of them are merged together by Snowman.
      ##
      ## NOTE: This example uses a placeholder inline key so the
      ##       template evaluates. You MUST replace it with your
      ##       own real SSH public key before using this in production.
      ############################################################
      sshPubKeys = [
        # Replace this with *your* real public key:
        "ssh-ed25519 AAAA... REPLACE_ME_WITH_YOUR_PUBLIC_KEY"
      ];

      # Alternative file-based examples (commented out by default):
      # sshPubKeyFile = ./users/keys/bas.pub;
      # sshPubKeyFiles = [
      #   ./users/keys/bas-laptop.pub
      #   ./users/keys/bas-desktop.pub
      # ];

      ############################################################
      ## User secrets (optional, via sops-nix)
      ##
      ## This is where you put per-user secrets such as:
      ##   - password_hash (for login)
      ##   - GitHub tokens
      ##   - API keys
      ##
      ## When enabled, Snowman will:
      ##   - Expose each entry in `keys` as a sops secret
      ##   - Use `userPasswordHashKey` as this user's hashedPasswordFile
      ##
      ## To keep the default template simple, this block is commented
      ## out. See the README for a full walkthrough.
      ############################################################
      # secrets = {
      #   # Path to your sops-encrypted user secrets
      #   sopsFile = ./users/secrets/bas_secrets.yml;
      #
      #   # Keys that should become sops secrets:
      #   keys = [ "password_hash" "github_token" ];
      #
      #   # Which key above holds the *hashed* password for this user
      #   userPasswordHashKey = "password_hash";
      # };

      # Simple alternative: initialPassword (NOT recommended long-term).
      # If you set this, Snowman will configure it as the initialPassword
      # for this user, as long as you do NOT also configure secrets/userPasswordHashKey.
      # initialPassword = "changeme";

      ############################################################
      ## Optional extra Home Manager config for this user
      ##
      ## If set, this file is imported into the user's home-manager
      ## configuration (it can set editor, PATH, env vars, etc.).
      ############################################################
      # envFile = ./users/env/bas.nix;

      ############################################################
      ## Home roles
      ##
      ## These control home-manager-level features for this user,
      ## implemented in Snowman's home modules:
      ##
      ##   - dev.enable     : example dev tool role (your own config)
      ##   - ssh.enable     : generate user-level SSH key if none exists
      ##   - secrets.enable : include `sops` CLI in this user's env
      ##   - dotfiles.*     : manage ~/.config, ~/.zshrc, etc.
      ############################################################
      roles = {
        dev.enable = true;
        # ssh.enable = true; # Optional, `true` when omitted
        secrets.enable = true;

        dotfiles = {
          enable = false;

          ########################################################
          ## MODE SELECTION
          ##
          ## Snowman supports two dotfiles modes:
          ##
          ## 1) Pinned mode (reproducible; uses flake input)
          ##
          ##    - You add a flake input for your dotfiles in
          ##      your config flake.nix, e.g.:
          ##
          ##        inputs.my-dotfiles = {
          ##          url = "github:YourName/dotfiles";
          ##          flake = false;
          ##        };
          ##
          ##    - You map it into `dotfilesSources` in your flake:
          ##
          ##        dotfilesSources = {
          ##          bas = inputs.my-dotfiles;
          ##        };
          ##
          ##    - Snowman will then look up that path by `sourceKey`.
          ##
          ########################################################

          # Pinned mode (reproducible; uses flake input)
          # default = home.username if omitted
          # sourceKey = "bas";

          ########################################################
          ## 2) Git mode (non-reproducible, but simple)
          ##
          ## If `sourceKey` is unset or not found in dotfilesSources,
          ## Snowman falls back to git:
          ##
          ##   - It will clone/pull `repo` into $HOME/<dir>
          ##   - It can optionally use sparse checkout
          ##
          ## By default in the template, repo is empty so nothing
          ## is cloned until you fill it in.
          ########################################################
          repo = "github:YourUser/dotfiles";
          dir = "Developer/dotfiles";
          branch = "main";
          sparse = [ "nvim" "zsh" ];

          ########################################################
          ## SHARED SETTINGS (both modes)
          ##
          ## linkMap: target -> path inside repo
          ########################################################
          linkMap = {
            # Example mappings:
            # "path/relative/to/home" = ".path/on/the/dotfiles/repo"
            # ".config/nvim"          = "nvim/.config/nvim";
            # ".zsh"                  = "zsh/.zsh";
            # ".zshrc"                = "zsh/.zshrc";
          };
        };
      };
    };

    # Add more users here:
    #
    # alice = {
    #   uid = 1001;
    #   groups = [ "wheel" ];
    #   shell = "bash";
    #   sshPubKeyFiles = [ ./users/keys/alice.pub ];
    #   roles = {
    #     dev.enable = true;
    #     ssh.enable = true;
    #   };
    # };
  };
}
