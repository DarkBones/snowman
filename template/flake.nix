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
      # url = "github:DarkBones/snowman";
      url = "path:..";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Add your pinned dotfiles here, e.g.:
    # bas-dotfiles = {
    #   url = "github:DarkBones/dotfiles";
    #   flake = false;
    # };
  };

  outputs = { self, nixpkgs, home-manager, sops-nix, snowman, ... }@inputs:
    let
      lib = nixpkgs.lib;

      # This is YOUR inventory, not snowman's
      inv = import ./inventory.nix;

      # This is you map your dotfile inputs
      dotfilesSources = {
        # bas = inputs.bas-dotfiles;
      };

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

        extraHomeImports = [ ./home/roles ];
      };

      mkHost = name: attrs:
        lib.nixosSystem {
          system = attrs.system;
          specialArgs = mkNixosSpecialArgs name attrs;
          modules = [
            snowman.nixosModules.default
            home-manager.nixosModules.home-manager
            ./hardware-configuration.nix
          ];
        };
    in { nixosConfigurations = lib.mapAttrs mkHost inv.hosts; };
}
