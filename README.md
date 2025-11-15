# Snowman ⛄

Snowman is an **inventory-driven NixOS framework** designed to be a reusable “engine” for your own personal, reproducible NixOS configuration.

It is built on a **distro + template** model:

* **The Snowman Repo (this one):**  
  The *engine*. It provides all core modules for users, hardware, secrets, and roles.

* **Your Config Repo (created from the template):**  
  The *car*. This contains your personal `inventory.nix`, secrets, user definitions, host definitions, dotfiles settings, etc.

You own your config repo forever. Snowman stays the clean, reusable engine underneath.

---

# 🚀 Step 1 — Create Your Personal Config Repo

**Do not clone this repo directly for personal use.**  
Instead, generate your *own* repo from Snowman's template.

### Option A: GitHub UI

Click the green **“Use this template”** button on this repo’s GitHub page.

### Option B: From your terminal

```bash
nix flake new -t github:DarkBones/snowman#default my-personal-config
cd my-personal-config
```

This creates your own fresh Snowman-powered configuration directory.

---

# 🧭 Step 2 — Configure Your System

Everything you edit happens *inside your personal config repo*.
Your new `my-personal-config/` directory is now your “forever config.”

Inside it:

## 1. Edit `inventory.nix`

This is the heart of Snowman.

* Delete or comment out the example host `vm-snowman`
* Add your own host (e.g. `my-laptop`)
* Delete or comment out the example user `bas`
* Add your own user (e.g. `alice`)

Each host and user lives under:

```nix
hosts = { ... };
users = { ... };
```

See the comments in `template/inventory.nix` for examples.

## 2. Choose a login method for each user (required)

For **every user listed in `hosts.<host>.users`**, Snowman enforces:

> Each user must provide at least one login method:
>
> * an **SSH key** (`sshPubKeys` / `sshPubKeyFile` / `sshPubKeyFiles`), **or**
> * a **password** (`initialPassword` or sops secrets + `userPasswordHashKey`).

Concretely, in `users.<name>` you can:

### Option A: SSH-only login

```nix
users.alice = {
  uid = 1000;
  groups = [ "wheel" ];
  shell = "zsh";

  # Pick ONE of these styles:
  sshPubKeys = [ "ssh-ed25519 AAAA... alice@laptop" ];
  # or:
  # sshPubKeyFile = ./users/keys/alice.pub;
  # or:
  # sshPubKeyFiles = [ ./users/keys/alice-laptop.pub ./users/keys/alice-desktop.pub ];
};
```

This user:

* passes Snowman’s “login method” assertion (has keys)
* can SSH in (because OpenSSH is configured as publickey-only)
* does **not** require any password to be configured

### Option B: Password-only login

```nix
users.alice = {
  uid = 1000;
  groups = [ "wheel" ];
  shell = "zsh";

  # Simple (non-sops) initial password:
  initialPassword = "changeme";
};
```

or with sops-managed password hash:

```nix
users.alice = {
  uid = 1000;
  groups = [ "wheel" ];
  shell = "zsh";

  secrets = {
    sopsFile = ./users/secrets/alice_secrets.yml;
    keys = [ "password_hash" ];
    userPasswordHashKey = "password_hash";
  };
};
```

This user:

* passes Snowman’s “login method” assertion (has a password)
* can log in locally via TTY
* **cannot SSH in** by default (SSH is publickey-only; see SSH behavior below)

### Option C: Both SSH + password

You can combine keys and passwords. Snowman only enforces that at least one method exists; having both is fine.

## 3. (Optional) Wire up secrets & extra files

Depending on what you actually need, you can optionally:

* Put your user’s SSH public key(s) into:

  ```text
  users/keys/<name>.pub
  ```

  and reference them via `sshPubKeyFile` or `sshPubKeyFiles`.

* Create **per-host** secrets:

  ```text
  hosts/secrets/<host>_secrets.yml
  ```

