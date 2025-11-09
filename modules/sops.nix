{ lib, sops-nix, config, inv, currentHost, ... }:
let
  hasHost = builtins.hasAttr currentHost inv.hosts;
  host = if hasHost then inv.hosts.${currentHost} else { };
  hostUsers = if hasHost then host.users else [ ];

  usersWithSecrets = lib.filterAttrs
    (name: u: lib.elem name hostUsers && (u.sopsSecretsFile or null) != null)
    inv.users;

  mkSecretsForUser = userName:
    let
      u = inv.users.${userName};
      sopsFile = u.sopsSecretsFile;
      secretKeys = u.sopsSecretKeys or [ ];
    in builtins.listToAttrs (map (key: {
      name = key; # keep YAML key name
      value = {
        inherit sopsFile;
        format = "yaml";
        path = key; # read just this key from that YAML file
        owner = config.users.users.${userName}.name;
        inherit (config.users.users.${userName}) group;
        mode = "0400";
      };
    }) secretKeys);

  perUserSecrets =
    lib.foldl' (acc: userName: acc // mkSecretsForUser userName) { }
    (builtins.attrNames usersWithSecrets);

in {
  imports = [ sops-nix.nixosModules.sops ];

  config = lib.mkIf (perUserSecrets != { }) {
    sops = {
      validateSopsFiles = false;

      age = {
        sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
        keyFile = "/var/lib/sops-nix/key.txt";
        generateKey = true;
      };

      secrets = perUserSecrets;
    };
  };
}
