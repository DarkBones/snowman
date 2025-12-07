{ pkgs, currentHost, ... }:
let
  # CHANGEME: This is where your mutable dotfiles live in Dev mode.
  devDotfilesPath = "$HOME/Developer/dotfiles";

  # CHANGEME: This is the target directory inside the dotfiles repo
  devNvimConfig = "${devDotfilesPath}/nvim/.config/nvim";
in {
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "snowman-dotfiles" ''
      set -euo pipefail

      DEV_NVIM="${devNvimConfig}"
      TARGET_NVIM="$HOME/.config/nvim"

      # ----------------------------------------------------------
      # No args → show current mode
      # ----------------------------------------------------------
      if [ "$#" -eq 0 ]; then
        if [ -L "$TARGET_NVIM" ]; then
          target="$(readlink -f "$TARGET_NVIM" 2>/dev/null || true)"

          if [ -n "$target" ] && [ "$target" = "$DEV_NVIM" ]; then
            echo "Current Snowman dotfiles mode: DEV"
            echo "  $TARGET_NVIM -> $target"
          else
            echo "Current Snowman dotfiles mode: PROD"
            echo "  $TARGET_NVIM -> $target"
          fi
        elif [ -e "$TARGET_NVIM" ]; then
          echo "Current Snowman dotfiles mode: UNKNOWN"
          echo "  $TARGET_NVIM exists but is not a symlink"
        else
          echo "Current Snowman dotfiles mode: UNKNOWN"
          echo "  $TARGET_NVIM does not exist"
        fi

        echo
        echo "Usage:"
        echo "  snowman-dotfiles dev    # enable dev mode (impure eval, link to repo)"
        echo "  snowman-dotfiles prod   # enable prod mode (pure eval, nix store)"
        exit 0
      fi

      MODE="$1"
      FLAKE_DIR="$(pwd)"

      case "$MODE" in
        dev)
          echo "➜ Enabling dotfiles DEV mode (SNOWMAN_DOTFILES_MODE=dev)"
          export SNOWMAN_DOTFILES_MODE=dev
          ;;

        prod|production)
          echo "➜ Enabling dotfiles PROD mode (unsetting SNOWMAN_DOTFILES_MODE)"
          unset SNOWMAN_DOTFILES_MODE

          # Make sure ~/.config/nvim is clean before HM recreates it
          if [ -e "$TARGET_NVIM" ] || [ -L "$TARGET_NVIM" ]; then
            echo "➜ Removing existing $TARGET_NVIM before prod rebuild"
            rm -rf "$TARGET_NVIM"
          fi
          ;;

        *)
          echo "Usage: snowman-dotfiles [dev|prod]" >&2
          exit 1
          ;;
      esac

      echo "➜ Rebuilding NixOS for host ${currentHost} in $MODE mode..."

      if [ "$MODE" = "dev" ]; then
        # Dev: needs SNOWMAN_DOTFILES_MODE + --impure so builtins.getEnv works
        sudo -E nixos-rebuild switch --impure --flake ".''${currentHost}"

        if [ -d "$DEV_NVIM" ]; then
          echo "➜ Linking $TARGET_NVIM -> $DEV_NVIM (dev mode)"
          rm -rf "$TARGET_NVIM"
          ln -s "$DEV_NVIM" "$TARGET_NVIM"
        else
          echo "⚠ DEV nvim dir '$DEV_NVIM' does not exist, skipping link." >&2
        fi
      else
        # Prod: pure evaluation, no env dependency
        sudo nixos-rebuild switch --flake ".''${currentHost}"
      fi
    '')
  ];
}
