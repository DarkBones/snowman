{ ... }: {
  security.sudo = {
    enable = true;
    extraConfig = ''
      Defaults !tty_tickets
      Defaults timestamp_timeout=15
    '';
  };
}
