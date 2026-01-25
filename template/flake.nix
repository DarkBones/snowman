{
  description = "A new Snowman user configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixos-hardware.url = "github:NixOS/nixos-hardware";

    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    snowman = {
      url = "github:DarkBones/snowman";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Optional: add pinned dotfiles inputs here, e.g.:
    # bas-dotfiles = {
    #   url = "github:YourUserName/dotfiles";
    #   flake = false;
    # };
  };

  outputs = { self, nixpkgs, home-manager, sops-nix, snowman, ... }@inputs:
    let
      lib = nixpkgs.lib;

      # This is YOUR inventory, not snowman's
      inv = import ./inventory.nix;

      # This is where you map your dotfiles inputs (optional).
      # Example (if you added `bas-dotfiles` above):
      # dotfilesSources = {
      #   bas = inputs.bas-dotfiles;
      # };
      dotfilesSources = { };

      makePkgs = system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      makePkgsUnstable = system:
        import inputs.nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
        };

      mkNixosSpecialArgs = name: attrs: {
        inherit home-manager inv sops-nix dotfilesSources;
        pkgsUnstable = makePkgsUnstable attrs.system;
        modulesPath = "${nixpkgs}/nixos/modules";
        currentHost = name;
        sopsConfigPath = ./.sops.yaml;
        networkSecretsPath = ./networks/secrets.yml;
        extraHomeImports = [ ./home/roles ./home/overrides ];
      };

      mkHost = name: attrs:
        # { strictHw ? true }: # Enable to hard error on missing hardware-configration.nix
        let
          host = inv.hosts.${name};
          hostName = host.hostname or name;
          hwFile = ./hosts/${hostName}-hardware-configuration.nix;
        in lib.nixosSystem {
          system = attrs.system;
          specialArgs = mkNixosSpecialArgs name attrs;
          modules = [
            # Snowman engine
            snowman.nixosModules.default

            # Home Manager integration
            home-manager.nixosModules.home-manager

            # Per-host wrapper that:
            #  - imports the hardware config
            #  - asserts that it exists
            ({ lib, ... }: {
              imports = lib.optional (builtins.pathExists hwFile) hwFile;

              assertions = [{
                assertion = builtins.pathExists hwFile;
                message = ''
                  ❌ Snowman: Hardware configuration missing for host "${name}"
                     (hostname "${hostName}").

                  Expected file:
                    hosts/${hostName}-hardware-configuration.nix

                  Fix:
                    On the machine this NixOS install is running on, execute:

                      ./bin/snowman-import-hardware ${name}

                    Then re-run:

                      sudo nixos-rebuild switch --flake .#${name}
                '';
              }];
            })
          ] ++ (attrs.extraModules or [ ]);
        };

      # -------- Home Manager configs --------

      mkHome = hostName: user:
        let
          host = inv.hosts.${hostName};
          system = host.system or "x86_64-linux";
          cfgName = "${user}@${hostName}";
        in {
          name = cfgName;
          value = home-manager.lib.homeManagerConfiguration {
            pkgs = makePkgs system;

            extraSpecialArgs = {
              inherit inputs inv sops-nix dotfilesSources;
              pkgsUnstable = makePkgsUnstable system;
              currentHost = hostName;
              sopsConfigPath = ./.sops.yaml;
              networkSecretsPath = ./networks/secrets.yml;
            };

            modules = [
              # Ensure HM knows which user this config is for
              ({ lib, ... }: {
                home.username = lib.mkDefault user;
                home.homeDirectory = lib.mkDefault "/home/${user}";
              })

              ({ lib, currentHost, ... }:
                let
                  hostCfg = inv.hosts.${currentHost};
                  userCfg = inv.users.${user};

                  userRoles = userCfg.roles or { };
                  enabledUserRoles = lib.filterAttrs
                    (_: roleCfg: roleCfg ? enable && roleCfg.enable) userRoles;

                  hostRoleFilter = hostCfg.availableRoles or null;

                  finalRoles = if hostRoleFilter == null then
                    enabledUserRoles
                  else
                    lib.filterAttrs
                    (roleName: _: lib.elem roleName hostRoleFilter)
                    enabledUserRoles;
                in { roles = finalRoles; })

              snowman.homeModules.default
              ./home
              ./home/roles
              ./home/overrides
            ];
          };
        };

      homeConfigurations = lib.listToAttrs (lib.concatMap (hostName:
        let
          host = inv.hosts.${hostName};
          users = host.users or (builtins.attrNames inv.users);
        in map (user: mkHome hostName user) users)
        (builtins.attrNames inv.hosts));

    in {
      nixosConfigurations = lib.mapAttrs mkHost inv.hosts;
      inherit homeConfigurations;
    };
}
