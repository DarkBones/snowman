{ lib, inv, currentHost, config, ... }:
let
  hasHost = builtins.hasAttr currentHost inv.hosts;
  host = if hasHost then inv.hosts.${currentHost} else { };
  wifi = host.wifi or null;

  networksCfg = inv.networks or { };

  # filter networks that declare a passwordSecret
  networksWithPassword =
    lib.filterAttrs (_: net: net ? passwordSecret) networksCfg;

  # Build networking.wireless.networks from host.wifi.networks
  # We use pskRaw = "ext:psk_<netName>", and provide those via secretsFile.
  mkWirelessNetworks = wifiCfg:
    let netNames = wifiCfg.networks or [ ];
    in lib.foldl' (acc: netName:
      let
        net = networksCfg.${netName};
        ssid = net.ssid;
      in acc // {
        "${ssid}" = {
          # Refer to a var defined in networking.wireless.secretsFile
          # e.g. psk_home=....., then pskRaw = "ext:psk_home"
          pskRaw = "ext:psk_${netName}";
        };
      }) { } netNames;

  # Script body that builds /run/secrets/wireless.conf from SOPS secrets.
  #
  # For each network <netName> with a passwordSecret, we expect sops.nix
  # to have created a secret named "wifi-<netName>-password".
  #
  # We then write:
  #   psk_<netName>=<password>
  #
  # so wpa_supplicant can read it via pskRaw = "ext:psk_<netName>".
  wirelessSecretsScript = lib.concatStringsSep "\n" (lib.mapAttrsToList
    (netName: net:
      let
        secretName = "wifi-${netName}-password";
        secretPath = config.sops.secrets.${secretName}.path;
      in ''
        # Secret for Wi-Fi network ${netName}
        if [ -r ${lib.escapeShellArg secretPath} ]; then
          echo "psk_${netName}=$(cat ${
            lib.escapeShellArg secretPath
          })" >> "$outfile"
        else
          echo "[snowman] WARNING: Secret file ${secretPath} for network ${netName} is missing or unreadable."
        fi
      '') networksWithPassword);

in {
  config = lib.mkMerge [
    # Static Wi-Fi mode: Snowman owns wpa_supplicant config.
    (lib.mkIf (hasHost && wifi != null && wifi.mode == "static-wifi") {
      networking.useDHCP = wifi.useDHCP or true;

      networking.networkmanager.enable = false;
      networking.wireless.enable = true;
      networking.wireless.interfaces = [ wifi.interface or "wlan0" ];

      networking.wireless.networks = mkWirelessNetworks wifi;
    })

    # Roaming mode: NetworkManager owns Wi-Fi; we still may want secretsFile,
    # but we don't touch networking.wireless.* here.
    (lib.mkIf (hasHost && wifi != null && wifi.mode == "roaming") {
      networking.useDHCP = wifi.useDHCP or true;
      networking.networkmanager.enable = true;
      networking.wireless.enable = false;
    })

    # Provide /run/secrets/wireless.conf from SOPS for all Wi-Fi networks
    # that declare `passwordSecret`.
    (lib.mkIf (hasHost && wifi != null && networksWithPassword != { }) {
      networking.wireless.secretsFile = "/run/secrets/wireless.conf";

      system.activationScripts."snowman-wireless-secrets" = ''
        set -eu

        outfile="/run/secrets/wireless.conf"
        mkdir -p /run/secrets
        : > "$outfile"
        chmod 600 "$outfile"

        ${wirelessSecretsScript}
      '';
    })

    {
      assertions = [
        {
          assertion = !(hasHost && wifi != null && wifi.mode == "static-wifi")
            || (wifi.networks or [ ]) != [ ];
          message = ''
            Host ${currentHost}: wifi.mode = "static-wifi" but wifi.networks is empty.
          '';
        }
        {
          assertion = !(hasHost && wifi != null && wifi.mode == "static-wifi")
            || lib.all (netName: builtins.hasAttr netName networksCfg)
            (wifi.networks or [ ]);
          message =
            "Host ${currentHost}: wifi.networks references undefined entries in inventory.networks.";
        }
      ];
    }
  ];
}
