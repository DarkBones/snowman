{ lib, config, ... }:
let inBootstrap = config.snowman.bootstrap.enable or false;
in lib.mkMerge [
  {
    services.openssh = {
      enable = lib.mkForce true;
      openFirewall = true;

      hostKeys = [{
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }];

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

        HostKeyAlgorithms = "ssh-ed25519";
        PubkeyAcceptedAlgorithms = "ssh-ed25519";
        MaxStartups = "10:30:100";
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
