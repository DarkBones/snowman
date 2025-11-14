#!/usr/bin/env bash
set -euo pipefail

: "${SNOWMAN_REPO:=https://github.com/DarkBones/snowman.git}"
: "${SNOWMAN_BRANCH:=main-v3-fixes}"
: "${HOST:=vm-snowman}"
: "${USB_LABEL:=SNOWMANKEY}"
: "${USB_MOUNT:=/mnt/snowman}"
: "${USB_KEYFILE:=snowman.key}"
: "${WORKDIR:=/etc/nixos}"

say() { printf '\033[1;32m>>>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!!\033[0m %s\n' "$*"; }

export NIX_CONFIG="experimental-features = nix-command flakes"

# Optional secrets USB
if lsblk -o LABEL -nr | grep -qx "$USB_LABEL"; then
  sudo mkdir -p "$USB_MOUNT"
  if sudo mount -L "$USB_LABEL" "$USB_MOUNT"; then
    say "Mounted $USB_LABEL at $USB_MOUNT"
    [ -f "$USB_KEYFILE" ] && export AGE_IDENTITIES="$USB_MOUNT/$USB_KEYFILE:${AGE_IDENTITIES-}"
  else
    warn "Could not mount $USB_LABEL"
  fi
fi

sudo mkdir -p "$WORKDIR"
sudo chown root:root "$WORKDIR"

TARGET=/etc/nixos
REPO="${SNOWMAN_REPO}"
BRANCH="${SNOWMAN_BRANCH}"

if [ -d "$TARGET/.git" ]; then
  say "Updating Snowman -> $TARGET"
  git -C "$TARGET" remote get-url origin >/dev/null 2>&1 || {
    warn "$TARGET is a git repo but has no 'origin'—backing it up."
    sudo mv "$TARGET" "/etc/nixos.bak.$(date +%s)"
    sudo mkdir -p "$TARGET"
    git clone --branch "$BRANCH" --depth 1 "$REPO" "$TARGET"
  }
  git -C "$TARGET" fetch --prune
  git -C "$TARGET" checkout "$BRANCH"
  git -C "$TARGET" reset --hard "origin/$BRANCH"
else
  if [ -d "$TARGET" ] && [ "$(ls -A "$TARGET")" ]; then
    warn "$TARGET exists and is not a git repo—backing it up."
    # Temporarily move the old config
    sudo mv "$TARGET" "/etc/nixos.bak"

    # Clone the new repo
    say "Cloning Snowman -> $TARGET"
    git clone --branch "$BRANCH" --depth 1 "$REPO" "$TARGET"

    # If the installer created a hardware config, copy it back!
    if [ -f "/etc/nixos.bak/hardware-configuration.nix" ]; then
      say "Preserving existing hardware-configuration.nix"
      sudo mv "/etc/nixos.bak/hardware-configuration.nix" "$TARGET/hardware-configuration.nix"
    fi

    # Clean up the rest of the backup
    sudo rm -rf "/etc/nixos.bak"
  fi
  say "Cloning Snowman -> $TARGET"
  git clone --branch "$BRANCH" --depth 1 "$REPO" "$TARGET"
fi

say "Apply Snowman (BIOS/GRUB expected)"
sudo -E nixos-rebuild boot --flake "$WORKDIR#$HOST"

say "Done. Reboot to use the new GRUB install."
