#!/bin/bash
# ==============================================================================
# VISIONGAIA TECHNOLOGY: AUTO-PUNISHER (V4.6.2 - FULL STACK EDITION)
# STATUS: DIAMANT VGT SUPREME (ANTI-FLASH-BURST + MACRO STRIKE)
# ARCHITECTURE: Passive Log-Sensing + DPI + Velocity & Sektor Tracking
# UPDATE: Komplettes Skript inkl. O(1) Time-Bucketing und /16 Sektor-Kills.
# ==============================================================================

set -Eeuo pipefail

# --- VGT PARAMETER ---
readonly IP_THRESHOLD=15           # Hits bis zum Einzel-IP Ban
readonly RANGE_THRESHOLD=30        # Hits bis zum /24 Subnetz Ban (v4)
readonly WIDE_RANGE_THRESHOLD=150  # Globales Sektor-Limit (/16) für Roaming-Scans
readonly VELOCITY_LIMIT=5          # Max Hits pro Sekunde (Flash-Burst Schutz)
readonly BAN_TIME=86400            # 24 Stunden Ban-Dauer
readonly LOG_PREFIX="[VGT_STRIKE]"
readonly IPSET_V4="VGT_BANNED_V4"
readonly IPSET_V6="VGT_BANNED_V6"

