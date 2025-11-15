{
  # Used as system.stateVersion + HM stateVersion
  release = "25.05";

  hosts = {
    vm-snowman = {
      system = "x86_64-linux";
      mutableUsers = false;
      hostname = "vm-snowman";

      # Reserved for future disko integration
      provision.disk.enable = false;

      # networking.useDHCP defaults to true when omitted.
      # networking.useDHCP = true;

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