* Create **per-user** secrets:

  ```text
  users/secrets/<name>_secrets.yml
  ```

* Update `.sops.yaml` with *your* Age public keys
  (see Secrets section below for details).

## 4. Commit your repo

```bash
git add .
git commit -m "Initial Snowman setup"
git push
```

Your config repo is now ready for installation.

---

# 🖥️ Step 3 — Install a New Machine

1. Boot the target machine using the **official NixOS minimal ISO**.

2. Connect to the internet.

3. Partition and format your disks normally.

4. Mount your root filesystem at `/mnt`, e.g.:

   ```bash
   mount /dev/sda1 /mnt
   ```

5. Install NixOS using your new config repo:

   ```bash
   nix-shell -p git
   nixos-install --flake git@github.com:YourName/my-personal-config#my-laptop
   ```

   (You can also use an HTTPS URL if you prefer.)

6. If you enabled the optional USB bootstrap (see below),
   plug in the `SNOWMANKEY` when prompted by sops-nix.

7. Reboot.

Your new Snowman-powered machine will be configured exactly as defined.

---

# 🔄 Step 4 — Deploy Updates

From your development machine (macOS, Linux, etc.), run:

```bash
nix run nixpkgs#nixos-rebuild -- switch \
  --flake path:/path/to/my-personal-config#my-laptop \
  --target-host alice@my-laptop-ip \
  --use-remote-sudo
```

This updates the remote machine using your personal Snowman configuration.

---

# 🔐 Secrets Management (Sops & Age)

All secret handling happens **inside your personal config repo**.

Snowman uses:

* **sops** to encrypt/decrypt files
* **sops-nix** to expose them to Nix at build time
* **Age keys** as recipients

## Per-user secrets (optional)

Example path:

```text
users/secrets/alice_secrets.yml
```

Example content (encrypted with sops):

```yaml
password_hash: "$y$j9T$..."
github_token: "ghp_123..."
```

Inventory entry:

```nix
users.alice = {
  uid = 1000;
  groups = [ "wheel" ];
  shell = "zsh";

  secrets = {
    sopsFile = ./users/secrets/alice_secrets.yml;
    keys = [ "password_hash" "github_token" ];
    userPasswordHashKey = "password_hash";
  };
};
```

Snowman will:

* Expose each entry in `keys` as a sops secret at build time
* Use `userPasswordHashKey` as `users.users.<name>.hashedPasswordFile`

This **counts as a valid login method** for the user (password-based login).

## Per-host secrets (optional)

Example path:

```text
hosts/secrets/my-laptop_secrets.yml
```

Inventory entry:

```nix
hosts.my-laptop.secrets = {
  sopsFile = ./hosts/secrets/my-laptop_secrets.yml;
  items = {
    wireguard-private-key = {
      key = "wireguard-private-key"; # YAML key path
      owner = "root";
      group = "root";
      mode = "0400";
    };
  };
};
```

Snowman maps these to `sops.secrets` entries and writes them as files with the given owner/group/mode.

---

## Inventory: Hosts & Users

Your `inventory.nix` is the heart of Snowman. It does two things:

- Defines **which hosts** you manage (`hosts = { ... };`)
- Defines **which users** exist and which hosts they appear on (`users = { ... };`)

### Hosts

Each entry under `hosts` is a machine:

```nix
hosts = {
  my-laptop = {
    system = "x86_64-linux";
    users  = [ "alice" ];
  };
};
```

Required per host:

* `system` – NixOS system type (e.g. `"x86_64-linux"`)
* `users` – list of user names that should exist on this host

Optional, but useful:

* `mutableUsers` – if `false`, users are only managed via Nix (no `passwd` edits)
* `hostname` – if you want a different runtime hostname than the attr name
* `profiles` – built-in NixOS profiles (e.g. `"qemu-guest"`)
* `bootstrap.usb` – “Snowman Key” for decrypting secrets from a USB on first boot
* `secrets` – per-host secrets managed via sops-nix

