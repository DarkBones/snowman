{ ... }: {
  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = false;
      LoginGraceTime = "30s";
      MaxAuthTries = 3;
    };
  };
}
