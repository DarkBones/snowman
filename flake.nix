{
  description = "Snowman minimal spine";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    disko.url = "github:nix-community/disko";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    agenix.url = "github:ryantm/agenix";
  };

  outputs = { self, nixpkgs, home-manager, disko, agenix, ... }:
    let
      inv = import ./inventory.nix;

      mkHost = name: attrs:
        nixpkgs.lib.nixosSystem {
          system = attrs.system;
          specialArgs = {
            inherit home-manager inv;
            currentHost = name;
          };
          modules = [
            home-manager.nixosModules.home-manager
            disko.nixosModules.disko
            agenix.nixosModules.default
            ./modules
          ];
        };
    in {
      nixosConfigurations = nixpkgs.lib.mapAttrs mkHost inv.hosts;

      age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    };
}
