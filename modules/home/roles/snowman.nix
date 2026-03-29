{ lib, config, pkgs, currentHost, ... }:
let
  cfg = config.roles.snowman;
  username = config.home.username;
  configName = "${username}@${currentHost}";
  isDarwin = pkgs.stdenv.isDarwin;
in {
  options.roles.snowman = {
    enable = lib.mkEnableOption "Snowman CLI for standalone home-manager";
    flakePath = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/snowman-config";
      description = "Default path to the snowman flake";
    };
  };

  # Only apply on Darwin (macOS) - on NixOS, the system module provides snowman
  config = lib.mkIf (cfg.enable && isDarwin) {
    home.file.".config/snowman/flake".text = cfg.flakePath + "\n";

    home.packages = [
      (pkgs.writeShellScriptBin "snowman" ''
        set -euo pipefail

        MODE_FILE="$HOME/.config/snowman/dotfiles-mode"
        DEFAULT_FLAKE_FILE="$HOME/.config/snowman/flake"

        die() { echo "error: $*" >&2; exit 1; }

        DEFAULT_FLAKE="$(cat "$DEFAULT_FLAKE_FILE" 2>/dev/null || true)"
        FLAKE_REF="''${SNOWMAN_FLAKE:-''${DEFAULT_FLAKE:-${cfg.flakePath}}}"

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
          FLAKE_REF="$(realpath "$FLAKE_REF" 2>/dev/null || echo "$FLAKE_REF")"
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
          echo "  gc [n]        Garbage collect (keep last n generations, default 10, 0 = all)"
          echo "  status        Show current mode and flake path"
          echo ""
          echo "Environment:"
          echo "  SNOWMAN_FLAKE  Override flake path"
          echo ""
          echo "Configuration: ${configName}"
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
          echo "config: ${configName}"
        }

        set_mode_file() {
          mode="$1"
          mkdir -p "$(dirname "$MODE_FILE")"
          echo "$mode" > "$MODE_FILE"
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
          echo "➜ Showing changes for ${configName} (dry-run, mode: $current_mode)"
          if [ "$current_mode" = "dev" ]; then
            home-manager build --impure --flake "$FLAKE_REF#${configName}"
          else
            home-manager build --flake "$FLAKE_REF#${configName}"
          fi
        }

        do_rollback() {
          echo "➜ Rolling back to previous generation"
          home-manager generations | head -2 | tail -1 | awk '{print $NF}' | xargs -I{} {}/activate
        }

        do_gc() {
          local keep="''${1:-10}"
          if ! [[ "$keep" =~ ^[0-9]+$ ]]; then
            die "gc: expected a number, got '$keep'"
          fi
          if [ "$keep" -eq 0 ]; then
            echo "➜ Deleting all old home-manager generations"
            home-manager expire-generations "-1 second" || true
          else
            echo "➜ Keeping last $keep home-manager generations, deleting older ones"
            # List generations, skip the last n, delete the rest
            home-manager generations | tail -n "+$((keep + 1))" | awk '{print $5}' | while read -r gen; do
              [ -n "$gen" ] && rm -rf "$gen" && echo "  removed: $gen"
            done
          fi
          echo "➜ Garbage collecting unreachable store paths"
          nix-collect-garbage
        }

        do_rebuild() {
          local mode="$1"
          echo "➜ Rebuilding home-manager for ${configName} using flake: $FLAKE_REF"

          if [ "$mode" = "dev" ]; then
            home-manager switch --impure --flake "$FLAKE_REF#${configName}"
            set_mode_file dev
          else
            home-manager switch --flake "$FLAKE_REF#${configName}"
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
            do_gc "$@"
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
  };
}
