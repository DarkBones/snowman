{ lib, config, ... }:
let
  inBootstrap = config.snowman.bootstrap.enable or false;
  users = builtins.attrNames (import ../../users/default.nix);
in {
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
    logRefusedConnections = true;
  };

  services.openssh.settings = lib.mkIf (!inBootstrap) {
    MaxAuthTries = 3;
    LoginGraceTime = "30s";
    AllowUsers = users;
    AuthenticationMethods = "publickey";
  };

  security.sudo.wheelNeedsPassword = lib.mkForce true;

  services.fail2ban = {
    enable = true;
    jails.sshd.settings = {
      enabled = true;
      backend = "systemd";
      port = "ssh";
      banaction = "nftables-multiport";
      maxretry = 4;
      findtime = "10m";
      bantime = "1h";
    };
  };
}
