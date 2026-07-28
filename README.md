<div align="center">

# ⚔️ VGT Auto-Punisher

### Archived predecessor of VGT GeDefense

[![Status](https://img.shields.io/badge/Status-Archived-red?style=for-the-badge)](#project-status)
[![Successor](https://img.shields.io/badge/Successor-VGT_GeDefense-00d9ff?style=for-the-badge)](https://github.com/visiongaiatechnology/gedefense)
[![Final Version](https://img.shields.io/badge/Final_Version-7.3.0-brightgreen?style=for-the-badge)](#historical-release)
[![License](https://img.shields.io/badge/License-AGPL--3.0--only-blue?style=for-the-badge)](LICENSE)
[![VGT](https://img.shields.io/badge/VGT-VisionGaiaTechnology-cyan?style=for-the-badge)](https://visiongaiatechnology.de)

> **VGT Auto-Punisher has been discontinued and evolved into VGT GeDefense.**
>
> Active development, security improvements and future releases continue exclusively in the GeDefense repository.

## ➜ [Open VGT GeDefense](https://github.com/visiongaiatechnology/gedefense)

</div>

---

## Project status

**VGT Auto-Punisher is closed and archived.**

The project is no longer actively developed, maintained or recommended for new installations. It remains publicly available as a historical research project and as the technical predecessor of **VGT GeDefense**.

| Project | Status | Repository |
|---|---|---|
| **VGT Auto-Punisher** | Archived / discontinued | This repository |
| **VGT GeDefense** | Active successor | [visiongaiatechnology/gedefense](https://github.com/visiongaiatechnology/gedefense) |

For new deployments, testing, bug reports, contributions and security research, use GeDefense:

```text
https://github.com/visiongaiatechnology/gedefense
```

---

## Why Auto-Punisher was replaced

Auto-Punisher began as an experimental investigation into behavior-based Linux intrusion detection using Bash, AWK, Python raw sockets, Netfilter and later eBPF/XDP.

The project demonstrated important concepts, but its original architecture eventually reached the limits of a shell- and userspace-heavy security stack. Continuing to extend that foundation would have increased complexity and security risk.

The lessons, concepts and strongest ideas from Auto-Punisher were therefore carried into a new architecture:

# VGT GeDefense

GeDefense is not a renamed Auto-Punisher release. It is the structured continuation and architectural redesign of the project.

```text
VGT Auto-Punisher
    Experimental Bash / AWK / Python security research
    Hybrid userspace and kernel packet defense
    Early behavior analysis and automatic response concepts
                         │
                         ▼
VGT GeDefense
    Rust eBPF/XDP data plane
    Go control plane and Host XDR
    Privilege-separated Rust response core
    Authenticated IPC and signed policies
    Encrypted evidence and operational state
    Reversible hardening and controlled response gates
    Local, sovereign dashboard without cloud control plane
```

---

## Continue with GeDefense

### Repository

[github.com/visiongaiatechnology/gedefense](https://github.com/visiongaiatechnology/gedefense)

### What moved to GeDefense

- kernel-near IPv4 and IPv6 defense with Rust eBPF/XDP;
- management allowlists and signed CIDR policies;
- Host XDR with multi-signal evidence gates;
- privilege-separated response handling;
- authenticated Control Plane ↔ Core communication;
- encrypted operational data and evidence;
- secure web gateway and local Command Center;
- Observe, Canary and Enforce promotion states;
- Emergency Stop and verified-empty rollback logic;
- reversible Linux hardening;
- continued GaiaOS integration.

### Where to report issues

Do not open new feature requests for Auto-Punisher. Security reports, bugs and improvements relating to the successor belong in the GeDefense project:

[GeDefense issues](https://github.com/visiongaiatechnology/gedefense/issues)

---

## Historical release

The final Auto-Punisher release was:

```text
VGT Auto-Punisher 7.3.0
```

Its research focus included:

- an experimental eBPF/XDP and IPSet defense path;
- IPv4 and IPv6 blocking;
- Python `AF_PACKET` traffic inspection;
- SNI, HTTP Host and JA3-derived signals;
- the experimental VGT TLS Behavioral Risk Engine;
- Redis-based synchronization concepts;
- Prometheus metrics;
- a terminal dashboard;
- journal identity checks and security hardening added after responsible disclosure.

These features document an important development stage, but they should not be interpreted as the current VGT security architecture.

---

## Security notice for existing users

Existing Auto-Punisher installations should be treated as legacy deployments.

- Do not deploy Auto-Punisher on new systems.
- Do not assume that archived code receives future security patches.
- Review all old firewall, IPSet, XDP, systemd and temporary-file state before migration.
- Test GeDefense in **Observe mode** before enabling active response.
- Keep emergency console access available during any kernel- or firewall-level migration.
- Never migrate block rules blindly without first confirming the management allowlist.

Auto-Punisher and GeDefense use different trust boundaries and operational models. Migration should therefore be handled as a fresh security deployment rather than an in-place script upgrade.

---

## Historical security disclosure

Severe vulnerabilities were identified and corrected during Auto-Punisher development, including classes related to command injection, log forging and unsafe temporary-file handling.

Special thanks to **Will** ([github.com/gtech](https://github.com/gtech)) for responsible disclosure, verification and architectural feedback. That audit was an important catalyst for treating Auto-Punisher transparently as an R&D project and ultimately replacing its architecture with GeDefense.

The historical fixes do not change the current status: Auto-Punisher is archived and receives no future development commitment.

---

## Historical value

Auto-Punisher remains available because it documents the path from an experimental Bash/AWK security engine toward a privilege-separated Rust, Go and eBPF security fabric.

It helped explore:

- where userspace automation is useful and where it becomes unsafe;
- why adversarial parsing should move to memory-safe components;
- how early packet rejection can reduce host resource pressure;
- why detection and destructive response must be separated;
- why one signal must never be enough to authorize process termination;
- why rollback and evidence integrity are part of defense, not optional extras;
- why a local security product should not depend on a cloud control plane.

Its most important result is not the final shell script. Its most important result is **GeDefense**.

---

## License

The historical Auto-Punisher source remains available under **AGPL-3.0-only**, subject to the repository's license file.

Archival status does not revoke or alter the license already granted for published versions.

---

## Support VisionGaiaTechnology

| Method | Address |
|---|---|
| **PayPal** | [paypal.me/dergoldenelotus](https://www.paypal.com/paypalme/dergoldenelotus) |
| **Bitcoin** | `bc1q3ue5gq822tddmkdrek79adlkm36fatat3lz0dm` |
| **ETH** | `0xD37DEfb09e07bD775EaaE9ccDaFE3a5b2348Fe85` |
| **USDT (ERC-20)** | `0xD37DEfb09e07bD775EaaE9ccDaFE3a5b2348Fe85` |

---

## About VisionGaiaTechnology

[VisionGaiaTechnology](https://visiongaiatechnology.de) develops sovereign, local-first and open security architectures with a focus on transparent trust boundaries, memory-safe components, reversible operations and user-controlled infrastructure.

<div align="center">

### Auto-Punisher ends here. GeDefense continues the mission.

## [Continue to VGT GeDefense →](https://github.com/visiongaiatechnology/gedefense)

</div>
