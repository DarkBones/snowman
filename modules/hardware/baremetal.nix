{ ... }: {
  services.qemuGuest.enable = false;
  powerManagement.cpuFreqGovernor = "schedutil";
  hardware.enableRedistributableFirmware = true;
  services.fwupd.enable = true;
}
