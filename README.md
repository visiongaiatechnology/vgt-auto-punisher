# ⚔️ VGT Auto-Punisher — Kernel-Level Behavioral IDS

[![License](https://img.shields.io/badge/License-AGPLv3-green?style=for-the-badge)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux-FCC624?style=for-the-badge&logo=linux)](https://kernel.org)
[![Version](https://img.shields.io/badge/Version-4.7.3-brightgreen?style=for-the-badge)](#)
[![Architecture](https://img.shields.io/badge/Architecture-Hybrid_Supreme-red?style=for-the-badge)](#)
[![IPv6](https://img.shields.io/badge/IPv6-SUPPORTED-blue?style=for-the-badge)](#)
[![DPI](https://img.shields.io/badge/DPI-ENABLED-purple?style=for-the-badge)](#)
[![SSH](https://img.shields.io/badge/SSH-ZERO_TOLERANCE-red?style=for-the-badge)](#)
[![Status](https://img.shields.io/badge/Status-STABLE-brightgreen?style=for-the-badge)](#)
[![VGT](https://img.shields.io/badge/VGT-VisionGaia_Technology-red?style=for-the-badge)](https://visiongaiatechnology.de)
[![Donate](https://img.shields.io/badge/Donate-PayPal-00457C?style=for-the-badge&logo=paypal)](https://www.paypal.com/paypalme/dergoldenelotus)

> *"Don't rate-limit attackers. Terminate them."*
> *AGPLv3 — For Humans, not for SaaS Corporations.*

**V4.7.3 is the official stable release of VGT Auto-Punisher.** This is the version we run in production.

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

### Set your Limits  ⚠️

```bash
# --- VGT PARAMETER ---
readonly IP_THRESHOLD=15           # Hits bis zum Einzel-IP Ban
readonly RANGE_THRESHOLD=30        # Hits bis zum /24 Subnetz Ban (v4)
readonly WIDE_RANGE_THRESHOLD=150  # Globales Sektor-Limit (/16) für Roaming-Scans
readonly VELOCITY_LIMIT=5          # Max Hits pro Sekunde (Flash-Burst Schutz)
readonly BAN_TIME=86400            # 24 Stunden Ban-Dauer
readonly LOG_PREFIX="[VGT_STRIKE]"
readonly IPSET_V4="VGT_BANNED_V4"
readonly IPSET_V6="VGT_BANNED_V6"
```

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

## 🆕 V4.7.3 — Supreme Auto-Pilot & SSH Zero-Tolerance

**This is the current release.** V4.7.3 adds Auto-Pilot port detection and SSH Zero-Tolerance on top of the V4.7.0 foundation.

| Feature | Description |
|---|---|
| **Auto-Pilot Mode** | No prompt on startup — all active ports detected and monitored automatically via `ss -tlnp` |
| **SSH Zero-Tolerance** | Any SSH connection attempt from a non-whitelisted IP is terminated instantly — 0 hits tolerance |
| **systemd Support** | Runs as a persistent background service — auto-starts after boot and Strato reboots |
| **`[🔐]` Strike Icon** | New icon for SSH Zero-Tolerance kills |

```
[🔐] ZERO-TOLERANCE: IP 185.220.101.47 terminiert (Illegaler SSH-Zugriff).
```

> **Logic:** If you have legitimate SSH access, your IP is on the whitelist. Anyone else touching port 22 has no business there.

---

## 🆕 V4.7.0 — Supreme Terminal UI & Port Mapping

V4.7.0 brings a complete terminal UI overhaul and real-time port mapping on top of the V4.6.2 foundation.

### All Features

| Feature | Description |
|---|---|
| **Supreme Terminal UI** | Full Unicode box-drawing table — professional terminal dashboard |
| **Port Mapping** | See exactly which service attackers are targeting — `[WEB]`, `[SSH]`, `[FTP]`, `[PNL]`, `[NET]` |
| **Status Column** | Real-time status per IP: `TRACKING` → `FLASH` → `IP-KILL` → `RNG-KILL` → `MAC-KILL` |
| **Strike Icons** | `[⚡]` Velocity · `[✖]` Terminated · `[☢]` Infra-Strike · `[☠]` Macro-Strike |
| **Velocity Strike** | Flash-burst detection — bans IPs that exceed 5 hits/second instantly |
| **Macro Strike** | /16 sector kill — terminates entire provider blocks when roaming scanners are detected |
| **O(1) Time-Bucketing** | Burst tracking uses log timestamps — zero CPU overhead |
| **Forgiveness Protocol** | All bans expire after 24h automatically — no permanent lockouts |
| **Dynamic Port Chunking** | iptables multiport handles max 15 ports per rule — auto-chunked |
| **Log Rate Limiting** | 50 logs/second max — protects disk/SSD from log floods |
| **Passive Log-Sensing** | Monitors only selected ports — legitimate users never affected |
| **DPI Sanitization** | XMAS, NULL, MSS anomaly, invalid state dropped at Layer 4 |
| **BBR + Kernel Hardening** | TCP stack optimized for performance and resilience |
| **Subnet Whitelist in AWK** | /24 ranges evaluated directly in the stream processor |
| **IPv6 Dual-Stack** | Full IPv4 + IPv6 monitoring and termination |
| **SSH Anti-Freeze** | Heartbeat every 45s prevents SSH timeout on long sessions |

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

## 🛡️ Four Strike Modes

### Velocity Strike — Flash Burst ⚡
When a single IP exceeds `VELOCITY_LIMIT` (default: 5 hits/second), it is terminated instantly. Catches automated scanners that fire in rapid bursts.

```
[⚡] VELOCITY STRIKE: IP 185.220.101.47 terminiert (Flash-Burst erkannt: 7 Hits/sek).
```

### Surgical Strike — Single IP
When a single IP exceeds `IP_THRESHOLD` (default: 15 hits), it is added to the ipset with a 24h timeout.

```
[✖] TERMINIERT: IP 185.220.101.47 für 24h hingerichtet.
```

### Infrastructure Strike — /24 Subnet
When hits from the same /24 subnet exceed `RANGE_THRESHOLD` (default: 30 hits), the entire subnet is banned. Catches coordinated botnet attacks that rotate IPs within the same provider block.

```
[☢] INFRA-SCHLAG: Range 177.23.200.0/24 für 24h terminiert.
```

### Macro Strike — /16 Sector ☠️
When hits from the same /16 sector exceed `WIDE_RANGE_THRESHOLD` (default: 150 hits), the entire provider sector is banned. Catches roaming scanners that spread across multiple /24 blocks.

```
[☠] MACRO-SCHLAG: Sektor 177.23.0.0/16 terminiert (Roaming-Scanner erkannt).
```

> **Real-world example:** A coordinated botnet distributed its traffic across `177.23.200.x` through `177.23.207.x`. Auto-Punisher detected the subnet pattern, terminated 5 complete /24 ranges — and triggered a /16 Macro Strike on the entire `177.23.0.0/16` sector.

---

## 🖥️ TUI Matrix Dashboard

```
╭──────────────────────────────────────────────────────────────────────────────────────────────────────╮
│   VGT AUTO-PUNISHER V4.7.0 - SUPREME TERMINAL DASHBOARD (L4 KINETICS)                               │
├───────────────────┬────────────────────────┬─────────────┬───────┬──────┬────────┬────────┬──────────┤
│ ZEITSTEMPEL       │ QUELL-IP               │ ZIEL (PORT) │ BURST │ HITS │ R-HITS │ S-HITS │ STATUS   │
├───────────────────┼────────────────────────┼─────────────┼───────┼──────┼────────┼────────┼──────────┤
│ Mar 20 16:21:22   │ 177.23.200.63          │ 443 [WEB]   │     7 │    7 │     67 │     67 │ FLASH    │
│ Mar 20 16:21:22   │ 185.220.101.47         │ 22  [SSH]   │     3 │   12 │     18 │     47 │ TRACKING │
│ Mar 20 16:21:22   │ 14.103.105.40          │ 80  [WEB]   │     1 │    1 │      1 │      1 │ TRACKING │
├───────────────────┴────────────────────────┴─────────────┴───────┴──────┴────────┴────────┴──────────┤
│ [⚡] VELOCITY STRIKE: IP 177.23.200.63 terminiert (Flash-Burst erkannt: 7 Hits/sek).                 │
├───────────────────┬────────────────────────┬─────────────┬───────┬──────┬────────┬────────┬──────────┤
│ [☢] INFRA-SCHLAG: Range 177.23.200.0/24 für 24h terminiert.                                         │
├───────────────────┴────────────────────────┴─────────────┴───────┴──────┴────────┴────────┴──────────┤
│ [☠] MACRO-SCHLAG: Sektor 177.23.0.0/16 terminiert (Roaming-Scanner erkannt).                        │
╰──────────────────────────────────────────────────────────────────────────────────────────────────────╯
```

**Port Color Mapping:**

| Color | Ports | Label | Meaning |
|---|---|---|---|
| 🔵 Cyan | 80, 443, 8443 | `[WEB]` | Web traffic |
| 🟣 Purple | 22, 2222 | `[SSH]` | SSH access |
| 🟡 Yellow | 21 | `[FTP]` | FTP legacy |
| 🟡 Yellow | 3306, 888 | `[PNL]` | Database / Panel |
| ⚪ White | Any other | `[NET]` | Generic network |

**Status Column:**

| Status | Color | Meaning |
|---|---|---|
| `TRACKING` | Gray | Monitoring — below thresholds |
| `FLASH` | Red | Velocity Strike imminent |
| `IP-KILL` | Red | Single IP banned |
| `RNG-KILL` | Red | /24 Range banned |
| `MAC-KILL` | Purple | /16 Sector banned |
| `SSH-KILL` | Purple | SSH Zero-Tolerance — instant ban |

- **Full Unicode box-drawing** — professional terminal dashboard
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
# Auto Punisher 4.6.2
nano auto-punisher4-6-2.sh
# Auto Punisher 4.7
nano punisher4-7.sh
# Auto Punisher 4.7.3 (Auto-Pilot + SSH Zero-Tolerance)
nano punisher47ssh.sh

# Edit: readonly WHITELIST_IPS="... YOUR.IP.0/24"

# 3. Make executable
# Auto Punisher 3
chmod +x auto-punisher3.sh
# Auto Punisher 3 Titan
chmod +x auto_punisher_titan3.sh
# Auto Punisher 4
chmod +x auto-punisher4.sh
# Auto Punisher 4.6.2
chmod auto-punisher4-6-2.sh
# Auto Punisher 4.7
chmod punisher4-7.sh
# Auto Punisher 4.7.3
chmod +x punisher47ssh.sh

# 4. Run
# Auto Punisher 3
sudo ./auto-punisher3.sh
# Auto Punisher 3 Titan
sudo ./auto_punisher_titan3.sh
# Auto Punisher 4
sudo ./auto-punisher4.sh
# Auto Punisher 4.6.2
sudo ./auto-punisher4-6-2.sh
# Auto Punisher 4.7
sudo ./punisher4-7.sh
# Auto Punisher 4.7.3 (Auto-Pilot)
sudo ./punisher47ssh.sh
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

## ⚙️ Run as systemd Service (Auto-Pilot Mode)

V4.7.3 is designed to run as a persistent background service — no terminal required, auto-starts after every reboot.

### Service Unit

Create `/etc/systemd/system/vgt-punisher.service`:

```ini
# ==============================================================================
# VISIONGAIA TECHNOLOGY: SYSTEMD SERVICE UNIT
# ZWECK: Automatischer Start des VGT Punishers nach Boot & Strato-Reboot
# ==============================================================================

[Unit]
Description=VGT Auto-Punisher Autonomous Defense
After=network-online.target netfilter-persistent.service
Wants=network-online.target

[Service]
Type=simple
ExecStart=/bin/bash /root/vgt_punisher.sh
Restart=always
RestartSec=10
Environment=PYTHONUNBUFFERED=1
SyslogIdentifier=vgt-punisher

[Install]
WantedBy=multi-user.target
```

### Installation

```bash
# Step 1 — Deploy the script
cp punisher47ssh.sh /root/vgt_punisher.sh
chmod +x /root/vgt_punisher.sh

# Step 2 — Create the service file
nano /etc/systemd/system/vgt-punisher.service
# (paste the service unit above)

# Step 3 — Enable and start
systemctl daemon-reload
systemctl enable vgt-punisher
systemctl start vgt-punisher

# Step 4 — Verify it's running
systemctl status vgt-punisher
```

### Live Monitoring (Background Mode)

Even when running as a service in the background, you can watch the live dashboard at any time:

```bash
journalctl -u vgt-punisher -f -o cat
```

> The full TUI dashboard streams directly to the journal — RGB colors, Unicode tables and all kill messages appear in real-time.

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
VERSION           4.7.3 (Supreme Auto-Pilot + SSH Zero-Tolerance)
ARCHITECTURE      Hybrid (iptables + ipset + journalctl + AWK)
SENSOR            Passive LOG on selected ports (scoped, rate-limited)
BAN_MECHANISM     ipset hash:net with 24h timeout (Forgiveness Protocol)
BAN_DURATION      24 hours (configurable via BAN_TIME)
STRIKE_MODES      4: Velocity + Surgical + Infrastructure + Macro
STRIKE_ICONS      [⚡] Velocity · [✖] Terminated · [☢] Infra · [☠] Macro · [🔐] SSH-Kill
VELOCITY_LIMIT    5 hits/second (Flash-Burst detection)
WIDE_RANGE        /16 sector kill at 150 hits (Roaming-Scanner)
PORT_MAPPING      [WEB] [SSH] [FTP] [PNL] [NET] with color coding
DPI               INVALID state, XMAS, NULL scan, MSS anomaly
PERSISTENCE       iptables-save after every ban
IPv4_RANGES       /24 + /16 subnet ban via AWK
IPv6              Single-IP ban (range bans disabled by design)
TCP_HARDENING     BBR, syncookies, SYN backlog, FQ qdisc
LOG_PROTECTION    Rate-limited to 50/s, burst 100
PORT_CHUNKING     Auto-chunked into groups of 14 (iptables limit)
SSH_SAFETY        Heartbeat + 24h auto-expiry + whitelist
SSH_TOLERANCE     Zero — any non-whitelisted SSH attempt = instant ban
AUTO_PILOT        No prompt — all ports auto-detected on startup
SERVICE_MODE      systemd compatible — runs as persistent background service
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

> *"Tino wanted to throw the script away. V4.7.3 runs as a systemd service, terminates SSH on first contact, and looks damn good doing it."* 😄

---

*Version 4.7.3 (SUPREME AUTO-PILOT + SSH ZERO-TOLERANCE) — VGT Auto-Punisher // Passive Radar + DPI + Kernel Hardening*
