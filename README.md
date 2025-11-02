## 🧊 Creating a New User in Snowman

Each user in **Snowman** lives under `users/<name>.nix` and can optionally have an encrypted password managed by **agenix**.

### Create the user file

Create `users/<name>.nix` (for example `users/alex.nix`):

```nix
{ pkgs, ... }: {
  imports = [
    # Optional — include if you want this user to have a password
    (import ../modules/security/user-password.nix {
      username  = "alex";
      secretPath = ../secrets/alex-password.age;
      enable = true;
    })
  ];

  users.users.alex = {
    isNormalUser = true;
    shell = pkgs.bashInteractive;
    extraGroups = [ "wheel" ]; # optional
    openssh.authorizedKeys.keys = [
      (builtins.readFile ../keys/alex.pub)
    ];
  };

  home-manager.users.alex = import ../home/alex.nix; # optional
}
```

Then add this file to the relevant host (e.g. `hosts/vm-snowman/users.nix`):

```nix
{ ... }: { imports = [ ../../users/alex.nix ]; }
```

---

### Generate a password

Run on your **dev machine** (not inside the VM):

```bash
nix run nixpkgs#mkpasswd -- -m yescrypt
```

Copy the resulting `$y$...` hash.

---

### 3️⃣Encrypt it with agenix

If this is the first time you’re using this host, make sure its SSH host public key is in `secrets.nix`.
You can retrieve it from the VM with:

```bash
ssh bas@<vm-ip> 'sudo cat /etc/ssh/ssh_host_ed25519_key.pub'
```

Then add it to `secrets.nix`:

```nix
let
  vm = "ssh-ed25519 AAAA... root@vm-snowman";
in {
  "secrets/alex-password.age".publicKeys = [ vm ];
}
```

Now encrypt the hash:

```bash
nix run github:ryantm/agenix -- -e secrets/alex-password.age
# paste ONLY the hash, save, and exit
```

---

### Deploy

Push the updated configuration to your host:

```bash
nix run .#deploy-vm bas@192.168.122.194
```

`agenix` will decrypt the password during activation, store it securely under `/run/agenix`, and set the user’s hashed password automatically.

---

### Verify

SSH into the machine and test:

```bash
ssh alex@<vm-ip>
sudo -k; sudo true
```

If prompted, the new password should work.
