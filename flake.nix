{
  description = "Snowman — Bas's forever NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    agenix.url = "github:ryantm/agenix";
  };

  outputs = { self, nixpkgs, home-manager, agenix, ... }:
    let
      inv = import ./inventory.nix;
      mkHost = name: attrs:
        nixpkgs.lib.nixosSystem {
          system = attrs.system;
          specialArgs = {
            inherit home-manager;
            release = inv.release;
            snowmanInventory = inv;
          };
          modules = [
            agenix.nixosModules.default
            ./modules/guard/base-required.nix
            home-manager.nixosModules.home-manager
            ./modules/base.nix
            ./hosts/${name}/configuration.nix
            (import ./modules/host-profile.nix { inherit name attrs; })
          ];
        };
    in {
      nixosConfigurations = nixpkgs.lib.mapAttrs mkHost inv.hosts;

      apps.x86_64-linux.deploy-vm = let
        pkgs = import nixpkgs { system = "x86_64-linux"; };
        script = ''
          #!/usr/bin/env bash
          set -euo pipefail

          if [ $# -lt 1 ] || [ $# -gt 2 ]; then
            echo "usage: nix run .#deploy-vm <host|user@host> [ssh-user]" >&2
            exit 1
          fi

          arg="$1"
          if echo "$arg" | grep -q "@"; then
            user=$(printf '%s' "$arg" | cut -d@ -f1)
            target=$(printf '%s' "$arg" | cut -d@ -f2-)
          else
            target="$arg"
            if [ $# -ge 2 ]; then
              user="$2"
            else
              echo "error: missing SSH user. Use 'user@host' or pass [ssh-user] as 2nd arg." >&2
              echo "usage: nix run .#deploy-vm <host|user@host> [ssh-user]" >&2
              exit 2
            fi
          fi

          # Use NIX_SSHOPTS to enable SSH connection sharing
          export NIX_SSHOPTS="-o ControlMaster=auto -o ControlPersist=60 -o ControlPath=~/.ssh/control-%r@%h:%p"

          exec nix run nixpkgs#nixos-rebuild -- switch \
            --flake .#vm-snowman \
            --target-host "$user@$target" \
            --build-host "$user@$target" \
            --use-remote-sudo
        '';
        drv = pkgs.writeShellScriptBin "deploy-vm" script;
      in {
        type = "app";
        program = "${drv}/bin/deploy-vm";
      };

      formatter = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-darwin" ]
        (system:
          let pkgs = import nixpkgs { inherit system; };
          in pkgs.nixpkgs-fmt);
    };
}