Per-host secrets look like this:

```nix
hosts.my-laptop.secrets = {
  sopsFile = ./hosts/secrets/my-laptop_secrets.yml;
  items = {
    wireguard-private-key = {
      key   = "wireguard-private-key"; # YAML path
      owner = "root";
      group = "root";
      mode  = "0400";
    };
  };
};
```

Snowman converts `items` into `sops.secrets` entries and writes them as files with the given owner/group/mode.

### Users

Each entry under `users` is a logical user that can be placed on one or more hosts:

```nix
users.alice = {
  uid    = 1000;
  groups = [ "wheel" ];
  shell  = "zsh";
};
```

A user may appear on multiple hosts by listing their name in each host’s `users` array.

#### Login requirement

For every user listed in `hosts.<host>.users`, Snowman enforces:

> Each user must provide at least one login method:
>
> * an **SSH key** (`sshPubKeys`, `sshPubKeyFile`, `sshPubKeyFiles`), or
> * a **password** (`initialPassword` or sops-managed hash via `userPasswordHashKey`).

If neither is configured, evaluation fails with a clear assertion.

#### SSH keys

You can configure SSH keys in three ways:

```nix
sshPubKeys     = [ "ssh-ed25519 AAAA... alice@laptop" ];
sshPubKeyFile  = ./users/keys/alice.pub;
sshPubKeyFiles = [ ./users/keys/alice-laptop.pub ./users/keys/alice-desktop.pub ];
```

All of them are merged into that user’s `authorized_keys` on each host where they appear.

#### Passwords (optional)

You can configure a password in two ways:

```nix
# Simple (non-sops) initial password:
initialPassword = "changeme";
```

or via sops:

```nix
secrets = {
  sopsFile            = ./users/secrets/alice_secrets.yml;
  keys                = [ "password_hash" ];
  userPasswordHashKey = "password_hash";
};
```

Snowman uses `userPasswordHashKey` as `hashedPasswordFile` for that user.

> **Note:** SSH is configured as **publickey-only** by default. Passwords are mainly for local TTY login unless you explicitly loosen SSH settings in your host config.

### Home roles

Home roles live under `users.<name>.roles` and are consumed by Snowman’s home-manager modules.

Examples:

```nix
users.alice.roles = {
  dev.enable     = true; # your own dev role in home/roles/dev.nix
  ssh.enable     = true; # ensure outbound SSH key exists
  secrets.enable = true; # include `sops` CLI
  dotfiles = {
    enable    = true;
    sourceKey = "alice"; # pinned mode
    linkMap = {
      ".config/nvim" = "nvim/.config/nvim";
      ".zshrc"       = "zsh/.zshrc";
    };
  };
};
```

`dotfiles` supports two modes:

1. **Pinned mode** (reproducible):

   * Add a flake input for your dotfiles:

     ```nix
     inputs.alice-dotfiles = {
       url   = "github:YourName/dotfiles";
       flake = false;
     };
     ```

   * Map it in your flake:

     ```nix
     dotfilesSources = {
       alice = inputs.alice-dotfiles;
     };
     ```

   * Set `sourceKey = "alice"` in `roles.dotfiles`.

2. **Git mode** (non-reproducible, but simple):

   * Leave `sourceKey` unset or not found in `dotfilesSources`
   * Configure:

     ```nix
     repo   = "git@github.com:YourName/dotfiles.git";
     dir    = "Developer/dotfiles";
     branch = "main";
     sparse = [ "nvim" "zsh" ];
     ```

In both modes, `linkMap` defines how paths inside the repo are linked into `$HOME`.

### Releases

At the top of `inventory.nix` you’ll also see:

```nix
release = "25.05";
```

Snowman uses this as both the NixOS `system.stateVersion` and the Home Manager `stateVersion` so you only set it once per inventory.

---

# 🔑 SSH Login Keys (`users/keys/`)

