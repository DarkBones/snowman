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

## How User Management Works

Snowman supports **two complementary ways** to define users:

1. **Central Inventory (`inventory.nix`)** — the recommended single-file overview for all hosts and users.
2. **Per-User Files (`users/people/*.nix`)** — reusable “profiles” or presets you can mix into the inventory.

### 🔹 Option 1: Inventory-based (preferred)

All user data lives directly in `inventory.nix`:

```nix
{
  users = {
    bas = {
      uid = 1000;
      groups = [ "wheel" ];
      shell = "zsh";
      sshPubKeyFile = ./users/keys/bas.pub;
      passwordSecret = ./secrets/bas-password.age;

      roles = {
        dev.enable = true;
        dotfiles.enable = true;
      };
    };
  };

  hosts.vm-snowman = {
    system = "x86_64-linux";
    hardware = "qemu";
    users = [ "bas" ];
  };
}
````

✅ **Simplest workflow** — one place to edit both hosts and users.
✅ **Ideal for small setups** or solo users.
⛔ Per-user versioning and ACLs are limited (everything in one file).

---

### 🔹 Option 2: People-based (advanced / teams)

Each file in `users/people/*.nix` exports a Nix attribute set describing a user or a user template.
Example:

```nix
# users/people/alex.nix
{
  uid = 1002;
  groups = [ "wheel" ];
  shell = "bash";
  sshPubKeyFile = ../keys/alex.pub;
  roles.dev.enable = true;
}
```

Then `inventory.nix` can either:

* Import it directly:

  ```nix
  users = {
    alex = import ./users/people/alex.nix;
  };
  ```
* Or build new entries from a shared “profile library”:

  ```nix
  let People = import ./users/people;
  in {
    users = {
      newhire = People.mkDevUser { uid = 1003; keyFile = ./users/keys/newhire.pub; };
    };
  }
  ```

✅ Enables per-user files, templates, and code-owners.
✅ Good for organizations or multiple maintainers.
⛔ Slightly more moving parts.

---

### Resolution rules

* If `inventory.nix` defines `users`, that set is used as the **source of truth**.
* `users/people/` acts as a **library** — nothing in it is auto-loaded unless referenced from the inventory.
* Each host imports `modules/users.nix`, which reads users from the inventory and automatically:

  * Creates system accounts.
  * Configures SSH keys and age secrets.
  * Enables Home Manager roles when defined.
