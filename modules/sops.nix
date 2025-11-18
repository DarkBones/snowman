{ lib, sops-nix, config, inv, currentHost, ... }:
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

      if (systemd-detect-virt > /dev/null); then
         echo "[snowman] In a VM, skipping USB key import."
         exit 0
      fi

      TARGET="/var/lib/sops-nix/age.key"
      USB_MOUNT="${usbCfg.path}"
      USB_LABEL="${usbCfg.label}"
      USB_KEY_FILE="${usbCfg.keyFile}"

      if [ -f "$TARGET" ]; then
        echo "[snowman] Existing SOPS age key at $TARGET – skipping USB import."
        exit 0
      fi

      echo "[snowman] Importing SOPS age key from USB label ''${USB_LABEL}"

      mkdir -p "$USB_MOUNT"

      mounted_here=0
      if ! mountpoint -q "$USB_MOUNT"; then
        if [ -b "/dev/disk/by-label/$USB_LABEL" ]; then
          echo "[snowman] Mounting /dev/disk/by-label/$USB_LABEL on $USB_MOUNT"
          mount "/dev/disk/by-label/$USB_LABEL" "$USB_MOUNT"
          mounted_here=1
        else
          echo "[snowman] ERROR: device with label $USB_LABEL not found."
          exit 1
        fi
      fi

      if [ ! -f "$USB_MOUNT/$USB_KEY_FILE" ]; then
        echo "[snowman] ERROR: key file '$USB_KEY_FILE' not found on $USB_MOUNT."
        if [ "$mounted_here" = 1 ]; then
          umount "$USB_MOUNT" || true
        fi
        exit 1
      fi

      echo "[snowman] Copying key to $TARGET"
      install -d -m 0700 /var/lib/sops-nix
      install -m 0400 -o root -g root "$USB_MOUNT/$USB_KEY_FILE" "$TARGET"

      if [ "$mounted_here" = 1 ]; then
        umount "$USB_MOUNT" || true
      fi

      echo "[snowman] SOPS age key imported successfully."
    '';

    assertions = sopsPasswordKeyAssertions;
  };
}