Snowman separates *user login keys* from *secrets* to make your configuration easier to understand.

## What goes in `users/keys/`?

This directory holds **SSH public keys** that allow users to log into your Snowman-managed machines.

Examples:

* Your laptop’s SSH public key
* Your work machine’s SSH public key
* A YubiKey-backed public key
* Any other key you want to authorize

These are **not secrets** — public keys are safe to store in Git.

```text
users/
  keys/
    alice.pub
    work-laptop.pub
    yubikey.pub
```

## How to use these keys

Inside `inventory.nix`, you reference them using `sshPubKeyFile` or `sshPubKeyFiles`:

```nix
users.alice = {
  uid = 1000;
  groups = [ "wheel" ];
  shell = "zsh";

  # Single file:
  sshPubKeyFile = ./users/keys/alice.pub;

  # or multiple:
  # sshPubKeyFiles = [
  #   ./users/keys/alice-laptop.pub
  #   ./users/keys/alice-desktop.pub
  # ];
};
```

Alternatively, inline keys:

```nix
sshPubKeys = [ "ssh-ed25519 AAAA... alice@laptop" ];
```

All forms are merged and end up in:

```text
~/.ssh/authorized_keys
```

for that user.

## Relationship to sops/Age

`users/keys/` is **not** related to `.sops.yaml`. That file controls:

* Age recipient keys
* Which keys can decrypt your **encrypted secret files**

SSH keys for login **must remain unencrypted**, because they live in the public, world-readable `authorized_keys`.

Use:

* `users/keys/*` → **public SSH keys for login**
* `users/secrets/*.yml` → **sops-encrypted files for secrets**, like password hashes or tokens

---

# 🔒 Authentication & SSH Behavior

This section summarizes how Snowman wires authentication and SSH.

## Inventory rule (per user)

For each user that appears in `hosts.<host>.users`, Snowman enforces:

> Each user must provide at least one login method:
>
> * **SSH key** (`sshPubKeys` / `sshPubKeyFile` / `sshPubKeyFiles`), or
> * **Password** (`initialPassword` or `secrets.userPasswordHashKey`).

If neither is configured, evaluation fails with a clear error message.

## OpenSSH defaults

Snowman configures SSH like this (simplified):

```nix
services.openssh = {
  enable = true;
  openFirewall = true;

  settings = {
    PermitRootLogin = "no";
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
    AuthenticationMethods = "publickey";
    AllowUsers = [ ...users from hosts.<host>.users... ];
    # plus various hardened defaults
  };
};
```

That means:

* SSH is **publickey-only** by default
* Users **without** SSH keys **cannot** SSH in
* Users with passwords but no keys can still log in on **local TTY**, but not via SSH

## Behavior matrix

| SSH keys configured? | Password configured? | SSH password auth enabled? | SSH login?                  | Local TTY login?                     |
| -------------------- | -------------------- | -------------------------- | --------------------------- | ------------------------------------ |
| ✅ Yes                | ❌ No                 | default (`false`)          | ✅ Yes (key)                 | ✅ Yes (if allowed by NixOS defaults) |
| ❌ No                 | ✅ Yes                | default (`false`)          | ❌ No (key-only)             | ✅ Yes                                |
| ✅ Yes                | ✅ Yes                | default (`false`)          | ✅ Yes (key)                 | ✅ Yes                                |
| ❌ No                 | ❌ No                 | any                        | ❌ Fails (Snowman assertion) | ❌ Fails (config build error)         |

If you intentionally want SSH password logins, you must:

1. Override the SSH settings in your *host config* (not in Snowman engine), e.g.:

   ```nix
   services.openssh.settings.PasswordAuthentication = true;
   services.openssh.settings.AuthenticationMethods = "publickey,password publickey,keyboard-interactive";
   ```

2. Ensure your users have passwords (`initialPassword` or sops-managed hash).

