#!/bin/bash
# ==============================================================================
# VISIONGAIA TECHNOLOGY: AUTO-PUNISHER (V4.1.3 - BETA)
# STATUS: DIAMANT VGT SUPREME (DPI & SANITIZATION RESTORED)
# ARCHITECTURE: Nftables Netlink API + Passive Discovery
# UPDATE: Re-Injektion der TCP-Sanitization (MSS, Invalid States, XMAS-Scans)
# ==============================================================================

set -Eeuo pipefail

# --- VGT PARAMETER ---
readonly IP_THRESHOLD=15
readonly RANGE_THRESHOLD_V4=30
readonly RANGE_THRESHOLD_V6=40
readonly BAN_TIMEOUT="24h"
readonly LOG_PREFIX="[VGT-STRIKE]"
readonly NFT_STATE_FILE="/etc/vgt_punisher.nft"
readonly SYSTEMD_UNIT="/etc/systemd/system/vgt-punisher.service"

readonly WHITELIST_V4="{ 127.0.0.1, 0.0.0.0/8 }"
readonly WHITELIST_V6="{ ::1, fe80::/10 }"

# --- VGT HIGH-END UI DESIGN (ANSI) ---
readonly C_RED='\033[38;2;255;51;102m'
readonly C_GREEN='\033[38;2;0;255;153m'
readonly C_YELLOW='\033[38;2;255;204;0m'
readonly C_CYAN='\033[38;2;0;204;255m'
readonly C_PURPLE='\033[38;2;153;51;255m'
readonly C_GRAY='\033[38;2;128;128;128m'
readonly C_RESET='\033[0m'
readonly TUI_SMCUP='\033[?1049h'
readonly TUI_RMCUP='\033[?1049l'
readonly TUI_HOME='\033[H'
readonly TUI_CLEAR_LINE='\033[K'

# ==============================================================================
# 1. PORT DISCOVERY & SURGICAL SETUP
# ==============================================================================
function setup_system() {
    if [[ $EUID -ne 0 ]]; then 
        echo -e "${C_RED}[FATAL] VGT-Protokoll erfordert Root-Privilegien.${C_RESET}" >&2
        exit 1
    fi

    clear
    echo -e "${C_PURPLE}==========================================================${C_RESET}"
    echo -e "${C_CYAN}   VGT APEX PASSIVE DISCOVERY (DPI ENABLED)${C_RESET}"
    echo -e "${C_PURPLE}==========================================================${C_RESET}"

    # --- PORT SCANNING ---
    echo -e "${C_GRAY}[VGT] Scanne aktive System-Ports...${C_RESET}"
    local open_ports
    open_ports=$(ss -tlnp | grep LISTEN | awk '{print $4}' | awk -F: '{print $NF}' | sort -un | tr '\n' ' ' | xargs)
    
    echo -e "${C_GREEN}[INFO] Aktuell offene Ports auf diesem Server:${C_RESET}"
    echo -e "${C_YELLOW}$open_ports${C_RESET}"
    echo ""
    echo -e "${C_CYAN}[?] Welche Ports soll der Punisher BEWACHEN?${C_RESET}"
    echo -e "${C_GRAY}(Standard: 22, 80, 443)${C_RESET}"
    read -p "Monitor-Ports (kommagetrennt): " USER_PORTS
    USER_PORTS=${USER_PORTS:-"22,80,443"}
    
    readonly MONITOR_PORT_SET="{ $(echo "$USER_PORTS" | sed 's/,/, /g') }"

    echo -e "${C_GRAY}[VGT] Initialisiere chirurgische Kernel-Injektion...${C_RESET}"

    # VGT APEX TCP-Stack Hardening
    cat <<EOF > /etc/sysctl.d/99-vgt-punisher.conf
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 65536
net.core.netdev_max_backlog = 65536
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
EOF
    sysctl -q -p /etc/sysctl.d/99-vgt-punisher.conf

    apply_kernel_engine "$MONITOR_PORT_SET"
    
    umask 0177
    nft list table inet vgt_punisher > "$NFT_STATE_FILE"
    echo -e "${C_CYAN}[+] VGT-Matrix inkl. DPI-Schutz persistiert.${C_RESET}"

    # Systemd Service
    cat <<EOF > "$SYSTEMD_UNIT"
[Unit]
Description=VGT Auto-Punisher Kernel Defense
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/nft -f $NFT_STATE_FILE
RemainAfterExit=yes
CapabilityBoundingSet=CAP_NET_ADMIN
ProtectSystem=strict
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable "$SYSTEMD_UNIT" >/dev/null 2>&1
    echo -e "${C_GREEN}[VGT] V4.1.3 DIAMANT aktiv. DPI & Monitoring gestartet.${C_RESET}"
}

