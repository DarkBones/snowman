{ username, secretPath ? null, enable ? true }:
{ lib, config, ... }:
let
  path = if secretPath != null then
    secretPath
  else
    ../secrets/${username}-password.age;
in lib.mkIf enable {
  age.secrets."${username}-password".file = path;
  users.users.${username}.hashedPasswordFile =
    config.age.secrets."${username}-password".path;
}
