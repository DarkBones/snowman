{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.roles.ssh;
in
{
  options.roles.ssh.enable = (lib.mkEnableOption "SSH role") // {
    default = true;
  };

  config = lib.mkIf cfg.enable {
    home.activation.ensureSshKey = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      set -eu

      keydir="$HOME/.ssh"
      keyfile="$keydir/id_ed25519"

      if [ ! -f "$keyfile" ]; then
        echo "⚙️  No SSH key found, generating new one for $USER..."
        mkdir -p "$keydir"
        chmod 700 "$keydir"

        "${pkgs.openssh}/bin/ssh-keygen" \
          -t ed25519 \
          -N "" \
          -f "$keyfile" \
          -C "$USER@$("${pkgs.inetutils}/bin/hostname")"

        echo "✅ Generated: $keyfile.pub"
        echo "👉 Public key"
        cat "$keyfile.pub"
      else
        echo "🔑 Existing SSH key found at $keyfile — skipping generation."
      fi
    '';
  };
}
