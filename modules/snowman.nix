{ pkgs, currentHost, ... }:
let
  defaultFlakePath = builtins.toString ../.;
in {
  environment.etc."snowman/flake".text = defaultFlakePath + "\n";

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "snowman" ''
      set -euo pipefail

      MODE_FILE="/etc/snowman/dotfiles-mode"
      DEFAULT_FLAKE_FILE="/etc/snowman/flake"

      die() { echo "error: $*" >&2; exit 1; }

      DEFAULT_FLAKE="$(cat "$DEFAULT_FLAKE_FILE" 2>/dev/null || true)"
      FLAKE_REF="''${SNOWMAN_FLAKE:-''${DEFAULT_FLAKE:-${defaultFlakePath}}}"

      # Expand $HOME if present
      if [[ "$FLAKE_REF" == "\$HOME/"* ]]; then
        FLAKE_REF="$HOME/''${FLAKE_REF#\$HOME/}"
      fi

      # Expand ~/
      if [[ "$FLAKE_REF" == "~/"* ]]; then
        FLAKE_REF="$HOME/''${FLAKE_REF#~/}"
      fi

      # Canonicalize local absolute paths
      if [[ "$FLAKE_REF" == /* ]]; then
        FLAKE_REF="$(readlink -f "$FLAKE_REF")"
        [[ -e "$FLAKE_REF" ]] || die "flake path not found: $FLAKE_REF"
      fi

      show_help() {
        echo "Usage: snowman [dev|prod|status]"
        echo ""
        echo "  dev     - Enable dev mode (mutable symlinks managed by HM)"
        echo "  prod    - Enable prod mode (immutable store links managed by HM) [default]"
        echo "  status  - Show current mode"
        echo ""
        echo "Environment:"
        echo "  SNOWMAN_FLAKE  - Override flake path (default: $DEFAULT_FLAKE_FILE)"
        exit 0
      }

      status() {
        if [ -r "$MODE_FILE" ]; then
          mode="$(cat "$MODE_FILE" || true)"
          case "$mode" in
            dev)  echo "dotfiles: DEV (from $MODE_FILE)" ;;
            prod) echo "dotfiles: PROD (from $MODE_FILE)" ;;
            *)    echo "dotfiles: UNKNOWN ('$mode' in $MODE_FILE)" ;;
          esac
        else
          echo "dotfiles: UNKNOWN ($MODE_FILE not present)"
        fi
        echo "flake: $FLAKE_REF"
      }

      set_mode_file() {
        mode="$1"
        sudo -H mkdir -p /etc/snowman
        echo "$mode" | sudo -H tee "$MODE_FILE" >/dev/null
      }

      MODE="''${1:-prod}"

      case "$MODE" in
        -h|--help|help)
          show_help
          ;;
        status)
          status
          exit 0
          ;;
        dev)
          echo "➜ Enabling dotfiles DEV mode (SNOWMAN_DOTFILES_MODE=dev)"
          export SNOWMAN_DOTFILES_MODE=dev
          ;;
        prod|production)
          echo "➜ Enabling dotfiles PROD mode"
          unset SNOWMAN_DOTFILES_MODE
          MODE="prod"
          ;;
        *)
          die "unknown command: $MODE"
          ;;
      esac

      echo "➜ Rebuilding NixOS for host ${currentHost} using flake: $FLAKE_REF"

      if [ "$MODE" = "dev" ]; then
        sudo -H -E nixos-rebuild switch --impure --flake "$FLAKE_REF#${currentHost}"
        set_mode_file dev
      else
        sudo -H nixos-rebuild switch --flake "$FLAKE_REF#${currentHost}"
        set_mode_file prod
      fi
    '')
  ];
}
