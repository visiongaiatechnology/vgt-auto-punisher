# ⚔️ VGT Auto-Punisher — Experimental Userspace IDS (R&D Project)

[![License](https://img.shields.io/badge/License-AGPLv3-green?style=for-the-badge)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux-FCC624?style=for-the-badge&logo=linux)](https://kernel.org)
[![Version](https://img.shields.io/badge/Version-6.3.4-brightgreen?style=for-the-badge)](#)
[![Architecture](https://img.shields.io/badge/Architecture-Userspace_Hybrid-orange?style=for-the-badge)](#)
[![Status](https://img.shields.io/badge/Status-R%26D_/_Experimental-yellow?style=for-the-badge)](#)
[![IPv6](https://img.shields.io/badge/IPv6-SUPPORTED-blue?style=for-the-badge)](#)
[![VGT](https://img.shields.io/badge/VGT-VisionGaia_Technology-red?style=for-the-badge)](https://visiongaiatechnology.de)

> *"Don't rate-limit attackers. Terminate them."*
> *AGPLv3 — Open Source. Open Knowledge.*

---

## ⚠️ DISCLAIMER: EXPERIMENTAL R&D PROJECT

This project is a **Proof of Concept (PoC)** exploring asynchronous userspace packet inspection using Bash, AWK, and Python Raw Sockets. It is **not** a kernel-level module, and parsing adversarial network input via high-level scripting languages as root carries inherent architectural risks.

**Do not use this in critical production environments.** For enterprise-grade kernel-level protection, we recommend established eBPF/Netfilter solutions like CrowdSec or nftables.

---

## 🚨 CRITICAL SECURITY NOTICE — VULNERABILITY DISCLOSURE

**All users running legacy versions (<= V6.3.2) must update to V6.4.0 or sunset the service.**

Two severe security vulnerabilities were identified in the legacy architecture by an independent security researcher:

| CVE Class | Component | Description |
|---|---|---|
| **CWE-77** — Command Injection | L7 Ghost Sensor | Unsanitized SNI/Host header data could be passed into a shell execution context, allowing Remote Code Execution (RCE) |
| **CWE-117** — Log Forging | AWK Engine | Attacker-controlled input could inject forged entries into the journal stream, bypassing detection logic |
| **CWE-59** - Symlink Attack | Insecure /tmp | Symlink attack vector fixed |

**Patch Status (V6.3.4):** The architecture has been overhauled. Shell evaluations have been completely replaced with a direct IPC (Inter-Process Communication) queue, eliminating the RCE vector. Inputs are now strictly sanitized before reaching the rendering engine.

🙏 **Special Thanks:** Massive respect and gratitude to **Will** [Will's Github](https://github.com/gtech) for responsibly disclosing these vulnerabilities, verifying the textbook command injection, and providing invaluable architectural feedback. His audit was the catalyst for reframing this project from a "commercial tool" into a transparent, educational R&D initiative.

---

## 💎 Support the Project

VGT Auto-Punisher is free. If you find it useful for learning or experimentation:

[![Donate via PayPal](https://img.shields.io/badge/Donate-PayPal-00457C?style=for-the-badge&logo=paypal)](https://www.paypal.com/paypalme/dergoldenelotus)

| Method | Address |
|---|---|
| **PayPal** | [paypal.me/dergoldenelotus](https://www.paypal.com/paypalme/dergoldenelotus) |
| **Bitcoin** | `bc1q3ue5gq822tddmkdrek79adlkm36fatat3lz0dm` |
| **ETH** | `0xD37DEfb09e07bD775EaaE9ccDaFE3a5b2348Fe85` |
| **USDT (ERC-20)** | `0xD37DEfb09e07bD775EaaE9ccDaFE3a5b2348Fe85` |

---

<img width="1920" height="1080" alt="VGT Dashboard Matrix" src="https://github.com/user-attachments/assets/6f6f8488-f04b-4732-93ba-6ee69ad1ad2e" />

---

## 🔬 The Project: What is the Auto-Punisher?

The VGT Auto-Punisher started as an experiment: **Can we build a highly kinetic, behavior-based Intrusion Detection System without compiling C or Rust, relying solely on standard Linux userspace tools?**

Version 6.3.4 is the peak of this specific architectural exploration. It combines a Python-based Raw Socket listener (to inspect TLS SNI and HTTP Host headers off the wire) with an asynchronous AWK-based analysis engine.

```
V4.x thought in IPs.
V5+ thinks in intentions.
V6.3.4 is where that idea reached the ceiling of what Bash/AWK can safely do.
```

### Current R&D Capabilities

| Experimental Feature | Description |
|---|---|
| **L7 SNI Extraction** | Python `AF_PACKET` socket reads TLS Client Hello packets directly off the wire to verify intended domains |
| **Domain Strict-Lock** | Any SNI/Host request not matching the local whitelist triggers a kinetic strike |
| **IPC Strike Engine** | Actions are passed via named pipes (`/tmp/vgt_action_queue`) to a background daemon, preventing `system()` fork-bombs |
| **Heuristic Aggregation** | Tracking flash-bursts, port scans, and roaming /16 subnet scanners entirely in RAM |
| **SMB Honeypot** | Zero-overhead TCP listener on Port 445 — distinguishes active EternalBlue payloads from passive scanners |
| **Unicode TUI Dashboard** | Lock-free terminal UI visualizing active threats and network velocity in real-time |

---

## 🏛️ Experimental Architecture (Userspace Hybrid)

```
Adversarial Packet arrives at Interface
    ↓
[ LAYER 4: Netfilter / iptables ]
    → iptables O(1) ipset lookup (Drops known threats instantly)
    → Drops INVALID states, XMAS, NULL scans
    ↓
[ LAYER 7: Python Raw Socket Sensor ]
    → Sniffs Port 80/443 traffic (Userspace)
    → Extracts SNI & HTTP Host Headers
    → Applies strictly alphanumeric sanitization
    → Writes to local Syslog
    ↓
[ ANALYSIS: AWK Render & Rules Engine ]
    → Tails journalctl stream
    → Aggregates state in-memory (O(1) bucketing)
    → Checks against Domain/IP Whitelists
    → Evaluates Velocity, Port-Probing, and SNI Spoofing
    ↓
[ EXECUTION: IPC Queue ]
    → Passes trigger data via Named Pipe
    → Background bash loop executes `ipset add` (Zero-Shell Eval)
```

### Strike Logic

```
[🎯] DOM-KILL     — Foreign/unknown domain (SNI Spoofing) → instant
[🎯] DOM-KILL     — DIRECT_IP_OR_MALFORMED → after 3 hits (mobile noise tolerance)
[🔐] SSH-KILL     — SSH from non-whitelisted IP → instant
[⚡] VELOCITY     — Flash-burst > threshold hits/sec → instant
[✖] RATE-LIMIT   — Single IP threshold exceeded
[☢] INFRA        — /24 subnet threshold exceeded
[☠] MACRO        — /16 sector threshold exceeded
[📁] SMB         — Port 445 Honeypot: active exploit payload or passive scan
```

---

## 🛠️ Educational Setup & Testing

If you want to study the code, test the Python Raw Socket implementation, or analyze the IPC queuing system in a sandboxed environment:

### Step 1 — Configure Whitelists (CRITICAL)

> **⚠️ YOU WILL LOCK YOURSELF OUT IF YOU SKIP THIS**

Before running the script, you must configure the whitelists. The engine is extremely aggressive and will lock you out of your own server if your IP or domain is not listed.

```bash
nano vgt-auto-punisher.sh

# 1. Add your admin IP/Subnet:
readonly WHITELIST_IPS="127.0.0.1 ::1 fe80::/10 YOUR_IP_HERE"

# Example with /24 (for ISPs that rotate IPs within a subnet):
readonly WHITELIST_IPS="127.0.0.1 ::1 fe80::/10 YOUR.IP.0/24"

# 2. Add legitimate domains hosted on this machine:
readonly WHITELIST_DOMAINS="example.com www.example.com"
```

### Step 2 — Verify Python3 and Raw Socket

```bash
# Check Python3
python3 --version

# Check Raw Socket support (required for L7 Ghost Sensor)
python3 -c "import socket; s = socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.ntohs(0x0003)); print('Raw Socket OK')"
```

> If `Raw Socket OK` — you're ready. If `Operation not permitted` — your VPS provider may restrict `AF_PACKET`. This is rare on dedicated VPS (Hetzner, Strato, netcup) but can occur on OpenVZ containers.

### Step 3 — Run

```bash
# Requires root for AF_PACKET and iptables manipulation
sudo ./vgt-auto-punisher.sh
```

### 🆘 Emergency Reset

If you lock yourself out during testing, access your VPS emergency console and flush the sets:

```bash
ipset flush VGT_BANNED_V4
ipset flush VGT_BANNED_V6
iptables -F INPUT
ip6tables -F INPUT
```

> All bans auto-expire after 24h anyway. Emergency console (Strato KVM, Hetzner Console, netcup KVM) is your fallback.

---

## ⚙️ Run as systemd Service

```ini
[Unit]
Description=VGT Auto-Punisher — Experimental Userspace IDS
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/root
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Environment="PYTHONUNBUFFERED=1"
ExecStartPre=/bin/chmod +x /root/vgt_punisher.sh
ExecStart=/bin/bash /root/vgt_punisher.sh
Restart=always
RestartSec=5s
SyslogIdentifier=vgt-punisher
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

```bash
systemctl daemon-reload
systemctl enable vgt-punisher
systemctl start vgt-punisher

# Monitor
journalctl -u vgt-punisher -f -o cat
```

---

## 🔧 Managing Bans

```bash
# View active bans
ipset list VGT_BANNED_V4
ipset list VGT_BANNED_V6

# Unban specific IP
ipset del VGT_BANNED_V4 1.2.3.4

# Flush all
ipset flush VGT_BANNED_V4
ipset flush VGT_BANNED_V6
```

---

## 📚 Learning Resources & Next Steps

This project reached the ceiling of what is safely possible using Bash/AWK in userspace for network parsing. If you are interested in building **production-ready** network security tools, we highly recommend exploring:

- **eBPF (Extended Berkeley Packet Filter):** The modern standard for true kernel-level packet inspection without context-switching overhead.
- **XDP (eXpress Data Path):** Dropping packets at the network driver level before the kernel even allocates an `sk_buff`.
- **Memory-Safe Languages:** Using Rust or Go for parsing untrusted network input.
- **CrowdSec / nftables:** For real production use cases.

**Recommended Reading:**
- [Google Project Zero Blog](https://googleprojectzero.blogspot.com/)
- *The Web Application Hacker's Handbook*
- [Stanford's Cryptography MOOC](https://crypto.stanford.edu/)

---

## 🔗 VGT Linux Defense Ecosystem

| Tool | Type | Purpose |
|---|---|---|
| ⚔️ **VGT Auto-Punisher** | **R&D / Experimental** | Userspace IDS — educational exploration |
| 🌐 **[VGT Global Threat Sync](https://github.com/visiongaiatechnology/vgt-global-threat-sync)** | **Preventive** | Daily feed sync — blocks known threats before arrival |
| 🔥 **[VGT Windows Firewall Burner](https://github.com/visiongaiatechnology/vgt-windows-burner)** | **Windows** | 280,000+ APT IPs in native Windows Firewall |
| 🔍 **[VGT Civilian Checker](https://github.com/visiongaiatechnology/Winsyssec)** | **Audit** | Windows security posture assessment |

---

## 🤝 Contributing

Pull requests welcome. For major changes please open an issue first.

Licensed under **AGPLv3** — *"Open Source. Open Knowledge."*

---

## 🏢 About VisionGaia Technology

[![VGT](https://img.shields.io/badge/VGT-VisionGaia_Technology-red?style=for-the-badge)](https://visiongaiatechnology.de)

VisionGaia Technology is an R&D collective exploring experimental architectures, AI integration, and cybersecurity paradigms. We build to learn, we break things to understand them, and we share the results.

---

*VGT Auto-Punisher V6.3.4 — Experimental Userspace IDS // IPC Hardened Edition*
