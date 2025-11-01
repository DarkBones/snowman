{ ... }: {
  services.qemuGuest.enable = true;
  boot.initrd.systemd.enable = true;
}
