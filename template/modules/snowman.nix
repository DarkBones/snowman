{ pkgs, currentHost, ... }: {
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "snowman" ''
      set -euo pipefail

      MODE_FILE="/etc/snowman/dotfiles-mode"

      show_help() {
        echo "Usage: snowman [dev|prod|status]"
        echo ""
        echo "  dev     - Enable dev mode (mutable symlinks managed by HM)"
        echo "  prod    - Enable prod mode (immutable store links managed by HM) [default]"
        echo "  status  - Show current mode (global system state)"
        exit 0
      }

      status() {
        if [ -r "$MODE_FILE" ]; then
          mode="$(cat "$MODE_FILE" || true)"
          case "$mode" in
            dev)
              echo "dotfiles: DEV (from $MODE_FILE)"
              ;;
            prod)
              echo "dotfiles: PROD (from $MODE_FILE)"
              ;;
            *)
              echo "dotfiles: UNKNOWN ('$mode' in $MODE_FILE)"
              ;;
          esac
        else
          echo "dotfiles: UNKNOWN ($MODE_FILE not present)"
        fi
      }

      set_mode_file() {
        mode="$1"
        # Only update after a successful rebuild
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
          echo "➜ Enabling dotfiles PROD mode (unsetting SNOWMAN_DOTFILES_MODE)"
          unset SNOWMAN_DOTFILES_MODE
          MODE="prod"
          ;;
        *)
          echo "Unknown mode: $MODE"
          show_help
          ;;
      esac

      echo "➜ Rebuilding NixOS for host ${currentHost}..."

      if [ "$MODE" = "dev" ]; then
        # Dev needs --impure to read the env var
        sudo -H -E nixos-rebuild switch --impure --flake ".#${currentHost}"
        set_mode_file dev
      else
        # Prod is pure
        sudo -H nixos-rebuild switch --flake ".#${currentHost}"
        set_mode_file prod
      fi
    '')
  ];
}
