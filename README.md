# ⚔️ VGT Auto-Punisher — Kernel-Level Behavioral IDS

[![License](https://img.shields.io/badge/License-AGPLv3-green?style=for-the-badge)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux-FCC624?style=for-the-badge&logo=linux)](https://kernel.org)
[![Version](https://img.shields.io/badge/Version-5.0.0-brightgreen?style=for-the-badge)](#)
[![Architecture](https://img.shields.io/badge/Architecture-L4_+_L7_Hybrid-red?style=for-the-badge)](#)
[![IPv6](https://img.shields.io/badge/IPv6-SUPPORTED-blue?style=for-the-badge)](#)
[![DPI](https://img.shields.io/badge/DPI-L4_+_L7-purple?style=for-the-badge)](#)
[![SSH](https://img.shields.io/badge/SSH-ZERO_TOLERANCE-red?style=for-the-badge)](#)
[![SNI](https://img.shields.io/badge/SNI-GHOST_SENSOR-orange?style=for-the-badge)](#)
[![Status](https://img.shields.io/badge/Status-STABLE-brightgreen?style=for-the-badge)](#)
[![VGT](https://img.shields.io/badge/VGT-VisionGaia_Technology-red?style=for-the-badge)](https://visiongaiatechnology.de)

> *"Don't rate-limit attackers. Terminate them."*
> *AGPLv3 — For Humans, not for SaaS Corporations.*

---

## 💎 Support the Project

VGT Auto-Punisher is free. If it keeps your server clean:

[![Donate via PayPal](https://img.shields.io/badge/Donate-PayPal-00457C?style=for-the-badge&logo=paypal)](https://www.paypal.com/paypalme/dergoldenelotus)

| Method | Address |
|---|---|
| **PayPal** | [paypal.me/dergoldenelotus](https://www.paypal.com/paypalme/dergoldenelotus) |
| **Bitcoin** | `bc1q3ue5gq822tddmkdrek79adlkm36fatat3lz0dm` |
| **ETH** | `0xD37DEfb09e07bD775EaaE9ccDaFE3a5b2348Fe85` |
| **USDT (ERC-20)** | `0xD37DEfb09e07bD775EaaE9ccDaFE3a5b2348Fe85` |

---

## 🚀 V5.0.0 — DIAMANT SUPREME L7 GHOST EDITION

**V5.0.0 is the current release.** This is the biggest architectural leap since V1 — Auto-Punisher is now a full L4 + L7 Hybrid IDS.

### What V5 can do that nothing else can

```
V4.x thought in IPs.
V5.0.0 thinks in intentions.
```

V5 deploys a **Python Raw Socket Ghost Sensor** that reads TLS SNI handshakes and HTTP Host headers directly off the wire — before the kernel processes them. Combined with the proven L4 engine, Auto-Punisher now knows not just *who* is connecting, but *what* they are trying to reach.

```
Direct IP access → no domain → instant ban [🎯]
Unknown domain   → not whitelisted → instant ban [🎯]
Whitelisted domain → allow with rate-limits
SSH from unknown IP → instant ban [🔐]
Flash-burst → instant ban [⚡]
/24 coordinated attack → subnet ban [☢]
/16 roaming scanner → sector ban [☠]
```

### V5.0.0 Full Feature Set

| Feature | Description |
|---|---|
| **L7 Ghost Sensor** | Python Raw Socket reads TLS SNI + HTTP Host directly off the wire — zero overhead |
| **Domain Whitelisting** | Only whitelisted domains are allowed — everything else triggers instant ban |
| **SNI Spoofing Kill** | Any foreign/unknown domain → `[🎯]` DOM-KILL instantly — no tolerance |
| **Mobile Noise Tolerance** | `DIRECT_IP_OR_MALFORMED` (mobile reconnects, TLS resumption) → 3 strikes before ban |
| **L4 + L7 Hybrid** | Web ports (80/443/8443) use L7 Ghost, all other ports use L4 SYN tracking |
| **Auto-Pilot Mode** | No prompt on startup — all ports detected and split automatically |
| **SSH Zero-Tolerance** | First SSH packet from unknown IP → instant ban — 0 hits tolerance |
| **Velocity Strike** | Flash-burst > 5 hits/second → instant ban `[⚡]` |
| **Surgical Strike** | > 15 hits from single IP → 24h ban `[✖]` |
| **Infrastructure Strike** | > 30 hits from /24 subnet → entire subnet banned `[☢]` |
| **Macro Strike** | > 150 hits from /16 sector → entire sector banned `[☠]` |
| **Forgiveness Protocol** | All bans auto-expire after 24h — no permanent lockouts |
| **systemd Support** | Runs as persistent background service — auto-starts after reboot |
| **Unicode TUI Dashboard** | Professional terminal dashboard with RGB ANSI colors |
| **Strike Icons** | `[🎯]` DOM · `[🔐]` SSH · `[⚡]` Velocity · `[✖]` Terminated · `[☢]` Infra · `[☠]` Macro |
| **DPI Sanitization** | XMAS, NULL, MSS anomaly, INVALID state dropped at Layer 4 |
| **BBR + Kernel Hardening** | TCP stack optimized for performance and resilience |
| **IPv6 Dual-Stack** | Full IPv4 + IPv6 monitoring and termination |
| **Anti-Log-Spam Cache** | Legitimate users never flood the journal — 1s cache per IP/domain pair |

### Strike Priority Order

```
[🎯] DOM-KILL     Priority 0a — Foreign/unknown domain (SNI Spoofing) → instant
[🎯] DOM-KILL     Priority 0b — DIRECT_IP_OR_MALFORMED → after 3 hits (mobile tolerance)
[🔐] SSH-KILL     Priority 1  — SSH from non-whitelisted IP → instant
[⚡] VELOCITY     Priority 2 — Flash-burst > 5 hits/sec → instant
[✖] RATE-LIMIT    Priority 3 — > 15 hits (whitelisted domains only)
[☢] INFRA         Priority 4 — /24 subnet threshold
[☠] MACRO         Priority 5 — /16 sector threshold
```

### New TUI Dashboard (V5)

```
╭──────────────────────────────────────────────────────────────────────────────────────────────────────────────╮
│   VGT AUTO-PUNISHER V5.0.0 - DIAMANT SUPREME (L7 SNI GHOST-SENSOR)                                          │
├────────┬─────────────────┬──────────────────┬───────────────┬───┬───┬───┬───┬──────────┤
│ ZEIT   │ QUELL-IP        │ DOMAIN (SNI/L7)  │ ZIEL (PORT)   │ B │ H │ R │ S │ STATUS   │
├────────┼─────────────────┼──────────────────┼───────────────┼───┼───┼───┼───┼──────────┤
│ 12:32  │ 185.128.37.145  │ example.com      │ 443 [WEB]     │ 1 │ 1 │ 1 │ 1 │ TRACKING │
│ 12:33  │ 94.102.61.8     │ DIRECT_IP        │ 443 [WEB]     │ 1 │ 1 │ 1 │ 1 │ DOM-KILL │
│ 12:33  │ 185.220.101.47  │ N/A (L4 SYN)     │ 22  [SSH]     │ 1 │ 1 │ 1 │ 1 │ SSH-KILL │
├────────┴─────────────────┴──────────────────┴───────────────┴───┴───┴───┴───┴──────────┤
│ [🎯] SNI/HOST VIOLATION: IP 94.102.61.8 terminiert (Zugriff auf: DIRECT_IP).            │
│ [🔐] ZERO-TOLERANCE: IP 185.220.101.47 terminiert (Illegaler L4 SSH-Zugriff).           │
╰──────────────────────────────────────────────────────────────────────────────────────────╯
```

---

## 🔴 CRITICAL — CONFIGURE BEFORE RUNNING

> ### ⚠️ YOU WILL LOCK YOURSELF OUT IF YOU SKIP THIS ⚠️

### Step 1 — Whitelist your IP

```bash
nano punisher5.sh

# Find this line and add your IP:
readonly WHITELIST_IPS="127.0.0.1 ::1 0.0.0.0 :: fe80::/10 YOUR.IP.HERE"

# ISP rotates your IP? Use /24:
readonly WHITELIST_IPS="127.0.0.1 ::1 0.0.0.0 :: fe80::/10 YOUR.IP.0/24"

# IPv6:
readonly WHITELIST_IPS="127.0.0.1 ::1 0.0.0.0 :: fe80::/10 2a02:xxxx:xxxx:xxxx::/64"
```

> **Why /24?** Many ISPs rotate your IP within a /24 block. Whitelist the whole subnet to avoid locking yourself out on reconnect.

### Step 2 — Whitelist your Domains

```bash
# Find this line and add ALL domains your server hosts:
readonly WHITELIST_DOMAINS="example.com www.example.com yourdomain.de www.yourdomain.de"
```

> **Important:** Any domain NOT on this list will trigger an instant DOM-KILL. Add every domain your server legitimately serves — including subdomains.

### Step 3 — Verify Python3 and Raw Socket

```bash
# Check Python3
python3 --version

# Check Raw Socket support (required for L7 Ghost Sensor)
python3 -c "import socket; s = socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.ntohs(0x0003)); print('Raw Socket OK')"
```

> If `Raw Socket OK` — you're ready. If `Operation not permitted` — your VPS provider may restrict `AF_PACKET`. This is rare on dedicated VPS (Hetzner, Strato, netcup) but can occur on OpenVZ containers.

```bash
# Install Python3 if not present
apt-get install python3 -y
```

### Step 4 — Fix journalctl filter (Required for L7)

The L7 Ghost Sensor writes to syslog. Open the script and change one line:

```bash
# Find this line:
journalctl -kf --grep="($LOG_PREFIX|$L7_PREFIX)"

# Replace with:
journalctl -f --grep="($LOG_PREFIX|VGT_L7)"
```

> **Why?** The `-k` flag limits journalctl to kernel messages only. Removing it allows the L7 Python sensor output to appear in the dashboard.

### Set your Limits

```bash
readonly IP_THRESHOLD=15           # Hits bis zum Einzel-IP Ban (Für legitime Domains)
readonly L7_STRIKE_THRESHOLD=3     # Toleranz für fehlerhafte/leere SNI (Background-Noise Mobile)
readonly RANGE_THRESHOLD=30        # Hits bis zum /24 Subnetz Ban (v4)
readonly WIDE_RANGE_THRESHOLD=150  # Globales Sektor-Limit (/16)
readonly VELOCITY_LIMIT=5          # Max Hits pro Sekunde
readonly BAN_TIME=86400            # 24 Stunden Ban-Dauer
```

### 🆘 Already Locked Out?

```bash
# Option A — Flush all bans
ipset flush VGT_BANNED_V4
ipset flush VGT_BANNED_V6

# Option B — Remove all iptables rules
iptables -F INPUT
ip6tables -F INPUT
```

> Use your hosting provider's emergency console (Strato KVM, Hetzner Console, netcup KVM). All bans auto-expire after 24h anyway.

---

## ⚙️ Run as systemd Service

V5.0.0 is designed to run as a persistent background service — no terminal required, auto-starts after every reboot.

### Service Unit

Create `/etc/systemd/system/vgt-punisher.service`:

```ini
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
# Step 1 — Deploy
cp punisher5.sh /root/vgt_punisher.sh
chmod +x /root/vgt_punisher.sh

# Step 2 — Create service
nano /etc/systemd/system/vgt-punisher.service

# Step 3 — Enable and start
systemctl daemon-reload
systemctl enable vgt-punisher
systemctl start vgt-punisher

# Step 4 — Verify
systemctl status vgt-punisher
```

### Live Monitoring

```bash
# Watch the full TUI dashboard even in background mode:
journalctl -u vgt-punisher -f -o cat

# Watch only kills:
journalctl -u vgt-punisher -f -o cat | grep -E "STRIKE|SCHLAG|TERMINATED|KILL"
```

---

## 🚀 Installation

### Requirements

| Tool | Purpose |
|---|---|
| `ipset` | High-speed IP blocklist |
| `iptables` / `ip6tables` | Firewall rules |
| `journalctl` | Log stream |
| `awk` | Stream analysis engine |
| `ss` | Port discovery |
| `python3` | L7 Ghost Sensor (V5+) |

```bash
# Debian / Ubuntu
apt-get install ipset iptables iproute2 python3 -y
```

### Setup

```bash
# 1. Clone
git clone https://github.com/visiongaiatechnology/vgt-auto-punisher.git
cd vgt-auto-punisher

# 2. Configure whitelist FIRST (see above)
nano punisher5.sh
# Edit: WHITELIST_IPS and WHITELIST_DOMAINS

# 3. Make executable
chmod +x punisher5.sh

# 4. Run
sudo ./punisher5.sh
```

### What happens on first run

```
1. Scans open ports via ss -tlnp
2. Splits ports: L7 (80/443/8443) vs L4 (all others)
3. Deploys L7 Ghost Sensor (Python Raw Socket)
4. Applies kernel TCP hardening (BBR, syncookies, backlog)
5. Creates ipset tables with 24h timeout
6. Injects DPI rules (XMAS, NULL, MSS, INVALID)
7. Injects scoped L4 LOG sensor (rate-limited to 50/s)
8. Starts hybrid AWK analysis stream (L4 + L7)
```

---

## 📦 Previous Releases

All previous versions remain available in the repository.

### V4.7.3 — Supreme Auto-Pilot + SSH Zero-Tolerance
`punisher47ssh.sh`

| Feature | Description |
|---|---|
| **Auto-Pilot** | No prompt — all ports auto-detected on startup |
| **SSH Zero-Tolerance** | First SSH contact from unknown IP → instant ban `[🔐]` |
| **systemd Support** | Runs as persistent background service |

```bash
nano punisher47ssh.sh   # Configure WHITELIST_IPS
chmod +x punisher47ssh.sh
sudo ./punisher47ssh.sh
```

---

### V4.7.0 — Supreme Terminal UI + Port Mapping
`punisher4-7.sh`

| Feature | Description |
|---|---|
| **Unicode TUI** | Full box-drawing dashboard with RGB ANSI |
| **Port Mapping** | `[WEB]` `[SSH]` `[FTP]` `[PNL]` `[NET]` service labels |
| **Strike Icons** | `[⚡]` `[✖]` `[☢]` `[☠]` |

```bash
nano punisher4-7.sh   # Configure WHITELIST_IPS
chmod +x punisher4-7.sh
sudo ./punisher4-7.sh
```

---

### V4.6.2 — Velocity + Macro Strike Engine
`auto-punisher4-6-2.sh`

| Feature | Description |
|---|---|
| **Velocity Strike** | Flash-burst detection `[⚡]` |
| **Macro Strike** | /16 sector kill `[☠]` |
| **O(1) Bucketing** | Zero CPU overhead burst tracking |

```bash
nano auto-punisher4-6-2.sh   # Configure WHITELIST_IPS
chmod +x auto-punisher4-6-2.sh
sudo ./auto-punisher4-6-2.sh
```

---

## 🏛️ Architecture — L4 + L7 Hybrid (V5)

```
Packet arrives at server
    ↓
iptables INPUT Position 1
    → ipset O(1) lookup → DROP if banned
    ↓
iptables INPUT Position 2-5
    → DPI: INVALID state → DROP
    → DPI: XMAS scan → DROP
    → DPI: NULL scan → DROP
    → DPI: MSS anomaly → DROP
    ↓
    ┌─────────────────────────────┐
    │  Port 80 / 443 / 8443?      │
    └──────┬──────────────────────┘
           │ YES                    NO
           ▼                        ▼
    L7 Ghost Sensor           L4 LOG Sensor
    (Python Raw Socket)       (iptables LOG)
    → Read TLS SNI                → SYN tracking
    → Read HTTP Host              → SSH Zero-Tolerance
    → Domain whitelist check      → Velocity detection
    → Direct IP → DOM-KILL [🎯]   → Rate limiting
           │                        │
           └──────────┬─────────────┘
                      ▼
              journalctl stream
              → AWK Hybrid Analyzer
              → Whitelist bypass
              → Strike execution
              → ipset ban (24h)
                      ↓
              After 24h → auto-expiry (Forgiveness Protocol)
```

---

## 📋 Port Reference

| Port | Service | Layer | Monitor? |
|---|---|---|---|
| `22` | SSH | L4 | ✅ Zero-Tolerance |
| `80` | HTTP | L7 | ✅ Domain check |
| `443` | HTTPS | L7 | ✅ SNI check |
| `8443` | HTTPS Alt | L7 | ✅ SNI check |
| `2222` | Custom SSH | L4 | ⚠️ If moved |
| `21` | FTP | L4 | ⚠️ Legacy |
| `3306` | MySQL | L4 | ⚠️ Not internet-facing |
| `25` | SMTP | L4 | ⚠️ Mail only |

---

## 🔍 Managing Bans

```bash
# View all active bans
ipset list VGT_BANNED_V4
ipset list VGT_BANNED_V6

# Count total bans
ipset list VGT_BANNED_V4 | grep -c "^[0-9]"

# Emergency: unban specific IP
ipset del VGT_BANNED_V4 1.2.3.4

# Emergency: flush all
ipset flush VGT_BANNED_V4
ipset flush VGT_BANNED_V6

# Restore after reboot
iptables-restore < /etc/iptables/rules.v4
ip6tables-restore < /etc/iptables/rules.v6
```

---

## 📦 System Specs

```
VERSION           5.0.0 (DIAMANT SUPREME L7 GHOST EDITION)
ARCHITECTURE      Hybrid L4 + L7 (iptables + ipset + Python Raw Socket + AWK)
L4_SENSOR         Passive SYN LOG on non-web ports (rate-limited 50/s)
L7_SENSOR         Python AF_PACKET Raw Socket — TLS SNI + HTTP Host extraction
BAN_MECHANISM     ipset hash:net with 24h timeout (Forgiveness Protocol)
BAN_DURATION      24 hours (configurable via BAN_TIME)
STRIKE_MODES      6: DOM + SSH + Velocity + Surgical + Infrastructure + Macro
STRIKE_ICONS      [🎯] DOM · [🔐] SSH · [⚡] Velocity · [✖] Rate · [☢] Infra · [☠] Macro
DOMAIN_WHITELIST  Configurable — all non-whitelisted domains → instant ban
DIRECT_IP_KILL    Foreign/unknown domain → instant ban (SNI Spoofing)
MOBILE_TOLERANCE  DIRECT_IP_OR_MALFORMED → 3 strikes via L7_STRIKE_THRESHOLD (mobile noise)
SSH_TOLERANCE     Zero — first contact from unknown IP = instant ban
L7_STRIKE_THRESHOLD 3 hits for MALFORMED/empty SNI before ban
VELOCITY_LIMIT    5 hits/second (Flash-Burst detection)
WIDE_RANGE        /16 sector kill at 150 hits (Roaming-Scanner)
PORT_SPLIT        L7: 80/443/8443 | L4: all other ports
DPI               INVALID, XMAS, NULL scan, MSS anomaly
PERSISTENCE       iptables-save after every ban
IPv4_RANGES       /24 + /16 subnet ban
IPv6              Single-IP ban (range bans disabled by design)
TCP_HARDENING     BBR, syncookies, SYN backlog, FQ qdisc
AUTO_PILOT        All ports auto-detected — no startup prompt
SERVICE_MODE      systemd compatible
OVERHEAD          ~0% CPU idle (event-driven) + minimal Python Ghost process
REQUIREMENTS      python3 + AF_PACKET Raw Socket support
```

---

## 🔗 VGT Linux Defense Ecosystem

| Tool | Type | Purpose |
|---|---|---|
| ⚔️ **VGT Auto-Punisher** | **Reactive** | Bans attackers the moment they hit |
| 🌐 **[VGT Global Threat Sync](https://github.com/visiongaiatechnology/vgt-global-threat-sync)** | **Preventive** | Daily feed sync — blocks known threats before arrival |
| 🔥 **[VGT Windows Firewall Burner](https://github.com/visiongaiatechnology/vgt-windows-burner)** | **Windows** | 280,000+ APT IPs in native Windows Firewall |
| 🔍 **[VGT Civilian Checker](https://github.com/visiongaiatechnology/Winsyssec)** | **Audit** | Windows security posture assessment |

> **Recommended stack:** Global Threat Sync (preventive) + Auto-Punisher V5 (reactive L4+L7) = complete coverage.

---

## 🤝 Contributing

Pull requests are welcome. For major changes, please open an issue first.

Licensed under **AGPLv3** — *"For Humans, not for SaaS Corporations."*

---

## 🏢 Built by VisionGaia Technology

[![VGT](https://img.shields.io/badge/VGT-VisionGaia_Technology-red?style=for-the-badge)](https://visiongaiatechnology.de)

VisionGaia Technology builds enterprise-grade security and AI tooling — engineered to the DIAMANT VGT SUPREME standard.

> *"Tino wanted to throw the script away. V5.0.0 reads TLS handshakes off the wire, terminates direct IP access instantly, and looks damn good doing it."* 😄

---

*Version 5.0.0 (DIAMANT SUPREME L7 GHOST EDITION) — VGT Auto-Punisher // L4 Passive Radar + L7 SNI Ghost + DPI + Kernel Hardening*
