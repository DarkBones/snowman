{ lib, sops-nix, config, inv, currentHost, ... }:

let
  cfg = config.roles.secrets;

  hasHost = builtins.hasAttr currentHost inv.hosts;
  host = if hasHost then inv.hosts.${currentHost} else { };

  # Very simple convention: first user in inventory list for this host
  primaryUserName =
    if hasHost && host.users != [ ] then builtins.head host.users else null;
in {
  imports = [ sops-nix.nixosModules.sops ];

  options.roles.secrets.enable = lib.mkEnableOption "Secrets role";

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      sops = {
        defaultSopsFile = ../secrets.yml;
        validateSopsFiles = false;

        age = {
          # Auto-import host SSH key as age identity
          sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
          keyFile = "/var/lib/sops-nix/key.txt";
          generateKey = true;
        };
      };
    }

    # Only define the secret if we actually have a primary user
    (lib.mkIf (primaryUserName != null) {
      sops.secrets."admin-password" = {
        # same style as the tutorial:
        owner = config.users.users.${primaryUserName}.name;
        inherit (config.users.users.${primaryUserName}) group;
        # optional: tighten permissions
        mode = "0400";
      };
    })
  ]);
}
