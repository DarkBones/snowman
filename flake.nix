{
  description = "Snowman minimal spine";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    disko.url = "github:nix-community/disko";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    agenix.url = "github:ryantm/agenix";
    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, nixpkgs-unstable, home-manager, disko, agenix, ... }:
    let
      inv = import ./inventory.nix;

      mkHost = name: attrs:
        let
          pkgsUnstable = import nixpkgs-unstable {
            system = attrs.system;
            config = { allowUnfree = true; };
          };
        in nixpkgs.lib.nixosSystem {
          system = attrs.system;
          specialArgs = {
            inherit home-manager inv pkgsUnstable;
            currentHost = name;
          };
          modules = [
            home-manager.nixosModules.home-manager
            disko.nixosModules.disko
            agenix.nixosModules.default
            ./modules
          ];
        };
    in { nixosConfigurations = nixpkgs.lib.mapAttrs mkHost inv.hosts; };
}
