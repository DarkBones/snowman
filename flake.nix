{
  description = "Snowman - An inventory-driven NixOS framework";

  # These inputs are just needed to *build* the modules,
  # not for your own config
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    sops-nix.url = "github:mic92/sops-nix";
  };

  outputs =
    inputs@{ self, nixpkgs, ... }:
    {
      nixosModules.default = ./modules/default.nix;
      homeModules.default = ./modules/home;

      # Pure helpers, usable from body flakes (e.g. role resolution for
      # standalone homeConfigurations, so the logic is not duplicated).
      lib.roles = import ./lib/roles.nix { lib = nixpkgs.lib; };

      templates.default = {
        path = ./template;
        description = "Default Snowman user configuration";
      };

      formatter.x86_64-linux =
        let
          pkgs = import nixpkgs { system = "x86_64-linux"; };
        in
        pkgs.nixpkgs-fmt;
    };
}
