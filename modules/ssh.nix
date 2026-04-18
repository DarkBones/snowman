{
  inv,
  currentHost,
  lib,
  ...
}:
let
  hasHost = builtins.hasAttr currentHost inv.hosts;
  host = if hasHost then inv.hosts.${currentHost} else { };
  allowed = host.users or [ ];
in
{
  config = lib.mkMerge [
    (lib.mkIf hasHost {
      networking.firewall = {
        enable = true;
        logRefusedConnections = true;
      };

      services.openssh = {
        enable = true;
        openFirewall = true;
        hostKeys = [
          {
            path = "/etc/ssh/ssh_host_ed25519_key";
            type = "ed25519";
          }
        ];

        settings = {
          PermitRootLogin = "no";
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          LoginGraceTime = "30s";
          MaxAuthTries = 3;
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
          AuthenticationMethods = "publickey";
          AllowUsers = allowed;
        };
      };
    })

    {
      assertions = [
        {
          assertion = hasHost;
          message = "Inventory: host ${currentHost} not found in inv.hosts (ssh.nix)";
        }
      ];
    }
  ];
}
