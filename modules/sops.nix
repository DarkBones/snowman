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
      validateSopsFiles = true;
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
      set -u
      set -o pipefail

      # Use absolute paths for binaries not in global PATH
      MOUNT="${pkgs.util-linux}/bin/mount"
      UMOUNT="${pkgs.util-linux}/bin/umount"
      MOUNTPOINT="${pkgs.util-linux}/bin/mountpoint"
      INSTALL="${pkgs.coreutils}/bin/install"
      CMP="${pkgs.diffutils}/bin/cmp"
      DETECT_VIRT="${pkgs.systemd}/bin/systemd-detect-virt"

      if [ -e /run/current-system ]; then

        log()  { echo "[snowman] $*"; }
        warn() { echo "[snowman] WARNING: $*" >&2; }

        TARGET="/var/lib/sops-nix/age.key"
        USB_MOUNT="${usbCfg.path}"
        USB_LABEL="${usbCfg.label}"
        USB_KEY_FILE="${usbCfg.keyFile}"

        # If helper exists and we are in a VM: skip
        if [ -x "$DETECT_VIRT" ] && "$DETECT_VIRT" >/dev/null 2>&1; then
          log "In a VM, skipping USB key import."
        else
          log "Checking SOPS age key against USB..."

          mkdir -p "$USB_MOUNT" || warn "Failed to create mount dir $USB_MOUNT"

          if [ -d "$USB_MOUNT" ]; then
            mounted_here=0
            if ! "$MOUNTPOINT" -q "$USB_MOUNT" 2>/dev/null; then
              if [ -b "/dev/disk/by-label/$USB_LABEL" ]; then
                if "$MOUNT" "/dev/disk/by-label/$USB_LABEL" "$USB_MOUNT"; then
                  mounted_here=1
                else
                  warn "Failed to mount /dev/disk/by-label/$USB_LABEL at $USB_MOUNT"
                fi
              else
                warn "Device label '$USB_LABEL' not found. Skipping bootstrap import."
              fi
            fi

            # Check if mount succeeded or was already mounted
            if "$MOUNTPOINT" -q "$USB_MOUNT" 2>/dev/null; then
               SRC="$USB_MOUNT/$USB_KEY_FILE"
               if [ ! -f "$SRC" ]; then
                 warn "Key file '$USB_KEY_FILE' missing on USB. Skipping."
               else
                 "$INSTALL" -d -m 0700 /var/lib/sops-nix 2>/dev/null || true

                 if [ ! -f "$TARGET" ]; then
                   log "Key not found at $TARGET. Copying from USB..."
                   "$INSTALL" -m 0400 -o root -g root "$SRC" "$TARGET" 2>/dev/null || warn "Failed to install key to $TARGET"
                 else
                   if "$CMP" -s "$SRC" "$TARGET"; then
                     log "Key matches USB. No change needed."
                   else
                     warn "Key mismatch. Overwriting stale key with USB key."
                     "$INSTALL" -m 0400 -o root -g root "$SRC" "$TARGET" 2>/dev/null || warn "Failed to overwrite key at $TARGET"
                   fi
                 fi
               fi

               if [ "$mounted_here" -eq 1 ]; then
                 "$UMOUNT" "$USB_MOUNT" 2>/dev/null || true
               fi
            fi
          fi
        fi
      else
        echo "[snowman] Install environment detected. Skipping USB key import."
      fi
    '';

    assertions = sopsPasswordKeyAssertions ++ networkPasswordAssertions;
  };
}
