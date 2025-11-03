{ lib, ... }: {
  services.openssh = {
    enable = true;

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

    hostKeys = [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
      {
        path = "/etc/ssh/ssh_host_rsa_key";
        type = "rsa";
        bits = 4096;
      }
    ];
  };

  # TOFIX
  # ⚠️ Bootstrap parachute: root SSH enabled for initial bring-up only.
  # Remove after confirming user SSH works reliably.
  users.users.root.openssh.authorizedKeys.keys =
    [ (builtins.readFile ../../users/keys/bas.pub) ];
}
