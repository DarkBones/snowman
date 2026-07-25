{
  ############################################################
  ## Start Here
  ##
  ## For a first successful install, you only need to do a few
  ## things:
  ##
  ## 1. Replace the example host and user values below.
  ## 2. Keep one simple login method (password or SSH key).
  ## 3. Keep `homeManaged = true` for the user who should get
  ##    Home Manager.
  ## 4. Leave optional sections commented out for now unless
  ##    you already know you need them.
  ##
  ## Learn later:
  ## - pinned dotfiles inputs
  ## - sops-managed secrets
  ## - declarative Wi-Fi
  ## - USB bootstrap keys
  ## - per-host role bindings across many machines
  ############################################################

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
    vm = {
      # Replace this with your first real machine.
      hostname = "vm-snowman";
      # Optional: Map inventory username to local machine username
      # (Useful on macOS where your local name might be "Bas" but inventory is "bas")
      localAccountNames = {
        bas = "Bas";
      };
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
      ## Role bindings: which roles apply to which user ON THIS HOST
      ##
      ## Each entry names a role module from home/roles/. Per-role
      ## configuration (if any) lives on the user, under
      ## users.<name>.roleConfig.<role>.
      ##
      ## Binding roles per host means one user can exist on many
      ## machines with different feature sets — e.g. bind "gaming"
      ## only on the desktop — without any exclusion lists.
      ############################################################
      roles.bas = [
        "dev"
        "secrets"
      ];

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
    #   roles.alice = [ "dev" "secrets" "my_company" ];
    # };
  };

  users = {
    bas = {
      # Replace "bas" with your real username before real use.
      uid = 1000;
      homeManaged = true;
      groups = [ "wheel" ];
      shell = "zsh";

      # face = ./path/to/avatar.png # Optional
      # isNormalUser = true # true by default
      # isSystemUser = false # false by default

      ########################################################
      ## Login method (required by Snowman)
      ##
      ## For the template we keep a simple temporary password
      ## so your first install is easy to understand.
      ##
      ## Replace this before real use, or switch to SSH keys /
      ## sops-based password hashes.
      ########################################################
      initialPassword = "changeme";

      ########################################################
      ## SSH public keys for logging in as this user
      ##
      ## These keys are written to ~/.ssh/authorized_keys for
      ## this user on every host that lists them in hosts.<host>.users.
      ##
      ## You normally put the public keys of the machines you
      ## SSH *from* here (laptop, work PC, YubiKey-backed key…),
      ## not the host’s own key.
      ########################################################
      # sshPubKeys = [ "ssh-ed25519 AAAA... REPLACE_ME_WITH_YOUR_PUBLIC_KEY" ];
      #
      # Alternative file-based styles:
      # sshPubKeyFile  = ./users/keys/bas.pub;
      # sshPubKeyFiles = [ ./users/keys/bas-laptop.pub ./users/keys/bas-desktop.pub ];

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

      ########################################################
      ## Role configuration (payload only!)
      ##
      ## WHICH roles this user gets on WHICH machine is bound
      ## per host, under hosts.<host>.roles.<user> above.
      ## This section only holds per-role settings for roles
      ## that need them. Roles without settings (like "dev")
      ## need no entry here — binding them on a host is enough.
      ##
      ## Notes on the roles bound above:
      ##
      ## - "dev": example dev tool role (see home/roles/dev.nix).
      ##
      ## - "secrets": separate from `users.bas.secrets` above:
      ##   `users.bas.secrets` → what secrets exist and how they
      ##   are stored (sops-nix, password hash, files);
      ##   the "secrets" role → whether this user gets the sops
      ##   CLI & helpers in their $PATH.
      ##
      ## - "ssh" is on by default everywhere (no binding needed).
      ########################################################
      roleConfig = {
        ########################################################
        ## Dotfiles ("head") role
        ##
        ## This is useful, but it is not required for your first
        ## successful install. To use it, add "dotfiles" to
        ## hosts.<host>.roles.bas and configure it here.
        ##
        ## Recommended learning order:
        ##   1. get one machine working
        ##   2. then choose a dotfiles strategy
        ##
        ## Two source models exist:
        ##   - Pinned source via flake input (recommended later)
        ##   - Git fallback via clone/pull on activation
        ########################################################
        # dotfiles = {

        ####################################################
        ## PINNED MODE (reproducible; uses flake input)
        ##
        ## Requires your body flake to define dotfilesSources,
        ## e.g.:
        ##
        ##   dotfilesSources = {
        ##     bas = inputs.my-dotfiles;
        ##   };
        ##
        ## and a flake input:
        ##
        ##   my-dotfiles = {
        ##     url = "github:YourUserName/dotfiles";
        ##     flake = false;
        ##   };
        ##
        ## When active, Snowman will try to resolve:
        ##   - `sourceKey` if set
        ##   - otherwise `home.username`
        ## in `dotfilesSources`. If that lookup succeeds,
        ## pinned mode is used.
        ####################################################
        #   sourceKey = "bas"; # defaults to home.username if omitted

        ####################################################
        ## GIT MODE (NON-REPRODUCIBLE, but easy to start with)
        ##
        ## Used when no usable pinned source can be found:
        ## - `sourceKey` is unset AND no dotfilesSources[home.username]
        ##   entry exists, OR
        ## - `sourceKey` is set but doesn't resolve in dotfilesSources.
        ##
        ## Good as a fallback. Not the ideal long-term setup.
        ##
        ## Replace the placeholder repo before enabling.
        ##
        ## `dir` may be:
        ##   - relative to $HOME, e.g. "dotfiles" or "Developer/dotfiles"
        ##   - home-relative, e.g. "~/Developer/dotfiles"
        ##   - absolute, e.g. "/home/alice/Developer/dotfiles"
        ####################################################
        #   repo = "https://github.com/YourUserName/dotfiles.git";
        #   dir = "Developer/dotfiles";
        #   branch = "main";
        #   sparse = [ "nvim" "zsh" ];

        ####################################################
        ## Shared settings for both modes:
        ## map $HOME/<target> → <path inside repo>
        ####################################################
        #   linkMap = {
        #     ".config/nvim" = "nvim/.config/nvim";
        #     ".zsh" = "zsh/.zsh";
        #     ".zshrc" = "zsh/.zshrc";
        #   };
        # };
      };
    };

    # Example of a second user. Note there is no role list here: which
    # roles alice gets is bound per host (hosts.<host>.roles.alice);
    # only per-role *settings* would go in `roleConfig`.
    # alice = {
    #   uid     = 1001;
    #   groups = [ "wheel" ];
    #   shell  = "bash";
    #   sshPubKeyFiles = [ ./users/keys/alice.pub ];
    # };
  };
}
