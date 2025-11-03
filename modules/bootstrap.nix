{ lib, config, ... }: {
  options.snowman.bootstrap.enable =
    lib.mkEnableOption "Allow mutable users for first login phase";
  config = lib.mkIf config.snowman.bootstrap.enable {
    users.mutableUsers = lib.mkForce true;
  };
}
