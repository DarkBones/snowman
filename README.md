# BEFORE RELEASE CHECKLIST

- [ ] Convert all existing encrypted secrets with bogus values

## 🔐 Bootstrap Secrets via USB (Snowman Key)

When setting up a **fresh machine or VM**, you may not yet have a host SSH key that can decrypt your Age secrets (like passwords or API tokens).
To handle that securely and reproducibly, **Snowman** supports a *USB-based bootstrap key*.

This lets you decrypt and provision your secrets during first boot, without manual file copying or re-encryption.

---

### 🧩 1. Create a dedicated bootstrap keypair

You’ll need the **`age`** CLI to create keys.
If you don’t already have it, you can temporarily run it via Nix (no install needed):

```bash
# With Nix installed
nix run nixpkgs#age -- age-keygen -o snowman.key
```

Or if you don’t have Nix yet:

```bash
# On most Linux distros or macOS (Homebrew)
sudo apt install age       # Debian/Ubuntu
# or
brew install age           # macOS / Homebrew
```

Then run:

```bash
age-keygen -o snowman.key
```

You’ll see output like:

```
# created: 2025-11-08T20:32:41+01:00
# public key: age10z86j26fzxkh64phvsa2nkc5zjdejyesjy4gu2zqmzh8tfknpprq7l3l0k
```

Copy that **public key** line into your repo’s `secrets.nix` so your bootstrap USB can decrypt secrets.

---

### 💾 2. Prepare your USB drive

1. Format or reuse a small drive (any filesystem works, but FAT32 or exFAT is easiest).
2. Label it `SNOWMANKEY`:

   ```bash
   sudo fatlabel /dev/sdX1 SNOWMANKEY   # (or e2label for ext4)
   ```
3. Copy your private key onto it:

   ```bash
   sudo mkdir -p /mnt/usb
   sudo mount /dev/sdX1 /mnt/usb
   sudo cp snowman.key /mnt/usb/
   sudo umount /mnt/usb
   ```

Your USB should now contain:

```
/snowman.key
```

---

### ⚙️ 3. Enable bootstrap for a host

In `inventory.nix`, under your host:

```nix
bootstrap.usb = {
  enable = true;
  label = "SNOWMANKEY";
  path = "/mnt/snowman";
  keyFile = "snowman.key";
  fsType = "vfat";
};
```

This automatically:

* mounts the USB when accessed (`x-systemd.automount`),
* adds `/mnt/snowman/snowman.key` to `age.identityPaths`,
* ensures the system won’t fail if the USB isn’t present (`nofail`).

---

### 🚀 4. Bootstrap a new machine

1. Plug in your USB drive.
2. Boot or install your system.
3. Run:

   ```bash
   sudo nixos-rebuild switch --flake /etc/nixos/snowman
   ```
4. You should see:

   ```
   [agenix] decrypting '/nix/store/.../snowman.env.age' ...
   ```

   ✅ This means your secrets were decrypted using the bootstrap key.

---

### 🧹 5. Remove bootstrap after first setup

Once the host has its own key (e.g. `/etc/ssh/ssh_host_ed25519_key`) added as a recipient in `secrets.nix`, disable USB bootstrap:

```nix
bootstrap.usb.enable = false;
```

Rebuild again:

```bash
sudo nixos-rebuild switch --flake .
```

Now this host can decrypt secrets by itself, no USB needed.

---

### 🧱 Example: `secrets.nix`

```nix
{
  "secrets/admin-password.age".publicKeys = [
    "ssh-ed25519 AAAAC3N... root@nixos"
    "ssh-ed25519 AAAAC3N... user@host-2025-09-22"
  ];

  "secrets/snowman.env.age".publicKeys = [
    "age1..."
    "ssh-ed25519 AAAAC3N... user@host"
  ];
}
```

---

### 🧠 TL;DR

| Step                                     | Purpose                                  |
| ---------------------------------------- | ---------------------------------------- |
| Create `snowman.key`                     | Bootstrap keypair for initial decryption |
| Add its public key to `secrets.nix`      | Allow it to decrypt secrets              |
| Label USB `SNOWMANKEY`                   | Used for automatic detection             |
| Enable `bootstrap.usb` in host inventory | Adds automount + key path                |
| Rebuild with USB plugged in              | Secrets decrypt successfully             |
| Disable bootstrap after first setup      | Host manages secrets itself              |
