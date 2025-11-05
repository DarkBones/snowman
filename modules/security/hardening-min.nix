{ lib, config, ... }:
let
  inBootstrap = config.snowman.bootstrap.enable or false;
  invUsers = if (config ? snowman) && (config.snowman ? inventory)
  && (config.snowman.inventory ? users) then
    config.snowman.inventory.users
  else
    import ../../users/default.nix;
  users = builtins.attrNames invUsers;
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
