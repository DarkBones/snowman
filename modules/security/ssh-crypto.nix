{ ... }: {
  services.openssh = {
    kexAlgorithms = [ "curve25519-sha256" "curve25519-sha256@libssh.org" ];
    macs = [ "hmac-sha2-512" "hmac-sha2-256" ];
  };
}
