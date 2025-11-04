# Snowman Security Overview

This document summarizes the baseline security posture of the **Snowman** NixOS configuration.

---

## 1. SSH & Remote Access

* **Key-only authentication** — password logins are disabled.
* **Root login prohibited.**
* **Allowed users** restricted to declared Nix users.
* **Ed25519-only keys** (fast, modern, strong).
* **Modern crypto**:
  * Kex: `curve25519-sha256`, `curve25519-sha256@libssh.org`
  * MACs: `hmac-sha2-512`, `hmac-sha2-256`
* **Connection limits**
  * 3 auth attempts, 30-second login grace period.
  * Optional keepalive: sends a heartbeat every 300 s, disconnects after 2 missed pings.
* **Firewall** allows only port 22 (nftables).
* **Fail2Ban** automatically bans repeated failed logins for one hour.

---

## 2. Kernel & Network Hardening

`modules/security/hardening-kernel.nix` sets secure sysctls:

| Category | Key Examples | Purpose |
|-----------|---------------|----------|
| Kernel info leak prevention | `kernel.kptr_restrict=2`, `kernel.dmesg_restrict=1` | Hide kernel addresses & logs from unprivileged users |
| Sandbox safety | `kernel.unprivileged_userns_clone=0`, `kernel.unprivileged_bpf_disabled=1` | Block risky user namespaces & eBPF |
| Process isolation | `kernel.yama.ptrace_scope=1` | Disallow arbitrary process tracing |
| Anti-spoofing | `net.ipv4.conf.*.rp_filter=1` | Drop packets with forged source IPs |
| Redirect defense | `accept_redirects=0`, `send_redirects=0` | Ignore malicious ICMP redirects |

---

## 3. Mandatory Access Control & Auditing

* **AppArmor enabled** — confines system services with least privilege.
* **Auditd enabled** — logs privileged syscalls and security events.

---

## 4. User & Secret Management

* **Immutable user database** — `users.mutableUsers = false`.
* **Passwords stored via `age` encryption**, never in plaintext in the Nix store.
* **Per-user SSH keys** defined in repo; extra keys imported from files.
* **Home-Manager** profiles for deterministic user environments.

---

## 5. System Hygiene

* Weekly garbage-collection and store optimisation.
* Journald capped at 200 MB (system) / 100 MB (runtime).
* `/tmp` cleaned on boot.
* Boot-time services only; no unnecessary daemons.

---

## 6. Bootstrap Mode

`bootstrap.enable = true` temporarily relaxes user immutability for first login.
Once disabled (default), the system is fully declarative again.

---

### Maintenance Notes

* Use `agenix` to manage all secrets.
* Update flake inputs regularly to pull kernel & OpenSSH security patches.
* Review `sshd_config` output with `sshd -T` after updates.

---

**Snowman’s security design goal:**  
> “Stay secure by default, while remaining reproducible, auditable, and easy to extend.”
```
