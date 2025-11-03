{ lib, config, ... }:
let inBootstrap = config.snowman.bootstrap.enable or false;
in {
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
  };

  # Root SSH parachute ONLY during bootstrap
  users.users.root.openssh.authorizedKeys.keys =
    lib.mkIf inBootstrap [ (builtins.readFile ../../users/keys/bas.pub) ];
}
