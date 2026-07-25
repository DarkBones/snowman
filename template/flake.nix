{
  description = "A new Snowman user configuration";

  # New users: you usually do NOT need to change this file for your first
  # successful install. Start with inventory.nix first.

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

      # Builds one NixOS host from the inventory (engine wiring + hardware
      # safety net). See lib/mk-host.nix.
      mkHost = import ./lib/mk-host.nix {
        inherit
          lib
          nixpkgs
          home-manager
          sops-nix
          snowman
          inv
          dotfilesSources
          makePkgsUnstable
          ;
      };

      # Standalone Home Manager configs: one per host × user, including
      # macOS machines. See lib/home-configurations.nix.
      homeConfigurations = import ./lib/home-configurations.nix {
        inherit
          lib
          inputs
          inv
          sops-nix
          snowman
          dotfilesSources
          makePkgs
          makePkgsUnstable
          ;
      };
    in
    {
      nixosConfigurations = lib.mapAttrs mkHost inv.hosts;
      inherit homeConfigurations;
    };
}
