#!/bin/bash
# ==============================================================================
# VISIONGAIA TECHNOLOGY: AUTO-PUNISHER (V6.0.2 - DIAMANT SUPREME DASHBOARD)
# STATUS: MAXIMUM OVERDRIVE (FIXED-FRAME TUI + L7 SNI GHOST-SENSOR)
# ARCHITECTURE: Asynchronous Tick-Render Engine + L4/L7 Ghost DPI
# UPDATE: Bulletproof String-Concatenation Rendering & Zombie-Log Kill
# ==============================================================================

set -Eeuo pipefail

# --- VGT PARAMETER ---
readonly IP_THRESHOLD=35           # Hits bis zum Einzel-IP Ban (Für legitime Domains)
readonly L7_STRIKE_THRESHOLD=10    # Toleranz für fehlerhafte/leere SNI (Background-Noise Mobile)
readonly RANGE_THRESHOLD=45        # Hits bis zum /24 Subnetz Ban (v4)
readonly WIDE_RANGE_THRESHOLD=77   # Globales Sektor-Limit (/16)
readonly VELOCITY_LIMIT=10         # Max Hits pro Sekunde
readonly BAN_TIME=86400            # 24 Stunden Ban-Dauer
readonly LOG_PREFIX="[VGT_STRIKE]"
readonly L7_PREFIX="[VGT_L7]"
readonly IPSET_V4="VGT_BANNED_V4"
readonly IPSET_V6="VGT_BANNED_V6"



# --- VGT MASTER WHITELISTS (GEHÄRTET) ---

readonly WHITELIST_IPS="127.0.0.1 ::1 0.0.0.0 :: fe80::/10"

# HIER DEINE ERLAUBTEN DOMAINS EINTRAGEN (Leerzeichen getrennt)

readonly WHITELIST_DOMAINS="example.de example.com"






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
readonly TUI_HIDE_CUR='\033[?25l'
readonly TUI_SHOW_CUR='\033[?25h'

# ==============================================================================
# 0. THE L7 GHOST SENSOR (PYTHON RAW SOCKET PAYLOAD)
# ==============================================================================
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

        cache_key = f"{src_ip}_{domain}"
        now = time.time()
        if cache_key in CACHE and (now - CACHE[cache_key]) < 1.0: continue
        CACHE[cache_key] = now

        syslog.syslog(f"SRC={src_ip} DPT={dst_port} DOMAIN={domain}")
except Exception as e:
    syslog.syslog(f"CRITICAL ERROR: {e}")
EOF
    pkill -f vgt_l7_ghost.py || true
    nohup python3 /tmp/vgt_l7_ghost.py >/dev/null 2>&1 &
}