# ==============================================================================
# 2. THE SURGICAL ENGINE (DPI INTEGRATED)
# ==============================================================================
function apply_kernel_engine() {
    local monitor_ports=$1
    
    nft -f - <<EOF
add table inet vgt_punisher
flush table inet vgt_punisher

table inet vgt_punisher {
    set denylist_v4 { type ipv4_addr; flags dynamic, timeout; timeout $BAN_TIMEOUT; size 100000; }
    set denylist_v6 { type ipv6_addr; flags dynamic, timeout; timeout $BAN_TIMEOUT; size 100000; }
    set denylist_range_v4 { type ipv4_addr; flags dynamic, timeout; timeout $BAN_TIMEOUT; size 50000; }
    set denylist_range_v6 { type ipv6_addr; flags dynamic, timeout; timeout $BAN_TIMEOUT; size 50000; }

    chain log_drop { limit rate 1/second burst 1 packets log prefix "$LOG_PREFIX [PUNISH] "; counter drop; }

    # --- LAYER 1: DER FILTER & DPI (HOOK PREROUTING) ---
    chain filter_ingress {
        type filter hook prerouting priority -150; policy accept;
        
        # [REINSTATED] DPI & SANITIZATION ENGINE
        ct state invalid counter drop
        tcp flags & (syn|fin) == (syn|fin) counter drop
        tcp flags syn tcp option maxseg size < 536 counter drop

        # Blockade bekannter Akteure
        ip saddr & 255.255.255.0 @denylist_range_v4 counter drop
        ip6 saddr & ffff:ffff:ffff:ffff:: @denylist_range_v6 counter drop
        ip saddr @denylist_v4 counter drop
        ip6 saddr @denylist_v6 counter drop
    }

    # --- LAYER 2: DER DETEKTOR (HOOK INPUT) ---
    chain detector {
        type filter hook input priority 0; policy accept;

        ip saddr { 127.0.0.1, 0.0.0.0/8 } accept
        ip6 saddr { ::1, fe80::/10 } accept

        # Behavioral Analysis
        tcp dport $monitor_ports tcp flags syn ct state { new, untracked } limit rate over $RANGE_THRESHOLD_V4/minute update @denylist_range_v4 { ip saddr & 255.255.255.0 } goto log_drop
        tcp dport $monitor_ports tcp flags syn ct state { new, untracked } limit rate over $IP_THRESHOLD/minute update @denylist_v4 { ip saddr } goto log_drop
    }
}
EOF
}

# ==============================================================================
# 3. NEON MATRIX (TUI)
# ==============================================================================
function cleanup_ui() {
    echo -ne "${TUI_RMCUP}"
    tput cnorm
    [[ -n "${DMESG_PID:-}" ]] && kill "$DMESG_PID" 2>/dev/null || true
    [[ -n "${STATS_PID:-}" ]] && kill "$STATS_PID" 2>/dev/null || true
    [[ -n "${DMESG_BUFFER:-}" ]] && rm -f "$DMESG_BUFFER"
    [[ -n "${STATS_BUFFER:-}" ]] && rm -f "$STATS_BUFFER"
    exit 0
}

