{ ... }: {
  config = {
    # Prevents low entropy conditions during first boot
    services.haveged.enable = true;

    environment.etc."ssh/ssh_known_hosts".text = ''
      github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
    '';
    security.sudo = {
      enable = true;
      extraConfig = ''
        Defaults !tty_tickets
        Defaults timestamp_timeout=15
      '';
    };
  };
}
