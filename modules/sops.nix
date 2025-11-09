{ lib, sops-nix, config, inv, currentHost, ... }:

let
  hasHost = builtins.hasAttr currentHost inv.hosts;
  host = if hasHost then inv.hosts.${currentHost} else { };
  hostUsers = if hasHost then host.users else [ ];

  usbCfg = host.bootstrap.usb or { enable = false; };

  keyFilePath = if usbCfg.enable then
    "${usbCfg.path}/${usbCfg.keyFile}"
  else
    "/var/lib/sops-nix/key.txt"; # TODO: DRY - and convert to .key

  generateKeyFlag = !usbCfg.enable;

  usersWithSecrets =
    lib.filterAttrs (name: u: lib.elem name hostUsers && (u ? sopsSecretsFile))
    inv.users;

  mkSecretsForUser = userName:
    let
      u = inv.users.${userName};
      sopsFile = u.sopsSecretsFile;
      secretKeys = u.sopsSecretKeys or [ ];
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

  perUserSecrets =
    lib.foldl' (acc: userName: acc // mkSecretsForUser userName) { }
    (builtins.attrNames usersWithSecrets);

  sopsPasswordKeyAssertions = lib.mapAttrsToList (name: u:
    let
      keyValid = !(u ? sopsPasswordHashKey)
        || lib.elem u.sopsPasswordHashKey (u.sopsSecretKeys or [ ]);
    in {
      assertion = keyValid;
      message = "User ${name}: sopsPasswordHashKey '${
          u.sopsPasswordHashKey or "«unset»"
        }' not found in sopsSecretKeys (${
          toString (u.sopsSecretKeys or [ ])
        }).";
    }) inv.users;

in {
  imports = [ sops-nix.nixosModules.sops ];

  config = lib.mkIf (perUserSecrets != { }) {
    sops = {
      validateSopsFiles = true;
      age = {
        sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
        keyFile = keyFilePath;
        generateKey = generateKeyFlag;
      };
      secrets = perUserSecrets;
    };

    assertions = sopsPasswordKeyAssertions;
  };
}
