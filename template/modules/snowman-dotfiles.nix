{ pkgs, currentHost, inv, lib, ... }:
let
  mkUserCase = user: userData:
    let
      cfg = userData.roles.dotfiles or { };
      enabled = cfg.enable or false;

      # Where the repo lives (e.g. "Developer/dotfiles")
      repoDir = cfg.dir or "dotfiles";

      # The map of { ".config/nvim" = "nvim/.config/nvim"; ... }
      linkMap = cfg.linkMap or { };

      # Convert linkMap to a Bash array entries: "target:source"
      linkEntries = lib.concatStringsSep "\n"
        (lib.mapAttrsToList (target: src: "  \"${target}:${src}\"") linkMap);
    in if !enabled then
      ""
    else ''
      "${user}")
        REPO_ROOT="$HOME/${repoDir}"
        LINKS=(
        ${linkEntries}
        )
        ;;
    '';

  # Generate the case statement for all users in the inventory
  userCases =
    lib.concatStringsSep "\n" (lib.mapAttrsToList mkUserCase inv.users);

in {
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "snowman-dotfiles" ''
      set -euo pipefail

      # Detect who is running the script
      CURRENT_USER="$(whoami)"

      # Default values
      REPO_ROOT=""
      LINKS=()

      # -----------------------------------------------------------------------
      # DYNAMIC CONFIGURATION FROM INVENTORY.NIX
      # -----------------------------------------------------------------------
      case "$CURRENT_USER" in
      ${userCases}
      *)
        echo "❌ Error: User '$CURRENT_USER' does not have dotfiles enabled in inventory.nix"
        exit 1
        ;;
      esac

      show_help() {
        echo "Usage: snowman-dotfiles [dev|prod]"
        echo ""
        echo "  dev   - Enable dev mode (impure, symlinks from ~/$REPO_ROOT)"
        echo "  prod  - Enable prod mode (pure, managed by Nix Store)"
        exit 0
      }

      if [ "$#" -eq 0 ]; then show_help; fi

      MODE="$1"

      # -----------------------------------------------------------------------
      # 1. PRE-FLIGHT CHECKS & CLEANUP
      # -----------------------------------------------------------------------
      case "$MODE" in
        dev)
          echo "➜ Enabling dotfiles DEV mode (SNOWMAN_DOTFILES_MODE=dev)"
          export SNOWMAN_DOTFILES_MODE=dev
          
          if [ ! -d "$REPO_ROOT" ]; then
             echo "❌ Error: Dotfiles repo not found at $REPO_ROOT"
             echo "   (Configured via roles.dotfiles.dir in inventory.nix)"
             exit 1
          fi
          ;;

        prod|production)
          echo "➜ Enabling dotfiles PROD mode (unsetting SNOWMAN_DOTFILES_MODE)"
          unset SNOWMAN_DOTFILES_MODE

          # Clean up existing symlinks so Home Manager can overwrite them cleanly
          echo "➜ Cleaning up existing symlinks..."
          for entry in "''${LINKS[@]}"; do
            TARGET="$HOME/''${entry%%:*}"
            if [ -L "$TARGET" ]; then
              rm "$TARGET"
              echo "   Deleted symlink: $TARGET"
            elif [ -e "$TARGET" ]; then
              echo "   ⚠️  Warning: $TARGET exists but is not a symlink. Skipping."
            fi
          done
          ;;
        *)
          show_help
          ;;
      esac

      # -----------------------------------------------------------------------
      # 2. REBUILD NIXOS
      # -----------------------------------------------------------------------
      echo "➜ Rebuilding NixOS for host ${currentHost}..."

      if [ "$MODE" = "dev" ]; then
        sudo -E nixos-rebuild switch --impure --flake "/etc/nixos#${currentHost}"
      else
        sudo nixos-rebuild switch --flake "/etc/nixos#${currentHost}"
      fi

      # -----------------------------------------------------------------------
      # 3. POST-BUILD LINKING (DEV MODE ONLY)
      # -----------------------------------------------------------------------
      if [ "$MODE" = "dev" ]; then
        echo "➜ Creating mutable symlinks..."
        
        for entry in "''${LINKS[@]}"; do
          TARGET="$HOME/''${entry%%:*}"
          SOURCE="$REPO_ROOT/''${entry##*:}"
          
          # Ensure parent dir exists
          mkdir -p "$(dirname "$TARGET")"

          if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
             echo "   Replacing existing: $TARGET"
             rm -rf "$TARGET"
          fi

          if [ -e "$SOURCE" ]; then
            ln -s "$SOURCE" "$TARGET"
            echo "   ✅ Linked: $TARGET -> $SOURCE"
          else
            echo "   ❌ Error: Source file not found: $SOURCE"
          fi
        done
      fi
    '')
  ];
}
