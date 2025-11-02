{ config, ... }: {
  age.secrets."bas-password".file = ../../secrets/bas-password.age;
  users.users.bas.hashedPasswordFile = config.age.secrets."bas-password".path;
}
