{ config, lib, ... }:
{
  age.secrets.snowmanEnv.file = ./../../secrets/snowman.env.age;

  environment.etc."snowman.env".source = config.age.secrets.snowmanEnv.path;

  # Export variables from it system-wide
  environment.extraInit = ''
    if [ -f /etc/snowman.env ]; then
      set -a
      . /etc/snowman.env
      set +a
    fi
  '';
}

