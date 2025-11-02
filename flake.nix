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
      systems = { vm-snowman = "x86_64-linux"; };
      mkHost = name:
        nixpkgs.lib.nixosSystem {
          system = systems.${name};
          specialArgs = { inherit home-manager; };
          modules = [
            agenix.nixosModules.default
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

      apps.x86_64-linux.add-user = let
        pkgs = import nixpkgs { system = "x86_64-linux"; };
        drv = pkgs.writeShellScriptBin "add-user" ''
              #!/usr/bin/env bash
              set -euo pipefail

              if [ $# -ne 1 ]; then
                echo "usage: nix run .#add-user <username>" >&2
                exit 1
              fi
              USERNAME="$1"

              ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || true)"
              if [ -z "$ROOT_DIR" ]; then
                echo "error: run inside the Snowman repo (git root not found)." >&2
                exit 2
              fi
              cd "$ROOT_DIR"

              # 0) sanity: required files
              test -f "secrets.nix" || { echo "error: secrets.nix missing"; exit 3; }
              test -f "users/registry.nix" || { echo "error: users/registry.nix missing"; exit 4; }

              # 1) host pubkey for agenix recipients
              HOST_PUB="$(sudo cat /etc/ssh/ssh_host_ed25519_key.pub)"
              if ! grep -qF "$HOST_PUB" secrets.nix; then
                echo "Adding this host key to secrets.nix recipients for $USERNAME…"
                printf '{ "secrets/%s-password.age".publicKeys = [ "%s" ]; }\n' "$USERNAME" "$HOST_PUB" >> secrets.nix
              fi

              # 2) create empty ssh pubkey file (user can paste later)
              mkdir -p users/keys
              touch "users/keys/$USERNAME.pub"

              # 3) insert user block if absent
              if ! grep -qE "^\\s*$USERNAME\\s*=" users/registry.nix; then
                echo "Adding user block to users/registry.nix…"
                NEXT_UID=$(( $(getent passwd | awk -F: '$3>=1000 {print $3}' | sort -n | tail -1) + 1 ))
                cat >> users/registry.nix <<EOF

          $USERNAME = {
            uid = $NEXT_UID;
            groups = [ "wheel" ];
            shell = "zsh";
            sshPubKeyFile = ../keys/$USERNAME.pub;
            passwordSecret = ../secrets/$USERNAME-password.age;

            roles = {
              dev.enable = true;
              dotfiles = {
                enable = true;
                sparse = [ "nvim" ];
                linkMap = { ".config/nvim" = "nvim/.config/nvim"; };
              };
            };
          };
          EOF
              fi

              # 4) generate password hash and write encrypted secret (no editor UI)
              echo "Create a login password for $USERNAME (will be hashed with yescrypt)…"
              HASH="$(nix shell nixpkgs#whois -c mkpasswd -m yescrypt)"
              printf '%s\n' "$HASH" | EDITOR=tee nix run nixpkgs#agenix -- -e "secrets/$USERNAME-password.age" >/dev/null

              echo "Tip: paste $USERNAME's SSH public key into users/keys/$USERNAME.pub (optional)."

              # 5) rebuild this host
              HOST="$(hostname)"
              echo "Rebuilding flake for host $HOST…"
              if ! sudo nixos-rebuild switch --flake .#"$HOST"; then
                echo
                echo "Rebuild failed. Ensure this machine has a host entry .#$HOST in flake.nix."
                echo "You can also run: sudo nixos-rebuild switch --flake .#<your-host-name>"
                exit 5
              fi

              echo "✅ User $USERNAME added. Try: su - $USERNAME"
        '';
      in {
        type = "app";
        program = "${drv}/bin/add-user";
      };
    };
}
