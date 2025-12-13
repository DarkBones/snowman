{ lib, pkgs, sops-nix, config, inv, currentHost, networkSecretsPath ? null, ...
}:
let
  hasHost = builtins.hasAttr currentHost inv.hosts;
  host = if hasHost then inv.hosts.${currentHost} else { };
  hostUsers = if hasHost then host.users else [ ];

  usbCfg = host.bootstrap.usb or { enable = false; };

  # Users that actually have a `secrets.sopsFile` configured
  usersWithSecrets =
    lib.filterAttrs (name: u: lib.elem name hostUsers && (u ? secrets.sopsFile))
    inv.users;

  isRotated = config.snowman.isRotated;
  usbConfigured = host.bootstrap.usb.enable or false;
  usbMode = usbConfigured && (!isRotated);

  mkSecretsForUser = userName:
    let
      u = inv.users.${userName};
      sopsFile = u.secrets.sopsFile;
      secretKeys = u.secrets.keys or [ ];
      passwordKey = u.secrets.userPasswordHashKey or null;

      mkValue = key:
        ({
          inherit sopsFile;
          format = "yaml";
          key = key;
          owner = userName;
          group = userName;
          mode = "0400";
        }
        # If this key is used as `userPasswordHashKey`, we need it
        # in /run/secrets-for-users so the users module can read it.
          // lib.optionalAttrs (passwordKey != null && key == passwordKey) {
            neededForUsers = true;
          });
    in builtins.listToAttrs (map (key: {
      name = key;
      value = mkValue key;
    }) secretKeys);

  perUserSecrets = lib.foldl' (acc: name: acc // mkSecretsForUser name) { }
    (builtins.attrNames usersWithSecrets);

  networksCfg = inv.networks or { };

  # For each network <netName> with a passwordSecret, create a SOPS secret:
  #   "wifi-<netName>-password"
  #
  # The data lives in networks/secrets.yml (networkSecretsPath), and
  # passwordSecret tells us the YAML key (e.g. "home.password").
  networkSecrets = if networkSecretsPath == null then
    { }
  else
    lib.foldl' (acc: netName:
      let net = networksCfg.${netName};
      in if net ? passwordSecret then
        acc // {
          "wifi-${netName}-password" = {
            sopsFile = networkSecretsPath;
            format = "yaml";
            key = net.passwordSecret; # e.g. "home.password"
            owner = "root";
            group = "root";
            mode = "0400";
          };
        }
      else
        acc) { } (builtins.attrNames networksCfg);

  hostSecrets = config.snowman.hostSecrets or { };
  allSecrets = hostSecrets // perUserSecrets // networkSecrets;

  sopsPasswordKeyAssertions = lib.mapAttrsToList (name: u: {
    assertion = !(u ? secrets.userPasswordHashKey)
      || lib.elem u.secrets.userPasswordHashKey (u.secrets.keys or [ ]);
    message = "User ${name}: secrets.userPasswordHashKey '${
        u.secrets.userPasswordHashKey or "«unset»"
      }' not found in secrets.keys (${toString (u.secrets.keys or [ ])}).";
  }) inv.users;

  networkPasswordAssertions = lib.mapAttrsToList (netName: net: {
    assertion = !(net ? passwordSecret) || networkSecretsPath != null;
    message =
      "Network ${netName}: passwordSecret is set but networkSecretsPath is null.";
  }) networksCfg;

in {
  imports = [ sops-nix.nixosModules.sops ];

  config = lib.mkIf (allSecrets != { }) {

    # Always use a local key file; for USB mode we copy into here.
    sops = {
      validateSopsFiles = false;
      age = {
        keyFile = "/var/lib/sops-nix/age.key";

        # If we have rotated (isRotated = true), usbMode becomes false.
        # generateKey becomes true. 
        # Sops-nix will then find the SSH host key automatically.
        generateKey = !usbMode;
      };
      secrets = allSecrets;
    };

    # Bootstrap: copy age key from USB -> /var/lib/sops-nix/age.key (once)
    system.activationScripts."00-snowman-import-sops-key" = lib.mkIf usbMode ''
      set -euo pipefail

      PROCEED=1
      DETECT_VIRT="${pkgs.systemd}/bin/systemd-detect-virt"

      # Never hard-fail boot because a helper isn't in PATH
      if [ -x "$DETECT_VIRT" ] && "$DETECT_VIRT" >/dev/null 2>&1; then
        echo "[snowman] In a VM, skipping USB key import."
        PROCEED=0
      fi

      TARGET="/var/lib/sops-nix/age.key"
      USB_MOUNT="${usbCfg.path}"
      USB_LABEL="${usbCfg.label}"
      USB_KEY_FILE="${usbCfg.keyFile}"

      if [ "$PROCEED" -eq 1 ]; then
        echo "[snowman] Checking SOPS age key against USB..."
        ...
      fi
    '';

    assertions = sopsPasswordKeyAssertions ++ networkPasswordAssertions;
  };
}
