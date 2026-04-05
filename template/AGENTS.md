# AGENTS.md

## Purpose

This repository is a **Snowman body repo**.

It was created from the Snowman template and is meant to be the user's **actual personal configuration repo**.

This is where the user customizes:
- hosts
- users
- roles
- secrets wiring
- local modules
- app and service layout
- Home Manager overrides

If you are helping the user, this is usually the **correct repo to edit**.

---

## The Three-Repo Model

A Snowman setup is usually split across three repositories:

### 1. Snowman base
The framework/engine repo.

Contains:
- reusable framework modules
- template files
- framework assertions and contracts

Users normally **do not edit** Snowman base directly unless they are intentionally changing the framework itself.

---

### 2. Body repo (this repo)
The user's real system configuration.

Contains:
- `inventory.nix`
- host definitions
- user definitions
- host-local modules
- Home Manager roles and overrides
- secret references
- flake wiring for the user's systems

If a change is about:
- “my machine”
- “my users”
- “my services”
- “my setup”
- “my roles”
- “my inventory”

then it probably belongs here.

---

### 3. Dotfiles repo
A separate repo for mutable config content.

Contains things like:
- shell config
- editor config
- terminal config
- launcher config
- browser config
- UI/theme config

If a change is about files that ultimately live in `$HOME`, it may belong in the dotfiles repo instead of this one.

---

## First Rule for Agents

Before changing anything, decide:

> Does this belong in **base**, **body**, or **dotfiles**?

Then:
- say which repo owns the change
- make the change in that repo

When unsure:
- default to **this body repo**
- unless the task is clearly about dotfile contents
- or clearly about framework internals

---

## What This Repo Usually Owns

This repo usually contains:

- `flake.nix`
- `flake.lock`
- `inventory.nix`
- `.sops.yaml`
- `hosts/`
- `modules/`
- `home/`
- `users/`
- `networks/`
- `assets/`

Exact contents may vary by user, but the body repo is always the place for personal system wiring.

---

## Core Mental Model

### Snowman base defines the framework
### This repo defines the user's actual systems
### The dotfiles repo defines mutable config content

Do not move responsibilities across those boundaries casually.

---

## Inventory Is the Source of Truth

`inventory.nix` is the central source of truth for this repo.

It typically defines:
- hosts
- users
- roles
- optional networks
- optional secrets wiring
- optional host capabilities

Prefer changing `inventory.nix` first instead of scattering parallel definitions elsewhere.

Examples of things that should usually originate in inventory:
- which users exist
- which hosts exist
- which roles a user has
- which hosts allow which roles
- whether a user is home-managed
- which secrets files are used

---

## Common Ownership Rules

### Belongs in this body repo

- adding or changing hosts
- adding or changing users
- enabling roles for a user
- restricting roles with `availableRoles`
- adding local NixOS modules
- wiring nginx / VPN / media / AI / desktop services
- setting flake inputs for personal repos
- choosing pinned vs mutable dotfiles sources
- adding Home Manager overrides specific to this user

---

### Belongs in the dotfiles repo

- Neovim config
- zsh/bash/fish config
- tmux config
- terminal emulator config
- Hyprland/Waybar/Wofi/SwayNC config content
- browser profiles/config files
- wallpapers
- theme CSS
- tool config files that live in `$HOME`

---

### Belongs in Snowman base

Only if the task is truly generic across all Snowman users:
- reusable framework features
- new inventory contracts
- template improvements for everyone
- engine assertions
- reusable generic modules

Do not put personal machine behavior into Snowman base.

---

## Dotfiles Model

This body repo usually wires dotfiles, but does not own their content.

### Prod mode
- links point to pinned/store-backed dotfiles
- reproducible
- stable

### Dev mode
- links point to a local mutable checkout
- intended for fast iteration

### Git fallback
- if pinned dotfiles are not configured, some setups may clone/update the repo during activation

### Important principle

Switching mode changes:

> where symlinks point

It does **not** fundamentally change:
- the host structure
- the user structure
- the role structure
- the repo boundaries

---

## Secrets

This repo usually references secrets through:
- `.sops.yaml`
- `users/secrets/...`
- `hosts/secrets/...`
- `networks/secrets.yml`

Never commit plaintext secrets.

When editing secret-related logic:
- preserve the declared schema
- keep recipients correct
- update both config and secret files together when needed

---

## Home Manager vs NixOS

This body repo usually contains both:

### NixOS-side config
Typical locations:
- `hosts/`
- `modules/`

Used for:
- system services
- boot
- hardware
- firewall
- users
- system packages
- networking

### Home Manager config
Typical locations:
- `home/roles/`
- `home/overrides/`
- `users/env/`

Used for:
- user packages
- desktop/session config
- user services
- symlinked config
- role-based user setup

When making changes, decide whether they belong at:
- system level
- user level
- or in dotfiles content

---

## Typical Tasks

### Add a host
Usually this repo.

- add a host in `inventory.nix`
- add host-specific module(s) if needed
- import hardware configuration
- wire host-specific services here

---

### Add a user
Usually this repo.

- add the user in `inventory.nix`
- add login method
- add groups/shell/secrets references
- set `homeManaged = true` if needed

---

### Add a role
Usually this repo first.

- add it under `home/roles/`
- enable it in `inventory.nix`
- restrict with `availableRoles` if necessary

Only move a role to Snowman base if it is genuinely generic.

---

### Add a system module
Usually this repo.

- place it in `modules/`
- import or attach it from host config / inventory-driven wiring

---

### Add a Home Manager override
Usually this repo.

- place it in `home/overrides/`
- keep it user-specific unless clearly reusable

---

### Change shell/editor/UI behavior
Usually the dotfiles repo.

Do not reimplement dotfile content in Nix if the repo already treats that content as dotfiles.

---

## AI Behavior Rules

When helping in this repo:

### Always
- preserve the inventory-driven structure
- keep host-specific logic out of generic modules where possible
- keep modules composable
- keep repo ownership clear
- explain whether the change belongs in body, dotfiles, or base

### Never
- suggest editing Snowman base for a purely personal change
- hardcode personal paths into generic/template code unless this repo explicitly owns them
- move mutable config content into this repo unless the user wants that
- remove assertions casually
- bypass inventory structure without a strong reason

### When unsure
- prefer body repo changes
- ask whether the config content itself lives in dotfiles

---

## Editing Guidance

When making changes in this repo:

- keep framework-level behavior in Snowman base
- keep personal system behavior here
- keep mutable config content in dotfiles
- update related files together
- prefer small, composable modules
- prefer explicit wiring over hidden magic

---

## Summary

This repo is the user's real Snowman configuration.

Use this repo for:
- personal hosts
- personal users
- personal roles
- personal services
- personal wiring

If you remember one rule:

> **This repo is where the user's real setup lives.**
