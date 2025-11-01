{ pkgs, ... }: {
  imports = [ ./baremetal.nix ];
  services.power-profiles-daemon.enable = true;
  services.logind.lidSwitch = "suspend";
  services.logind.lidSwitchDocked = "ignore";
  services.upower.enable = true;

  # Optional extras:
  # programs.light.enable = true;   # brightness control
  # services.tlp.enable = true;     # alternative to PPD (don’t use both)
}