# ==============================================================================
# 1. INITIALISIERUNG
# ==============================================================================
function init_defense() {
    if [[ $EUID -ne 0 ]]; then 
        echo -e "${C_RED}[FATAL] Root erforderlich.${C_RESET}" >&2
        exit 1
    fi
    clear
    echo -e "${C_PURPLE}Injektiere VGT V6.0 APEX Schilde...${C_RESET}"

    local open_ports
    open_ports=$(ss -tlnp | grep LISTEN | awk '{print $4}' | awk -F: '{print $NF}' | sort -un | tr '\n' ',' | sed 's/,$//' || echo "22,80,443")
    L4_PORTS=$(echo "$open_ports" | tr ',' '\n' | grep -vE "^(80|443|8443)$" | tr '\n' ',' | sed 's/,$//')

    ipset create "$IPSET_V4" hash:net family inet maxelem 1000000 timeout $BAN_TIME -exist 2>/dev/null || true
    ipset create "$IPSET_V6" hash:net family inet6 maxelem 1000000 timeout $BAN_TIME -exist 2>/dev/null || true

    for cmd in "iptables" "ip6tables"; do
        set_name=$([[ "$cmd" == "iptables" ]] && echo "$IPSET_V4" || echo "$IPSET_V6")
        if ! $cmd -C INPUT -m set --match-set "$set_name" src -j DROP >/dev/null 2>&1; then
            $cmd -I INPUT 1 -m set --match-set "$set_name" src -j DROP
        fi
    done

    # DPI Sanitization (Dual-Stack Mirroring für IPv4 & IPv6)
    for cmd in "iptables" "ip6tables"; do
        if ! $cmd -C INPUT -m state --state INVALID -j DROP >/dev/null 2>&1; then
            $cmd -I INPUT 2 -m state --state INVALID -j DROP
            $cmd -I INPUT 3 -p tcp --tcp-flags ALL FIN,PSH,URG -j DROP 
            $cmd -I INPUT 4 -p tcp --tcp-flags ALL NONE -j DROP        
            $cmd -I INPUT 5 -p tcp --tcp-flags SYN,RST SYN -m tcpmss ! --mss 536:65535 -j DROP
        fi
    done

    if [[ -n "$L4_PORTS" ]]; then
        IFS=',' read -r -a port_array <<< "$L4_PORTS"
        chunk_size=14
        for ((i=0; i<${#port_array[@]}; i+=chunk_size)); do
            chunk=$(IFS=, ; echo "${port_array[*]:i:chunk_size}")
            
            # VGT: IPv4 LOG Sensor Injektion
            while iptables -D INPUT -p tcp -m multiport --dports "$chunk" ! -i lo --syn -m limit --limit 50/s --limit-burst 100 -j LOG --log-prefix "$LOG_PREFIX " 2>/dev/null; do :; done
            while iptables -D INPUT -p tcp -m multiport --dports "$chunk" ! -i lo --syn -j LOG --log-prefix "$LOG_PREFIX " 2>/dev/null; do :; done
            iptables -I INPUT 6 -p tcp -m multiport --dports "$chunk" ! -i lo --syn -m limit --limit 50/s --limit-burst 100 -j LOG --log-prefix "$LOG_PREFIX "

            # VGT: IPv6 LOG Sensor Injektion (Fix für unsichtbaren Google/Gmail Traffic)
            while ip6tables -D INPUT -p tcp -m multiport --dports "$chunk" ! -i lo --syn -m limit --limit 50/s --limit-burst 100 -j LOG --log-prefix "$LOG_PREFIX " 2>/dev/null; do :; done
            while ip6tables -D INPUT -p tcp -m multiport --dports "$chunk" ! -i lo --syn -j LOG --log-prefix "$LOG_PREFIX " 2>/dev/null; do :; done
            ip6tables -I INPUT 6 -p tcp -m multiport --dports "$chunk" ! -i lo --syn -m limit --limit 50/s --limit-burst 100 -j LOG --log-prefix "$LOG_PREFIX "
        done
    fi

    deploy_l7_ghost
}

# ==============================================================================
# 2. THE TUI RENDER ENGINE (FIXED-FRAME AWK)
# ==============================================================================
function cleanup_ui() {
    echo -ne "${TUI_RMCUP}${TUI_SHOW_CUR}"
    tput cnorm
    dmesg -E 2>/dev/null || true                         # VGT: Kernel-Console Broadcasts wiederherstellen
    pkill -f "journalctl -f --grep" 2>/dev/null || true  # Tötet gnadenlos hängende Log-Prozesse
    pkill -P $$ 2>/dev/null || true                      # Kille alle Sub-Prozesse
    pkill -f vgt_l7_ghost.py 2>/dev/null || true
    rm -f /tmp/vgt_l7_ghost.py
    exit 0
}

function start_hunt() {
    echo -ne "${TUI_SMCUP}${TUI_HIDE_CUR}"
    trap cleanup_ui SIGINT SIGTERM EXIT

    dmesg -D 2>/dev/null || true                         # VGT: Unterdrücke direkte Kernel-TTY-Injektionen

    # Bündelung der Streams: Log-Daten + Live-Heartbeat direkt in die Render Engine!
    {
        journalctl -f --grep="($LOG_PREFIX|$L7_PREFIX)" 2>/dev/null &
        while true; do 
            echo "[VGT_TICK] $(date +'%H:%M:%S')"
            sleep 1
        done
    } | awk -v ip_limit="$IP_THRESHOLD" -v l7_limit="$L7_STRIKE_THRESHOLD" -v r_limit="$RANGE_THRESHOLD" -v wr_limit="$WIDE_RANGE_THRESHOLD" -v v_limit="$VELOCITY_LIMIT" -v set_v4="$IPSET_V4" -v set_v6="$IPSET_V6" -v wl="$WHITELIST_IPS" -v wl_dom="$WHITELIST_DOMAINS" '
        BEGIN {
            c_res = "\033[0m"; c_gry = "\033[38;2;100;100;100m"; c_cyn = "\033[38;2;0;204;255m"; 
            c_ylw = "\033[38;2;255;204;0m"; c_red = "\033[38;2;255;51;102m"; c_pur = "\033[38;2;180;0;255m";
            c_grn = "\033[38;2;0;255;153m"; c_wht = "\033[38;2;255;255;255m"; c_bld = "\033[1m";
            
            # VGT: stat_ssh auf stat_sys (System Kills) aktualisiert
            stat_ip = 0; stat_dom = 0; stat_flash = 0; stat_sys = 0; stat_infra = 0; stat_macro = 0; stat_total = 0;
            current_time = "00:00:00";
            
            LOG_MAX = 14; KILL_MAX = 5;
            for(i=1; i<=LOG_MAX; i++) log_buffer[i] = sprintf("%-132s", " ");
            for(i=1; i<=KILL_MAX; i++) kill_buffer[i] = sprintf("%-132s", " ");
            log_idx = 0; kill_idx = 0;

            # Grid Architecture (Exakt 132 chars innen, erweitert für 32-Zeichen Domains)
            sep_10 = "──────────"; sep_17 = "─────────────────"; sep_34 = "──────────────────────────────────"; 
            sep_13 = "─────────────"; sep_10_2 = "──────────";
            
            top_line = ""; for(i=0;i<132;i++) top_line = top_line "─";
            mid_line  = sep_10 "┼" sep_17 "┼" sep_34 "┼" sep_13 "┼" sep_10_2 "┼" sep_10_2 "┼" sep_10_2 "┼" sep_10_2 "┼" sep_10_2;
            head_line = sep_10 "┬" sep_17 "┬" sep_34 "┬" sep_13 "┬" sep_10_2 "┬" sep_10_2 "┬" sep_10_2 "┬" sep_10_2 "┬" sep_10_2;
            bot_line  = sep_10 "┴" sep_17 "┴" sep_34 "┴" sep_13 "┴" sep_10_2 "┴" sep_10_2 "┴" sep_10_2 "┴" sep_10_2 "┴" sep_10_2;

            split(wl_dom, wl_dom_arr, " ");
            for(i in wl_dom_arr) valid_domains[tolower(wl_dom_arr[i])] = 1;

            printf "\033[2J";
        }

        function render_frame() {
            printf "\033[H"; 
            
            print c_cyn "╭" top_line "╮" c_res;
            print c_cyn "│" c_pur "  ██╗   ██╗ ██████╗ ████████╗  " c_bld sprintf("%-101s", "VISIONGAIA TECHNOLOGY: SUPREME DASHBOARD V6.0") c_res c_cyn "│" c_res;
            print c_cyn "│" c_pur "  ██║   ██║██╔════╝ ╚══██╔══╝  " c_wht sprintf("%-40s", "SYSTEM STATUS: [ DIAMANT SUPREME ]") c_cyn sprintf("%-61s", "UHRZEIT: " current_time) c_res c_cyn "│" c_res;
            print c_cyn "│" c_pur "  ╚██╗ ██╔╝██║  ███╗   ██║     " c_gry sprintf("%-101s", "-----------------------------------------------------------------------------------------------------") c_res c_cyn "│" c_res;
            
            stats_a = sprintf("[X] IP-KILLS: %-5d |  [🎯] DOM-KILLS: %-5d", stat_ip, stat_dom);
            # VGT: Live-Stats Panel auf SYS-SNIPES geändert
            stats_b = sprintf("[⚡] FLASH: %-8d |  [🔐] SYS-SNIPES: %-4d", stat_flash, stat_sys);
            stats_c = sprintf("[☢] INFRA (/24): %-3d |  [☠] MACRO (/16): %-4d", stat_infra, stat_macro);
            
            print c_cyn "│" c_pur "   ╚████╔╝ ██║   ██║   ██║     " c_red sprintf("%-43s", stats_a) c_ylw sprintf("%-58s", stats_b) c_res c_cyn "│" c_res;
            print c_cyn "│" c_pur "    ╚██╔╝  ╚██████╔╝   ██║     " c_pur sprintf("%-101s", stats_c) c_res c_cyn "│" c_res;
            print c_cyn "│" c_pur "     ╚═╝    ╚═════╝    ╚═╝     " c_wht sprintf("%-101s", "TOTAL KINETIC STRIKES: " stat_total) c_res c_cyn "│" c_res;

            print c_cyn "├" head_line "┤" c_res;
            print c_cyn "│" c_gry " ZEIT     " c_cyn "│" c_gry " QUELL-IP        " c_cyn "│" c_gry " DOMAIN (SNI/L7)                  " c_cyn "│" c_gry " ZIEL (PORT) " c_cyn "│" c_gry "  BURST   " c_cyn "│" c_gry "   HITS   " c_cyn "│" c_gry "  R-HITS  " c_cyn "│" c_gry "  S-HITS  " c_cyn "│" c_gry " STATUS   " c_cyn "│" c_res;
            print c_cyn "├" mid_line "┤" c_res;

            for(i=1; i<=LOG_MAX; i++) {
                real_idx = (log_idx - LOG_MAX + i);
                if(real_idx < 1) { print c_cyn "│" c_gry sprintf("%-132s", " ") c_cyn "│" c_res; } 
                else { print log_buffer[(real_idx - 1) % LOG_MAX + 1]; }
            }

            print c_cyn "├" top_line "┤" c_res;
            print c_cyn "│" c_red c_bld sprintf(" %-131s", "[ KINETIC STRIKE PROTOCOL ]") c_res c_cyn "│" c_res;
            print c_cyn "├" top_line "┤" c_res;

            for(i=1; i<=KILL_MAX; i++) {
                real_idx = (kill_idx - KILL_MAX + i);
                if(real_idx < 1) { print c_cyn "│" c_gry sprintf("%-132s", " ") c_cyn "│" c_res; } 
                else { print kill_buffer[(real_idx - 1) % KILL_MAX + 1]; }
            }
            print c_cyn "╰" top_line "╯" c_res;
            fflush();
        }

        function push_log(line) { log_idx++; log_buffer[(log_idx - 1) % LOG_MAX + 1] = line; }
        
        function push_kill(icon, text, color) {
            kill_idx++; stat_total++;
            raw_msg = sprintf("[%s] %s %s", current_time, icon, text);
            pad = 132 - length(raw_msg); if(pad < 0) pad = 0;
            pad_str = ""; for(p=0; p<pad; p++) pad_str = pad_str " ";
            
            # Kugelsichere String-Konkatenation statt sprintf Format
            formatted = c_cyn "│" c_res " " color raw_msg c_res pad_str " " c_cyn "│" c_res;
            kill_buffer[(kill_idx - 1) % KILL_MAX + 1] = formatted;
        }

        /\[VGT_TICK\]/ {
            current_time = $2;
            render_frame();
            next;
        }

        /SRC=/ {
            match($0, /SRC=([0-9a-fA-F:.]+)/, arr); ip = arr[1];
            if (ip ~ /^[0:]+$/) ip = "::";

            is_wl = 0; split(wl, wl_parts, " ");
            for (i in wl_parts) {
                if (wl_parts[i] == ip) { is_wl = 1; break; }
                if (wl_parts[i] ~ /\/24$/) {
                    split(wl_parts[i], wl_range, "."); split(ip, ip_parts, ".");
                    if (wl_range[1] == ip_parts[1] && wl_range[2] == ip_parts[2] && wl_range[3] == ip_parts[3]) { is_wl = 1; break; }
                }
            }
            if (is_wl || ip == "" || tolower(ip) ~ /^fe80:/) next;

            if (ip ~ /:/) {
                is_v6 = 1; target_set = set_v6; range = "IPv6_STRIKE"; wide_range = "IPv6_WIDE"; save_cmd = "ip6tables-save > /etc/iptables/rules.v6";
            } else {
                is_v6 = 0; target_set = set_v4; save_cmd = "iptables-save > /etc/iptables/rules.v4";
                split(ip, octets, "."); 
                range = octets[1] "." octets[2] "." octets[3] ".0/24";
                wide_range = octets[1] "." octets[2] ".0.0/16";
            }

            match($0, /DPT=([0-9]+)/, arr_dpt); dpt = arr_dpt[1];
            tgt_color = c_gry;
            if (dpt == "80" || dpt == "443" || dpt == "8443") { tgt_color = c_cyn; svc = "[WEB]"; }
            # VGT BIFURKATION: Port 25 (Public Mail Routing = Tolerant)
            else if (dpt == "25") { tgt_color = c_grn; svc = "[SMTP]"; }
            # VGT BIFURKATION: Client Ports (IMAP/POP/Submission = Zero-Trust)
            else if (dpt == "465" || dpt == "587" || dpt == "143" || dpt == "993" || dpt == "110" || dpt == "995") { tgt_color = c_ylw; svc = "[SEC-MAIL]"; }
            else if (dpt == "22" || dpt == "2222") { tgt_color = c_pur; svc = "[SSH]"; }
            else if (dpt == "21") { tgt_color = c_ylw; svc = "[FTP]"; }
            else if (dpt == "3306" || dpt == "888") { tgt_color = c_ylw; svc = "[PNL]"; }
            else { tgt_color = c_wht; svc = "[NET]"; }
            tgt_formatted = dpt " " svc;

            domain_label = "N/A (L4 SYN)"; domain_col = c_gry;
            is_l7_strike = 0; foreign_domain = "";
            
            if ($0 ~ /VGT_L7/) {
                match($0, /DOMAIN=([^ ]+)/, arr_dom); domain_val = arr_dom[1];
                if (valid_domains[tolower(domain_val)]) {
                    domain_label = domain_val; domain_col = c_grn;
                } else if (domain_val == "DIRECT_IP_OR_MALFORMED") {
                    domain_label = substr(domain_val, 1, 32); domain_col = c_red; l7_viol[ip]++;
                    if (l7_viol[ip] >= l7_limit) is_l7_strike = 1;
                } else {
                    domain_label = substr(domain_val, 1, 32); domain_col = c_red; is_l7_strike = 2; foreign_domain = domain_val;
                }
            }

            ip_count[ip]++;
            if (!is_v6) { range_count[range]++; wide_range_count[wide_range]++; }

            sec_key = ip "_" $1 $2 $3; burst_count[sec_key]++; ip_burst = burst_count[sec_key];

            status_msg = "TRACKING"; status_col = c_gry;
            if (is_l7_strike > 0) { status_msg = "DOM-KILL"; status_col = c_red; }
            # VGT ZERO-TRUST: ALLES was nicht [WEB] oder [SMTP] ist, ist ein Instant-Kill (Inklusive [SEC-MAIL])
            else if (svc != "[WEB]" && svc != "[SMTP]") { status_msg = "SYS-KILL"; status_col = c_pur; }
            else if (ip_burst >= v_limit) { status_msg = "FLASH"; status_col = c_red; }
            else if (l7_viol[ip] > 0 && l7_viol[ip] < l7_limit) { status_msg = "L7-WARN"; status_col = c_ylw; }
            else if (ip_count[ip] >= ip_limit) { status_msg = "IP-KILL"; status_col = c_red; }
            else if (!is_v6 && range_count[range] >= r_limit) { status_msg = "RNG-KILL"; status_col = c_red; }
            else if (!is_v6 && wide_range_count[wide_range] >= wr_limit) { status_msg = "MAC-KILL"; status_col = c_pur; }

            b_col  = (ip_burst >= v_limit) ? c_red : (ip_burst >= (v_limit - 2) ? c_ylw : c_grn);
            h_col  = (ip_count[ip] >= (ip_limit - 3)) ? c_red : c_ylw;
            r_col  = (!is_v6 && range_count[range] >= (r_limit - 5)) ? c_red : c_ylw;
            wr_col = (!is_v6 && wide_range_count[wide_range] >= (wr_limit - 20)) ? c_red : c_ylw;

            # Harte String Typen-Erzwingung durch "" Anhängsel (Verhindert Type-Crashes in awk)
            disp_b = (ip_burst < 0) ? "XXX" : (ip_burst > 999 ? "999" : ip_burst "");
            disp_h = (ip_count[ip] < 0) ? "XXX" : (ip_count[ip] > 999 ? "999" : ip_count[ip] "");
            disp_r = is_v6 ? "0" : ((range_count[range] < 0) ? "XXX" : (range_count[range] > 999 ? "999" : range_count[range] ""));
            disp_w = is_v6 ? "0" : ((wide_range_count[wide_range] < 0) ? "XXX" : (wide_range_count[wide_range] > 999 ? "999" : wide_range_count[wide_range] ""));

            # Kugelsicheres Rendering via pure String-Konkatenation statt gigantischem sprintf
            padded_time = sprintf("%-8.8s", current_time);
            padded_ip = sprintf("%-15.15s", ip);
            padded_dom = sprintf("%-32.32s", domain_label);
            padded_tgt = sprintf("%-11.11s", tgt_formatted);
            padded_b = sprintf("%3s", disp_b);
            padded_h = sprintf("%3s", disp_h);
            padded_r = sprintf("%3s", disp_r);
            padded_w = sprintf("%3s", disp_w);
            padded_status = sprintf("%-8.8s", status_msg);

            row = c_cyn "│" c_res " " c_gry padded_time c_res " " c_cyn "│" \
                  c_res " " c_wht padded_ip c_res " " c_cyn "│" \
                  c_res " " domain_col padded_dom c_res " " c_cyn "│" \
                  c_res " " tgt_color padded_tgt c_res " " c_cyn "│" \
                  c_res "   " b_col padded_b c_res "    " c_cyn "│" \
                  c_res "   " h_col padded_h c_res "    " c_cyn "│" \
                  c_res "   " r_col padded_r c_res "    " c_cyn "│" \
                  c_res "   " wr_col padded_w c_res "    " c_cyn "│" \
                  c_res " " status_col padded_status c_res " " c_cyn "│" c_res;
            
            push_log(row);

            # --- KINETIC STRIKES (EXECUTION) ---
            if (is_l7_strike > 0 && !killed[ip]) {
                killed[ip] = 1; stat_dom++;
                msg = (is_l7_strike == 2) ? "SNI SPOOFING: IP " ip " eliminiert (Fremde Domain: " foreign_domain ")." : "SNI VIOLATION: IP " ip " eliminiert (" l7_viol[ip] "x fehlerhaft).";
                push_kill("[🎯]", msg, c_red);
                system("ipset add " target_set " " ip " -exist"); system(save_cmd " 2>/dev/null || true");
                ip_count[ip] = -999; burst_count[sec_key] = -999;
            }
            # VGT ZERO-TRUST STRIKE: Gnadenlose Eliminierung bei jedem non-web/non-smtp Port (Driftnet & Co auf IMAP/POP)
            else if (svc != "[WEB]" && svc != "[SMTP]" && !killed[ip]) {
                killed[ip] = 1; stat_sys++;
                push_kill("[🔐]", "ZERO-TOLERANCE: IP " ip " eliminiert (Illegaler " svc "-Scan auf Port " dpt ").", c_pur);
                system("ipset add " target_set " " ip " -exist"); system(save_cmd " 2>/dev/null || true");
                ip_count[ip] = -999; burst_count[sec_key] = -999;
            }
            else if (ip_burst >= v_limit && !killed[ip]) {
                killed[ip] = 1; stat_flash++;
                push_kill("[⚡]", "VELOCITY STRIKE: IP " ip " eliminiert (" ip_burst " Hits/sek).", c_red);
                system("ipset add " target_set " " ip " -exist"); system(save_cmd " 2>/dev/null || true");
                burst_count[sec_key] = -999; 
            } 
            else if (ip_count[ip] == ip_limit && !killed[ip]) {
                killed[ip] = 1; stat_ip++;
                push_kill("[✖]", "RATE-LIMIT: IP " ip " für 24h hingerichtet.", c_red);
                system("ipset add " target_set " " ip " -exist"); system(save_cmd " 2>/dev/null || true");
            }
            if (!is_v6 && range_count[range] == r_limit && !killed[range]) {
                killed[range] = 1; stat_infra++;
                push_kill("[☢]", "INFRA-SCHLAG: Range " range " für 24h terminiert.", c_red);
                system("ipset add " target_set " " range " -exist"); system(save_cmd " 2>/dev/null || true");
            }
            if (!is_v6 && wide_range_count[wide_range] == wr_limit && !killed[wide_range]) {
                killed[wide_range] = 1; stat_macro++;
                push_kill("[☠]", "MACRO-SCHLAG: Sektor " wide_range " terminiert (Scanner).", c_pur);
                system("ipset add " target_set " " wide_range " -exist"); system(save_cmd " 2>/dev/null || true");
            }

            render_frame();
        }
    ' 2>/dev/null
}

# ==============================================================================
# MAIN ENTRY
# ==============================================================================
init_defense
start_hunt
