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
        system = "x86_64-linux";
        pkgs = import nixpkgs { inherit system; };
        agenixBin = "${agenix.packages.${system}.default}/bin/agenix";
      in let
        script = ''
          #!/usr/bin/env bash
          set -euo pipefail

          if [ $# -lt 2 ] || [ $# -gt 3 ]; then
            echo "usage: nix run .#add-user <username> <host|user@host> [ssh-user]" >&2
            exit 1
          fi

          USERNAME="$1"
          TARGET="$2"
          SSH_USER="$3:-$(printf '%s' "$TARGET" | cut -d@ -f1)"

          ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || true)"
          if [ -z "$ROOT_DIR" ]; then
            echo "error: run inside the Snowman repo (git root not found)." >&2
            exit 2
          fi
          cd "$ROOT_DIR"

          get_mkpasswd() {
            if command -v mkpasswd >/dev/null 2>&1; then
              mkpasswd "$@"
            else
              nix shell --quiet nixpkgs#whois -c mkpasswd "$@"
            fi
          }

          test -f "secrets.nix" || { echo "error: secrets.nix missing"; exit 3; }
          test -f "users/registry.nix" || { echo "error: users/registry.nix missing"; exit 4; }

          echo "[snowman:add-user] Reading host key from $TARGET…"
          HOST_PUB="$(ssh "$TARGET" 'cat /etc/ssh/ssh_host_ed25519_key.pub' 2>/dev/null || true)"
          if [ -z "$HOST_PUB" ]; then
            echo "Remote host key requires sudo; prompting on $TARGET…"
            HOST_PUB="$(ssh -t "$TARGET" 'sudo cat /etc/ssh/ssh_host_ed25519_key.pub' | tr -d "\r")"
          fi

          mkdir -p users/keys
          : > "users/keys/$USERNAME.pub"

          # === users/registry.nix ===
          if ! grep -qE "^[[:space:]]*$USERNAME[[:space:]]*=" users/registry.nix; then
            echo "[snowman:add-user] Adding $USERNAME to users/registry.nix…"
            TMP="$(mktemp)"
            awk -v uname="$USERNAME" -v pub="../keys/$USERNAME.pub" -v secret="../secrets/$USERNAME-password.age" '
              BEGIN { done=0 }
              /^\}/ && !done {
                print "  " uname " = {"
                print "    uid = 1001;"
                print "    groups = [ \"wheel\" ];"
                print "    shell = \"zsh\";"
                print "    sshPubKeyFile = " pub ";"
                print "    passwordSecret = " secret ";"
                print ""
                print "    roles = {"
                print "      dev.enable = true;"
                print "      dotfiles = {"
                print "        enable = true;"
                print "        sparse = [ \"nvim\" ];"
                print "        linkMap = { \".config/nvim\" = \"nvim/.config/nvim\"; };"
                print "      };"
                print "    };"
                print "  };"
                done=1
              }
              { print }
            ' users/registry.nix > "$TMP"
            mv "$TMP" users/registry.nix
          fi

          # === secrets.nix ===
          if ! grep -q "secrets/$USERNAME-password.age" secrets.nix; then
            echo "[snowman:add-user] Adding $USERNAME to secrets.nix…"
            TMP="$(mktemp)"
            if grep -q "^let" secrets.nix; then
              # has 'let ... in {'
              awk -v uname="$USERNAME" -v key="$HOST_PUB" '
                /^}/ && ++n==1 { print "  \"secrets/" uname "-password.age\".publicKeys = [ \"" key "\" ];"; }
                { print }
              ' secrets.nix > "$TMP"
            else
              # plain { … }
              awk -v uname="$USERNAME" -v key="$HOST_PUB" '
                /^}/ && ++n==1 { print "  \"secrets/" uname "-password.age\".publicKeys = [ \"" key "\" ];"; }
                { print }
              ' secrets.nix > "$TMP"
            fi
            mv "$TMP" secrets.nix
          fi

          echo "[snowman:add-user] Create a login password for $USERNAME (hashed with yescrypt)…"
          HASH="$(get_mkpasswd -m yescrypt)"
          printf '%s\n' "$HASH" | EDITOR=tee sudo -E ${agenixBin} -e "secrets/$USERNAME-password.age" >/dev/null

          echo "[snowman:add-user] Deploying to $TARGET…"
          nix run .#deploy-vm "$TARGET" "$SSH_USER"
          echo "✅ User $USERNAME deployed successfully."
        '';
        drv = pkgs.writeShellScriptBin "add-user" "$script";
      in {
        type = "app";
        program = "${drv}/bin/add-user";
      };
    };
}
