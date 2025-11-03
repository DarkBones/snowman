{ lib, config, ... }:
let inBootstrap = config.snowman.bootstrap.enable or false;
in lib.mkMerge [
  {
    services.openssh = {
      enable = lib.mkForce true;
      openFirewall = true;
      settings = {
        PermitRootLogin = "no";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        AllowTcpForwarding = "yes";
        X11Forwarding = false;
        PrintMotd = false;
        UseDns = false;
        ClientAliveInterval = 300;
        ClientAliveCountMax = 2;
        LogLevel = "VERBOSE";
      };
    };

    users.users.sshd.isSystemUser = lib.mkDefault true;
    users.groups.sshd = lib.mkDefault { };
  }

  (lib.mkIf inBootstrap {
    users.users.root.openssh.authorizedKeys.keys =
      [ (builtins.readFile ../../users/keys/bas.pub) ];
  })
]
