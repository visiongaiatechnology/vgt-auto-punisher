# ⚔️ VGT Auto-Punisher — Experimental Userspace/Kernel Hybrid IDS (R&D Project)

[![License](https://img.shields.io/badge/License-AGPLv3-green?style=for-the-badge)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux-FCC624?style=for-the-badge&logo=linux)](https://kernel.org)
[![Version](https://img.shields.io/badge/Version-7.2.0-brightgreen?style=for-the-badge)](#)
[![Architecture](https://img.shields.io/badge/Architecture-eBPF%2FXDP_Kernel_Hybrid-orange?style=for-the-badge)](#)
[![Status](https://img.shields.io/badge/Status-R%26D_/_Experimental-yellow?style=for-the-badge)](#)
[![IPv6](https://img.shields.io/badge/IPv6-SUPPORTED-blue?style=for-the-badge)](#)
[![VGT](https://img.shields.io/badge/VGT-VisionGaia_Technology-red?style=for-the-badge)](https://visiongaiatechnology.de)

> *"Don't rate-limit attackers. Terminate them."*
> *AGPLv3 — Open Source. Open Knowledge.*

---

## ⚠️ DISCLAIMER: EXPERIMENTAL R&D PROJECT

This project is a **Proof of Concept (PoC)** exploring hybrid kernel/userspace intrusion detection using eBPF/XDP, Python Raw Sockets, and AWK. While V7.2.0 introduces genuine kernel-level packet processing, the control plane remains in userspace — this is **not** a certified production security solution.

**Do not use this in critical production environments.** For enterprise-grade protection, we recommend established eBPF/Netfilter solutions like CrowdSec or nftables alongside this tool — not instead of them.

---

## 🚨 CRITICAL SECURITY NOTICE — VULNERABILITY DISCLOSURE

**All users running legacy versions (<= V6.3.2) must update immediately.**

Three severe vulnerabilities were identified in the legacy architecture:

| CVE Class | Component | Description |
|---|---|---|
| **CWE-77** — Command Injection | L7 Ghost Sensor | Unsanitized SNI/Host header data passed into shell execution context — RCE vector |
| **CWE-117** — Log Forging | AWK Engine | Attacker-controlled input could inject forged entries into journal stream, bypassing detection logic |
| **CWE-59** — Symlink Attack | `/tmp` handling | Insecure temp file operations exposed to symlink attack |

**Patch Status (V6.4.0+):** Shell evaluations replaced with direct IPC queue. All inputs strictly sanitized before reaching the rendering engine. V7.2.0 extends this with `journalctl _UID=0` log verification — log forging from unprivileged processes is structurally impossible.

🙏 **Special Thanks:** Massive respect and gratitude to **Will** ([github.com/gtech](https://github.com/gtech)) for responsibly disclosing these vulnerabilities, verifying the textbook command injection, and providing invaluable architectural feedback. His audit was the catalyst for reframing this project as a transparent, educational R&D initiative.

---

## 📋 Changelog — V7.2.0

> **V7.2.0 is a generational architecture leap.** The project breaks through the userspace ceiling with kernel-level eBPF/XDP packet processing, enterprise cluster sync, and JA3 TLS fingerprinting.

| Feature | V6.4.0 | V7.2.0 |
|---|---|---|
| **Packet Filter Layer** | Userspace + iptables/ipset fallback | eBPF/XDP — kernel driver level, bypasses TCP/IP stack |
| **SYN Flood Resistance** | CPU bottleneck under massive L4 floods | XDP_DROP at NIC driver — near-zero CPU cost |
| **Cluster Sync** | Single isolated node | Redis PubSub — native RESP client, no dependencies |
| **Metrics** | In-memory AWK TUI only | Prometheus HTTP exporter (port 9100, loopback-bound) |
| **L7 Detection Depth** | SNI + HTTP Host parsing | SNI + HTTP Host + **JA3 TLS fingerprinting** |
| **IPv6 Protection** | Single-address tracking | Dynamic /64 subnet banning |
| **Log Spoofing Resistance** | Global journalctl (spoofable via `logger`) | `_UID=0` systemd verification — unforgeable |
| **L7 Sensor DoS** | IndexError on malformed frames → crash | try-except per packet — silent discard, sensor stays live |
| **Logger Injection** | Variables in logger call — flag injection possible | POSIX `--` option terminator — structurally prevented |
| **Prometheus Exposure** | Bound to `0.0.0.0` (internet-exposed) | Strictly bound to `127.0.0.1` |
| **TUI Rendering** | Terminal clear on each frame — flicker under load | ANSI `\033[H` double-buffering — stable at 10,000+ events/s |

---

## 💎 Support the Project

[![Donate via PayPal](https://img.shields.io/badge/Donate-PayPal-00457C?style=for-the-badge&logo=paypal)](https://www.paypal.com/paypalme/dergoldenelotus)

| Method | Address |
|---|---|
| **PayPal** | [paypal.me/dergoldenelotus](https://www.paypal.com/paypalme/dergoldenelotus) |
| **Bitcoin** | `bc1q3ue5gq822tddmkdrek79adlkm36fatat3lz0dm` |
| **ETH / USDT (ERC-20)** | `0xD37DEfb09e07bD775EaaE9ccDaFE3a5b2348Fe85` |

---

<img width="1920" height="1080" alt="VGT Dashboard Matrix" src="https://github.com/user-attachments/assets/6f6f8488-f04b-4732-93ba-6ee69ad1ad2e" />

---

## 🔬 What is the Auto-Punisher?

The VGT Auto-Punisher started as an experiment: **Can we build a highly kinetic, behavior-based IDS without compiling C or Rust, relying solely on standard Linux userspace tools?**

V6.3.4 answered that question — and hit its ceiling. V7.2.0 breaks through it.

```
V4.x thought in IPs.
V5+ thought in intentions.
V6.3.4 reached the ceiling of what Bash/AWK can safely do.
V7.2.0 offloads the critical path to the kernel itself.
```

The core insight of V7.2.0: the AWK analysis engine and IPC queue remain in userspace for flexibility, but the **actual packet drops happen at the NIC driver level via eBPF/XDP** — before the kernel's TCP/IP stack ever allocates a socket buffer. SYN floods that would saturate a userspace daemon are now absorbed at near-zero CPU cost.

---

## 🏛️ Architecture — V7.2.0 Kernel Hybrid

```
Adversarial Packet arrives at NIC
    ↓
[ eBPF/XDP — Kernel Driver Level ]
    → v4_ban_map (1,000,000 entries) / v6_ban_map (500,000 entries)
    → XDP_DROP: packet never reaches TCP/IP stack
    → Atomic load protocol — zero downtime on rule reload
    ↓ (IP not yet banned)
[ LAYER 4: Netfilter / iptables ]
    → ipset fallback for non-XDP environments
    → Drops INVALID states, XMAS, NULL scans
    ↓
[ LAYER 7: Python Raw Socket Sensor (Ghost Sensor) ]
    → AF_PACKET sniff on Port 80/443
    → Extracts SNI & HTTP Host headers
    → Computes JA3 TLS fingerprint (MD5 of cipher suites + extensions + curves)
    → Strict alphanumeric sanitization before any processing
    → Writes via systemd logger (UID=0 — unforgeable identity)
    ↓
[ ANALYSIS: AWK Rules Engine ]
    → Reads journalctl _UID=0 SYSLOG_IDENTIFIER=VGT_L7_GHOST (spoofing immune)
    → Reads iptables events via journalctl -k (kernel-sourced, unforgeable)
    → Aggregates state in RAM (O(1) bucketing)
    → Checks Domain/IP whitelists, JA3 blocklist
    → Evaluates velocity, port probing, SNI mismatch, subnet patterns
    ↓
[ EXECUTION: IPC Queue ]
    → Named pipe /tmp/vgt_action_queue
    → Background daemon executes eBPF map update + ipset add (zero shell eval)
    ↓
         ┌──────────────────────────────────────┐
         ↓                                      ↓
[ eBPF Map Updater ]              [ Redis PubSub Client ]
  → Writes ban to v4/v6_ban_map     → Native RESP protocol (raw sockets)
  → Next packet: XDP_DROP            → Replicates ban to cluster nodes
         ↓
[ Prometheus Exporter — 127.0.0.1:9100 ]
  → L7 hits, kills, JA3 blocks, Redis syncs, TUI metrics
```

---

## 🔑 Phase A — eBPF/XDP Kernel Offloading

The most significant architectural advancement in Auto-Punisher history. At runtime, the system:

1. **Generates** a high-performance C program (`vgt_xdp.c`) containing the ban map definitions and XDP drop logic
2. **Compiles** it via LLVM/Clang into BPF bytecode
3. **Loads** it directly into the network driver — atomic protocol, zero downtime

```c
// XDP Drop Logic (simplified)
if (bpf_map_lookup_elem(&v4_ban_map, &src_ip)) {
    return XDP_DROP;  // Packet never reaches kernel TCP/IP stack
}
```

**Ban Map Capacity:**
- `v4_ban_map`: 1,000,000 IPv4 entries
- `v6_ban_map`: 500,000 IPv6 entries

Attacker packets are dropped at the NIC driver level. A DDoS that would saturate a userspace daemon vanishes at near-zero CPU cost.

---

## 🔑 Phase B — JA3 TLS Fingerprinting

V7.2.0 extends the L7 Ghost Sensor with cryptographic client fingerprinting. Every TLS Client Hello is deconstructed:

```
JA3 Input Fields:
  → SSLVersion
  → Ciphers (sorted list)
  → Extensions (sorted list)
  → EllipticCurves
  → EllipticCurvePointFormats

JA3 Hash = MD5(SSLVersion,Ciphers,Extensions,EllipticCurves,ECPointFormats)
```

Known malicious TLS stacks are blocked **by their cryptographic signature** regardless of IP address:

| Framework | JA3 Behavior | Result |
|---|---|---|
| **Metasploit** | Fixed cipher suite order, known extensions | Instant block |
| **Cobalt Strike** | Characteristic TLS profile | Instant block |
| **Masscan** | Minimal TLS handshake, distinctive fingerprint | Instant block |

Rotating residential IPs no longer provide evasion. The malware framework's TLS implementation is the identifier.

---

## 🔑 Phase C — Redis Cluster Sync

Zero-dependency cluster synchronization via a native Python RESP client implemented over raw TCP sockets — no Redis library, no external packages.

```
Node A detects attack → encodes RESP PUBLISH command → sends over raw socket → 
Node B/C/D receive event → immediately update their eBPF ban maps
```

A ban discovered by one node propagates to the full cluster within milliseconds.

---

## 🛡️ Strike Logic

```
[🎯] DOM-KILL     — Foreign/unknown domain (SNI mismatch) → instant XDP_DROP
[🎯] DOM-KILL     — DIRECT_IP_OR_MALFORMED → after 3 hits (mobile noise tolerance)
[🎯] JA3-KILL     — Known malicious TLS fingerprint → instant XDP_DROP
[🔐] SSH-KILL     — SSH from non-whitelisted IP → instant
[⚡] VELOCITY     — Flash-burst exceeds threshold → instant
[✖]  RATE-LIMIT   — Single IP threshold exceeded
[☢]  INFRA        — /24 subnet threshold exceeded
[☠]  MACRO        — /16 sector threshold exceeded
[🌐] IPV6-SUBNET  — Rotating /64 IPv6 attack → entire subnet banned
[📁] SMB          — Port 445 Honeypot: active exploit payload or passive scan
```

---

## 🔒 Security Hardening (V7.2.0)

### Anti-Log-Spoofing — systemd UID=0 Verification

**V6.4.0 problem:** Global `journalctl --grep` allowed unprivileged processes (e.g. compromised `www-data`) to inject fake ban triggers via the `logger` command.

**V7.2.0 fix:**
```bash
# iptables events — kernel-sourced, unforgeable
journalctl -k

# L7 events — verified UID=0 + exact SYSLOG_IDENTIFIER
journalctl _UID=0 SYSLOG_IDENTIFIER=VGT_L7_GHOST
```
`systemd-journald` stores the producer UID cryptographically. Spoofing attempts from unprivileged users are silently ignored.

### L7 Sensor DoS Hardening

**V6.4.0 problem:** Malformed/fragmented Ethernet frames triggered `IndexError` or `struct.error` in the Python packet loop — crashing the sensor.

**V7.2.0 fix:** Every byte decompression wrapped in a per-packet `try-except`. Malformed frames are silently discarded via `continue`. The sensor stays live under sustained malformed packet floods.

### Logger Parameter Injection

**V7.2.0 fix:** POSIX `--` option terminator applied to all `logger` calls. Flag injection via variable content is structurally impossible.

### Prometheus Exposure Fix

`0.0.0.0:9100` → `127.0.0.1:9100`. Security metrics are no longer internet-accessible.

---

## 📊 TUI Performance — Double-Buffering

```
V6.4.0: Terminal clear on each frame
  → Screen flicker under high event load
  → Rendering instability at >1,000 events/s

V7.2.0: ANSI \033[H cursor repositioning + line-level clears
  → Zero flicker at 10,000+ events/s
  → 132-character monospace terminal alignment
  → Column widths mathematically calculated to prevent framebuffer overflow
```

---

## ⚙️ Requirements

| Component | Requirement |
|---|---|
| **OS** | Linux (kernel 5.10+ recommended for XDP native mode) |
| **Privileges** | root (eBPF map loading, AF_PACKET, iptables) |
| **Python** | 3.8+ |
| **Compiler** | LLVM/Clang (for eBPF compilation: `apt install clang llvm`) |
| **Tools** | `ipset`, `iptables`/`ip6tables`, `iproute2` (`ip link`) |
| **Optional** | Redis instance (for cluster sync), Prometheus/Grafana (for metrics) |

### Check eBPF/XDP Support

```bash
# Verify Clang is available
clang --version

# Verify XDP support on your interface
ip link show eth0 | grep xdp

# Check AF_PACKET (required for L7 Ghost Sensor)
python3 -c "import socket; s = socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.ntohs(0x0003)); print('AF_PACKET OK')"
```

> **Note:** XDP native mode requires a supported NIC driver (most cloud providers: Hetzner, Strato, netcup — supported). OpenVZ containers may not support XDP — the system falls back to iptables/ipset automatically.

---

## 🛠️ Setup

### Step 1 — Configure Whitelists (CRITICAL)

> **⚠️ YOU WILL LOCK YOURSELF OUT IF YOU SKIP THIS**

```bash
nano vgt-auto-punisher.sh

# 1. Add your admin IP/Subnet:
readonly WHITELIST_IPS="127.0.0.1 ::1 fe80::/10 YOUR_IP_HERE"

# Example with /24 (for ISPs that rotate within a subnet):
readonly WHITELIST_IPS="127.0.0.1 ::1 fe80::/10 YOUR.IP.0/24"

# 2. Add legitimate domains hosted on this machine:
readonly WHITELIST_DOMAINS="example.com www.example.com"

# 3. (Optional) Configure Redis for cluster sync:
readonly REDIS_HOST="127.0.0.1"
readonly REDIS_PORT=6379

# 4. (Optional) Add known-malicious JA3 hashes to blocklist:
readonly JA3_BLOCKLIST="a0e9f5d64349fb13191bc781f81f42e1 ada70206e40642a3e4461f35503241d"
```

### Step 2 — Run

```bash
sudo ./vgt-auto-punisher.sh
```

The daemon will: load the eBPF/XDP program, initialize ban maps, start the Ghost Sensor, register the Prometheus exporter on `127.0.0.1:9100`, and attach to the TUI dashboard.

### Step 3 — Monitor

```bash
# Prometheus metrics
curl http://127.0.0.1:9100/metrics

# Active bans
ipset list VGT_BANNED_V4
ipset list VGT_BANNED_V6

# eBPF map contents (requires bpftool)
bpftool map dump name v4_ban_map
```

---

## ⚙️ Run as systemd Service

```ini
[Unit]
Description=VGT Auto-Punisher — eBPF/XDP Hybrid IDS
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
journalctl -u vgt-punisher -f -o cat
```

---

## 🆘 Emergency Reset

If you lock yourself out during testing, access your VPS emergency console:

```bash
# Flush eBPF ban maps
bpftool map dump name v4_ban_map | grep -o '"key":.*' | while read k; do bpftool map delete name v4_ban_map $k; done

# Flush ipset fallback
ipset flush VGT_BANNED_V4
ipset flush VGT_BANNED_V6

# Reset iptables
iptables -F INPUT
ip6tables -F INPUT
```

> All bans auto-expire after 24h. Emergency console (Strato KVM, Hetzner Console, netcup KVM) is your fallback.

---

## 📚 What This Project Teaches

V7.2.0 is a working demonstration of:

- **eBPF/XDP runtime compilation** — generating and loading kernel programs dynamically from a bash/python control plane
- **JA3 TLS fingerprinting** — extracting cryptographic client identifiers from raw TLS Client Hello packets
- **RESP protocol implementation** — building a Redis-compatible PubSub client from raw TCP sockets without any library
- **systemd journal UID verification** — using `_UID=0` filtering for log integrity
- **AF_PACKET raw socket sniffing** — deep packet inspection from Python userspace

For production security, the next steps are:
- **eBPF CO-RE (Compile Once, Run Everywhere):** Portable BPF programs that don't require Clang at runtime
- **XDP + AF_XDP:** Zero-copy packet processing to userspace
- **Rust for parsing:** Memory-safe parsing of adversarial network input

**Recommended Reading:**
- [Cilium eBPF Documentation](https://docs.cilium.io/en/stable/bpf/)
- [Google Project Zero Blog](https://googleprojectzero.blogspot.com/)
- [The Linux Kernel eBPF Verifier](https://www.kernel.org/doc/html/latest/bpf/verifier.html)

---

## 🔗 VGT Linux Defense Ecosystem

| Tool | Type | Purpose |
|---|---|---|
| ⚔️ **VGT Auto-Punisher** | **R&D / Experimental** | eBPF/XDP Hybrid IDS — educational exploration |
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

*VGT Auto-Punisher V7.2.0 — eBPF/XDP Kernel Hybrid IDS // JA3 TLS Fingerprinting // Redis Cluster Sync // Prometheus Metrics // Anti-Log-Spoofing // Dynamic IPv6 /64 Banning // Double-Buffered TUI // AGPLv3*
