{ lib, sops-nix, config, inv, currentHost, ... }:
let
  hasHost = builtins.hasAttr currentHost inv.hosts;
  host = if hasHost then inv.hosts.${currentHost} else { };
  hostUsers = if hasHost then host.users else [ ];

  usbCfg = host.bootstrap.usb or { enable = false; };

  usersWithSecrets =
    lib.filterAttrs (name: u: lib.elem name hostUsers && (u ? secrets.sopsFile))
    inv.users;

  mkSecretsForUser = userName:
    let
      u = inv.users.${userName};
      sopsFile = u.secrets.sopsFile;
      secretKeys = u.secrets.keys or [ ];
    in builtins.listToAttrs (map (key: {
      name = key;
      value = {
        inherit sopsFile;
        format = "yaml";
        key = key;
        owner = userName;
        group = userName;
        mode = "0400";
      };
    }) secretKeys);

  perUserSecrets = lib.foldl' (acc: name: acc // mkSecretsForUser name) { }
    (builtins.attrNames usersWithSecrets);

  hostSecrets = config.snowman.hostSecrets or { };
  allSecrets = hostSecrets // perUserSecrets;

  sopsPasswordKeyAssertions = lib.mapAttrsToList (name: u: {
    assertion = !(u ? secrets.userPasswordHashKey)
      || lib.elem u.secrets.userPasswordHashKey (u.secrets.keys or [ ]);
    message = "User ${name}: secrets.userPasswordHashKey '${
        u.secrets.userPasswordHashKey or "«unset»"
      }' not found in secrets.keys (${toString (u.secrets.keys or [ ])}).";
  }) inv.users;

in {
  imports = [ sops-nix.nixosModules.sops ];

  config = lib.mkIf (allSecrets != { }) {
    sops = {
      validateSopsFiles = false;

      age = lib.mkMerge [
        (lib.mkIf (!usbCfg.enable) {
          generateKey = true;
          # optional: no sshKeyPaths here, or keep both if you want
        })
        (lib.mkIf usbCfg.enable {
          sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
          generateKey = false;
          keyFile = "${usbCfg.path}/${usbCfg.keyFile}";
        })
      ];

      secrets = allSecrets;
    };

    assertions = sopsPasswordKeyAssertions;
  };
}
