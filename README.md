# Snowman ⛄

Snowman is an **inventory-driven NixOS framework** designed to be a reusable **base** for your own personal, reproducible NixOS configuration.

It is built on a **distro + template** model and a literal **snowman**:

- **The Snowman Repo (this one):**  
  The **base**. It provides all core modules for users, hardware, secrets, and roles.

- **Your Config Repo (created from the template):**  
  The **body**. This contains your personal `inventory.nix`, secrets, user definitions, host definitions, dotfiles wiring, etc.

- **Your Dotfiles Repo (optional, but recommended):**  
  The **head**. This is where your actual editor/shell/tool configs live. Snowman’s roles (e.g. `roles.dotfiles`) mount that “head” onto your Snowman body.

You own your **body repo** forever. Snowman stays the clean, reusable **base** underneath, and your **head** (dotfiles) can evolve independently.

---

# 🚀 Step 1 — Create Your Personal Config Repo (Snowman Body)

**Do not clone this repo directly.** 
Instead, generate your *own* repo from Snowman's template.

### Option A: GitHub UI

Click the green **“Use this template”** button on this repo’s GitHub page.

### Option B: From your terminal

```bash
nix flake new -t github:DarkBones/snowman#default my-personal-config
cd my-personal-config
````

This creates your own fresh **Snowman body repo** (configuration directory) powered by the Snowman base.

---

# 🧭 Step 2 — Configure Your System (Inventory First)

Everything you edit happens *inside your personal config/body repo*.
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

Your **body repo** is now ready to be used on a real machine.

---

# 🏗️ Where to Put Your Configuration (Base, Body & Head)

Snowman is layered. Depending on what you are trying to configure, you will edit one of three things:

* The **base** (this Snowman repo) — only if you are developing Snowman itself.
* Your **body repo** (personal config) — where hosts, users, roles, and wiring live.
* Your **head repo** (dotfiles) — where your actual editor/shell/tool configs live.

Within the **body repo**, you usually touch one of three areas:

### 1. `inventory.nix` (The Blueprint)

**Use for:** Infrastructure, Users, Secrets.

This is the high-level view of your fleet. You use this to define **existence**:

* "This host exists."
* "This user exists on this host."
* "This user is a `dev` and has `secrets`."
* "This disk partition layout is X."
* "This host allows these roles for these users."

### 2. `hosts/<host-name>.nix` (The System Config)

**Use for:** Machine-specific system services, timezones, and standard NixOS options.

This file is a standard NixOS module. Snowman (the base) imports it automatically via the body repo. You use this for **system behavior**:

```nix
# hosts/my-laptop.nix
{ pkgs, ... }: {
  imports = [
    ./my-laptop-hardware-configuration.nix # Imported via snowman-import-hardware
  ];

  # Standard NixOS configuration goes here:
  time.timeZone = "America/New_York";
  networking.hostId = "8425e349"; # Required for ZFS

  # Enable specific services for this machine
  services.tailscale.enable = true;
  services.nginx.enable = true;

  environment.systemPackages = [ pkgs.vim ];
}
```

### 3. `home/roles/*.nix` (The User Config)

**Use for:** Reusable user environments (Home Manager).

If you want to configure tools, shells, or dotfiles that a user carries with them across multiple machines, write a **Role**.

1. Create `home/roles/gaming.nix` (standard Home Manager module).

2. Enable it in `inventory.nix`:

   ```nix
   users.alice.roles.gaming.enable = true;
   ```

3. (Optional) Restrict which roles can run on a specific host using
   `availableRoles` – host-level **role allowlist**. If set, only roles whose names appear in this list are applied for users on this host, even if the user has more roles enabled. If omitted, all `roles.<name>.enable = true` roles are applied.

Separate from that, your **head repo** (dotfiles) is mounted via roles like `roles.dotfiles`, which tell Snowman where to pull your head from and how to attach it.

---

# 🖥️ Step 3 — Install NixOS Normally, Then Hand Control to Snowman

Snowman assumes the following workflow:

> **Install NixOS with the normal installer, reboot, log in as your user, then switch the machine over to your Snowman body repo.**

You do **not** run Snowman from the live ISO after installation.

## 1. Install NixOS with the graphical (or standard) installer

On the target machine:

1. Boot the official NixOS ISO (graphical installer is fine).
2. Use the installer normally:

   * partition and format disks,
   * pick a filesystem (ext4, btrfs, …),
   * choose a bootloader (GRUB / systemd-boot),
   * create an initial user account (e.g. `bas`),
   * finish the installation.
   * **(Recommended for laptops / Wi-Fi machines)**  
     In the generated `/etc/nixos/configuration.nix`, make sure you have:
     ```nix
     networking.networkmanager.enable = true;
     ```
     This gives you `nmtui` after the first reboot so you can connect to Wi-Fi
     **before** switching the machine to Snowman.

The installer will write its own `/etc/nixos/configuration.nix` and
`/etc/nixos/hardware-configuration.nix`. Think of these as **temporary**:
your Snowman **body repo**, powered by the base, will replace them.

3. Reboot into the freshly installed system.
4. Log in as the user you created during installation.

### 💡 Wi-Fi & networking workflow

Snowman **does not touch networking** unless you explicitly ask it to via
`hosts.<name>.wifi` in `inventory.nix`.

That means:

- If you **don’t** define a `wifi` block for a host, Snowman leaves your
  existing NetworkManager / `nmtui` setup alone.
- You can always install NixOS, reboot, connect to Wi-Fi using `nmtui`, and
  *then* pull your Snowman config.

A very typical flow for a laptop or Raspberry Pi with a screen:

1. Install NixOS normally and ensure:
   ```nix
   networking.networkmanager.enable = true;
   ```

2. Reboot into the installed system.
3. Log in as the user you created during install.
4. Run:

   ```bash
   nmtui
   ```

   and connect to Wi-Fi like on any other distro.
5. Clone your Snowman body repo and continue with `./bin/snowman-import-hardware`
   and `sudo nixos-rebuild --flake ...`.

This works even if you never configure Wi-Fi in `inventory.nix`.
Inventory-driven Wi-Fi is **optional** and mainly intended for headless or
fully declarative setups.

## 2. Clone your Snowman config/body repo on the installed system

On the newly installed system:

```bash
# Example location; choose whatever you like
mkdir -p ~/Developer
cd ~/Developer

git clone git@github.com:YourName/my-personal-config.git
cd my-personal-config
```

From now on, **all commands are run inside this body repo**, as that user.

## 3. Import the installer’s hardware configuration

The installer already generated `/etc/nixos/hardware-configuration.nix`
for this machine. Snowman wants that file **inside your body repo**, under
a host-specific name, and it will assert that it exists.

Use the helper script from the template:

```bash
./bin/snowman-import-hardware <host-name>
```

Example:

```bash
./bin/snowman-import-hardware my-laptop
```

This will:

* read `/etc/nixos/hardware-configuration.nix` from the installed system, and
* copy it to:

  ```text
  hosts/my-laptop-hardware-configuration.nix
  ```

If the file already exists, the script refuses to overwrite it, so you won’t
accidentally lose edits.

Snowman’s flake wiring will automatically import this file for the host and
fail with a clear error if it’s missing.

## 4. Switch the machine to your Snowman config/body

Once:

* your host exists in `inventory.nix`,
* the matching `hosts/<host>-hardware-configuration.nix` file exists
  (created via `snowman-import-hardware`), and
* your users are wired up,

run from inside your body repo on the installed system:

```bash
sudo nixos-rebuild switch --flake .#my-laptop
```

This **replaces** the installer’s “throwaway” configuration with your
Snowman-driven one (base + body). From now on you manage the machine purely by editing your body repo and running `nixos-rebuild` with the flake.

---

# 🔄 Step 4 — Deploy Updates (From Any Machine)

From your development machine (macOS, Linux, etc.), run:

```bash
nix run nixpkgs#nixos-rebuild -- switch \
  --flake path:/path/to/my-personal-config#my-laptop \
  --target-host alice@my-laptop-ip \
  --use-remote-sudo
```

This updates the remote machine using your personal Snowman body configuration.

---

# 🔐 Secrets Management (Sops & Age)

All secret handling happens **inside your personal config/body repo**.

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
      key   = "wireguard-private-key"; # YAML key path
      owner = "root";
      group = "root";
      mode  = "0400";
    };
  };
};
```

Snowman maps these to `sops.secrets` entries and writes them as files with the given owner/group/mode.

---

## Inventory: Hosts & Users

Your `inventory.nix` is the heart of your Snowman **body**. It does two things:

* Defines **which hosts** you manage (`hosts = { ... };`)
* Defines **which users** exist and which hosts they appear on (`users = { ... };`)

### Hosts

Each entry under `hosts` is a machine:

```nix
hosts = {
  my-laptop = {
    system = "x86_64-linux";
    users  = [ "alice" ];

    # Optional: advanced boot/disk inventory for Snowman + disko
    hardware = {
      boot = { firmware = "efi"; };
      bootDevice = "/dev/sda";
      fs = {
        type = "ext4";
        partition = 1;
      };
    };

    # Optional: per-host role filter
    # If omitted, all enabled user roles run here.
    # If set, only roles in this list are applied:
    # availableRoles = [ "dev" "secrets" ];
  };
};
```

Required per host:

* `system` – NixOS system type (e.g. `"x86_64-linux"`)
* `users` – list of user names that should exist on this host

Optional, but useful:

* `hardware` – advanced block used for bootloader control
  * If omitted, Snowman simply uses your imported `hardware-configuration.nix` and does not change bootloader settings.
  * If present with `boot.firmware = "bios"` or `"efi"`, Snowman configures GRUB/systemd-boot based on it.
  * If set to `boot.firmware = "none"`, Snowman explicitly **does not** touch bootloader settings.
* `availableRoles` – host-level **role allowlist**. If set, only roles whose names appear in this list are applied for users on this host. If omitted, all `roles.<name>.enable = true` roles are applied.
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

#### Optional: Wi-Fi configuration in `inventory.nix`

For most machines, you can let NetworkManager handle Wi-Fi and never mention it
in `inventory.nix`. If `hosts.<name>.wifi` is **absent**, Snowman does **nothing**
to your networking – whatever you set up during install (e.g. via `nmtui`) stays.

If you want **declarative Wi-Fi**, especially for headless hosts, you can add a
`wifi` block to a host and (optionally) a `networks` block at the top level of
the inventory:

```nix
{
  # Used as system.stateVersion + HM stateVersion
  release = "25.05";

  ########################################################
  ## Optional: named Wi-Fi networks
  ## Secrets live in networks/secrets.yml (see template).
  ########################################################
  networks = {
    home = {
      ssid = "my-home-ssid";
      # YAML path inside networks/secrets.yml:
      passwordSecret = "home/password";
    };
    work = {
      ssid = "corp-wifi";
      passwordSecret = "work/password";
    };
  };

  hosts = {
    rpi4 = {
      system = "aarch64-linux";
      users  = [ "bas" ];

      ####################################################
      ## Wi-Fi (optional)
      ##
      ## If this block is omitted, Snowman leaves
      ## networking alone (NetworkManager / nmtui, etc.).
      ####################################################

      # Roaming mode: let NetworkManager handle Wi-Fi.
      # Use this for laptops / interactive machines.
      # wifi = {
      #   mode = "roaming";   # or simply omit `wifi` entirely
      # };

      # Static/headless Wi-Fi: wpa_supplicant + sops-managed PSKs.
      # Useful for Pis / servers with no screen.
      wifi = {
        mode = "static-wifi";
        interface = "wlan0";  # default if omitted
        useDHCP = true;       # default if omitted
        networks = [ "home" ];  # names from the top-level `networks` attr
      };

      # ...
    };
  };

  users = { ... };
}
```

#### Hardware configuration files (per host)

As described above, Snowman expects a per-host hardware file:

```text
hosts/<host>-hardware-configuration.nix
```

You normally create this once per host by running, **on the installed system**:

```bash
cd /path/to/my-personal-config
./bin/snowman-import-hardware <host-name>
```

This copies `/etc/nixos/hardware-configuration.nix` into the correct location.
Snowman’s flake wiring automatically imports it and refuses to build if it’s
missing, with an explicit error telling you which command to run.

From then on, hardware for that host is fully managed via Git like everything
else.

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
> * a **password** (`initialPassword` or `secrets.userPasswordHashKey`).

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

### Home roles & host filtering

Home roles live under `users.<name>.roles` and are consumed by Snowman’s home-manager modules.

Examples:

```nix
users.alice.roles = {
  dev.enable     = true; # your own dev role in home/roles/dev.nix
  ssh.enable     = true; # ensure outbound SSH key exists
  secrets.enable = true; # include `sops` CLI
  gaming.enable  = true; # e.g. Steam, GPU drivers on gaming PC only

  dotfiles = {
    enable    = true;
    sourceKey = "alice"; # pinned mode or git mode
    linkMap = {
      ".config/nvim" = "nvim/.config/nvim";
      ".zshrc"       = "zsh/.zshrc";
    };
  };
};
```

By default, **all roles with `enable = true` are applied** for that user on any host they appear on.

If you set `hosts.<host>.availableRoles`, Snowman will:

1. Take the set of roles where `roles.<name>.enable = true`.
2. Intersect it with `availableRoles`.
3. Only apply the resulting subset on that host.

Example:

```nix
users.bas.roles = {
  bas.enable     = true;
  dev.enable     = true;
  secrets.enable = true;
  ssh.enable     = true;
  gaming.enable  = true; # installs Steam, GPU drivers, etc.
};

hosts.gaming-pc = {
  system = "x86_64-linux";
  users  = [ "bas" ];

  # availableRoles = [ "bas" "dev" "secrets" "ssh" "gaming" ]; # <- defaults to all available
};

hosts.work-laptop = {
  system = "x86_64-linux";
  users  = [ "bas" ];

  # No Steam, no gaming stack on the work machine:
  availableRoles = [ "bas" "dev" "secrets" "ssh" ];
};
```

On `gaming-pc`, all five roles are applied.
On `work-laptop`, `gaming` is ignored even though it’s enabled for `bas`.

This lets you **reuse the same logical user across many machines** while keeping host-specific role policies declarative and centralised in `inventory.nix`.

### Releases

At the top of `inventory.nix` you’ll also see:

```nix
release = "25.05";
```

Snowman uses this as both the NixOS `system.stateVersion` and the Home Manager `stateVersion` so you only set it once per inventory/body.

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

1. Override the SSH settings in your *host config* (not in the Snowman base), e.g.:

   ```nix
   services.openssh.settings.PasswordAuthentication = true;
   services.openssh.settings.AuthenticationMethods =
     "publickey,password publickey,keyboard-interactive";
   ```

2. Ensure your users have passwords (`initialPassword` or sops-managed hash).

Snowman will then assert that SSH *allows* passwords **only if** each SSH-enabled user actually has one, to avoid “login impossible” states.

---

# 🧩 Home Roles (dev, ssh, secrets, dotfiles/head)

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
  Example dev tool role (from your body repo’s `home/roles/dev.nix`).

* `roles.ssh.enable`
  Ensures a **user-level outbound SSH key** exists at `$HOME/.ssh/id_ed25519`.
  This is for the user to SSH *out* from the machine, not for logging in.

* `roles.secrets.enable`
  Includes the `sops` CLI (from `pkgsUnstable`) in the user’s environment.

* `roles.dotfiles.*`
  Mounts your **head repo** (dotfiles) into the user’s home, either:

  * via **pinned mode** (flake input mapped through `dotfilesSources`), or
  * via **git mode** (clone/pull at activation time).

These roles are **opt-in** (`enable = true` in the inventory example); if you omit them or set `enable = false`, Snowman simply won’t apply that home-manager role.

Combined with `hosts.<host>.availableRoles`, you can define a **rich set of roles per user** and still keep each host’s active role set tight and appropriate.

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

# 🧑‍💻 For Maintainers (Developing the Snowman Base Itself)

If you are **editing Snowman's modules** (this repo, the **base**) and want to test those changes with your own personal body repo:

## 1. Use two separate repos

* `~/Developer/snowman/` — the **base** (this repo)
* `~/Developer/snowman-config/` — your actual **body** configuration (made from the template)
* `~/Developer/dotfiles/` — your **head** (optional, but nicely thematic)

## 2. Temporarily point your body repo to your local Snowman base

Inside `snowman-config/flake.nix`:

```nix
inputs.snowman.url = "path:../snowman";
```

This allows live testing of base/module changes without pushing to GitHub.

## 3. Deploy from *your body repo* (not from the base)

```bash
cd ~/Developer/snowman-config

nix run nixpkgs#nixos-rebuild -- switch \
  --flake .#my-host \
  --target-host user@host \
  --use-remote-sudo
```

## 4. When satisfied, push updates to GitHub

Then switch your body repo back to the stable GitHub source:

```nix
inputs.snowman.url = "github:DarkBones/snowman";
```

This keeps the Snowman **base** pure and reusable for everyone, while your **body** and **head** stay fully yours.
