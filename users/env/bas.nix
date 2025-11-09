{ osConfig, ... }: {
  home.sessionVariables = {
    EDITOR = "nvim";
    LANG = "en_US.UTF-8";
    FLAKE = "~/Developer/snowman";

    TEST = osConfig.sops.secrets.test.path;
  };
}
