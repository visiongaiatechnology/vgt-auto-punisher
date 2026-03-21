#!/bin/bash
# ==============================================================================
# VISIONGAIA TECHNOLOGY: AUTO-PUNISHER (V5.0.0 - SUPREME L7 GHOST EDITION)
# STATUS: DIAMANT VGT SUPREME (ANTI-FLASH-BURST + MACRO STRIKE + L7 SNI DPI)
# ARCHITECTURE: Passive L4 SYN-Sensing + Active L7 Raw-Socket Ghost Payload
# UPDATE: L7 Domain Whitelisting, Zero-Tolerance IP-Direct Kills, UI Refactoring
# ==============================================================================

set -Eeuo pipefail

# --- VGT PARAMETER ---
readonly IP_THRESHOLD=15           # Hits bis zum Einzel-IP Ban (Für legitime Domains)
readonly L7_STRIKE_THRESHOLD=3     # Toleranz für fehlerhafte/leere SNI (Background-Noise Mobile)
readonly RANGE_THRESHOLD=30        # Hits bis zum /24 Subnetz Ban (v4)
readonly WIDE_RANGE_THRESHOLD=150  # Globales Sektor-Limit (/16)
readonly VELOCITY_LIMIT=5          # Max Hits pro Sekunde
readonly BAN_TIME=86400            # 24 Stunden Ban-Dauer
readonly LOG_PREFIX="[VGT_STRIKE]"
readonly L7_PREFIX="[VGT_L7]"
readonly IPSET_V4="VGT_BANNED_V4"
readonly IPSET_V6="VGT_BANNED_V6"



# --- VGT MASTER WHITELISTS (GEHÄRTET) ---

readonly WHITELIST_IPS="127.0.0.1 ::1 0.0.0.0 :: fe80::/10"

# HIER DEINE ERLAUBTEN DOMAINS EINTRAGEN (Leerzeichen getrennt)

readonly WHITELIST_DOMAINS="example.de www.example.de" 


# --- VGT HIGH-END UI DESIGN (ANSI) ---
readonly C_RED='\033[38;2;255;51;102m'
readonly C_GREEN='\033[38;2;0;255;153m'
readonly C_YELLOW='\033[38;2;255;204;0m'
readonly C_CYAN='\033[38;2;0;204;255m'
readonly C_PURPLE='\033[38;2;153;51;255m'
readonly C_GRAY='\033[38;2;128;128;128m'
readonly C_WHITE='\033[38;2;255;255;255m'
readonly C_RESET='\033[0m'
readonly TUI_SMCUP='\033[?1049h'
readonly TUI_RMCUP='\033[?1049l'

# ==============================================================================
# 0. THE L7 GHOST SENSOR (PYTHON RAW SOCKET PAYLOAD)
# ==============================================================================
# Extrahiert kompromisslos SNI und Host-Header auf Netzwerkebene ohne Overhead.
function deploy_l7_ghost() {
    cat << 'EOF' > /tmp/vgt_l7_ghost.py
import socket, struct, sys, syslog, time

syslog.openlog(ident="VGT_L7")
CACHE = {}

def parse_sni(payload):
    try:
        if len(payload) < 43 or payload[0] != 22 or payload[5] != 1: return None
        offset = 44 + payload[43]
        offset += 2 + struct.unpack('>H', payload[offset:offset+2])[0]
        offset += 1 + payload[offset]
        if offset + 2 > len(payload): return None
        ext_total_len = struct.unpack('>H', payload[offset:offset+2])[0]
        offset += 2
        end = offset + ext_total_len
        while offset < end:
            ext_type, ext_len = struct.unpack('>HH', payload[offset:offset+4])
            offset += 4
            if ext_type == 0:
                name_type = payload[offset+2]
                name_len = struct.unpack('>H', payload[offset+3:offset+5])[0]
                if name_type == 0: return payload[offset+5:offset+5+name_len].decode('utf-8')
            offset += ext_len
    except: pass
    return "DIRECT_IP_OR_MALFORMED"

def parse_http(payload):
    try:
        lines = payload.split(b'\r\n')
        for line in lines:
            if line.lower().startswith(b'host:'):
                host = line.split(b':')[1].strip().decode('utf-8')
                return host.split(':')[0]
    except: pass
    return "DIRECT_IP_OR_MALFORMED"

try:
    s = socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.ntohs(0x0003))
    while True:
        packet = s.recvfrom(65536)[0]
        eth_proto = struct.unpack('!H', packet[12:14])[0]
        offset = 14
        if eth_proto == 0x0800:
            iph = struct.unpack('!BBHHHBBH4s4s', packet[offset:offset+20])
            if iph[6] != 6: continue
            iph_length = (iph[0] & 0xF) * 4
            src_ip = socket.inet_ntoa(iph[8])
            offset += iph_length
        elif eth_proto == 0x86dd:
            iph = struct.unpack('!IHBB16s16s', packet[offset:offset+40])
            if iph[2] != 6: continue
            src_ip = socket.inet_ntop(socket.AF_INET6, iph[4])
            offset += 40
        else: continue

        tcph = struct.unpack('!HHLLBBHHH', packet[offset:offset+20])
        dst_port = tcph[1]
        if dst_port not in (80, 443, 8443): continue

        tcph_length = tcph[4] >> 4
        h_size = offset + tcph_length * 4
        payload = packet[h_size:]
        if len(payload) == 0: continue

        domain = parse_sni(payload) if dst_port in (443, 8443) else parse_http(payload)
        if not domain: continue

        # Anti-Log-Spam Cache für legitime User (1 Sekunde pro IP/Domain)
        cache_key = f"{src_ip}_{domain}"
        now = time.time()
        if cache_key in CACHE and (now - CACHE[cache_key]) < 1.0: continue
        CACHE[cache_key] = now

        syslog.syslog(f"SRC={src_ip} DPT={dst_port} DOMAIN={domain}")

