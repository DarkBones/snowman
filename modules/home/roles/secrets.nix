{
  lib,
  config,
  pkgsUnstable,
  ...
}:
let
  cfg = config.roles.secrets;
in
{
  options.roles.secrets.enable = lib.mkEnableOption "Secrets role";
  config = lib.mkIf cfg.enable { home.packages = with pkgsUnstable; [ sops ]; };
}
