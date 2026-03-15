# ⚔️ VGT Auto-Punisher — Kernel-Level Behavioral IDS

[![License](https://img.shields.io/badge/License-AGPLv3-green?style=for-the-badge)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux-FCC624?style=for-the-badge&logo=linux)](https://kernel.org)
[![Version](https://img.shields.io/badge/Version-4.1.3_BETA-orange?style=for-the-badge)](#)
[![Engine](https://img.shields.io/badge/Engine-nftables-red?style=for-the-badge)](#)
[![IPv6](https://img.shields.io/badge/IPv6-SUPPORTED-blue?style=for-the-badge)](#)
[![DPI](https://img.shields.io/badge/DPI-ENABLED-purple?style=for-the-badge)](#)
[![Status](https://img.shields.io/badge/Status-DIAMANT-purple?style=for-the-badge)](#)
[![VGT](https://img.shields.io/badge/VGT-VisionGaia_Technology-red?style=for-the-badge)](https://visiongaiatechnology.de)
[![Donate](https://img.shields.io/badge/Donate-PayPal-00457C?style=for-the-badge&logo=paypal)](https://www.paypal.com/paypalme/dergoldenelotus)

> *"Don't rate-limit attackers. Terminate them."*
> *AGPLv3 — For Humans, not for SaaS Corporations.*

---

## 🚧 V4 BETA — Active Development

> **V4.1.3 is a BETA release.** The core engine is stable and production-tested. Additional features, hardening layers, and documentation are actively being developed. Expect updates over the coming days.
>
> V3.x remains available in the repository for those who prefer the stable iptables-based variant.

**Planned for upcoming releases:**
- Global Threat Feed integration (Feodo, Spamhaus, Emerging Threats)
- Extended whitelist management via CLI
- `--status` flag for quick health check
- Automated test suite

---

## 🔴 CRITICAL — READ BEFORE RUNNING `--setup`

> ### ⚠️ YOU WILL LOSE SERVER ACCESS IF YOU SKIP THIS ⚠️

`--setup` flushes the VGT table and rebuilds the entire ruleset. **All existing rules in the `vgt_punisher` table are replaced.** If you have not configured your ports correctly, you may lose SSH access.

### ✅ V4.1.3 Has a Built-In Safety Net

V4.1.3 solves this with **Passive Port Discovery**. On `--setup`, the script automatically scans your server for open ports and asks you to confirm which ones to protect:

```
==========================================================
   VGT APEX PASSIVE DISCOVERY (DPI ENABLED)
==========================================================
[VGT] Scanne aktive System-Ports...
[INFO] Aktuell offene Ports auf diesem Server: 22 80 443 3306

[?] Welche Ports soll der Punisher BEWACHEN?
(Standard: 22, 80, 443)
Monitor-Ports (kommagetrennt):
```

Press **Enter** for the default (22, 80, 443) or enter your custom list. Selected ports are always accessible — even during active attacks.

The ruleset also permanently includes:
```nftables
ct state established,related accept  # Active connections never dropped
ip saddr { 127.0.0.1, 0.0.0.0/8 } accept  # Localhost always allowed
```

---

### 📋 Common Port Reference

| Port | Service | Include? |
|---|---|---|
| `22` | SSH | ✅ Always |
| `80` | HTTP | ✅ Webserver |
| `443` | HTTPS | ✅ Webserver |
| `2222` | Custom SSH | ⚠️ If you moved SSH |
| `8080` | HTTP Alt / Admin | ⚠️ If you use it |
| `8443` | HTTPS Alt | ⚠️ If you use it |
| `3306` | MySQL / MariaDB | ⚠️ Only if remote access needed |
| `5432` | PostgreSQL | ⚠️ Only if remote access needed |
| `25` | SMTP | ⚠️ Mail server only |
| `587` | SMTP Submission | ⚠️ Mail server only |
| `993` | IMAPS | ⚠️ Mail server only |
| `21` | FTP | ⚠️ Legacy — prefer SFTP |

> **Rule of thumb:** Only open ports you actively use. Every open port is an attack surface.

---

### 🆘 Already Locked Out?

Use your hosting provider's **emergency web console** (Strato KVM, Hetzner Console, netcup KVM, etc.) and run:

```bash
# Option A — Flush only the VGT table
nft flush table inet vgt_punisher

# Option B — Delete state file and reboot
rm /etc/vgt_punisher.nft && reboot
```

---

## 🆕 What's New in V4.1.3

| Feature | V3.x | V4.1.3 |
|---|---|---|
| **Engine** | iptables + ipset | nftables (native kernel) |
| **Table flush** | `flush ruleset` (ALL rules) | `flush table inet vgt_punisher` (VGT only) |
| **Port Setup** | Manual whitelist edit | Passive Discovery + interactive prompt |
| **DPI** | None | MSS anomaly, invalid state, XMAS/NULL scan detection |
| **IPv6** | Optional | Full Dual-Stack (IP + /64 subnet bans) |
| **Logging** | Coupled to drops | Rate-decoupled (1/sec max — kernel-safe) |
| **Persistence** | iptables-save | Systemd oneshot + nft statefile (chmod 0600) |
| **TCP Hardening** | Basic | BBR congestion control, syncookies, rp_filter |
| **TUI** | Basic ANSI | Alternate screen buffer, zero flicker, /dev/shm |
| **Memory Safety** | AWK array reset | nftables set size limits (OOM-safe) |

---

## 🏛️ Architecture

V4.1.3 operates on two kernel hooks:

```
Packet arrives
    ↓
PREROUTING (priority -150) — filter_ingress chain
    → DPI: invalid state, XMAS scan, MSS anomaly → drop
    → denylist_range check → counter drop   ← subnet bans
    → denylist check → counter drop         ← IP bans
    ↓
INPUT (priority 0) — detector chain
    → Whitelist bypass → accept
    → Rate heuristic on monitored ports
    → Threshold exceeded → update denylist → log_drop chain
    ↓
log_drop chain
    → Drop at line-rate (O(1))
    → Log max 1x/second (kernel printk safe)
```

**Key principle:** Banned IPs are dropped at PREROUTING — before routing, before conntrack, before userspace. Zero overhead for banned traffic.

---

## 🛡️ Deep Packet Inspection

Every packet passes through DPI at PREROUTING before reaching the behavioral detector:

```nftables
ct state invalid counter drop                              # Invalid connection state
tcp flags & (syn|fin) == (syn|fin) counter drop           # Malformed SYN+FIN
tcp flags syn tcp option maxseg size < 536 counter drop   # MSS anomaly / fingerprinting
```

This eliminates NULL scans, XMAS scans, and MSS-based OS fingerprinting attacks with zero behavioral analysis required.

---

## ⚙️ Kernel TCP Hardening

Applied automatically during `--setup`:

```bash
net.ipv4.tcp_syncookies = 1          # SYN flood protection
net.ipv4.tcp_max_syn_backlog = 65536  # Large SYN queue
net.core.netdev_max_backlog = 65536   # NIC receive buffer
net.ipv4.tcp_congestion_control = bbr # Google BBR (throughput + resilience)
net.core.default_qdisc = fq           # Fair queuing
```

---

## 🖥️ TUI Matrix Dashboard

```
████████████████████████████████████████████████████████████████████████████████
   VGT AUTO-PUNISHER V4.1.3 - APEX PARADIGM (DPI RESTORED)
████████████████████████████████████████████████████████████████████████████████

⯈ KERNEL DROP METRICS (PACKETS ANNIHILATED)
  IPv4 DROPS (SINGLE IP):    48,291
  IPv4 DROPS (SUBNET):       12,847
  IPv6 DROPS (SINGLE IP):    3,104

──────────────────────────────────────────────────────────────────────────────
⯈ RECENT KERNEL STRIKES (RATE-LIMITED)
  [VGT-STRIKE] [PUNISH] IN=eth0 SRC=185.220.101.47 ...
  [VGT-STRIKE] [PUNISH] IN=eth0 SRC=3.134.100.0 ...
```

- **Alternate screen buffer** — clean exit, no terminal pollution
- **Zero flicker** — cursor positioned at home, lines cleared individually
- **`/dev/shm` buffers** — RAM-based temp files, no disk I/O
- **Rate-limited event stream** — dmesg direct read, immune to log floods
- **Background stats worker** — nft counters polled every 2 seconds

---

## 🚀 Installation

### Requirements

| Requirement | Minimum | Notes |
|---|---|---|
| Linux Kernel | 5.2+ | nftables dynamic sets with timeout |
| nftables | Any recent | `apt install nftables` |
| iproute2 | Any | `ss` command for port discovery |
| systemd | Any | For boot persistence |

### Setup

```bash
# Clone
git clone https://github.com/visiongaiatechnology/vgt-auto-punisher.git
cd vgt-auto-punisher

# Make executable
chmod +x auto-punisher.sh

# One-time setup — interactive, safe
sudo ./auto-punisher.sh --setup

# Start TUI dashboard
sudo ./auto-punisher.sh --ui
```

### What `--setup` Does — Step by Step

```
1. Scans open ports via ss -tlnp
2. Asks which ports to always allow
3. Applies kernel TCP hardening (sysctl)
4. Builds nftables ruleset atomically
5. Persists to /etc/vgt_punisher.nft (chmod 0600)
6. Installs sandboxed systemd service (boot persistence)
7. Enables service — bans survive reboots
```

---

## 🔍 Managing the Ruleset

```bash
# View full ruleset with counters
sudo nft -a list table inet vgt_punisher

# View banned IPs
sudo nft list set inet vgt_punisher denylist_v4
sudo nft list set inet vgt_punisher denylist_v6

# View banned subnets
sudo nft list set inet vgt_punisher denylist_range_v4

# Remove a specific ban
sudo nft delete element inet vgt_punisher denylist_v4 { 1.2.3.4 }

# Flush all bans (keeps ruleset active)
sudo nft flush set inet vgt_punisher denylist_v4
sudo nft flush set inet vgt_punisher denylist_range_v4

# Re-run setup (updates ruleset, keeps bans)
sudo ./auto-punisher.sh --setup
```

---

## 📦 System Specs

```
ENGINE            nftables (kernel-space, zero userspace overhead)
HOOK_1            PREROUTING priority -150 (DPI + denylist drops)
HOOK_2            INPUT priority 0 (behavioral rate detection)
DETECTION         Port-scoped rate heuristics, fully in-kernel
LOGGING           Rate-decoupled (max 1 log/second, drops at line-rate)
BAN_MECHANISM     nftables dynamic sets (timeout-based, size-limited)
BAN_TIMEOUT       24h (configurable)
PERSISTENCE       Systemd oneshot + /etc/vgt_punisher.nft (chmod 0600)
TCP_HARDENING     BBR, syncookies, netdev backlog tuning
DPI               invalid state, XMAS/NULL scans, MSS anomaly
IPv4_RANGES       /24 bitwise masking (255.255.255.0)
IPv6_RANGES       /64 bitwise masking (ffff:ffff:ffff:ffff::)
OVERHEAD          ~0% CPU after setup (pure kernel evaluation)
STATUS            BETA — actively developed
```

---

## 🔗 VGT Linux Defense Ecosystem

| Tool | Type | Purpose |
|---|---|---|
| ⚔️ **VGT Auto-Punisher** | **Reactive** | Bans attackers the moment they hit |
| 🌐 **[VGT Global Threat Sync](https://github.com/visiongaiatechnology/vgt-global-threat-sync)** | **Preventive** | Daily feed sync — blocks known threats before arrival |
| 🔥 **[VGT Windows Firewall Burner](https://github.com/visiongaiatechnology/vgt-windows-burner)** | **Windows** | 280,000+ APT IPs in native Windows Firewall |
| 🔍 **[VGT Civilian Checker](https://github.com/visiongaiatechnology/Winsyssec)** | **Audit** | Windows security posture assessment |

> **Recommended stack:** Run Global Threat Sync daily via cron for preventive coverage, Auto-Punisher as a persistent service for reactive coverage.

---

## ⚠️ Known Limitations (BETA)

- **Kernel 5.2+ required** — nftables dynamic sets with timeout need a modern kernel. Check with `uname -r`.
- **nftables replaces iptables** — V4 uses its own isolated table `inet vgt_punisher`. Conflicts with other nftables rulesets are possible. Test in a staging environment first.
- **IPv6 /64 range bans** — ISPs sometimes assign /64 dynamically. Monitor for false positives.
- **BBR requires kernel 4.9+** — setup continues gracefully if unavailable.
- **No `--uninstall` yet** — to remove, run `nft delete table inet vgt_punisher` and `systemctl disable vgt-punisher`.

---

## 🤝 Contributing

Pull requests are welcome. For major changes, please open an issue first.

Licensed under **AGPLv3** — *"For Humans, not for SaaS Corporations."*

---

## ☕ Support the Project

VGT Auto-Punisher is free. If it keeps your server clean:

[![Donate via PayPal](https://img.shields.io/badge/Donate-PayPal-00457C?style=for-the-badge&logo=paypal)](https://www.paypal.com/paypalme/dergoldenelotus)

---

## 🏢 Built by VisionGaia Technology

[![VGT](https://img.shields.io/badge/VGT-VisionGaia_Technology-red?style=for-the-badge)](https://visiongaiatechnology.de)

VisionGaia Technology builds enterprise-grade security and AI tooling — engineered to the DIAMANT VGT SUPREME standard.

> *"Tino wanted to throw the script away. V4.1.3 is what happened instead."* 😄

---

*Version 4.1.3 BETA (APEX PARADIGM) — VGT Auto-Punisher // Kernel-Level Behavioral IDS*
*Active development — more features coming soon.*
