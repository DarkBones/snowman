{ ... }: {
  imports = [ ./baremetal.nix ];

  # never sleep, reliable boots
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;

  boot.kernel.sysctl."vm.swappiness" = 10;
  networking.useNetworkd = true;
  systemd.network.wait-online.enable = false;
  networking.networkmanager.enable = false;
  systemd.network.enable = true;
}