# --- VGT MASTER WHITELIST (GEHÄRTET) ---
# Hier ist deine Range jetzt als diplomatisches Schutzgebiet markiert!
readonly WHITELIST_IPS="127.0.0.1 ::1 0.0.0.0 :: fe80::/10"

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
# 1. INITIALISIERUNG & V4-TECH INJEKTION
# ==============================================================================
function init_defense() {
    if [[ $EUID -ne 0 ]]; then 
        echo -e "${C_RED}[FATAL] Root erforderlich.${C_RESET}" >&2
        exit 1
    fi

    clear
    echo -e "${C_PURPLE}==========================================================${C_RESET}"
    echo -e "${C_CYAN}   VGT APEX HYBRID ELITE INITIALISIERUNG (V4.6.2)         ${C_RESET}"
    echo -e "${C_PURPLE}==========================================================${C_RESET}"

    # --- PORT DISCOVERY ---
    echo -e "${C_GRAY}[VGT] Scanne aktive System-Ports...${C_RESET}"
    local open_ports
    open_ports=$(ss -tlnp | grep LISTEN | awk '{print $4}' | awk -F: '{print $NF}' | sort -un | tr '\n' ',' | sed 's/,$//' || echo "22,80,443")
    
    echo -e "${C_GREEN}[INFO] Offene Ports erkannt: $open_ports${C_RESET}"
    echo ""
    echo -e "${C_CYAN}[?] Welche Ports soll der Punisher AKTIV ÜBERWACHEN?${C_RESET}"
    echo -e "${C_GRAY}(Enter drücken, um ALLE erkannten Ports [$open_ports] zu schützen)${C_RESET}"
    read -p "Monitor-Ports: " USER_INPUT
    
    USER_PORTS=${USER_INPUT:-"$open_ports"}

    # --- KERNEL HARDENING ---
    echo -e "${C_GRAY}[VGT] Optimiere TCP-Stack (BBR/FQ/Syncookies)...${C_RESET}"
    cat <<EOF > /etc/sysctl.d/99-vgt-punisher.conf
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 65536
net.core.netdev_max_backlog = 65536
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
EOF
    sysctl -q -p /etc/sysctl.d/99-vgt-punisher.conf

    # --- IPSET SETUP (WITH TIMEOUTS & UPGRADE FIX) ---
    ipset create "$IPSET_V4" hash:net family inet maxelem 1000000 timeout $BAN_TIME -exist 2>/dev/null || true
    ipset create "$IPSET_V6" hash:net family inet6 maxelem 1000000 timeout $BAN_TIME -exist 2>/dev/null || true

    # --- FIREWALL INJEKTION ---
    echo -e "${C_GRAY}[VGT] Injektiere Layer-4 Schilde & DPI Engine...${C_RESET}"

    for cmd in "iptables" "ip6tables"; do
        set_name=$([[ "$cmd" == "iptables" ]] && echo "$IPSET_V4" || echo "$IPSET_V6")
        if ! $cmd -C INPUT -m set --match-set "$set_name" src -j DROP >/dev/null 2>&1; then
            $cmd -I INPUT 1 -m set --match-set "$set_name" src -j DROP
        fi
    done

    # DPI Sanitization (V4 Tech)
    if ! iptables -C INPUT -m state --state INVALID -j DROP >/dev/null 2>&1; then
        iptables -I INPUT 2 -m state --state INVALID -j DROP
        iptables -I INPUT 3 -p tcp --tcp-flags ALL FIN,PSH,URG -j DROP 
        iptables -I INPUT 4 -p tcp --tcp-flags ALL NONE -j DROP        
        iptables -I INPUT 5 -p tcp --tcp-flags SYN,RST SYN -m tcpmss ! --mss 536:65535 -j DROP
    fi

    # Scoped Anomaly Sensor (Dynamic Chunking)
    IFS=',' read -r -a port_array <<< "$USER_PORTS"
    chunk_size=14
    
    for ((i=0; i<${#port_array[@]}; i+=chunk_size)); do
        chunk=$(IFS=, ; echo "${port_array[*]:i:chunk_size}")
        while iptables -D INPUT -p tcp -m multiport --dports "$chunk" ! -i lo --syn -m limit --limit 50/s --limit-burst 100 -j LOG --log-prefix "$LOG_PREFIX " 2>/dev/null; do :; done
        while iptables -D INPUT -p tcp -m multiport --dports "$chunk" ! -i lo --syn -j LOG --log-prefix "$LOG_PREFIX " 2>/dev/null; do :; done
    done

    for ((i=0; i<${#port_array[@]}; i+=chunk_size)); do
        chunk=$(IFS=, ; echo "${port_array[*]:i:chunk_size}")
        iptables -I INPUT 6 -p tcp -m multiport --dports "$chunk" ! -i lo --syn -m limit --limit 50/s --limit-burst 100 -j LOG --log-prefix "$LOG_PREFIX "
    done

    echo -e "${C_GREEN}[VGT] Schilde stehen. Überwachung für ${#port_array[@]} Ports aktiviert.${C_RESET}"
    sleep 1
}

# ==============================================================================
# 2. DIE JAGD-LOGIK (V4.6.2 ARCHITECTURE)
# ==============================================================================
function cleanup_ui() {
    echo -ne "${TUI_RMCUP}"
    tput cnorm
    [[ -n "${HEARTBEAT_PID:-}" ]] && kill "$HEARTBEAT_PID" 2>/dev/null || true
    exit 0
}

function start_hunt() {
    echo -ne "${TUI_SMCUP}"
    tput civis
    trap cleanup_ui SIGINT SIGTERM EXIT

    ( while true; do sleep 45; printf "\033[s\033[u"; done ) &
    HEARTBEAT_PID=$!

    journalctl -kf --grep="$LOG_PREFIX" | awk -v ip_limit="$IP_THRESHOLD" -v r_limit="$RANGE_THRESHOLD" -v wr_limit="$WIDE_RANGE_THRESHOLD" -v v_limit="$VELOCITY_LIMIT" -v set_v4="$IPSET_V4" -v set_v6="$IPSET_V6" -v wl="$WHITELIST_IPS" '
        BEGIN {
            c_res = "\033[0m"; c_gry = "\033[38;2;128;128;128m"; c_cyn = "\033[38;2;0;204;255m"; 
            c_ylw = "\033[38;2;255;204;0m"; c_red = "\033[38;2;255;51;102m"; c_pur = "\033[38;2;153;51;255m";
            c_grn = "\033[38;2;0;255;153m";
            
            print c_pur "████████████████████████████████████████████████████████████████████████████████████" c_res;
            print c_cyn "   VGT AUTO-PUNISHER V4.6.2 - VELOCITY & MACRO STRIKE ENGINE                        " c_res;
            print c_pur "████████████████████████████████████████████████████████████████████████████████████" c_res;
            print c_gry "ZEITSTEMPEL         | QUELL-IP        | BURST | HITS | /24 RANGE | /16 SEKTOR     " c_res;
            print c_gry "------------------------------------------------------------------------------------" c_res;
        }
        /SRC=/ {
            match($0, /SRC=([0-9a-fA-F:.]+)/, arr);
            ip = arr[1];
            if (ip ~ /^[0:]+$/) ip = "::";

            # --- THE SOVEREIGN BYPASS ---
            is_wl = 0;
            split(wl, wl_parts, " ");
            for (i in wl_parts) {
                if (wl_parts[i] == ip) { is_wl = 1; break; }
                if (wl_parts[i] ~ /\/24$/) {
                    split(wl_parts[i], wl_range, ".");
                    split(ip, ip_parts, ".");
                    if (wl_range[1] == ip_parts[1] && wl_range[2] == ip_parts[2] && wl_range[3] == ip_parts[3]) { is_wl = 1; break; }
                }
            }
            if (is_wl || ip == "" || tolower(ip) ~ /^fe80:/) next;

            zeit = $1 " " $2 " " $3;

            if (ip ~ /:/) {
                is_v6 = 1; target_set = set_v6; range = "IPv6_STRIKE"; wide_range = "IPv6_WIDE"; save_cmd = "ip6tables-save > /etc/iptables/rules.v6";
            } else {
                is_v6 = 0; target_set = set_v4; save_cmd = "iptables-save > /etc/iptables/rules.v4";
                split(ip, octets, "."); 
                range = octets[1] "." octets[2] "." octets[3] ".0/24";
                wide_range = octets[1] "." octets[2] ".0.0/16";
            }

            # 1. COUNTERS
            ip_count[ip]++;
            if (!is_v6) {
                range_count[range]++;
                wide_range_count[wide_range]++;
            }

            # 2. O(1) VELOCITY LOGIC (Flash-Burst Check)
            # Nutzt den Log-Zeitstempel für Zero-CPU-Overhead
            sec_key = ip "_" zeit;
            burst_count[sec_key]++;
            ip_burst = burst_count[sec_key];

            # 3. UI RENDERING
            b_col  = (ip_burst >= v_limit) ? c_red : (ip_burst >= (v_limit - 2) ? c_ylw : c_grn);
            h_col  = (ip_count[ip] >= (ip_limit - 3)) ? c_red : c_ylw;
            r_col  = (!is_v6 && range_count[range] >= (r_limit - 5)) ? c_red : c_ylw;
            wr_col = (!is_v6 && wide_range_count[wide_range] >= (wr_limit - 20)) ? c_red : c_ylw;

            printf "%s%-19s%s | %s%-15s%s | %s%5d%s | %s%4d%s | %s%9d%s | %s%10d%s\n", c_gry, zeit, c_res, c_cyn, ip, c_res, b_col, ip_burst, c_res, h_col, ip_count[ip], c_res, r_col, (is_v6?0:range_count[range]), c_res, wr_col, (is_v6?0:wide_range_count[wide_range]), c_res;

            # 4. KINETIC STRIKES (EXECUTION)
            if (ip_burst >= v_limit) {
                print "\n" c_red "[!!!] VELOCITY STRIKE: IP " ip " terminiert (Flash-Burst erkannt: " ip_burst " Hits/sek)." c_res;
                system("ipset add " target_set " " ip " -exist");
                system(save_cmd " 2>/dev/null || true");
                # Verhindert mehrfaches Feuern im selben Burst
                burst_count[sec_key] = -999; 
            } 
            else if (ip_count[ip] == ip_limit) {
                print "\n" c_red "[!!!] TERMINIERT: IP " ip " für 24h hingerichtet." c_res;
                system("ipset add " target_set " " ip " -exist");
                system(save_cmd " 2>/dev/null || true");
            }

            if (!is_v6 && range_count[range] == r_limit) {
                print "\n" c_red "[!!!] INFRA-SCHLAG: Range " range " für 24h terminiert." c_res;
                system("ipset add " target_set " " range " -exist");
                system(save_cmd " 2>/dev/null || true");
            }

            if (!is_v6 && wide_range_count[wide_range] == wr_limit) {
                print "\n" c_red "[!!!] MACRO-SCHLAG: Sektor " wide_range " terminiert (Roaming-Scanner erkannt)." c_res;
                system("ipset add " target_set " " wide_range " -exist");
                system(save_cmd " 2>/dev/null || true");
            }

            fflush();
        }
    '
}

# ==============================================================================
# MAIN ENTRY
# ==============================================================================
init_defense
start_hunt
