# Snowman

Snowman is an inventory-driven NixOS framework.

This repository is the **base/engine**. Most users should **not** edit this repo directly.

If you want to use Snowman for your own machines:

1. Click **Use this template**
2. Create your own config repo
3. Make your first machine work there

That user-owned config repo is where almost all personalization belongs.

## What You Are Looking At

Snowman uses three repositories:

- **Snowman base**: the engine in this repo. It provides reusable modules, framework contracts, and the template.
- **Body repo**: your personal config repo created from the template. This is where you define hosts, users, roles, services, and secrets wiring.
- **Dotfiles repo**: your editor, shell, terminal, and app config content that gets linked into `$HOME`.

If a change is about **your machine**, **your users**, or **your services**, it probably belongs in the **body repo**, not here.

## Who Snowman Is For

Snowman is a good fit if you want:

- an inventory-driven NixOS setup
- a clear split between framework, system config, and dotfiles
- a path from one machine to many machines without rewriting everything
- stable dotfiles for normal use and mutable dotfiles for fast iteration

Snowman is probably not the right starting point if you want a single-file NixOS config with no layering.

## Start Here

Do **not** clone this repo as your personal config.

Create a body repo from the template instead:

### GitHub

Use the repository's **Use this template** button.

### Terminal

```bash
nix flake new -t github:DarkBones/snowman#default my-snowman-config
cd my-snowman-config
```

Your new repo is the one you will actually live in.

After creating it:

- read its `README.md`
- keep this base repo as background/reference material
- only come back here if you are changing the framework itself

## Happy Path For Your First Machine

The intended onboarding path is:

1. Create your body repo from the template.
2. Replace the obvious example values in `inventory.nix`.
3. Define one host and one user.
4. Pick one login method.
5. Install plain NixOS normally.
6. Clone your body repo onto that machine.
7. Import hardware with `./bin/snowman-import-hardware <host-name>`.
8. Rebuild with `sudo nixos-rebuild switch --flake .#<host-name>`.

You do **not** need to understand roles, dotfiles modes, secrets rotation, or multi-host patterns before the first successful install.

## What To Change First In The Template

In your new body repo, day-one edits should be small and obvious:

- replace the example host
- replace the example user
- replace the placeholder password or add SSH keys
- set `homeManaged = true` for the user you want Home Manager to manage
- leave advanced sections commented out unless you actually need them

The template is meant to get one machine working first. It can scale later.

## Repo Boundaries

### What belongs in Snowman base

- reusable engine behavior
- inventory contracts and assertions
- generic NixOS and Home Manager modules
- template improvements for all future users
- generic AI/operator guidance

### What belongs in the body repo

- host-specific config
- user definitions and login methods
- local services and reverse proxy layout
- personal roles and overrides
- machine fleet structure
- flake wiring for your systems and dotfiles

### What belongs in the dotfiles repo

- shell config
- editor config
- terminal config
- launcher/bar/browser config
- theme files, wallpapers, and other files linked into `$HOME`

Snowman stays reusable by keeping those boundaries intact.

## Dotfiles Model

Snowman keeps dotfiles **content** separate from dotfiles **wiring**.

There are three concepts:

- **Pinned source**: reproducible dotfiles from a flake input
- **Git fallback**: clone or update a repo on the target machine if no pinned source is configured
- **Mode**: whether symlinks should currently point at the stable source or a mutable checkout

### Prod mode

- stable
- rebuild-oriented
- intended for normal use
- when pinned dotfiles are configured, symlinks point at the pinned/store-backed source

### Dev mode

- fast iteration
- intended for the machine where you edit dotfiles
- symlinks point at a local checkout

### Git fallback

- convenient fallback
- not the ideal long-term reproducible setup
- useful when you want to start before pinning a dotfiles input

Switching modes changes **where the symlinks point**. It does not change the overall architecture.

## Learn Later

Once the first machine works, then learn these in order:

1. reusable roles in `home/roles/`
2. pinned vs mutable dotfiles workflows
3. SOPS and Age for secrets
4. host-local modules and service layout
5. multi-host patterns and role filtering
6. framework-level customization

That ordering is intentional. You do not need all of it up front.

## SOPS + Age Keys

Snowman secrets flow through `sops-nix`, so any operator or host that must decrypt secrets needs an Age recipient in `.sops.yaml` and access to the corresponding Age private key. Convert your SSH key pair once, keep the `age1…` recipient in `.sops.yaml`, and point `sops` at the generated secret key file when running commands.

```
nix profile add nixpkgs#ssh-to-age
nix run nixpkgs#ssh-to-age -- -i ~/.ssh/id_ed25519.pub
nix run nixpkgs#ssh-to-age -- --private-key -i ~/.ssh/id_ed25519 > ~/.ssh/id_ed25519.age
chmod 600 ~/.ssh/id_ed25519.age
export SOPS_AGE_KEY_FILE="$HOME/.ssh/id_ed25519.age"
```

Paste the first command’s output into `.sops.yaml`, keep the generated `.age` file private, and repeat the conversion for any additional keys you need (USB tokens, hosts, etc.). Make sure `SOPS_AGE_KEY_FILE` is exported in every shell that runs `sops`—for example, add

```
export SOPS_AGE_KEY_FILE="$HOME/.ssh/id_ed25519.age"
```

to your shell’s startup file (`~/.bashrc`, `~/.zshrc`, `~/.config/fish/config.fish`, etc.) or a direnv hook so the identity is always available when editing secrets.

## Framework Contract

These are core behaviors of the engine:

- the base exports `nixosModules.default`, `homeModules.default`, and the template from [`flake.nix`](./flake.nix)
- `inventory.nix` in the body repo is the source of truth
- every host must define a hostname and at least one user
- every user must have at least one login method
- Home Manager only applies to users with `homeManaged = true`
- `hosts.<host>.availableRoles` filters enabled user roles on that host
- dotfiles wiring preserves prod/dev semantics
- secrets wiring uses sops-nix and should stay schema-driven

If you change the engine contract, update the template and docs together.

## Where To Read Next

- New user setup: [`template/README.md`](./template/README.md)
- Framework/operator boundaries: [`AGENTS.md`](./AGENTS.md)
- Template guidance for AI tools: [`template/AGENTS.md`](./template/AGENTS.md)

## For Snowman Maintainers

Edit this repo only when the change is generic across Snowman users.

Typical base-repo work:

- improving the template
- adding or refining framework modules
- tightening assertions and contracts
- fixing generic onboarding or UX issues

When testing engine changes locally, point your body repo at a local path input first, then switch it back to the GitHub source when done.
