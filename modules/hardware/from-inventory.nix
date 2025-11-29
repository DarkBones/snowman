{ inv, lib, currentHost, ... }:
let hasHost = builtins.hasAttr currentHost inv.hosts;
in {
  config = lib.mkIf hasHost {
    networking.hostName = inv.hosts.${currentHost}.hostname or currentHost;
    system.stateVersion = inv.release;
  };
}
