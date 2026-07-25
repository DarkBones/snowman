{
  lib,
  pkgs,
  config,
  currentHost,
  ...
}:
{
  options.snowman.flakePath = lib.mkOption {
    type = lib.types.str;
    default = "";
    example = "/home/alice/my-snowman-config";
    description = ''
      Path to the body/config flake the `snowman` CLI should operate on.
      Written to /etc/snowman/flake. If unset, the CLI requires the
      SNOWMAN_FLAKE environment variable.
    '';
  };

  config = {
    environment.etc."snowman/flake" = lib.mkIf (config.snowman.flakePath != "") {
      text = config.snowman.flakePath + "\n";
    };

    environment.systemPackages = [
      (import ../lib/snowman-cli.nix {
        inherit pkgs;
        variant = "nixos";
        target = currentHost;
        modeFile = "/etc/snowman/dotfiles-mode";
        flakeFile = "/etc/snowman/flake";
        extraPath = "/run/current-system/sw/bin";
      })
    ];
  };
}
