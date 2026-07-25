#!/usr/bin/env bash
# Instantiate the bundled template the way a new user would
# (`nix flake new -t`) and evaluate every output. Checks against the
# local engine checkout, not whatever the shipped lock pins, so engine
# and template changes are tested together before pushing.
set -euo pipefail

engine="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

nix flake new -t "path:$engine" "$tmp/config"

# Stand-in for the snowman-import-hardware step a real user runs on the
# target machine; without it the engine's hardware safety net (rightly)
# fails the eval.
cat > "$tmp/config/hosts/vm-snowman-hardware-configuration.nix" <<'EOF'
{ ... }:
{
  fileSystems."/" = {
    device = "/dev/vda1";
    fsType = "ext4";
  };
  boot.loader.grub.devices = [ "/dev/vda" ];
}
EOF

nix flake check "$tmp/config" \
  --override-input snowman "path:$engine" \
  --no-write-lock-file

echo "template OK"
