# ⚔️ VGT Auto-Punisher — Kernel-Level Behavioral IDS

[![License](https://img.shields.io/badge/License-AGPLv3-green?style=for-the-badge)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux-FCC624?style=for-the-badge&logo=linux)](https://kernel.org)
[![Version](https://img.shields.io/badge/Version-4.5.0-brightgreen?style=for-the-badge)](#)
[![Architecture](https://img.shields.io/badge/Architecture-Hybrid_Supreme-red?style=for-the-badge)](#)
[![IPv6](https://img.shields.io/badge/IPv6-SUPPORTED-blue?style=for-the-badge)](#)
[![DPI](https://img.shields.io/badge/DPI-ENABLED-purple?style=for-the-badge)](#)
[![Status](https://img.shields.io/badge/Status-STABLE-brightgreen?style=for-the-badge)](#)
[![VGT](https://img.shields.io/badge/VGT-VisionGaia_Technology-red?style=for-the-badge)](https://visiongaiatechnology.de)
[![Donate](https://img.shields.io/badge/Donate-PayPal-00457C?style=for-the-badge&logo=paypal)](https://www.paypal.com/paypalme/dergoldenelotus)

> *"Don't rate-limit attackers. Terminate them."*
> *AGPLv3 — For Humans, not for SaaS Corporations.*

**V4.5.0 is the official stable release of VGT Auto-Punisher.** This is the version we run in production.

---

## 🔴 CRITICAL — ADD YOUR IP TO THE WHITELIST FIRST

> ### ⚠️ YOU WILL LOCK YOURSELF OUT IF YOU SKIP THIS ⚠️

Before running the script, open it and add your public IP to the whitelist:

```bash
# Step 1 — Find your public IP
curl -4 -s ifconfig.me   # Your IPv4
curl -6 -s ifconfig.me   # Your IPv6

# Step 2 — Open the script
nano auto-punisher.sh

# Step 3 — Find this line and add your IP:
readonly WHITELIST_IPS="127.0.0.1 ::1 0.0.0.0 :: fe80::/10 YOUR.IP.HERE"

# If your ISP rotates your IP within a subnet (common with home connections):
readonly WHITELIST_IPS="127.0.0.1 ::1 0.0.0.0 :: fe80::/10 YOUR.IP.0/24"

# For IPv6, whitelist the entire /64 subnet:
readonly WHITELIST_IPS="127.0.0.1 ::1 0.0.0.0 :: fe80::/10 2a02:xxxx:xxxx:xxxx::/64"
```

> **Why /24?** Many ISPs rotate your IP within a /24 subnet block. If you whitelist only a single IP and your ISP assigns you a new one, you will be locked out on the next session.

### 🆘 Already Locked Out?

Use your hosting provider's emergency console **(Strato KVM, Hetzner Console, netcup KVM, etc.)** and run:

```bash
# Option A — Flush all bans (bans expire after 24h anyway)
ipset flush VGT_BANNED_V4
ipset flush VGT_BANNED_V6

# Option B — Remove all iptables rules
iptables -F INPUT
ip6tables -F INPUT
```

> **Note:** V4.5.0 introduces the **Forgiveness Protocol** — all bans automatically expire after 24 hours. Even if you get locked out, you will regain access within 24h without any manual intervention.

---

## 🆕 V4.5.0 — Official Stable Release

**This is the official version.** All previous versions were development iterations leading to this release.

| Feature | Description |
|---|---|
| **Forgiveness Protocol** | All bans expire after 24h automatically — no permanent lockouts |
| **Dynamic Port Chunking** | iptables multiport handles max 15 ports per rule — auto-chunked |
| **Log Rate Limiting** | 50 logs/second max — protects disk/SSD from log floods |
| **Passive Log-Sensing** | Monitors only selected ports — legitimate users never affected |
| **DPI Sanitization** | XMAS, NULL, MSS anomaly, invalid state dropped at Layer 4 |
| **BBR + Kernel Hardening** | TCP stack optimized for performance and resilience |
| **Subnet Whitelist in AWK** | /24 ranges evaluated directly in the stream processor |
| **IPv6 Dual-Stack** | Full IPv4 + IPv6 monitoring and termination |
| **SSH Anti-Freeze** | Heartbeat every 45s prevents SSH timeout on long sessions |
| **TUI Matrix** | Alternate screen buffer, RGB ANSI, zero flicker |

---

## 🏛️ Architecture — Hybrid Supreme

V4.5.0 combines passive log-sensing (V3 architecture) with V4 kernel hardening and DPI:

```
Packet arrives at server
    ↓
iptables INPUT Position 1
    → ipset O(1) lookup → DROP if banned     ← Banned traffic never reaches app
    ↓
iptables INPUT Position 2-5
    → DPI: INVALID state → DROP
    → DPI: XMAS scan (FIN+PSH+URG) → DROP
    → DPI: NULL scan (no flags) → DROP
    → DPI: MSS anomaly → DROP
    ↓
iptables INPUT Position 6+
    → Passive LOG on monitored ports only    ← Rate-limited: 50/s max
    → Normal traffic passes through
    ↓
journalctl stream → AWK analysis
    → Whitelist check → skip if whitelisted
    → IP hit count → threshold → ipset add (24h timeout)
    → /24 subnet count → threshold → ipset add (24h timeout)
    ↓
After 24h → ban expires automatically (Forgiveness Protocol)
```

---

## 🛡️ Two Strike Modes

### Surgical Strike — Single IP
When a single IP exceeds `IP_THRESHOLD` (default: 15 hits), it is added to the ipset with a 24h timeout.

```
[!!!] TERMINIERT: IP 185.220.101.47 für 24h hingerichtet.
```

### Infrastructure Strike — /24 Subnet
When hits from the same /24 subnet exceed `RANGE_THRESHOLD` (default: 30 hits), the entire subnet is banned. This catches coordinated botnet attacks that rotate IPs within the same provider block.

```
[!!!] INFRA-SCHLAG: Range 177.23.200.0/24 für 24h terminiert.
```

> **Real-world example:** A coordinated botnet distributed its traffic across `177.23.200.x` through `177.23.207.x`. Auto-Punisher detected the subnet pattern and terminated 5 complete /24 ranges within 3 minutes — while the attack was still ongoing.

---

## 🖥️ TUI Matrix Dashboard

```
████████████████████████████████████████████████████████████████████████████████
   VGT AUTO-PUNISHER V4.5.0 - OPEN SOURCE MASTER (FOOLPROOF EDITION)
████████████████████████████████████████████████████████████████████████████████
ZEITSTEMPEL         | QUELL-IP                                | HITS | RANGE
------------------------------------------------------------------------------
Mar 16 03:12:44     | 185.220.101.47                          |   12 |   18
Mar 16 03:12:45     | 177.23.200.63                           |    1 |   28

[!!!] TERMINIERT: IP 185.220.101.47 für 24h hingerichtet.
[!!!] INFRA-SCHLAG: Range 177.23.200.0/24 für 24h terminiert.
```

- **RGB ANSI colors** — IPs turn red as they approach the ban threshold
- **Alternate screen buffer** — clean exit, terminal restored on CTRL+C
- **SSH Anti-Freeze Heartbeat** — saves/restores cursor every 45s
- **Live stream** — every monitored SYN packet appears in real-time

---

## 🚀 Installation

### Requirements

| Tool | Purpose |
|---|---|
| `ipset` | High-speed IP blocklist |
| `iptables` / `ip6tables` | Firewall rules |
| `journalctl` | Kernel log stream |
| `awk` | Stream analysis engine |
| `ss` | Port discovery |

```bash
# Debian / Ubuntu
apt-get install ipset iptables iproute2
```

### Setup

```bash
# 1. Clone
git clone https://github.com/visiongaiatechnology/vgt-auto-punisher.git
cd vgt-auto-punisher

# 2. Add your IP to the whitelist FIRST
# Auto Punisher 3
nano auto-punisher3.sh
# Auto Punisher 3 Titan
nano auto_punisher_titan3.sh
# Auto Punisher 4
nano auto-punisher4.sh

# Edit: readonly WHITELIST_IPS="... YOUR.IP.0/24"

# 3. Make executable
# Auto Punisher 3
chmod +x auto-punisher3.sh
# Auto Punisher 3 Titan
chmod +x auto_punisher_titan3.sh
# Auto Punisher 4
chmod +x auto-punisher4.sh

# 4. Run
# Auto Punisher 3
sudo ./auto-punisher3.sh
# Auto Punisher 3 Titan
sudo ./auto_punisher_titan3.sh
# Auto Punisher 3
sudo ./auto-punisher4.sh
```

### What happens on first run

```
1. Scans open ports via ss -tlnp
2. Asks which ports to monitor (default: all detected)
3. Applies kernel TCP hardening (BBR, syncookies, backlog)
4. Creates ipset tables with 24h timeout
5. Injects DPI rules (XMAS, NULL, MSS, INVALID)
6. Injects scoped LOG sensor (rate-limited to 50/s)
7. Starts live AWK analysis stream
```

---

## 📋 Port Reference

| Port | Service | Monitor? |
|---|---|---|
| `22` | SSH | ✅ Always |
| `80` | HTTP | ✅ Webserver |
| `443` | HTTPS | ✅ Webserver |
| `2222` | Custom SSH | ⚠️ If you moved SSH |
| `8080` | HTTP Alt | ⚠️ If you use it |
| `3306` | MySQL | ⚠️ Only if internet-facing |
| `5432` | PostgreSQL | ⚠️ Only if internet-facing |
| `25` | SMTP | ⚠️ Mail server only |
| `21` | FTP | ⚠️ Legacy — prefer SFTP |

> **Rule of thumb:** Only monitor ports that face the internet directly. Database ports should never be internet-facing.

---

## 🔍 Managing Bans

```bash
# View all active bans
ipset list VGT_BANNED_V4
ipset list VGT_BANNED_V6

# Count total bans
ipset list VGT_BANNED_V4 | grep -c "^[0-9]"

# Emergency: unban a specific IP
ipset del VGT_BANNED_V4 1.2.3.4

# Emergency: flush all bans
ipset flush VGT_BANNED_V4
ipset flush VGT_BANNED_V6

# Bans are auto-saved after each strike
# Restore after reboot:
iptables-restore < /etc/iptables/rules.v4
ip6tables-restore < /etc/iptables/rules.v6
```

---

## 📦 System Specs

```
VERSION           4.5.0 (Official Stable Release)
ARCHITECTURE      Hybrid (iptables + ipset + journalctl + AWK)
SENSOR            Passive LOG on selected ports (scoped, rate-limited)
BAN_MECHANISM     ipset hash:net with 24h timeout (Forgiveness Protocol)
BAN_DURATION      24 hours (configurable via BAN_TIME)
DPI               INVALID state, XMAS, NULL scan, MSS anomaly
PERSISTENCE       iptables-save after every ban
IPv4_RANGES       /24 subnet ban via AWK subnet analysis
IPv6              Single-IP ban (range bans disabled by design)
TCP_HARDENING     BBR, syncookies, SYN backlog, FQ qdisc
LOG_PROTECTION    Rate-limited to 50/s, burst 100
PORT_CHUNKING     Auto-chunked into groups of 14 (iptables limit)
SSH_SAFETY        Heartbeat + 24h auto-expiry + whitelist
OVERHEAD          ~0% CPU idle (event-driven, no polling)
```

---

## 🔗 VGT Linux Defense Ecosystem

| Tool | Type | Purpose |
|---|---|---|
| ⚔️ **VGT Auto-Punisher** | **Reactive** | Bans attackers the moment they hit |
| 🌐 **[VGT Global Threat Sync](https://github.com/visiongaiatechnology/vgt-global-threat-sync)** | **Preventive** | Daily feed sync — blocks known threats before arrival |
| 🔥 **[VGT Windows Firewall Burner](https://github.com/visiongaiatechnology/vgt-windows-burner)** | **Windows** | 280,000+ APT IPs in native Windows Firewall |
| 🔍 **[VGT Civilian Checker](https://github.com/visiongaiatechnology/Winsyssec)** | **Audit** | Windows security posture assessment |

> **Recommended stack:** Global Threat Sync daily (preventive) + Auto-Punisher as service (reactive) = complete coverage.

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

> *"Tino wanted to throw the script away. V4.5.0 terminated a ByteDance botnet and 5 coordinated /24 ranges instead."* 😄

---

*Version 4.5.0 (OPEN SOURCE MASTER — FOOLPROOF EDITION) — VGT Auto-Punisher // Official Stable Release*
