# The one `snowman` CLI, shared by the NixOS system module
# (modules/snowman.nix) and the standalone Home Manager role
# (modules/home/roles/snowman.nix). Platform differences are confined to
# the arguments and the variant-specific command bodies below; everything
# else (flake resolution, mode tracking, dispatch) is written once.
{
  pkgs,
  variant, # "nixos" | "home-manager"
  target, # rebuild target: hostname on NixOS, user@host for standalone HM
  modeFile, # where the dev/prod dotfiles mode persists ($HOME expands at runtime)
  flakeFile, # where the default flake path is read from
  fallbackFlake ? "", # used when flakeFile is absent and SNOWMAN_FLAKE is unset
  extraPath, # appended to PATH so nix and the rebuild tool resolve
}:
assert variant == "nixos" || variant == "home-manager";
let
  isNixos = variant == "nixos";
  targetLabel = if isNixos then "host" else "config";
  rebuildTool = if isNixos then "NixOS" else "home-manager";

  setModeCmd =
    if isNixos then
      ''
        sudo -H mkdir -p "$(dirname "$MODE_FILE")"
        echo "$mode" | sudo -H tee "$MODE_FILE" >/dev/null
      ''
    else
      ''
        mkdir -p "$(dirname "$MODE_FILE")"
        echo "$mode" > "$MODE_FILE"
      '';

  diffCmd =
    if isNixos then
      ''
        if [ "$current_mode" = "dev" ]; then
          sudo -H -E nixos-rebuild dry-activate --impure --flake "$FLAKE_REF#${target}"
        else
          sudo -H nixos-rebuild dry-activate --flake "$FLAKE_REF#${target}"
        fi
      ''
    else
      ''
        if [ "$current_mode" = "dev" ]; then
          home-manager build --impure --flake "$FLAKE_REF#${target}"
        else
          home-manager build --flake "$FLAKE_REF#${target}"
        fi
      '';

  rollbackCmd =
    if isNixos then
      ''
        sudo -H nixos-rebuild switch --rollback
      ''
    else
      ''
        home-manager generations | head -2 | tail -1 | awk '{print $NF}' | xargs -I{} {}/activate
      '';

  gcCmd =
    if isNixos then
      ''
        if [ "$keep" -eq 0 ]; then
          echo "➜ Deleting all old generations"
          sudo nix-env --delete-generations old -p /nix/var/nix/profiles/system
        else
          echo "➜ Keeping last $keep generations, deleting older ones"
          sudo nix-env --delete-generations "+$keep" -p /nix/var/nix/profiles/system
        fi
        echo "➜ Garbage collecting unreachable store paths"
        sudo nix-collect-garbage
        echo "➜ Updating boot entries"
        sudo /run/current-system/bin/switch-to-configuration boot
      ''
    else
      ''
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
      '';

  rebuildCmd =
    if isNixos then
      ''
        if [ "$mode" = "dev" ]; then
          sudo -H -E nixos-rebuild switch --impure --flake "$FLAKE_REF#${target}"
        else
          sudo -H nixos-rebuild switch --flake "$FLAKE_REF#${target}"
        fi
      ''
    else
      ''
        if [ "$mode" = "dev" ]; then
          home-manager switch --impure --flake "$FLAKE_REF#${target}"
        else
          home-manager switch --flake "$FLAKE_REF#${target}"
        fi
      '';
in
pkgs.writeShellScriptBin "snowman" ''
  set -euo pipefail

  # Ensure nix and other tools are in PATH
  export PATH="$PATH:${extraPath}"
  MODE_FILE="${modeFile}"
  DEFAULT_FLAKE_FILE="${flakeFile}"

  die() { echo "error: $*" >&2; exit 1; }

  DEFAULT_FLAKE="$(cat "$DEFAULT_FLAKE_FILE" 2>/dev/null || true)"
  FLAKE_REF="''${SNOWMAN_FLAKE:-''${DEFAULT_FLAKE:-${fallbackFlake}}}"

  if [ -z "$FLAKE_REF" ]; then
    die "no flake configured. Set snowman.flakePath (NixOS) or roles.snowman.flakePath (Home Manager), or export SNOWMAN_FLAKE=/path/to/your/snowman-config"
  fi

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
    echo "  secrets ...   Run the body repo's secrets doctor (status/verify)"
    echo ""
    echo "Environment:"
    echo "  SNOWMAN_FLAKE  Override flake path"
    echo ""
    echo "Current ${targetLabel}: ${target}"
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
    echo "${targetLabel}: ${target}"
  }

  set_mode_file() {
    mode="$1"
    ${setModeCmd}
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
    echo "➜ Showing changes for ${target} (dry-run, mode: $current_mode)"
    ${diffCmd}
  }

  do_rollback() {
    echo "➜ Rolling back to previous generation"
    ${rollbackCmd}
  }

  do_gc() {
    local keep="''${1:-10}"
    if ! [[ "$keep" =~ ^[0-9]+$ ]]; then
      die "gc: expected a number, got '$keep'"
    fi
    ${gcCmd}
  }

  do_rebuild() {
    local mode="$1"
    echo "➜ Rebuilding ${rebuildTool} for ${target} using flake: $FLAKE_REF"
    ${rebuildCmd}
    set_mode_file "$mode"
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
    secrets)
      doctor="$FLAKE_REF/bin/snowman-secrets-doctor"
      if [ -x "$doctor" ]; then
        exec "$doctor" "$@"
      else
        die "no executable found at $doctor (secrets doctor is only available when the flake is a local checkout)"
      fi
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
''
