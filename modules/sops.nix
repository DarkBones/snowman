{ lib, sops-nix, config, inv, currentHost, networkSecretsPath ? null, ... }:
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

      if (systemd-detect-virt > /dev/null); then
         echo "[snowman] In a VM, skipping USB key import."
         PROCEED=0
      fi

      TARGET="/var/lib/sops-nix/age.key"
      USB_MOUNT="${usbCfg.path}"
      USB_LABEL="${usbCfg.label}"
      USB_KEY_FILE="${usbCfg.keyFile}"

      if [ "$PROCEED" -eq 1 ]; then
        echo "[snowman] Checking SOPS age key against USB..."
        
        # 1. Mount the USB
        mkdir -p "$USB_MOUNT"
        mounted_here=0
        
        if ! mountpoint -q "$USB_MOUNT"; then
          if [ -b "/dev/disk/by-label/$USB_LABEL" ]; then
            mount "/dev/disk/by-label/$USB_LABEL" "$USB_MOUNT"
            mounted_here=1
          else
            echo "[snowman] WARNING: Device $USB_LABEL not found. Skipping bootstrap import."
            exit 0
          fi
        fi

        # 2. Check source key
        if [ ! -f "$USB_MOUNT/$USB_KEY_FILE" ]; then
          echo "[snowman] ERROR: Key file '$USB_KEY_FILE' missing on USB."
          if [ "$mounted_here" -eq 1 ]; then umount "$USB_MOUNT"; fi
          exit 1
        fi

        # 3. Compare and Copy (The Fix)
        DO_COPY=0
        if [ ! -f "$TARGET" ]; then
          echo "[snowman] Key not found at $TARGET. Copying..."
          DO_COPY=1
        else
          # Compare content. If different, overwrite.
          if ! cmp -s "$USB_MOUNT/$USB_KEY_FILE" "$TARGET"; then
             echo "[snowman] Key mismatch! Overwriting stale key with USB key."
             DO_COPY=1
          else
             echo "[snowman] Key matches USB. No change needed."
          fi
        fi

        if [ "$DO_COPY" -eq 1 ]; then
          install -d -m 0700 /var/lib/sops-nix
          install -m 0400 -o root -g root "$USB_MOUNT/$USB_KEY_FILE" "$TARGET"
        fi

        # 4. Cleanup
        if [ "$mounted_here" -eq 1 ]; then
          umount "$USB_MOUNT" || true
        fi
      fi
    '';

    assertions = sopsPasswordKeyAssertions ++ networkPasswordAssertions;
  };
}
