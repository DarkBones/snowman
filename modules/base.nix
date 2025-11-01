{ ... }: {
  imports = [ ./security/ssh.nix ];

  time.timeZone = "Europe/Berlin";
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
