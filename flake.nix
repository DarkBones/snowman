{
  description = "Snowman minimal spine";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    nixos-hardware.url = "github:NixOS/nixos-hardware";

    sops-nix = {
      url = "github:mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    ############################################################
    ## OPTIONAL: PINNED DOTFILES INPUTS (ADVANCED)
    ##
    ## By default, Snowman uses "Git mode" for dotfiles:
    ##   - roles.dotfiles.repo / branch / sparse in inventory.nix
    ##   - git clone/pull at Home Manager activation time
    ##
    ## If you want *pinned* dotfiles (reproducible, locked in
    ## flake.lock), you can add git inputs here and wire them
    ## into `dotfilesSources` below.
    ##
    ## Example for user `bas`:
    ##
    ## bas-dotfiles = {
    ##   # Any non-flake git URL works here (https or ssh).
    ##   # This gets pinned in flake.lock.
    ##   url = "github:DarkBones/dotfiles";
    ##   flake = false;
    ## };
    ############################################################
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, disko, sops-nix
    # , bas-dotfiles  # Uncomment when you actually use a pinned dotfiles input
    , ... }:
    let
      inv = import ./inventory.nix;

      mkHost = name: attrs:
        let
          pkgsUnstable = import nixpkgs-unstable {
            system = attrs.system;
            config = { allowUnfree = true; };
          };

          ########################################################
          ## dotfilesSources:
          ##
          ## This attrset is passed into NixOS + Home Manager
          ## as `specialArgs` / `extraSpecialArgs`.
          ##
          ## - When empty (default), all users use Git mode.
          ## - To enable pinned mode for a user, map a key
          ##   (usually their username) to a flake input.
          ##
          ##   Example, together with the commented input above:
          ##
          ##   dotfilesSources = {
          ##     bas = bas-dotfiles;
          ##   };
          ##
          ## In inventory.nix you can then set:
          ##
          ##   users.bas.roles.dotfiles.sourceKey = "bas";
          ##
          ## or just rely on the default sourceKey = home.username.
          ########################################################
          dotfilesSources = {
            # bas = bas-dotfiles;
          };

        in nixpkgs.lib.nixosSystem {
          system = attrs.system;
          specialArgs = {
            inherit home-manager inv pkgsUnstable sops-nix dotfilesSources
              disko;

            modulesPath = nixpkgs.nixosModules;

            currentHost = name;
          };
          modules =
            [ home-manager.nixosModules.home-manager ./modules/default.nix ];
        };
    in { nixosConfigurations = nixpkgs.lib.mapAttrs mkHost inv.hosts; };
}