Snowman will then assert that SSH *allows* passwords **only if** each SSH-enabled user actually has one, to avoid “login impossible” states.

---

# 🧩 Home Roles (dev, ssh, secrets, dotfiles)

Home-manager roles for a user are defined in `inventory.nix` under `users.<name>.roles`.

Example:

```nix
users.alice = {
  uid = 1000;
  groups = [ "wheel" ];
  shell = "zsh";

  roles = {
    dev.enable = true;
    ssh.enable = true;
    secrets.enable = true;

    dotfiles = {
      enable = true;
      # sourceKey / repo / linkMap etc.
    };
  };
};
```

Current roles:

* `roles.dev.enable`
  Example dev tool role (from your personal config’s `home/roles/dev.nix`).

* `roles.ssh.enable`
  Ensures a **user-level outbound SSH key** exists at `$HOME/.ssh/id_ed25519`.
  This is for the user to SSH *out* from the machine, not for logging in.

* `roles.secrets.enable`
  Includes the `sops` CLI (from `pkgsUnstable`) in the user’s environment.

* `roles.dotfiles.*`
  Manages your dotfiles either:

  * via **pinned mode** (flake input mapped through `dotfilesSources`), or
  * via **git mode** (clone/pull at activation time).

These roles are **opt-in** (`enable = true` in the inventory example); if you omit them or set `enable = false`, Snowman simply won’t apply that home-manager role.

---

# 💾 Optional: USB Bootstrap Age Key (“Snowman Key”)

This allows a **brand-new machine** to decrypt your secrets *before* it has its own Age key enrolled.

## 1. Generate a Snowman bootstrap key

```bash
nix run nixpkgs#age -- age-keygen -o snowman.key
```

Put the *public key* into your `.sops.yaml` (e.g. under `&snowman_usb`).

## 2. Prepare the USB

1. Format USB with label `SNOWMANKEY`
2. Copy `snowman.key` (private key) to the root

## 3. Enable in inventory

```nix
bootstrap.usb = {
  enable = true;
  label = "SNOWMANKEY";
  path = "/mnt/snowman";
  keyFile = "snowman.key";
  fsType = "vfat";
};
```

When this is enabled, Snowman configures sops-nix to **not** auto-generate an Age key and instead use the USB key file.

## 4. Turn it off after first boot

After installation:

1. Convert host SSH key to Age:

   ```bash
   nix run nixpkgs#ssh-to-age -- /etc/ssh/ssh_host_ed25519_key.pub
   ```

2. Add the new Age key to `.sops.yaml`

3. Re-encrypt secrets:

   ```bash
   sops updatekeys users/secrets/*.yml
   sops updatekeys hosts/secrets/*.yml
   ```

4. Set:

   ```nix
   bootstrap.usb.enable = false;
   ```

Now the machine no longer needs the USB. From this point on, your sops files are encrypted to the host's SSH key (converted to an Age recipient), and Snowman uses that host key for decryption. No USB is required anymore.

---

# 🧑‍💻 For Maintainers (Developing Snowman Itself)

If you are **editing Snowman's modules** and want to test those changes with your own personal config:

## 1. Use two separate repos

* `~/Developer/snowman/` — the engine (this repo)
* `~/Developer/snowman-config/` — your actual configuration (made from the template)

## 2. Temporarily point your config to your local Snowman repo

Inside `snowman-config/flake.nix`:

```nix
inputs.snowman.url = "path:../snowman";
```

This allows live testing of module changes without pushing to GitHub.

## 3. Deploy from *your* config repo (not from Snowman)

```bash
cd ~/Developer/snowman-config

nix run nixpkgs#nixos-rebuild -- switch \
  --flake .#my-host \
  --target-host user@host \
  --use-remote-sudo
```

## 4. When satisfied, push updates to GitHub

Then switch your config back to the stable GitHub source:

```nix
inputs.snowman.url = "github:DarkBones/snowman";
```

This keeps Snowman pure and reusable for everyone.
