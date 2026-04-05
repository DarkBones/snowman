# AGENTS.md

## Purpose

Snowman is an inventory-driven NixOS framework.

This repository is the **Snowman base (engine)**.

It defines:
- the framework
- reusable modules
- the template used by new users

### 🚫 Important constraint

**End users DO NOT modify this repository.**

- Users create their own config via “Use this template”
- That creates a separate **body repo**
- All personalization happens there

This repo is only changed by:
- the Snowman author
- or via deliberate upstream contributions (PRs)

If you are helping a user:

> **Never suggest editing Snowman base. Always work in the body repo unless explicitly asked to modify the engine.**

---

## Architecture Overview

A Snowman setup consists of three repos:

### 1. Snowman base (this repo)
- framework + modules
- inventory contract
- default template
- CLI behavior

### 2. Body repo (user-owned, from template)
- hosts, users, roles
- personal configuration
- services and machine layout
- overrides and extensions

### 3. Dotfiles repo (user-owned)
- mutable app/editor/shell configs
- files linked into `$HOME`

---

## Repo Boundaries (Strict)

### Snowman base (this repo)
Only contains:
- generic framework behavior
- reusable modules
- inventory schema + assertions
- template definitions
- cross-user features

**Must NOT contain:**
- usernames
- hostnames
- personal services
- machine-specific logic
- user-specific workflows

---

### Body repo (where users work)

Contains:
- hosts and inventory
- users and login methods
- secrets wiring
- services (nginx, docker, etc.)
- personal roles
- overrides

> If a change is about “my machine” → it belongs here.

---

### Dotfiles repo

Contains:
- editor configs
- shell configs
- UI/app configs

> If a change is about files in `$HOME` → it belongs here.

---

## 🔴 First Rule for Agents

Before making changes, decide:

> **Does this belong in base, body, or dotfiles?**

Then:
- explain your choice
- proceed in the correct repo

If unsure:
- default to **body repo**

---

## Framework Contract (Do Not Break)

These behaviors are defined by the engine and must be preserved:

- The base exports:
  - `nixosModules.default`
  - `homeModules.default`
  - a flake template

- The body repo:
  - imports Snowman base
  - defines `inventory.nix` as the source of truth

- `inventory.nix` defines:
  - hosts
  - users
  - roles
  - optional networking + secrets

- Every host must:
  - exist in `inv.hosts`
  - define a hostname
  - define at least one user

- Every user must have **one login method**:
  - SSH key
  - `initialPassword`
  - or SOPS password

- Home Manager only applies if:
  - `homeManaged = true`

- Role filtering:
  - `hosts.<host>.availableRoles` restricts user roles

- Secrets:
  - managed via `sops-nix`
  - must follow declared schema

---

## New User Setup Flow

When guiding a new user:

1. Create repo from template
2. Edit `inventory.nix`
   - replace usernames
   - replace hostnames
   - remove placeholder passwords
3. Define first host
4. Define first user
5. Add login method (SSH or password)
6. Enable Home Manager if desired
7. Choose dotfiles strategy
8. Configure secrets (`.sops.yaml`)
9. Install NixOS
10. Import hardware config
11. Rebuild system

Before first real install, verify:
- no placeholder values remain
- dotfiles source is valid
- secrets are configured
- hardware config exists

---

## Dotfiles Model

Snowman separates:

- **content** → dotfiles repo
- **wiring** → Snowman modules

### Modes

Controlled by `SNOWMAN_DOTFILES_MODE`:

#### Prod mode (default)
- links to pinned/store-backed dotfiles
- reproducible
- stable

#### Dev mode
- links to local mutable checkout (e.g. `~/Developer/dotfiles`)
- fast iteration

#### Git fallback
- repo cloned during activation
- used if no pinned source exists

### Key Principle

Switching modes changes:
> **where symlinks point**

It does NOT change:
- role structure
- module structure
- system design

---

## AI Behavior Rules

When modifying Snowman-based systems:

### Always:
- preserve inventory-driven design
- keep modules composable
- respect repo boundaries
- explain where changes belong

### Never:
- move personal config into base
- remove assertions without replacement
- hardcode user-specific paths in base
- break dev/prod dotfiles semantics

### When uncertain:
- default to body repo
- ask for clarification

---

## Common Tasks

### Add a host
→ body repo

- update `inventory.nix`
- add host module if needed
- import hardware config

---

### Add a user
→ body repo

- define in `inventory.nix`
- set login method
- enable roles

---

### Add a role
→ body repo first

- place in `home/roles/`
- enable per user
- only move to base if generic

---

### Add a service
→ body repo

- define module
- attach to host

---

### Dotfiles setup
→ body repo

- configure `roles.dotfiles`
- map `linkMap`
- optionally pin via flake input

---

### Secrets
→ body repo

- configure `.sops.yaml`
- define secrets in inventory
- ensure keys exist

---

## Template Warning

Template values are examples.

Replace:
- usernames
- hostnames
- passwords
- repo URLs
- dotfiles paths

Do not keep:
- `changeme`
- example repos
- placeholder configs

---

## Editing This Repo (Snowman Base)

Only modify this repo if:

- you are extending the framework itself
- you are fixing a generic issue
- you are improving the template for all users

When doing so:

- keep everything generic
- update template if behavior changes
- maintain strict separation from user config
- document changes clearly

---

## Summary

Snowman enforces:

- **engine (base)** → immutable framework
- **body repo** → user customization
- **dotfiles repo** → mutable config

If you remember one rule:

> **Users do not edit Snowman base.**
