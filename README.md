# ⚔️ VGT Auto-Punisher — Kernel-Level Behavioral IDS

[![License](https://img.shields.io/badge/License-AGPLv3-yellow?style=for-the-badge)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux-FCC624?style=for-the-badge&logo=linux)](https://kernel.org)
[![Kernel](https://img.shields.io/badge/Layer-Kernel_Level-red?style=for-the-badge)](#)
[![Status](https://img.shields.io/badge/Status-DIAMANT-purple?style=for-the-badge)](#)
[![VGT](https://img.shields.io/badge/VGT-VisionGaia_Technology-red?style=for-the-badge)](https://visiongaiatechnology.de)
[![Donate](https://img.shields.io/badge/Donate-PayPal-00457C?style=for-the-badge&logo=paypal)](https://www.paypal.com/paypalme/dergoldenelotus)

> *"Don't rate-limit attackers. Terminate them."*

---

## 🆕 V3.0 — DUAL STACK SUPREME

[![Version](https://img.shields.io/badge/Version-3.0-brightgreen?style=for-the-badge)](#)
[![IPv6](https://img.shields.io/badge/IPv6-SUPPORTED-blue?style=for-the-badge)](#)
[![Neon UI](https://img.shields.io/badge/UI-NEON_MATRIX-purple?style=for-the-badge)](#)

**What's new in V3.0:**

- **Full IPv6 Support** — Dual-Stack monitoring with separate `ipset hash:net family inet6` + `ip6tables` integration. IPv4 and IPv6 attacks detected and terminated independently.
- **Neon Matrix UI** — Color-coded ANSI terminal dashboard. IPs approaching the ban threshold turn red in real-time.
- **Dynamic Whitelist** — Configurable at the top of the script. Includes `127.0.0.1`, `::1`, `fe80::/10` (Link-Local) out of the box.
- **IPv6 Infrastructure Strike deliberately disabled** — IPv6 range bans are omitted by design. ISPs assign dynamic /48 and /64 blocks — a range ban would hit legitimate users. Single-IP termination only for IPv6.
- **Graceful Exit** — `CTRL+C` kills the heartbeat daemon cleanly. Your ipset bans remain active after exit.

```
============================================================================
   VGT AUTO-PUNISHER - OPEN SOURCE DEFENSE ENGINE (V3.0)
   Status: DUAL STACK SUPREME (IPv4 & IPv6 Monitoring)
============================================================================
   IP-Limit: 15 | Range-Limit: 30
   Whitelist: 127.0.0.1 ::1 0.0.0.0 :: fe80::/10
   Features:  Anti-Freeze Heartbeat, Neon-Matrix, Self-Healing Sensors
----------------------------------------------------------------------------
ZEITSTEMPEL         | QUELL-IP                                | HITS | RANGE
----------------------------------------------------------------------------
Mar 15 09:12:44     | 185.220.101.47                          |    1 |    3
Mar 15 09:12:45     | 2a0e:97c0:4d0::1                        |    1 |    0
...
[!!!] PUNISH: IP 185.220.101.47 terminiert (Limit erreicht).
----------------------------------------------------------------------------
[!!!] INFRA-SCHLAG: Range 185.220.101.0/24 terminiert (Limit erreicht).
----------------------------------------------------------------------------
```

---

**VGT Auto-Punisher** is a zero-dependency, kernel-level behavioral Intrusion Detection System for Linux servers. It streams live kernel events via `journalctl`, analyzes behavioral patterns in real-time via `awk`, and executes permanent IP bans directly in the kernel via `ipset` + `iptables`/`ip6tables` — with zero application-layer overhead.

No Python. No Node. No frameworks. Pure Bash + kernel primitives.

---

## 🚨 The Problem With Standard Rate Limiters

Most rate limiters operate at the application layer — Nginx, Apache, PHP. By the time they trigger, the attack has already consumed server resources.

| Standard Rate Limiters | VGT Auto-Punisher |
|---|---|
| ❌ Application layer — attack reaches PHP | ✅ Kernel layer — attack never reaches the app |
| ❌ Temporary blocks — attacker retries | ✅ Permanent ipset ban — mathematically blocked |
| ❌ Per-IP only — distributed attacks bypass | ✅ Surgical IP strike + /24 Infrastructure strike |
| ❌ No behavioral analysis | ✅ Real-time hit counting per IP and subnet |
| ❌ Manual setup required | ✅ Self-healing init — deploys itself on first run |
| ❌ Silent — no visibility | ✅ Live terminal dashboard with timestamps |

---

## ⚡ How It Works

```
Every TCP SYN packet
    → iptables LOG rule writes to kernel journal
    → journalctl streams live to Auto-Punisher
    → awk counts hits per IP and per /24 subnet
    → Threshold reached → ipset ban → kernel DROP
    → iptables-save → permanent across reboots
```

Two strike modes:

**Surgical Strike** — Single IP exceeds threshold → that IP is permanently banned.

**Infrastructure Strike** — Entire /24 subnet exceeds threshold → the full range is banned. Eliminates coordinated attacks from the same provider infrastructure.

---

## 🛡️ Self-Healing Initialization

On first run, Auto-Punisher automatically deploys its own defense infrastructure:

```
[VGT] Initialisiere System-Integritäts-Check...
[+] Erstelle IPSET-Tabelle: VGT_AUTO_BANNED
[+] Verknüpfe IPSET mit Firewall (Position 1)...
[+] Installiere Anomalie-Sensor (Log-Regel)...
[VGT] System-Integrität bestätigt. Schilde sind aktiv.
```

No manual iptables configuration required. No manual ipset setup. It installs itself.

---

## 📊 Live Terminal Dashboard

```
==========================================================
   VGT AUTO-PUNISHER - OPEN SOURCE DEFENSE ENGINE
   Status: DIAMANT VGT SUPREME (READY FOR GITHUB)
==========================================================
   IP-Limit: 30 | Range-Limit: 60
   Sicherheit: Hard-Whitelist (127.0.0.1) ist AKTIV
----------------------------------------------------------
ZEITSTEMPEL         | QUELL-IP        | HITS | RANGE-HITS
----------------------------------------------------------
Mar 15 09:12:44     | 185.220.101.47  |    1 |    3
Mar 15 09:12:44     | 185.220.101.52  |    1 |    4
Mar 15 09:12:45     | 185.220.101.47  |    2 |    5
...
[!!!] PUNISH: IP 185.220.101.47 terminiert (Limit 30 erreicht).
----------------------------------------------------------
[!!!] INFRA-SCHLAG: Range 185.220.101.0/24 terminiert (Limit 60 erreicht).
----------------------------------------------------------
```

---

## 🚀 Installation

### Requirements
- Linux (Debian / Ubuntu / CentOS)
- Root access
- `ipset`, `iptables`, `journalctl` (auto-installed if missing)

### Setup

```bash
# Clone the repository
git clone https://github.com/visiongaiatechnology/vgt-auto-punisher.git
cd vgt-auto-punisher

# Make executable
chmod +x auto-punisher.sh

# Run as root
sudo ./auto-punisher.sh
```

That's it. Auto-Punisher handles the rest.

---

## ⚙️ Configuration

All settings are at the top of the script:

```bash
IPSET_NAME="VGT_AUTO_BANNED"   # Name of the ipset blocklist
IP_THRESHOLD=30                 # Hits until single IP is banned
RANGE_THRESHOLD=60              # Hits until entire /24 subnet is banned
LOG_PREFIX="[VGT_ANOMALY]"      # Must match the iptables LOG prefix
```

### Adding your own IPs to the whitelist

Edit the Hard Whitelist section in the awk block:

```bash
# Extend this line with your own IPs
if (ip == "127.0.0.1" || ip == "0.0.0.0" || ip == "YOUR_IP_HERE") next;
```

### Running as a background daemon

```bash
# Run in background with nohup
nohup sudo ./auto-punisher.sh > /var/log/vgt-punisher.log 2>&1 &

# Or as a systemd service (recommended for production)
```

### Systemd Service (Recommended)

```ini
# /etc/systemd/system/vgt-punisher.service
[Unit]
Description=VGT Auto-Punisher IDS
After=network.target

[Service]
Type=simple
ExecStart=/path/to/auto-punisher.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

```bash
systemctl enable vgt-punisher
systemctl start vgt-punisher
```

---

## 🔍 Managing the Blocklist

```bash
# View all currently banned IPs
ipset list VGT_AUTO_BANNED

# Remove a specific IP (emergency unban)
ipset del VGT_AUTO_BANNED 1.2.3.4

# Clear the entire blocklist
ipset flush VGT_AUTO_BANNED

# Check how many IPs are banned
ipset list VGT_AUTO_BANNED | grep -c "^[0-9]"
```

---

## 📦 System Specs

```
DETECTION_LAYER   KERNEL (iptables/ip6tables LOG → journalctl stream)
ANALYSIS_ENGINE   AWK (zero external dependencies)
BAN_MECHANISM     ipset hash:net (IPv4) + hash:net family inet6 (IPv6)
PERSISTENCE       iptables-save → rules.v4 / ip6tables-save → rules.v6
STRIKE_MODES      Surgical (single IP) + Infrastructure (/24 IPv4 only)
IP_STACK          Dual-Stack (IPv4 + IPv6)
WHITELIST         Dynamic — configurable at script top
OVERHEAD          ~0% CPU idle (event-driven, no polling)
UI                Neon Matrix (ANSI color-coded, real-time threat levels)
```

---

## ⚠️ Important Notes

- **Run as root** — kernel-level operations require root privileges
- **Test your own IP first** — make sure your IP is whitelisted before deploying
- **Aggressive by design** — thresholds are tuned for Tier 4 infrastructure. Lower them for shared hosting.
- **IPv6 range bans disabled by design** — ISPs assign dynamic /48 and /64 blocks. Range bans would hit legitimate users. IPv6 single-IP bans only.
- **ipset survives reboots** — bans are persisted via `iptables-save` and `ip6tables-save`

---

## 🤝 Contributing

Pull requests are welcome. For major changes, please open an issue first.

Licensed under **AGPLv3** — free to use, modify, and deploy.

---

## ☕ Support the Project

VGT Auto-Punisher is free. If it saves your server:

[![Donate via PayPal](https://img.shields.io/badge/Donate-PayPal-00457C?style=for-the-badge&logo=paypal)](https://www.paypal.com/paypalme/dergoldenelotus)

---

## 🏢 Built by VisionGaia Technology

[![VGT](https://img.shields.io/badge/VGT-VisionGaia_Technology-red?style=for-the-badge)](https://visiongaiatechnology.de)

VisionGaia Technology builds enterprise-grade security and AI tooling — engineered to the DIAMANT VGT SUPREME standard.

> *"By the time most firewalls react, the damage is done. Auto-Punisher acts at the speed of the kernel."*

---

*Version 3.0 (DUAL STACK SUPREME) — VGT Auto-Punisher // Kernel-Level Behavioral IDS*
