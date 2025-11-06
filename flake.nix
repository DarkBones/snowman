{
  description = "Snowman minimal spine";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    disko.url = "github:nix-community/disko";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
  };

  outputs = { self, nixpkgs, home-manager, disko, ... }:
    let
      inv = import ./inventory.nix;

      mkHost = name: attrs:
        nixpkgs.lib.nixosSystem {
          system = attrs.system;
          specialArgs = { inherit home-manager inv; };
          modules = [
            home-manager.nixosModules.home-manager
            disko.nixosModules.disko
            ./modules/hardware/from-inventory.nix
            ./modules/users/from-inventory.nix
          ];
        };
    in { nixosConfigurations = nixpkgs.lib.mapAttrs mkHost inv.hosts; };
}
