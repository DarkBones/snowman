{
  lib,
  config,
  osConfig ? null,
  ...
}:
let
  defaultConfigDir = "${config.home.homeDirectory}/snowman-config";
  configuredFlakePath =
    if osConfig != null && osConfig ? snowman && osConfig.snowman.flakePath != "" then
      osConfig.snowman.flakePath
    else
      defaultConfigDir;
in
{
  config = {
    home.sessionPath = [ "${configuredFlakePath}/bin" ];

    home.sessionVariables.SNOWMAN_CONFIG_PATH = lib.mkDefault configuredFlakePath;
  };
}
