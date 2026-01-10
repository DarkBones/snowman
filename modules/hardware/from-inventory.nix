{ inv, lib, currentHost, ... }:
let
  hasHost = builtins.hasAttr currentHost inv.hosts;
  host = if hasHost then inv.hosts.${currentHost} else { };
in {
  config = lib.mkMerge [
    (lib.mkIf (hasHost && (host ? hostname)) {
      networking.hostName = host.hostname;
    })

    (lib.mkIf hasHost { system.stateVersion = inv.release; })

    {
      assertions = [
        {
          assertion = hasHost;
          message =
            "Inventory: host ${currentHost} not found in inv.hosts (hardware.from-inventory.nix)";
        }
        {
          assertion = !hasHost || (host ? hostname);
          message = ''
            Inventory: hosts.${currentHost}.hostname must be set.

            Snowman no longer guesses the hostname from the flake name.
            Add for example:

              hosts.${currentHost}.hostname = "${currentHost}";

            to your inventory.nix.
          '';
        }
      ];
    }
  ];
}
