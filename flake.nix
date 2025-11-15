{
  description = "Snowman - An inventory-driven NixOS framework";

  # These inputs are just needed to *build* the modules,
  # not for your own config
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    sops-nix.url = "github:mic92/sops-nix";
    disko.url = "github:nix-community/disko";
  };

  outputs = inputs@{ self, nixpkgs, ... }: {

    nixosModules.default = ./modules;
    homeModules.default = ./modules/home;

    templates.default = {
      path = ./template;
      description = "Default Snowman user configuration";
    };

    formatter.x86_64-linux =
      let pkgs = import nixpkgs { system = "x86_64-linux"; };
      in pkgs.nixpkgs-fmt;
  };
}