except Exception as e:
    syslog.syslog(f"CRITICAL ERROR: {e}")
EOF
    # Start Ghost Payload in Background
    pkill -f vgt_l7_ghost.py || true
    nohup python3 /tmp/vgt_l7_ghost.py >/dev/null 2>&1 &
    L7_PID=$!
    echo -e "${C_GREEN}[VGT] L7 Ghost Payload (SNI-Sniffer) aktiv. PID: $L7_PID${C_RESET}"
}

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
    echo -e "${C_CYAN}   VGT APEX HYBRID ELITE INITIALISIERUNG (V5.0.0)         ${C_RESET}"
    echo -e "${C_PURPLE}==========================================================${C_RESET}"

    # --- PORT DISCOVERY ---
    echo -e "${C_GRAY}[VGT] Scanne aktive System-Ports...${C_RESET}"
    local open_ports
    open_ports=$(ss -tlnp | grep LISTEN | awk '{print $4}' | awk -F: '{print $NF}' | sort -un | tr '\n' ',' | sed 's/,$//' || echo "22,80,443")
    
    # Split Ports: L4 (SYN Tracking) vs L7 (Domain Tracking)
    L7_PORTS="80,443,8443"
    L4_PORTS=$(echo "$open_ports" | tr ',' '\n' | grep -vE "^(80|443|8443)$" | tr '\n' ',' | sed 's/,$//')

    echo -e "${C_GREEN}[INFO] L4 Infrastruktur-Ports (SYN-Watch): ${L4_PORTS:-NONE}${C_RESET}"
    echo -e "${C_GREEN}[INFO] L7 Web-Ports (SNI-DPI): $L7_PORTS${C_RESET}"

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
    ipset create "$IPSET_V4" hash:net family inet maxelem 1000000 timeout $BAN_TIME -exist 2>/dev/null || true
    ipset create "$IPSET_V6" hash:net family inet6 maxelem 1000000 timeout $BAN_TIME -exist 2>/dev/null || true

    # --- FIREWALL INJEKTION ---
    echo -e "${C_GRAY}[VGT] Injektiere Layer-4 Schilde...${C_RESET}"
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

    # L4 Scoped Anomaly Sensor (Dynamic Chunking for non-web ports)
    if [[ -n "$L4_PORTS" ]]; then
        IFS=',' read -r -a port_array <<< "$L4_PORTS"
        chunk_size=14
        for ((i=0; i<${#port_array[@]}; i+=chunk_size)); do
            chunk=$(IFS=, ; echo "${port_array[*]:i:chunk_size}")
            while iptables -D INPUT -p tcp -m multiport --dports "$chunk" ! -i lo --syn -m limit --limit 50/s --limit-burst 100 -j LOG --log-prefix "$LOG_PREFIX " 2>/dev/null; do :; done
            while iptables -D INPUT -p tcp -m multiport --dports "$chunk" ! -i lo --syn -j LOG --log-prefix "$LOG_PREFIX " 2>/dev/null; do :; done
            iptables -I INPUT 6 -p tcp -m multiport --dports "$chunk" ! -i lo --syn -m limit --limit 50/s --limit-burst 100 -j LOG --log-prefix "$LOG_PREFIX "
        done
    fi

    deploy_l7_ghost
    sleep 1
}

# ==============================================================================
# 2. DIE JAGD-LOGIK (V5.0.0 HYBRID KERNEL)
# ==============================================================================
function cleanup_ui() {
    echo -ne "${TUI_RMCUP}"
    tput cnorm
    [[ -n "${HEARTBEAT_PID:-}" ]] && kill "$HEARTBEAT_PID" 2>/dev/null || true
    pkill -f vgt_l7_ghost.py || true
    rm -f /tmp/vgt_l7_ghost.py
    exit 0
}

function start_hunt() {
    echo -ne "${TUI_SMCUP}"
    tput civis
    trap cleanup_ui SIGINT SIGTERM EXIT

    ( while true; do sleep 45; printf "\033[s\033[u"; done ) &
    HEARTBEAT_PID=$!

    # Verknüpfung beider Sensoren: Iptables (L4 Kernel) & Python-Ghost (L7 User-Space)
    journalctl -f --grep="($LOG_PREFIX|$L7_PREFIX)" | awk -v ip_limit="$IP_THRESHOLD" -v l7_limit="$L7_STRIKE_THRESHOLD" -v r_limit="$RANGE_THRESHOLD" -v wr_limit="$WIDE_RANGE_THRESHOLD" -v v_limit="$VELOCITY_LIMIT" -v set_v4="$IPSET_V4" -v set_v6="$IPSET_V6" -v wl="$WHITELIST_IPS" -v wl_dom="$WHITELIST_DOMAINS" '
        BEGIN {
            c_res = "\033[0m"; c_gry = "\033[38;2;128;128;128m"; c_cyn = "\033[38;2;0;204;255m"; 
            c_ylw = "\033[38;2;255;204;0m"; c_red = "\033[38;2;255;51;102m"; c_pur = "\033[38;2;153;51;255m";
            c_grn = "\033[38;2;0;255;153m"; c_wht = "\033[38;2;255;255;255m"; c_bld = "\033[1m";
            
            # Mathematisch kalibrierte Tabellen-Architektur (Exakt 116 Zeichen innere Breite)
            sep_8  = "────────"; 
            sep_10 = "──────────"; 
            sep_13 = "─────────────"; 
            sep_17 = "─────────────────"; 
            sep_20 = "────────────────────"; 
            
            top_line = ""; for(i=0;i<116;i++) top_line = top_line "─";
            mid_line = sep_10 "┼" sep_17 "┼" sep_20 "┼" sep_13 "┼" sep_10 "┼" sep_8 "┼" sep_10 "┼" sep_10 "┼" sep_10;
            head_line = sep_10 "┬" sep_17 "┬" sep_20 "┬" sep_13 "┬" sep_10 "┬" sep_8 "┬" sep_10 "┬" sep_10 "┬" sep_10;
            bot_line = sep_10 "┴" sep_17 "┴" sep_20 "┴" sep_13 "┴" sep_10 "┴" sep_8 "┴" sep_10 "┴" sep_10 "┴" sep_10;

            # Whitelist Arrays
            split(wl_dom, wl_dom_arr, " ");
            for(i in wl_dom_arr) valid_domains[tolower(wl_dom_arr[i])] = 1;

            print c_cyn "╭" top_line "╮" c_res;
            printf "%s│%s%s%-116s%s%s│%s\n", c_cyn, c_pur, c_bld, "   VGT AUTO-PUNISHER V5.0.2 - DIAMANT SUPREME (L7 SNI GHOST-SENSOR)", c_res, c_cyn, c_res;
            print c_cyn "├" head_line "┤" c_res;
            print c_cyn "│" c_gry " ZEIT     " c_cyn "│" c_gry " QUELL-IP        " c_cyn "│" c_gry " DOMAIN (SNI/L7)    " c_cyn "│" c_gry " ZIEL (PORT) " c_cyn "│" c_gry "  BURST   " c_cyn "│" c_gry "  HITS  " c_cyn "│" c_gry "  R-HITS  " c_cyn "│" c_gry "  S-HITS  " c_cyn "│" c_gry " STATUS   " c_cyn "│" c_res;
            print c_cyn "├" mid_line "┤" c_res;
        }

        function print_kill(icon, text, color) {
            raw_msg = icon " " text;
            pad = 114 - length(raw_msg); # 116 Gesamte Breite minus 2 Rand-Leerzeichen
            if (pad < 0) pad = 0;
            printf "%s├%s┤%s\n", c_cyn, bot_line, c_res;
            printf "%s│ %s%s%s%*s %s│%s\n", c_cyn, color, raw_msg, c_res, pad, "", c_cyn, c_res;
            printf "%s├%s┤%s\n", c_cyn, head_line, c_res;
        }

        /SRC=/ {
            match($0, /SRC=([0-9a-fA-F:.]+)/, arr);
            ip = arr[1];
            if (ip ~ /^[0:]+$/) ip = "::";

            # --- THE SOVEREIGN BYPASS (IP WHITELIST) ---
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

            # Zeit-Formatierung (nur hh:mm:ss für kompakte UI)
            zeit = $3;

            # IPv4 / IPv6 Logik
            if (ip ~ /:/) {
                is_v6 = 1; target_set = set_v6; range = "IPv6_STRIKE"; wide_range = "IPv6_WIDE"; save_cmd = "ip6tables-save > /etc/iptables/rules.v6";
            } else {
                is_v6 = 0; target_set = set_v4; save_cmd = "iptables-save > /etc/iptables/rules.v4";
                split(ip, octets, "."); 
                range = octets[1] "." octets[2] "." octets[3] ".0/24";
                wide_range = octets[1] "." octets[2] ".0.0/16";
            }

            # PORT MAPPING
            match($0, /DPT=([0-9]+)/, arr_dpt); dpt = arr_dpt[1];
            tgt_color = c_gry;
            if (dpt == "80" || dpt == "443" || dpt == "8443") { tgt_color = c_cyn; svc = "[WEB]"; }
            else if (dpt == "22" || dpt == "2222") { tgt_color = c_pur; svc = "[SSH]"; }
            else if (dpt == "21") { tgt_color = c_ylw; svc = "[FTP]"; }
            else if (dpt == "3306" || dpt == "888") { tgt_color = c_ylw; svc = "[PNL]"; }
            else { tgt_color = c_wht; svc = "[NET]"; }
            tgt_formatted = sprintf("%-11.11s", (dpt " " svc));

            # L7 DOMAIN MAPPING
            domain_label = "N/A (L4 SYN)";
            domain_col = c_gry;
            is_l7_strike = 0;
            
            if ($0 ~ /VGT_L7/) {
                match($0, /DOMAIN=([^ ]+)/, arr_dom); 
                domain_val = arr_dom[1];
                
                if (valid_domains[tolower(domain_val)]) {
                    domain_label = domain_val;
                    domain_col = c_grn; # Legit Domain
                } else {
                    domain_label = substr(domain_val, 1, 18);
                    domain_col = c_red;
                    l7_viol[ip]++;
                    if (l7_viol[ip] >= l7_limit) {
                        is_l7_strike = 1; # Illegitime Domain Limit erreicht
                    }
                }
            }

            # COUNTERS
            ip_count[ip]++;
            if (!is_v6) {
                range_count[range]++;
                wide_range_count[wide_range]++;
            }

            # VELOCITY
            sec_key = ip "_" $1 $2 $3;
            burst_count[sec_key]++;
            ip_burst = burst_count[sec_key];

            # STATUS RESOLUTION
            status_msg = "TRACKING"; status_col = c_gry;
            if (is_l7_strike) { status_msg = "DOM-KILL"; status_col = c_red; }
            else if (svc == "[SSH]") { status_msg = "SSH-KILL"; status_col = c_pur; }
            else if (ip_burst >= v_limit) { status_msg = "FLASH"; status_col = c_red; }
            else if (l7_viol[ip] > 0 && l7_viol[ip] < l7_limit) { status_msg = "L7-WARN"; status_col = c_ylw; }
            else if (ip_count[ip] >= ip_limit) { status_msg = "IP-KILL"; status_col = c_red; }
            else if (!is_v6 && range_count[range] >= r_limit) { status_msg = "RNG-KILL"; status_col = c_red; }
            else if (!is_v6 && wide_range_count[wide_range] >= wr_limit) { status_msg = "MAC-KILL"; status_col = c_pur; }

            # COMPACT UI COLORS
            b_col  = (ip_burst >= v_limit) ? c_red : (ip_burst >= (v_limit - 2) ? c_ylw : c_grn);
            h_col  = (ip_count[ip] >= (ip_limit - 3)) ? c_red : c_ylw;
            r_col  = (!is_v6 && range_count[range] >= (r_limit - 5)) ? c_red : c_ylw;
            wr_col = (!is_v6 && wide_range_count[wide_range] >= (wr_limit - 20)) ? c_red : c_ylw;

            # ZOMBIE-TRAFFIC FILTER (Für Kinetische Nachbeben)
            disp_b = (ip_burst < 0) ? "XXX" : (ip_burst > 999 ? 999 : ip_burst);
            disp_h = (ip_count[ip] < 0) ? "XXX" : (ip_count[ip] > 999 ? 999 : ip_count[ip]);
            disp_r = is_v6 ? 0 : ((range_count[range] < 0) ? "XXX" : (range_count[range] > 999 ? 999 : range_count[range]));
            disp_w = is_v6 ? 0 : ((wide_range_count[wide_range] < 0) ? "XXX" : (wide_range_count[wide_range] > 999 ? 999 : wide_range_count[wide_range]));

            # ROW RENDER (Mathematische Perfektion + Zombie Filter)
            printf "%s│%s %s%-8.8s%s %s│%s %s%-15.15s%s %s│%s %s%-18.18s%s %s│%s %s%-11.11s%s %s│%s   %s%3s%s    %s│%s  %s%3s%s   %s│%s   %s%3s%s    %s│%s   %s%3s%s    %s│%s %s%-8.8s%s %s│%s\n", \
                c_cyn, c_res, c_gry, zeit, c_res, \
                c_cyn, c_res, c_wht, ip, c_res, \
                c_cyn, c_res, domain_col, domain_label, c_res, \
                c_cyn, c_res, tgt_color, tgt_formatted, c_res, \
                c_cyn, c_res, b_col, disp_b, c_res, \
                c_cyn, c_res, h_col, disp_h, c_res, \
                c_cyn, c_res, r_col, disp_r, c_res, \
                c_cyn, c_res, wr_col, disp_w, c_res, \
                c_cyn, c_res, status_col, status_msg, c_res, \
                c_cyn, c_res;

            # --- KINETIC STRIKES (EXECUTION) ---
            
            # 0. L7 DOMAIN STRIKE (Instant Kill bei direkt IP / Falscher Domain)
            if (is_l7_strike && !killed[ip]) {
                killed[ip] = 1;
                msg = "SNI/HOST VIOLATION: IP " ip " terminiert (" l7_viol[ip] "x illegaler L7 Zugriff).";
                print_kill("[🎯]", msg, c_red);
                system("ipset add " target_set " " ip " -exist");
                system(save_cmd " 2>/dev/null || true");
                ip_count[ip] = -999; burst_count[sec_key] = -999;
            }
            # 1. SSH ZERO-TOLERANCE STRIKE
            else if (svc == "[SSH]" && !killed[ip]) {
                killed[ip] = 1;
                msg = "ZERO-TOLERANCE: IP " ip " terminiert (Illegaler L4 SSH-Zugriff).";
                print_kill("[🔐]", msg, c_pur);
                system("ipset add " target_set " " ip " -exist");
                system(save_cmd " 2>/dev/null || true");
                ip_count[ip] = -999; burst_count[sec_key] = -999;
            }
            # 2. Flash-Burst Strike
            else if (ip_burst >= v_limit && !killed[ip]) {
                killed[ip] = 1;
                msg = "VELOCITY STRIKE: IP " ip " terminiert (Flash-Burst erkannt: " ip_burst " Hits/sek).";
                print_kill("[⚡]", msg, c_red);
                system("ipset add " target_set " " ip " -exist");
                system(save_cmd " 2>/dev/null || true");
                burst_count[sec_key] = -999; 
            } 
            # 3. Standard IP Strike (Für whitelisted Domains die spammen)
            else if (ip_count[ip] == ip_limit && !killed[ip]) {
                killed[ip] = 1;
                msg = "RATE-LIMIT: IP " ip " für 24h hingerichtet (Limit überschritten).";
                print_kill("[✖]", msg, c_red);
                system("ipset add " target_set " " ip " -exist");
                system(save_cmd " 2>/dev/null || true");
            }

            # 4. Infra-Schlag (/24)
            if (!is_v6 && range_count[range] == r_limit && !killed[range]) {
                killed[range] = 1;
                msg = "INFRA-SCHLAG: Range " range " für 24h terminiert.";
                print_kill("[☢]", msg, c_red);
                system("ipset add " target_set " " range " -exist");
                system(save_cmd " 2>/dev/null || true");
            }

            # 5. Macro-Schlag (/16)
            if (!is_v6 && wide_range_count[wide_range] == wr_limit && !killed[wide_range]) {
                killed[wide_range] = 1;
                msg = "MACRO-SCHLAG: Sektor " wide_range " terminiert (Roaming-Scanner erkannt).";
                print_kill("[☠]", msg, c_pur);
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
