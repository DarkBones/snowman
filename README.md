# Snowman ⛄

Snowman is an **inventory-driven NixOS framework** designed to be a reusable **base** for your own personal, reproducible NixOS configuration.

It is built on a **distro + template** model and a literal **snowman**:

  - **The Snowman Repo (this one):** The **base**. It provides all core modules for users, hardware, secrets, and roles.

  - **Your Config Repo (created from the template):** The **body**. This contains your personal `inventory.nix`, secrets, user definitions, host definitions, dotfiles wiring, etc.

  - **Your Dotfiles Repo (optional, but recommended):** The **head**. This is where your actual editor/shell/tool configs live. Snowman’s roles (e.g. `roles.dotfiles`) mount that “head” onto your Snowman body.

You own your **body repo** forever. Snowman stays the clean, reusable **base** underneath, and your **head** (dotfiles) can evolve independently.

-----

# 🚀 Step 1 — Create Your Personal Config Repo (Snowman Body)

**Do not clone this repo directly.** Instead, generate your *own* repo from Snowman's template.

### Option A: GitHub UI

Click the green **“Use this template”** button on this repo’s GitHub page.

### Option B: From your terminal

```bash
nix flake new -t github:DarkBones/snowman#default my-personal-config
cd my-personal-config
```

This creates your own fresh **Snowman body repo** (configuration directory) powered by the Snowman base.

-----

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

*(See the "Deep Dive" section below for all available options.)*

## 2. Choose a login method for each user (required)

For **every user listed in `hosts.<host>.users`**, Snowman enforces:

> Each user must provide at least one login method:
>
>   * an **SSH key** (`sshPubKeys` / `sshPubKeyFile` / `sshPubKeyFiles`), **or**
>   * a **password** (`initialPassword` or sops secrets + `userPasswordHashKey`).

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

This user passes Snowman’s “login method” assertion (has keys) and can SSH in. They do **not** require a password.

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

This user can log in locally via TTY. They **cannot SSH in** by default (SSH is publickey-only; see Deep Dive below).

### Option C: Both SSH + password

You can combine keys and passwords. Snowman only enforces that at least one method exists; having both is fine.

## 3. (Optional) Wire up secrets & extra files

Depending on what you actually need, you can optionally:

  * Put your user’s SSH public key(s) into: `users/keys/<name>.pub`
  * Create **per-host** secrets: `hosts/secrets/<host>_secrets.yml`
  * Create **per-user** secrets: `users/secrets/<name>_secrets.yml`
  * Update `.sops.yaml` with *your* Age public keys.

## 4. Commit your repo

```bash
git add .
git commit -m "Initial Snowman setup"
git push
```

Your **body repo** is now ready to be used on a real machine.

-----

# 🏗️ Where to Put Your Configuration

Snowman is layered. Depending on what you are trying to configure, you will edit one of three things:

  * The **base** (this Snowman repo) — only if you are developing Snowman itself.
  * Your **body repo** (personal config) — where hosts, users, roles, and wiring live.
  * Your **head repo** (dotfiles) — where your actual editor/shell/tool configs live.

Within the **body repo**, you usually touch one of three areas:

1.  **`inventory.nix` (The Blueprint):** Define hosts, users, secrets, and Wi-Fi.
2.  **`hosts/<host-name>.nix` (The System Config):** Machine-specific services, timezones, and NixOS options.
3.  **`home/roles/*.nix` (The User Config):** Reusable user environments (Home Manager).

-----

# 🖥️ Step 3 — Install NixOS Normally, Then Hand Control to Snowman

Snowman assumes the following workflow:

> **Install NixOS with the normal installer, reboot, log in as your user, then switch the machine over to your Snowman body repo.**

You do **not** run Snowman from the live ISO after installation.

## 1. Install NixOS with the graphical (or standard) installer

1.  Boot the official NixOS ISO.
2.  Install normally (partition, user creation, etc.).
3.  **(Recommended)** Ensure `networking.networkmanager.enable = true;` in the generated config so you have Wi-Fi (`nmtui`) after reboot.
4.  Reboot into the installed system.

## 2. Clone your Snowman config/body repo on the installed system

```bash
mkdir -p ~/Developer
cd ~/Developer
git clone git@github.com:YourName/my-personal-config.git
cd my-personal-config
```

From now on, **all commands are run inside this body repo**, as that user.

## 3. Import the installer’s hardware configuration

Snowman needs the hardware scan generated by the installer.

```bash
./bin/snowman-import-hardware my-laptop
```

This copies `/etc/nixos/hardware-configuration.nix` to `hosts/my-laptop-hardware-configuration.nix`.

## 4. Switch the machine to your Snowman config/body

```bash
sudo nixos-rebuild switch --flake .#my-laptop
```

This **replaces** the installer’s “throwaway” configuration with your Snowman-driven one.

-----

# 🛠️ Workflows: Dotfiles (Dev vs. Prod)

Snowman includes a workflow for managing your "Head" (Dotfiles).

Because NixOS stores files in the immutable Nix Store, editing your Neovim or Shell config usually requires a rebuild (`sudo nixos-rebuild switch`). This is too slow for tweaking configs.

Snowman solves this with the `snowman-dotfiles` command.

### Prod Mode (Default)

In this mode, your dotfiles are fetched from your Git host (flake input), locked, and reproducible. They live in the Nix Store.

```bash
snowman-dotfiles prod
```

### Dev Mode

In this mode, Snowman tells Home Manager to **ignore** your dotfiles configuration. Instead, it creates a mutable symlink from your local clone (`~/Developer/dotfiles`) to `~/.config/...`.

```bash
snowman-dotfiles dev
```

You can now edit your Neovim config in `~/Developer/dotfiles`, restart Neovim, and see changes instantly. No rebuild required.

