{ lib, inv, currentHost, config, ... }:
let
  hasHost = builtins.hasAttr currentHost inv.hosts;
  host = if hasHost then inv.hosts.${currentHost} else { };
  wifi = host.wifi or null;

  networksCfg = inv.networks or { };

  # Build networking.wireless.networks from host.wifi.networks
  # We expect each inventory network to have:
  #   ssid = "...";
  #   passwordSecret = "ENV_VAR_NAME";  # name in the .env secrets file
  mkWirelessNetworks = wifiCfg:
    let netNames = wifiCfg.networks or [ ];
    in lib.foldl' (acc: netName:
      let
        net = networksCfg.${netName};
        ssid = net.ssid;
        # Name of the env var that will hold the PSK in the secrets .env file
        envVar =
          net.passwordSecret or "SNOWMAN_WIFI_${lib.toUpper netName}_PASSWORD";
      in acc // {
        "${ssid}" = {
          # Ask wpa_supplicant to fetch PSK from env var ENV_VAR
          pskRaw = "ext:${envVar}";
        };
      }) { } netNames;

in {
  config = lib.mkMerge [
    # Static Wi-Fi (For static machines that don't need to change networks)
    (lib.mkIf (hasHost && wifi != null && wifi.mode == "static-wifi") {
      networking.useDHCP = wifi.useDHCP or true;

      networking.networkmanager.enable = false;
      networking.wireless.enable = true;
      networking.wireless.interfaces = [ wifi.interface or "wlan0" ];

      networking.wireless.secretsFile = config.sops.secrets."wifi-env".path;

      networking.wireless.networks = mkWirelessNetworks wifi;
    })

    # Roaming mode: let NetworkManager own Wi-Fi completely
    (lib.mkIf (hasHost && wifi != null && wifi.mode == "roaming") {
      networking.useDHCP = wifi.useDHCP or true;
      networking.networkmanager.enable = true;
      networking.wireless.enable = false;
    })

    {
      assertions = [
        {
          assertion = !(hasHost && wifi != null && wifi.mode == "static-wifi")
            || (wifi.networks or [ ]) != [ ];
          message = ''
            Host ${currentHost}: wifi.mode = "static-wifi" but wifi.networks is empty.'';
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
