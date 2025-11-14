{
  description = "Snowman minimal spine";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    nixos-hardware.url = "github:NixOS/nixos-hardware";

    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ############################################################
    ## OPTIONAL: PINNED DOTFILES INPUTS (ADVANCED)
    ##
    ## By default, Snowman uses "Git mode" for dotfiles:
    ##   - roles.dotfiles.repo / branch / sparse in inventory.nix
    ##   - git clone/pull at Home Manager activation time
    ##
    ## If you want *pinned* dotfiles (reproducible, locked in
    ## flake.lock), you can add git inputs here and wire them
    ## into `dotfilesSources` below.
    ##
    ## Example for user `bas`:
    ##
    ## bas-dotfiles = {
    ##   # Any non-flake git URL works here (https or ssh).
    ##   # This gets pinned in flake.lock.
    ##   url = "github:DarkBones/dotfiles";
    ##   flake = false;
    ## };
    ############################################################
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, disko, sops-nix
    # , bas-dotfiles  # Uncomment when you actually use a pinned dotfiles input
    , ... }:
    let
      lib = nixpkgs.lib;
      inv = import ./inventory.nix;

      makePkgs = system: import nixpkgs {
        inherit system;
        config = { allowUnfree = true; };
      };

      makePkgsUnstable = system: import nixpkgs-unstable {
        inherit system;
        config = { allowUnfree = true; };
      };

      ########################################################
      ## dotfilesSources:
      ##
      ## This attrset is passed into NixOS + Home Manager
      ## as `specialArgs` / `extraSpecialArgs`.
      ##
      ## - When empty (default), all users use Git mode.
      ## - To enable pinned mode for a user, map a key
      ##   (usually their username) to a flake input.
      ########################################################
      dotfilesSources = {
        # bas = bas-dotfiles;
      };

      mkNixosSpecialArgs = name: attrs: {
        inherit home-manager inv sops-nix dotfilesSources disko;
        pkgsUnstable = makePkgsUnstable attrs.system;

        # Always point at the actual nixos/modules path instead of the attrset
        # of predefined modules exposed under nixpkgs.nixosModules.
        modulesPath = "${nixpkgs}/nixos/modules";

        currentHost = name;
      };

      mkHost = name: attrs:
        nixpkgs.lib.nixosSystem {
          system = attrs.system;
          specialArgs = mkNixosSpecialArgs name attrs;
          modules =
            [ home-manager.nixosModules.home-manager ./modules/default.nix ];
        };

      nixosConfigurations = lib.mapAttrs mkHost inv.hosts;

      mkHomeConfigs = hostName: hostAttrs:
        let
          hostUsers = inv.hosts.${hostName}.users or [ ];
          managedUsers = lib.filter (user:
            (inv.users.${user}.homeManaged or false)) hostUsers;
          system = hostAttrs.system;
          pkgs = makePkgs system;
          pkgsUnstable = makePkgsUnstable system;
          osConfig = nixosConfigurations.${hostName}.config;
        in lib.listToAttrs (map (user:
          let
            userCfg = inv.users.${user};
            baseModules = [ ./modules/home/default.nix ]
              ++ lib.optional (userCfg ? envFile) userCfg.envFile
              ++ [{
                home.username = user;
                home.homeDirectory = "/home/${user}";
                home.stateVersion = inv.release;
                roles = userCfg.roles or { };
                programs.home-manager.enable = true;
                systemd.user.startServices = false;
              }];
          in {
            name = "${user}@${hostName}";
            value = home-manager.lib.homeManagerConfiguration {
              inherit pkgs;
              extraSpecialArgs = {
                inherit pkgsUnstable dotfilesSources inv osConfig;
                currentHost = hostName;
              };
              modules = baseModules;
            };
          }) managedUsers);

      homeConfigurations = lib.concatMapAttrs mkHomeConfigs inv.hosts;

    in {
      inherit nixosConfigurations homeConfigurations;
    };
}
