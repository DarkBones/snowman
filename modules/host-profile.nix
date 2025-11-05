{ name, attrs }:
{ release, ... }: {
  networking.hostName = attrs.hostname or name;
  system.stateVersion = release;
}