-----

# 🔄 Step 4 — Deploy Updates (From Any Machine)

From your development machine (macOS, Linux, etc.), run:

```bash
nix run nixpkgs#nixos-rebuild -- switch \
  --flake path:/path/to/my-personal-config#my-laptop \
  --target-host alice@my-laptop-ip \
  --use-remote-sudo
```

-----

# 📖 Reference & Deep Dive

This section details the advanced configuration available in `inventory.nix`.

## 1. Inventory Structure

### Releases

At the top of `inventory.nix`:

```nix
release = "25.05";
```

Snowman uses this as both the NixOS `system.stateVersion` and the Home Manager `stateVersion`.

### Hosts

Each entry under `hosts` is a machine:

```nix
hosts = {
  my-laptop = {
    system = "x86_64-linux";
    users  = [ "alice" ];

    # Optional: Advanced hardware/boot control
    hardware.boot.firmware = "efi"; # "bios", "efi", "raspberry-pi", or "none"
    
    # Optional: Enable compatibility for unpatched binaries (Mason/VSCode)
    compatibility = true;

    # Optional: Limit which roles run on this specific host
    availableRoles = [ "dev" "secrets" ];
  };
};
```

  * `compatibility = true`: Enables `nix-ld`, allowing standard Linux binaries (like VSCode Servers or Mason LSPs) to run without patching.
  * `availableRoles`: If set, only user roles appearing in this list are applied. This lets you reuse one user definition across many hosts (e.g., enable "gaming" for the user, but filter it out on the work laptop).

### Users

A user definition can include roles, which correspond to files in `home/roles/`:

```nix
users.alice.roles = {
  dev.enable = true;
  ssh.enable = true;
  dotfiles = {
    enable = true;
    # ...
  };
};
```

## 2. Wi-Fi Configuration

Snowman allows two modes for networking.

**Mode A: Hand-off (Default)**
If you do not define a `wifi` block, Snowman leaves networking alone. You use `nmtui` or `nmcli` manually.

**Mode B: Declarative (Inventory-Driven)**
Useful for headless machines (Raspberry Pi).

1.  Define networks globally in `inventory.nix`:
    ```nix
    networks = {
      home = { ssid = "my-ssid"; passwordSecret = "home/password"; };
    };
    ```
2.  Enable on the host:
    ```nix
    hosts.rpi4.wifi = {
      mode = "static-wifi"; # uses wpa_supplicant + sops
      networks = [ "home" ];
    };
    ```

## 3. SSH Keys vs. Secrets

  * **`users/keys/*.pub`**: These are **public** keys used for logging *into* the machine (`authorized_keys`). They are not encrypted.
  * **`users/secrets/*.yml`**: These are **private** data (password hashes, tokens) encrypted with **sops**.

## 4. Authentication Matrix

Snowman configures OpenSSH to be **publickey-only** by default.

| SSH keys configured? | Password configured? | SSH login?                  | Local TTY login?                     |
| -------------------- | -------------------- | --------------------------- | ------------------------------------ |
| ✅ Yes                | ❌ No                 | ✅ Yes (key)                 | ✅ Yes (if allowed by NixOS defaults) |
| ❌ No                 | ✅ Yes                | ❌ No (key-only)             | ✅ Yes                                |
| ✅ Yes                | ✅ Yes                | ✅ Yes (key)                 | ✅ Yes                                |

To enable password-based SSH (not recommended), override `services.openssh.settings.PasswordAuthentication = true;` in your `hosts/<name>.nix` file.

-----

# 🔐 Secrets Management (Sops & Age)

All secret handling happens **inside your personal config/body repo**.

Snowman uses:

  * **sops** to encrypt/decrypt files
  * **sops-nix** to expose them to Nix at build time
  * **Age keys** as recipients

## Per-user secrets

Example: `users/secrets/alice_secrets.yml`
Mapped in inventory via: `users.alice.secrets.sopsFile`.
Used for password hashes, API tokens, etc.

## Per-host secrets

Example: `hosts/secrets/my-laptop_secrets.yml`
Mapped in inventory via: `hosts.my-laptop.secrets`.
Used for WireGuard keys, Wi-Fi PSKs, host-specific tokens.

-----

# 💾 Optional: USB Bootstrap Age Key (“Snowman Key”)

This allows a **brand-new machine** to decrypt your secrets *before* it has its own Age key enrolled.

## 1. Generate a Snowman bootstrap key

```bash
nix run nixpkgs#age -- age-keygen -o snowman.key
```

Put the *public key* into your `.sops.yaml`.

## 2. Prepare the USB

1.  Format USB with label `SNOWMANKEY`
2.  Copy `snowman.key` (private key) to the root

## 3. Enable in inventory

```nix
bootstrap.usb = {
  enable = true;
  label = "SNOWMANKEY";
  path = "/mnt/snowman";
  keyFile = "snowman.key";
};
```

When enabled, Snowman boots using the key on the USB drive to decrypt secrets.

## 4. Turn it off after first boot

After installation:

1.  Convert host SSH key to Age:

    ```bash
    nix run nixpkgs#ssh-to-age -- /etc/ssh/ssh_host_ed25519_key.pub
    ```

2.  Add the new Age key to `.sops.yaml`

3.  Re-encrypt secrets:

    ```bash
    sops updatekeys users/secrets/*.yml
    sops updatekeys hosts/secrets/*.yml
    ```

4.  Set:

    ```nix
    bootstrap.usb.enable = false;
    ```

Now the machine no longer needs the USB. From this point on, your sops files are encrypted to the host's SSH key (converted to an Age recipient), and Snowman uses that host key for decryption. No USB is required anymore.

-----

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
