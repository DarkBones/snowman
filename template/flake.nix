{
  description = "A new Snowman user configuration";

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
      #
      # Example (if you added `bas-dotfiles` above):
      #
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
        pkgs = makePkgs attrs.system;
        modulesPath = "${nixpkgs}/nixos/modules";
        currentHost = name;
        sopsConfigPath = ./.sops.yaml;
        networkSecretsPath = ./networks/secrets.yml;

        extraHomeImports = [ ./home/roles ./home/overrides ];
      };

      mkHost = name: attrs:
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
    in { nixosConfigurations = lib.mapAttrs mkHost inv.hosts; };
}
