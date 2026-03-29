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
        echo "Usage: snowman <command> [args]"
        echo ""
        echo "Commands:"
        echo "  prod          Rebuild in prod mode (immutable dotfiles)"
        echo "  dev           Rebuild in dev mode (mutable dotfiles)"
        echo "  update [inp]  Update flake inputs (all or specific input)"
        echo "  diff          Show what would change (dry-run)"
        echo "  rollback      Rollback to previous generation"
        echo "  gc            Garbage collect old generations"
        echo "  status        Show current mode and flake path"
        echo ""
        echo "Environment:"
        echo "  SNOWMAN_FLAKE  Override flake path"
        echo ""
        echo "Current flake: $FLAKE_REF"
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
        echo "host: ${currentHost}"
      }

      set_mode_file() {
        mode="$1"
        sudo -H mkdir -p /etc/snowman
        echo "$mode" | sudo -H tee "$MODE_FILE" >/dev/null
      }

      do_update() {
        local input="''${1:-}"
        if [ -n "$input" ]; then
          echo "➜ Updating flake input: $input"
          nix flake update "$input" --flake "$FLAKE_REF"
        else
          echo "➜ Updating all flake inputs"
          nix flake update --flake "$FLAKE_REF"
        fi
      }

      get_current_mode() {
        if [ -r "$MODE_FILE" ]; then
          cat "$MODE_FILE" 2>/dev/null || echo "prod"
        else
          echo "prod"
        fi
      }

      do_diff() {
        local current_mode
        current_mode="$(get_current_mode)"
        echo "➜ Showing changes for ${currentHost} (dry-run, mode: $current_mode)"
        if [ "$current_mode" = "dev" ]; then
          sudo -H -E nixos-rebuild dry-activate --impure --flake "$FLAKE_REF#${currentHost}"
        else
          sudo -H nixos-rebuild dry-activate --flake "$FLAKE_REF#${currentHost}"
        fi
      }

      do_rollback() {
        echo "➜ Rolling back to previous generation"
        sudo -H nixos-rebuild switch --rollback
      }

      do_gc() {
        echo "➜ Garbage collecting old generations"
        sudo nix-collect-garbage -d
        echo "➜ Removing old boot entries"
        sudo /run/current-system/bin/switch-to-configuration boot
      }

      do_rebuild() {
        local mode="$1"
        echo "➜ Rebuilding NixOS for host ${currentHost} using flake: $FLAKE_REF"

        if [ "$mode" = "dev" ]; then
          sudo -H -E nixos-rebuild switch --impure --flake "$FLAKE_REF#${currentHost}"
          set_mode_file dev
        else
          sudo -H nixos-rebuild switch --flake "$FLAKE_REF#${currentHost}"
          set_mode_file prod
        fi
      }

      if [ $# -eq 0 ]; then
        show_help
        exit 1
      fi

      CMD="$1"
      shift

      case "$CMD" in
        -h|--help|help)
          show_help
          exit 0
          ;;
        status)
          status
          ;;
        update)
          do_update "$@"
          ;;
        diff)
          do_diff
          ;;
        rollback)
          do_rollback
          ;;
        gc)
          do_gc
          ;;
        dev)
          echo "➜ Enabling dotfiles DEV mode (SNOWMAN_DOTFILES_MODE=dev)"
          export SNOWMAN_DOTFILES_MODE=dev
          do_rebuild dev
          ;;
        prod|production)
          echo "➜ Enabling dotfiles PROD mode"
          unset SNOWMAN_DOTFILES_MODE
          do_rebuild prod
          ;;
        *)
          die "unknown command: $CMD (try 'snowman help')"
          ;;
      esac
    '')
  ];
}
