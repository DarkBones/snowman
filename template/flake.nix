{
  description = "A new Snowman user configuration";

  # New users: you usually do NOT need to change this file for your first
  # successful install. Start with inventory.nix first.

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager/release-25.05";
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

    # Optional, later: add pinned dotfiles inputs here.
    # This is the reproducible/stable dotfiles path, but you can ignore it
    # until after your first machine works.
    #
    # Example:
    # my-dotfiles = {
    #   url = "github:YourUserName/dotfiles";
    #   flake = false;
    # };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      sops-nix,
      snowman,
      ...
    }@inputs:
    let
      lib = nixpkgs.lib;

      # This is your source of truth.
      # Most first-time users should spend their time in inventory.nix, not here.
      inv = import ./inventory.nix;

      # Optional, later: map pinned dotfiles inputs here.
      # If you leave this empty, Snowman can still work and the dotfiles role
      # can use git fallback or remain disabled until you are ready.
      #
      # Example (if you added `my-dotfiles` above):
      # dotfilesSources = {
      #   alice = inputs.my-dotfiles;
      # };
      dotfilesSources = { };

      makePkgs =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
      makePkgsUnstable =
        system:
        import inputs.nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
        };

      mkNixosSpecialArgs = name: attrs: {
        inherit
          home-manager
          inv
          sops-nix
          dotfilesSources
          ;
        pkgsUnstable = makePkgsUnstable attrs.system;
        modulesPath = "${nixpkgs}/nixos/modules";
        currentHost = name;
        sopsConfigPath = ./.sops.yaml;
        networkSecretsPath = ./networks/secrets.yml;
        extraHomeImports = [
          ./home/roles
          ./home/overrides
        ];
      };

      mkHost =
        name: attrs:
        let
          host = inv.hosts.${name};
          hostName = host.hostname or name;
          hwFile = ./hosts/${hostName}-hardware-configuration.nix;
        in
        lib.nixosSystem {
          system = attrs.system;
          specialArgs = mkNixosSpecialArgs name attrs;
          modules = [
            # Snowman engine
            snowman.nixosModules.default

            # Home Manager integration
            home-manager.nixosModules.home-manager

            # This keeps the first install safe:
            # - import hardware if it exists
            # - fail with a clear message if you forgot to import it
            (
              { lib, ... }:
              {
                imports = lib.optional (builtins.pathExists hwFile) hwFile;

                assertions = [
                  {
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
                  }
                ];
              }
            )
          ]
          ++ (attrs.extraModules or [ ]);
        };

      # -------- Home Manager configs --------

      mkHome =
        hostName: user:
        let
          host = inv.hosts.${hostName};
          system = host.system or "x86_64-linux";
          isDarwin = lib.hasSuffix "darwin" system;
          cfgName = "${user}@${hostName}";

          # Resolve actual local username (for macOS aliases)
          localAccountNames = host.localAccountNames or { };
          actualUsername =
            if builtins.hasAttr user localAccountNames then localAccountNames.${user} else user;
          cfgNameActual = "${actualUsername}@${hostName}";

          value = home-manager.lib.homeManagerConfiguration {
            pkgs = makePkgs system;

            extraSpecialArgs = {
              inherit
                inputs
                inv
                sops-nix
                dotfilesSources
                ;
              pkgsUnstable = makePkgsUnstable system;
              currentHost = hostName;
              sopsConfigPath = ./.sops.yaml;
              networkSecretsPath = ./networks/secrets.yml;
            };

            modules = [
              # Ensure HM knows which user this config is for
              (
                { lib, ... }:
                {
                  home.username = lib.mkDefault actualUsername;
                  home.homeDirectory = lib.mkDefault (
                    if isDarwin then "/Users/${actualUsername}" else "/home/${actualUsername}"
                  );
                }
              )

              (
                { lib, currentHost, ... }:
                let
                  hostCfg = inv.hosts.${currentHost};
                  userCfg = inv.users.${user};

                  userRoles = userCfg.roles or { };
                  enabledUserRoles = lib.filterAttrs (_: roleCfg: roleCfg ? enable && roleCfg.enable) userRoles;

                  hostRoleFilter = hostCfg.availableRoles or null;

                  finalRoles =
                    if hostRoleFilter == null then
                      enabledUserRoles
                    else
                      lib.filterAttrs (roleName: _: lib.elem roleName hostRoleFilter) enabledUserRoles;
                in
                {
                  # Ensure sourceKey stays the inventory name even if home.username is local name
                  roles =
                    finalRoles
                    // (lib.optionalAttrs (finalRoles ? dotfiles) {
                      dotfiles = finalRoles.dotfiles // {
                        sourceKey = lib.mkDefault user;
                      };
                    });
                }
              )

              snowman.homeModules.default
              ./home
              ./home/roles
              ./home/overrides
            ];
          };
        in
        [
          {
            name = cfgName;
            inherit value;
          }
        ]
        ++ (lib.optional (cfgName != cfgNameActual) {
          name = cfgNameActual;
          inherit value;
        });

      homeConfigurations = lib.listToAttrs (
        lib.concatMap (
          hostName:
          let
            host = inv.hosts.${hostName};
            users = host.users or (builtins.attrNames inv.users);
          in
          lib.concatMap (user: mkHome hostName user) users
        ) (builtins.attrNames inv.hosts)
      );

    in
    {
      nixosConfigurations = lib.mapAttrs mkHost inv.hosts;
      inherit homeConfigurations;
    };
}