function show_ui() {
    echo -ne "${TUI_SMCUP}"
    tput civis
    trap cleanup_ui SIGINT SIGTERM EXIT
    
    DMESG_BUFFER=$(mktemp -p /dev/shm vgt_dmesg.XXXXXX)
    dmesg -w | grep --line-buffered "$LOG_PREFIX" > "$DMESG_BUFFER" &
    DMESG_PID=$!
    
    STATS_BUFFER=$(mktemp -p /dev/shm vgt_stats.XXXXXX)
    echo "0 0 0" > "$STATS_BUFFER"
    
    (
        while true; do
            local stats
            stats=$(nft -a list table inet vgt_punisher 2>/dev/null || echo "")
            local v4_drops=$(echo "$stats" | awk '/ip saddr @denylist_v4/ {for(i=1;i<=NF;i++) if($i=="packets") print $(i+1)}' | head -n 1)
            local r4_drops=$(echo "$stats" | awk '/denylist_range_v4/ {for(i=1;i<=NF;i++) if($i=="packets") print $(i+1)}' | head -n 1)
            local v6_drops=$(echo "$stats" | awk '/ip6 saddr @denylist_v6/ {for(i=1;i<=NF;i++) if($i=="packets") print $(i+1)}' | head -n 1)
            echo "${v4_drops:-0} ${r4_drops:-0} ${v6_drops:-0}" > "${STATS_BUFFER}.tmp"
            mv "${STATS_BUFFER}.tmp" "$STATS_BUFFER"
            sleep 2
        done
    ) &
    STATS_PID=$!

    while true; do
        echo -ne "${TUI_HOME}"
        echo -e "${C_PURPLE}██████████████████████████████████████████████████████████████████████████████${C_RESET}${TUI_CLEAR_LINE}"
        echo -e "${C_CYAN}   VGT AUTO-PUNISHER V4.1.3 - APEX PARADIGM (DPI RESTORED)                 ${C_RESET}${TUI_CLEAR_LINE}"
        echo -e "${C_PURPLE}██████████████████████████████████████████████████████████████████████████████${C_RESET}${TUI_CLEAR_LINE}"
        
        read -r V4_COUNT V4_NET_COUNT V6_COUNT < "$STATS_BUFFER"
        
        echo -e "${TUI_CLEAR_LINE}"
        echo -e "${C_GRAY}⯈ KERNEL DROP METRICS (PACKETS ANNIHILATED)${C_RESET}${TUI_CLEAR_LINE}"
        echo -e "  ${C_RED}IPv4 DROPS (SINGLE IP):    ${V4_COUNT:-0}${C_RESET}${TUI_CLEAR_LINE}"
        echo -e "  ${C_YELLOW}IPv4 DROPS (SUBNET):       ${V4_NET_COUNT:-0}${C_RESET}${TUI_CLEAR_LINE}"
        echo -e "  ${C_CYAN}IPv6 DROPS (SINGLE IP):    ${V6_COUNT:-0}${C_RESET}${TUI_CLEAR_LINE}"

        echo -e "${TUI_CLEAR_LINE}"
        echo -e "${C_PURPLE}──────────────────────────────────────────────────────────────────────────────${C_RESET}${TUI_CLEAR_LINE}"
        echo -e "${C_CYAN}⯈ RECENT KERNEL STRIKES (RATE-LIMITED)${C_RESET}${TUI_CLEAR_LINE}"
        
        local STRIKES
        STRIKES=$(tail -n 8 "$DMESG_BUFFER" | awk -v cyan="${C_CYAN}" -v reset="${C_RESET}" -v clr="${TUI_CLEAR_LINE}" '
        {
            idx = index($0, "VGT-STRIKE]"); 
            if(idx > 0) print "  " cyan substr($0, idx) reset clr
        }')

        if [[ -n "$STRIKES" ]]; then echo -e "$STRIKES"; else echo -e "  ${C_GRAY}DPI & Verhaltensanalyse aktiv. Warte auf Anomalien...${C_RESET}${TUI_CLEAR_LINE}"; fi
        echo -ne "\033[J" 
        sleep 1
    done
}

case "${1:-}" in
    --setup) setup_system ;;
    --ui) show_ui ;;
    *)
        echo -e "${C_YELLOW}VGT Auto-Punisher V4.1.3 (DIAMANT SUPREME)${C_RESET}"
        echo "Nutzung:"
        echo "  $0 --setup        (Interaktives Setup & Port-Discovery)"
        echo "  $0 --ui           (Startet High-End Monitor)"
        exit 1
        ;;
esac
