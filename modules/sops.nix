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

  perUserSecrets =
    lib.foldl' (acc: userName: acc // mkSecretsForUser userName) { }
    (builtins.attrNames usersWithSecrets);

  hostSecrets = config.snowman.hostSecrets or { };
  allSecrets = hostSecrets // perUserSecrets;

  sopsPasswordKeyAssertions = lib.mapAttrsToList (name: u:
    let
      keyValid = !(u ? secrets.userPasswordHashKey)
        || lib.elem u.secrets.userPasswordHashKey (u.secrets.keys or [ ]);
    in {
      assertion = keyValid;
      message = "User ${name}: secrets.userPasswordHashKey '${
          u.secrets.userPasswordHashKey or "«unset»"
        }' not found in secrets.keys (${toString (u.secrets.keys or [ ])}).";
    }) inv.users;

in {
  imports = [ sops-nix.nixosModules.sops ];

  config = lib.mkIf (allSecrets != { }) {
    sops = {
      validateSopsFiles = true;
      age = {
        sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
        keyFile = keyFilePath;
        generateKey = generateKeyFlag;
      };
      secrets = allSecrets;
    };

    assertions = sopsPasswordKeyAssertions;
  };
}
