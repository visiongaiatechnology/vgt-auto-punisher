#!/bin/bash
# ==============================================================================
# VISIONGAIA TECHNOLOGY: AUTO-PUNISHER (V4.4.1 - INTELLIGENT DEFAULT)
# STATUS: DIAMANT VGT SUPREME (MAXIMAL-RESILIENZ)
# ARCHITECTURE: Passive Log-Sensing + DPI Sanitization
# UPDATE: "Enter-to-Protect-All" Logik für die Port-Überwachung integriert.
# ==============================================================================

set -Eeuo pipefail

# --- VGT PARAMETER ---
readonly IP_THRESHOLD=15           # Hits bis zum Einzel-IP Ban
readonly RANGE_THRESHOLD=30        # Hits bis zum /24 Subnetz Ban (v4)
readonly LOG_PREFIX="[VGT_STRIKE]"
readonly IPSET_V4="VGT_BANNED_V4"
readonly IPSET_V6="VGT_BANNED_V6"

# --- VGT MASTER WHITELIST ---
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
    echo -e "${C_CYAN}   VGT APEX HYBRID ELITE INITIALISIERUNG (V4.4.1)${C_RESET}"
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
    
    # VGT INTELLIGENT DEFAULT: Wenn leer, nimm alle erkannten Ports
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

    # --- IPSET SETUP ---
    ipset create "$IPSET_V4" hash:net family inet maxelem 1000000 -exist
    ipset create "$IPSET_V6" hash:net family inet6 maxelem 1000000 -exist 2>/dev/null || true

    # --- FIREWALL INJEKTION ---
    echo -e "${C_GRAY}[VGT] Injektiere Layer-4 Schilde & DPI Engine...${C_RESET}"

    # Ingress Drop für gebannte IPs
    for cmd in "iptables" "ip6tables"; do
        set_name=$([[ "$cmd" == "iptables" ]] && echo "$IPSET_V4" || echo "$IPSET_V6")
        if ! $cmd -C INPUT -m set --match-set "$set_name" src -j DROP >/dev/null 2>&1; then
            $cmd -I INPUT 1 -m set --match-set "$set_name" src -j DROP
        fi
    done

    # DPI Sanitization
    if ! iptables -C INPUT -m state --state INVALID -j DROP >/dev/null 2>&1; then
        iptables -I INPUT 2 -m state --state INVALID -j DROP
        iptables -I INPUT 3 -p tcp --tcp-flags ALL FIN,PSH,URG -j DROP 
        iptables -I INPUT 4 -p tcp --tcp-flags ALL NONE -j DROP        
        iptables -I INPUT 5 -p tcp --tcp-flags SYN,RST SYN -m tcpmss ! --mss 536:65535 -j DROP
    fi

    # Scoped Anomaly Sensor
    iptables -D INPUT -p tcp -m multiport --dports "$USER_PORTS" ! -i lo --syn -j LOG --log-prefix "$LOG_PREFIX " 2>/dev/null || true
    iptables -I INPUT 6 -p tcp -m multiport --dports "$USER_PORTS" ! -i lo --syn -j LOG --log-prefix "$LOG_PREFIX "

    echo -e "${C_GREEN}[VGT] Schilde stehen. Überwachung für: $USER_PORTS${C_RESET}"
    sleep 1
}

# ==============================================================================
# 2. DIE JAGD-LOGIK (V3 ARCHITECTURE + V4 UI)
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

    journalctl -kf --grep="$LOG_PREFIX" | awk -v ip_limit="$IP_THRESHOLD" -v range_limit="$RANGE_THRESHOLD" -v set_v4="$IPSET_V4" -v set_v6="$IPSET_V6" -v wl="$WHITELIST_IPS" '
        BEGIN {
            c_res = "\033[0m"; c_gry = "\033[38;2;128;128;128m"; c_cyn = "\033[38;2;0;204;255m"; 
            c_ylw = "\033[38;2;255;204;0m"; c_red = "\033[38;2;255;51;102m"; c_pur = "\033[38;2;153;51;255m";
            
            print c_pur "██████████████████████████████████████████████████████████████████████████████" c_res;
            print c_cyn "   VGT AUTO-PUNISHER V4.4.1 - HYBRID SUPREME (INTELLIGENT DEFAULT)          " c_res;
            print c_pur "██████████████████████████████████████████████████████████████████████████████" c_res;
            print c_gry "ZEITSTEMPEL         | QUELL-IP                                | HITS | RANGE" c_res;
            print c_gry "------------------------------------------------------------------------------" c_res;
        }
        /SRC=/ {
            match($0, /SRC=([0-9a-fA-F:.]+)/, arr);
            ip = arr[1];
            if (ip ~ /^[0:]+$/) ip = "::";

            if (index(" " wl " ", " " ip " ") > 0 || ip == "" || tolower(ip) ~ /^fe80:/) next;

            zeit = $1 " " $2 " " $3;

            if (ip ~ /:/) {
                is_v6 = 1; target_set = set_v6; range = "IPv6_STRIKE"; save_cmd = "ip6tables-save > /etc/iptables/rules.v6";
            } else {
                is_v6 = 0; target_set = set_v4; save_cmd = "iptables-save > /etc/iptables/rules.v4";
                split(ip, octets, "."); range = octets[1] "." octets[2] "." octets[3] ".0/24";
            }

            ip_count[ip]++;
            if (!is_v6) range_count[range]++;

            h_col = (ip_count[ip] >= (ip_limit - 3)) ? c_red : c_ylw;
            r_col = (!is_v6 && range_count[range] >= (range_limit - 5)) ? c_red : c_ylw;

            printf "%s%-19s%s | %s%-39s%s | %s%4d%s | %s%4d%s\n", c_gry, zeit, c_res, c_cyn, ip, c_res, h_col, ip_count[ip], c_res, r_col, (is_v6 ? 0 : range_count[range]), c_res;

            if (ip_count[ip] == ip_limit) {
                print "\n" c_red "[!!!] TERMINIERT: IP " ip " hingerichtet." c_res;
                system("ipset add " target_set " " ip " -exist");
                system(save_cmd " 2>/dev/null || true");
            }

            if (!is_v6 && range_count[range] == range_limit) {
                print "\n" c_red "[!!!] INFRA-SCHLAG: Range " range " terminiert." c_res;
                system("ipset add " target_set " " range " -exist");
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
