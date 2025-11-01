{
  description = "Snowman — Bas's forever NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, ... }:
    let
      systems = { vm-snowman = "x86_64-linux"; };
      mkHost = name:
        nixpkgs.lib.nixosSystem {
          system = systems.${name};
          specialArgs = { inherit home-manager; };
          modules = [
            ./modules/guard/base-required.nix
            home-manager.nixosModules.home-manager
            ./modules/base.nix
            ./hosts/${name}/configuration.nix
          ];
        };
    in {
      nixosConfigurations.vm-snowman = mkHost
        "vm-snowman"; # TODO: Place in easy to configure location and import

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
    };
}
