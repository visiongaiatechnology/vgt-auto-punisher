# ⚔️ VGT Auto-Punisher — Kernel-Level Behavioral IDS

[![License](https://img.shields.io/badge/License-AGPLv3-green?style=for-the-badge)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux-FCC624?style=for-the-badge&logo=linux)](https://kernel.org)
[![Version](https://img.shields.io/badge/Version-4.4.0-brightgreen?style=for-the-badge)](#)
[![Architecture](https://img.shields.io/badge/Architecture-Hybrid_Supreme-red?style=for-the-badge)](#)
[![IPv6](https://img.shields.io/badge/IPv6-SUPPORTED-blue?style=for-the-badge)](#)
[![DPI](https://img.shields.io/badge/DPI-ENABLED-purple?style=for-the-badge)](#)
[![Status](https://img.shields.io/badge/Status-DIAMANT-purple?style=for-the-badge)](#)
[![VGT](https://img.shields.io/badge/VGT-VisionGaia_Technology-red?style=for-the-badge)](https://visiongaiatechnology.de)
[![Donate](https://img.shields.io/badge/Donate-PayPal-00457C?style=for-the-badge&logo=paypal)](https://www.paypal.com/paypalme/dergoldenelotus)

> *"Don't rate-limit attackers. Terminate them."*
> *AGPLv3 — For Humans, not for SaaS Corporations.*

---

## 🔴 CRITICAL — ADD YOUR IP TO THE WHITELIST FIRST

> ### ⚠️ YOU WILL LOCK YOURSELF OUT IF YOU SKIP THIS ⚠️

Before running the script, open it and add your public IP to the whitelist:

```bash
# Find your public IP
curl -4 -s ifconfig.me   # Your IPv4
curl -6 -s ifconfig.me   # Your IPv6

# Open the script
nano auto-punisher.sh

# Find this line and add your IP:
readonly WHITELIST_IPS="127.0.0.1 ::1 0.0.0.0 :: fe80::/10 YOUR.IP.HERE"

# If your ISP rotates your IP (common with home connections), whitelist the entire /24:
readonly WHITELIST_IPS="127.0.0.1 ::1 0.0.0.0 :: fe80::/10 YOUR.IP.0/24"

# For IPv6, whitelist the entire /64 subnet:
readonly WHITELIST_IPS="127.0.0.1 ::1 0.0.0.0 :: fe80::/10 2a02:xxxx:xxxx:xxxx::/64"
```

> **Why /24 for home users?** Many ISPs rotate your IP within a subnet block. If you whitelist a single IP and your ISP assigns you a new one, you will be locked out on the next session.

### 🆘 Already Locked Out?

Use your hosting provider's emergency console and run:

```bash
# Flush all bans immediately
ipset flush VGT_BANNED_V4
ipset flush VGT_BANNED_V6

# Or remove all iptables rules
iptables -F INPUT
ip6tables -F INPUT
```

---

## 🏛️ Architecture — Hybrid Supreme

V4.4.0 combines the best of all previous versions into one stable, production-ready engine:

```
V3 Architecture  →  Passive Log-Sensing (journalctl → AWK → ipset)
V4 Technology    →  Port Discovery + DPI + Kernel Hardening + TUI
```

```
Packet arrives
    ↓
iptables INPUT (Position 1)
    → ipset check → DROP if banned        ← O(1) speed
    ↓
iptables INPUT (Position 2)
    → DPI: INVALID state → DROP
    → DPI: XMAS scan → DROP
    → DPI: NULL scan → DROP
    → DPI: MSS anomaly → DROP
    ↓
iptables INPUT (Position 6)
    → Scoped LOG on monitored ports       ← Passive sensor
    ↓
journalctl stream → AWK analysis
    → IP hit count → threshold → ipset ban
    → /24 subnet count → threshold → ipset ban
```

**Key advantage:** The LOG sensor only fires on your selected ports — legitimate web traffic on other ports is never counted. Normal users never hit the threshold.

---

## 🆕 What's New in V4.4.0

| Feature | V3.x | V4.4.0 |
|---|---|---|
| **Architecture** | iptables + ipset + AWK | Hybrid: same + DPI + BBR |
| **Port Discovery** | None | `ss -tlnp` scans open ports |
| **DPI** | None | XMAS, NULL, MSS, INVALID state |
| **Kernel Hardening** | Basic | BBR, syncookies, backlog tuning |
| **Sensor Scope** | All TCP SYN | Only on selected ports |
| **TUI** | Basic ANSI | Alternate screen, RGB ANSI, zero flicker |
| **SSH Heartbeat** | ✅ | ✅ (prevents timeout on long sessions) |
| **IPv6** | ✅ | ✅ Dual-Stack |
| **Whitelist** | Top of script | Top of script + /24 subnet support |

---

## 🛡️ Deep Packet Inspection

V4.4.0 adds iptables-level DPI rules that drop malformed packets before the behavioral analysis even starts:

```bash
# Invalid connection state
iptables -I INPUT 2 -m state --state INVALID -j DROP

# XMAS scan (FIN+PSH+URG flags)
iptables -I INPUT 3 -p tcp --tcp-flags ALL FIN,PSH,URG -j DROP

# NULL scan (no flags)
iptables -I INPUT 4 -p tcp --tcp-flags ALL NONE -j DROP

# MSS anomaly (fingerprinting / malformed SYN)
iptables -I INPUT 5 -p tcp --tcp-flags SYN,RST SYN -m tcpmss ! --mss 536:65535 -j DROP
```

---

## ⚙️ Kernel TCP Hardening

Applied automatically on first run:

```bash
net.ipv4.tcp_syncookies = 1          # SYN flood protection
net.ipv4.tcp_max_syn_backlog = 65536  # Large SYN queue
net.core.netdev_max_backlog = 65536   # NIC receive buffer
net.ipv4.tcp_congestion_control = bbr # Google BBR
net.core.default_qdisc = fq           # Fair queuing
```

---

## 🖥️ TUI Matrix Dashboard

```
████████████████████████████████████████████████████████████████████████████████
   VGT AUTO-PUNISHER V4.4.0 - HYBRID SUPREME (PASSIVE RADAR + DPI)
████████████████████████████████████████████████████████████████████████████████
ZEITSTEMPEL         | QUELL-IP                                | HITS | RANGE
------------------------------------------------------------------------------
Mar 16 03:12:44     | 185.220.101.47                          |   12 |   18
Mar 16 03:12:44     | 185.220.101.52                          |    3 |   21

[!!!] TERMINIERT: IP 185.220.101.47 hingerichtet.
[!!!] INFRA-SCHLAG: Range 185.220.101.0/24 terminiert.
```

- **RGB ANSI colors** — IPs turn red as they approach the ban threshold
- **Alternate screen buffer** — clean exit, no terminal pollution
- **SSH Anti-Freeze Heartbeat** — prevents SSH timeout during long sessions
- **Live stream** — every SYN packet on monitored ports appears in real-time

---

## 🚀 Installation

### Requirements

- Linux (Debian / Ubuntu / CentOS)
- `ipset`, `iptables`, `ip6tables`, `journalctl`, `awk`
- Root access

### Setup

```bash
# Clone
git clone https://github.com/visiongaiatechnology/vgt-auto-punisher.git
cd vgt-auto-punisher

# 1. Add your IP to the whitelist first!
nano auto-punisher.sh
# Edit: readonly WHITELIST_IPS="... YOUR.IP.HERE"

# 2. Make executable
chmod +x auto-punisher.sh

# 3. Run
sudo ./auto-punisher.sh
```

On first run, the script:
1. Scans open ports via `ss -tlnp`
2. Asks which ports to monitor
3. Applies kernel TCP hardening
4. Sets up ipset tables
5. Injects DPI rules into iptables
6. Starts the live AWK analysis stream

---

## 📋 Common Port Reference

| Port | Service | Monitor? |
|---|---|---|
| `22` | SSH | ✅ Always |
| `80` | HTTP | ✅ Webserver |
| `443` | HTTPS | ✅ Webserver |
| `2222` | Custom SSH | ⚠️ If you moved SSH |
| `8080` | HTTP Alt | ⚠️ If you use it |
| `3306` | MySQL | ⚠️ Only if remote access needed |
| `5432` | PostgreSQL | ⚠️ Only if remote access needed |
| `25` | SMTP | ⚠️ Mail server only |
| `21` | FTP | ⚠️ Legacy — prefer SFTP |

> **Rule of thumb:** Only monitor ports that face the internet. Database ports should never be internet-facing.

---

## 🔍 Managing the Blocklist

```bash
# View all banned IPv4 IPs
ipset list VGT_BANNED_V4

# View all banned IPv6 IPs
ipset list VGT_BANNED_V6

# Count total bans
ipset list VGT_BANNED_V4 | grep -c "^[0-9]"

# Emergency: unban a specific IP
ipset del VGT_BANNED_V4 1.2.3.4

# Emergency: flush all bans
ipset flush VGT_BANNED_V4
ipset flush VGT_BANNED_V6

# Bans survive reboot (iptables-save is called automatically)
# To restore after reboot:
iptables-restore < /etc/iptables/rules.v4
ip6tables-restore < /etc/iptables/rules.v6
```

---

## 📦 System Specs

```
ARCHITECTURE      Hybrid (iptables + ipset + journalctl + AWK)
SENSOR            Passive LOG on selected ports (scoped, non-invasive)
BAN_MECHANISM     ipset hash:net (O(1) lookup, up to 1,000,000 entries)
DPI               INVALID state, XMAS scan, NULL scan, MSS anomaly
PERSISTENCE       iptables-save → /etc/iptables/rules.v4
IPv4_RANGES       /24 subnet ban via AWK analysis
IPv6              Single-IP ban (range bans disabled by design)
TCP_HARDENING     BBR, syncookies, SYN backlog tuning
SSH_SAFETY        Heartbeat + Whitelist + scoped port monitoring
OVERHEAD          ~0% CPU idle (event-driven, no polling)
```

---

## 🔗 VGT Linux Defense Ecosystem

| Tool | Type | Purpose |
|---|---|---|
| ⚔️ **VGT Auto-Punisher** | **Reactive** | Bans attackers in real-time |
| 🌐 **[VGT Global Threat Sync](https://github.com/visiongaiatechnology/vgt-global-threat-sync)** | **Preventive** | Daily feed sync — blocks known threats |
| 🔥 **[VGT Windows Firewall Burner](https://github.com/visiongaiatechnology/vgt-windows-burner)** | **Windows** | 280,000+ APT IPs in Windows Firewall |
| 🔍 **[VGT Civilian Checker](https://github.com/visiongaiatechnology/Winsyssec)** | **Audit** | Windows security posture assessment |

> **Recommended stack:** Global Threat Sync daily for preventive coverage + Auto-Punisher for reactive coverage.

---

## ⚠️ Important Notes

- **Whitelist your IP first** — see the Critical Warning section above
- **Dynamic IPs** — whitelist your entire `/24` subnet if your ISP rotates your IP
- **IPv6 range bans disabled** — ISPs assign /64 blocks dynamically, range bans would hit legitimate users
- **Scoped monitoring** — only ports you select are monitored, web traffic on other ports is never counted
- **Bans persist** — `iptables-save` is called after every ban. Restore with `iptables-restore` after reboot.

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

> *"Tino wanted to throw the script away. V4.4.0 is what happened instead."* 😄

---

*Version 4.4.0 (HYBRID SUPREME) — VGT Auto-Punisher // Passive Radar + DPI + Kernel Hardening*
