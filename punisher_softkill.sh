#!/bin/bash
# ==============================================================================
# VISIONGAIA TECHNOLOGY: AUTO-PUNISHER (V6.3.4 - OPEN SOURCE DIAMANT HYBRID)
# STATUS: DUAL-MODE ACTIVE (FULL DASHBOARD TUI + BULLETPROOF SERVICE TIER)
# VARIANT: SOFTKILL KASKADE (PROXY FALLTHROUGH)
# ARCHITECTURE: Asynchronous Tick-Render Engine + L4/L7 Ghost DPI + IPC Strike Executor
# SECURITY: DIAMANT VGT SUPREME - Zero-Shell Injection (IPC) & Anti-Fork-Bomb
# ==============================================================================

set -Eeuo pipefail

# --- VGT PARAMETER ---
readonly IP_THRESHOLD=17           # Hits bis zum Einzel-IP Ban (Für legitime Domains)
readonly L7_STRIKE_THRESHOLD=10    # Toleranz für fehlerhafte/leere SNI (Background-Noise Mobile)
readonly RANGE_THRESHOLD=45        # Hits bis zum /24 Subnetz Ban (v4)
readonly WIDE_RANGE_THRESHOLD=77   # Globales Sektor-Limit (/16)
readonly VELOCITY_LIMIT=10         # Max Hits pro Sekunde
readonly BAN_TIME=86400            # 24 Stunden Ban-Dauer
readonly MAX_STRIKES_PER_SEC=50    # Executor Rate-Limit gegen Fork-Bomben

# HÄRTUNG: Keine eckigen Klammern, um Regex-Kollisionen im journalctl zu verhindern.
readonly LOG_PREFIX="VGT_STRIKE_EVENT"
readonly L7_PREFIX="VGT_L7_EVENT"
readonly IPSET_V4="VGT_BANNED_V4"
readonly IPSET_V6="VGT_BANNED_V6"
readonly VGT_QUEUE="/tmp/vgt_action_queue"

# --- VGT MASTER WHITELISTS (GEHÄRTET) ---
readonly WHITELIST_IPS="127.0.0.1 ::1 0.0.0.0 :: fe80::/10"
# HIER DEINE ERLAUBTEN DOMAINS EINTRAGEN (Leerzeichen getrennt)
readonly WHITELIST_DOMAINS="sample.de"

# --- VGT HIGH-END UI DESIGN (ANSI) & INTELLIGENT DETECTION ---
if [[ ! -t 1 ]]; then
    export VGT_DISPLAY_MODE="SILENT"
    TUI_SMCUP=""; TUI_RMCUP=""; TUI_HIDE_CUR=""; TUI_SHOW_CUR=""
    C_RED=""; C_GREEN=""; C_YELLOW=""; C_CYAN=""; C_PURPLE=""; C_GRAY=""; C_WHITE=""; C_RESET=""
    function tput() { return 0; }
    function clear() { return 0; }
else
    export VGT_DISPLAY_MODE="VISUAL"
    C_RED='\033[38;2;255;51;102m'
    C_GREEN='\033[38;2;0;255;153m'
    C_YELLOW='\033[38;2;255;204;0m'
    C_CYAN='\033[38;2;0;204;255m'
    C_PURPLE='\033[38;2;153;51;255m'
    C_GRAY='\033[38;2;128;128;128m'
    C_WHITE='\033[38;2;255;255;255m'
    C_RESET='\033[0m'
    TUI_SMCUP='\033[?1049h'
    TUI_RMCUP='\033[?1049l'
    TUI_HIDE_CUR='\033[?25l'
    TUI_SHOW_CUR='\033[?25h'
fi

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# ==============================================================================
# 0. THE L7 GHOST SENSOR (PYTHON RAW SOCKET PAYLOAD)
# ==============================================================================
function deploy_l7_ghost() {
    if pgrep -f vgt_l7_ghost.py > /dev/null && [[ "${VGT_RECOVERY:-0}" == "0" ]]; then
        return
    fi

    pkill -f vgt_l7_ghost.py 2>/dev/null || true
    sleep 0.5

    cat << 'EOF' > /tmp/vgt_l7_ghost.py
import socket, struct, sys, syslog, time

syslog.openlog(ident="VGT_L7_GHOST")
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

        raw_domain = parse_sni(payload) if dst_port in (443, 8443) else parse_http(payload)
        if not raw_domain: continue
        
        # [ DIAMANT VGT SUPREME SECURITY FIX ]
        domain = "".join([c for c in raw_domain if c.isalnum() or c in ".-_"])
        if not domain or len(domain) > 255: continue

        cache_key = f"{src_ip}_{domain}"
        now = time.time()
        if cache_key in CACHE and (now - CACHE[cache_key]) < 1.0: continue
        CACHE[cache_key] = now

        syslog.syslog(f"VGT_L7_EVENT SRC={src_ip} DPT={dst_port} DOMAIN={domain}")
except Exception as e:
    syslog.syslog(f"CRITICAL ERROR: {e}")
EOF
    nohup python3 /tmp/vgt_l7_ghost.py >/dev/null 2>&1 &
}

# ==============================================================================
# 1. INITIALISIERUNG & ASYNC IPC EXECUTOR (DIAMANT SUPREME CORE)
# ==============================================================================
function start_executor() {
    rm -f "$VGT_QUEUE"
    mkfifo "$VGT_QUEUE"
    
    # Asynchroner Background-Daemon. Beseitigt AWK system() Limits und Fork-Bomben.
    (
        exec 3<> "$VGT_QUEUE" # Pipe offen halten
        
        local count=0
        local current_sec=$(date +%s)
        
        while IFS='|' read -r action target msg <&3; do
            [[ -z "$action" ]] && continue
            
            # Rate-Limiting / Anti-Fork-Bomb Token Bucket
            local now=$(date +%s)
            if (( now != current_sec )); then
                current_sec=$now
                count=0
            fi
            if (( count >= MAX_STRIKES_PER_SEC )); then
                sleep 0.05
            fi
            ((count++))

            # Direkte Exec-Aufrufe ohne Shell-Evaluierung.
            if [[ "$action" == "BAN_V4" ]]; then
                ipset add "$IPSET_V4" "$target" -exist 2>/dev/null || true
                logger "[VGT_KILL_LOG] $msg"
            elif [[ "$action" == "BAN_V6" ]]; then
                ipset add "$IPSET_V6" "$target" -exist 2>/dev/null || true
                logger "[VGT_KILL_LOG] $msg"
            fi
        done
    ) &
    export VGT_EXEC_PID=$!
}

function init_defense() {
    if [[ $EUID -ne 0 ]]; then 
        echo -e "${C_RED}[FATAL] Root erforderlich.${C_RESET}" >&2
        exit 1
    fi
    
    if [[ "$VGT_DISPLAY_MODE" == "VISUAL" ]]; then
        clear
        echo -e "${C_PURPLE}Injektiere VGT V6.3.4 (OS) Softkill IPC Schilde...${C_RESET}"
    fi

    ipset create "$IPSET_V4" hash:net family inet maxelem 1000000 timeout $BAN_TIME -exist 2>/dev/null || true
    ipset create "$IPSET_V6" hash:net family inet6 maxelem 1000000 timeout $BAN_TIME -exist 2>/dev/null || true

    for cmd in "iptables" "ip6tables"; do
        set_name=$([[ "$cmd" == "iptables" ]] && echo "$IPSET_V4" || echo "$IPSET_V6")
        if ! $cmd -C INPUT -m set --match-set "$set_name" src -j DROP >/dev/null 2>&1; then
            $cmd -I INPUT 1 -m set --match-set "$set_name" src -j DROP
        fi
    done

    # DPI Sanitization
    for cmd in "iptables" "ip6tables"; do
        if ! $cmd -C INPUT -m state --state INVALID -j DROP >/dev/null 2>&1; then
            $cmd -I INPUT 2 -m state --state INVALID -j DROP
            $cmd -I INPUT 3 -p tcp --tcp-flags ALL FIN,PSH,URG -j DROP 
            $cmd -I INPUT 4 -p tcp --tcp-flags ALL NONE -j DROP        
            $cmd -I INPUT 5 -p tcp --tcp-flags SYN,RST SYN -m tcpmss ! --mss 536:65535 -j DROP
        fi
    done

    # VGT OMEGA: GLOBAL PORT TRAP
    for cmd in "iptables" "ip6tables"; do
        while $cmd -D INPUT -p tcp -m state --state NEW -m multiport ! --dports 80,443,8443 ! -i lo -m limit --limit 50/s --limit-burst 100 -j LOG --log-prefix "$LOG_PREFIX " 2>/dev/null; do :; done
        while $cmd -D INPUT -p tcp -m state --state NEW -m multiport ! --dports 80,443,8443 ! -i lo -j LOG --log-prefix "$LOG_PREFIX " 2>/dev/null; do :; done
        
        $cmd -I INPUT 6 -p tcp -m state --state NEW -m multiport ! --dports 80,443,8443 ! -i lo -m limit --limit 50/s --limit-burst 100 -j LOG --log-prefix "$LOG_PREFIX "
    done

    deploy_l7_ghost
    start_executor
}

function cleanup_ui() {
    if [[ "$VGT_DISPLAY_MODE" == "VISUAL" ]]; then
        echo -ne "${TUI_RMCUP}${TUI_SHOW_CUR}"
        tput cnorm 2>/dev/null || true
        dmesg -E 2>/dev/null || true
    fi
    pkill -f "journalctl -n 0 -f --grep" 2>/dev/null || true
    kill -9 $VGT_EXEC_PID 2>/dev/null || true
    rm -f "$VGT_QUEUE"
    pkill -P $$ 2>/dev/null || true
    exit 0
}

# ==============================================================================
# 2. THE AWK PROCESSOR & RENDER ENGINE
# ==============================================================================
AWK_SCRIPT='
BEGIN {
    c_res = "\033[0m"; c_gry = "\033[38;2;100;100;100m"; c_cyn = "\033[38;2;0;204;255m"; 
    c_ylw = "\033[38;2;255;204;0m"; c_red = "\033[38;2;255;51;102m"; c_pur = "\033[38;2;180;0;255m";
    c_grn = "\033[38;2;0;255;153m"; c_wht = "\033[38;2;255;255;255m"; c_bld = "\033[1m";
    
    stat_ip = 0; stat_dom = 0; stat_flash = 0; stat_sys = 0; stat_infra = 0; stat_macro = 0; stat_total = 0;
    current_time = "00:00:00";
    
    LOG_MAX = 14; KILL_MAX = 5;
    for(i=1; i<=LOG_MAX; i++) log_buffer[i] = sprintf("%-132s", " ");
    for(i=1; i<=KILL_MAX; i++) kill_buffer[i] = sprintf("%-132s", " ");
    log_idx = 0; kill_idx = 0;

    sep_10 = "──────────"; sep_17 = "─────────────────"; sep_34 = "──────────────────────────────────"; 
    sep_13 = "─────────────"; sep_10_2 = "──────────";
    
    top_line = ""; for(i=0;i<132;i++) top_line = top_line "─";
    mid_line  = sep_10 "┼" sep_17 "┼" sep_34 "┼" sep_13 "┼" sep_10_2 "┼" sep_10_2 "┼" sep_10_2 "┼" sep_10_2 "┼" sep_10_2;
    head_line = sep_10 "┬" sep_17 "┬" sep_34 "┬" sep_13 "┬" sep_10_2 "┬" sep_10_2 "┬" sep_10_2 "┬" sep_10_2 "┬" sep_10_2;
    bot_line  = sep_10 "┴" sep_17 "┴" sep_34 "┴" sep_13 "┴" sep_10_2 "┴" sep_10_2 "┴" sep_10_2 "┴" sep_10_2 "┴" sep_10_2;

    split(wl_dom, wl_dom_arr, " ");
    for(i in wl_dom_arr) valid_domains[tolower(wl_dom_arr[i])] = 1;

    if (mode == "VISUAL") { printf "\033[2J"; }
}

function render_frame() {
    if (mode != "VISUAL") return;
    
    printf "\033[H"; 
    
    print c_cyn "╭" top_line "╮" c_res;
    print c_cyn "│" c_pur "  ██╗   ██╗ ██████╗ ████████╗  " c_bld sprintf("%-101s", "VISIONGAIA TECHNOLOGY: SUPREME DASHBOARD V6.3.4 (SOFTKILL)") c_res c_cyn "│" c_res;
    print c_cyn "│" c_pur "  ██║   ██║██╔════╝ ╚══██╔══╝  " c_wht sprintf("%-40s", "SYSTEM STATUS: [ DIAMANT IPC SECURED ]") c_cyn sprintf("%-61s", "UHRZEIT: " current_time) c_res c_cyn "│" c_res;
    print c_cyn "│" c_pur "  ╚██╗ ██╔╝██║  ███╗   ██║     " c_gry sprintf("%-101s", "-----------------------------------------------------------------------------------------------------") c_res c_cyn "│" c_res;
    
    stats_a = sprintf("[X] IP-KILLS: %-5d |  [🎯] DOM-KILLS: %-5d", stat_ip, stat_dom);
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
    
    formatted = c_cyn "│" c_res " " color raw_msg c_res pad_str " " c_cyn "│" c_res;
    kill_buffer[(kill_idx - 1) % KILL_MAX + 1] = formatted;
}

# IPC Queue Dispatcher - Zero Shell Evaluation
function execute_strike(ip, is_v6, log_msg) {
    q_act = is_v6 ? "BAN_V6" : "BAN_V4"
    print q_act "|" ip "|" log_msg > q_pipe
    fflush(q_pipe)
}

function execute_range_strike(range, log_msg) {
    print "BAN_V4|" range "|" log_msg > q_pipe
    fflush(q_pipe)
}

$0 !~ /VGT_STRIKE_EVENT/ && $0 !~ /VGT_L7_EVENT/ && $0 !~ /\[VGT_TICK\]/ { next; }

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
        is_v6 = 1; range = "IPv6_STRIKE"; wide_range = "IPv6_WIDE";
    } else {
        is_v6 = 0;
        split(ip, octets, "."); 
        range = octets[1] "." octets[2] "." octets[3] ".0/24";
        wide_range = octets[1] "." octets[2] ".0.0/16";
    }

    match($0, /DPT=([0-9]+)/, arr_dpt); dpt = arr_dpt[1];
    
    # --- VGT OMEGA: CHIRURGISCHE PORT KLASSIFIZIERUNG ---
    if (dpt == "80" || dpt == "443" || dpt == "8443") { tgt_color = c_cyn; svc = "[WEB]"; }
    else if (dpt == "22" || dpt == "887" || dpt == "3306" || dpt == "12843" || dpt == "21" || dpt == "23" || dpt == "3389" || dpt == "2222") { tgt_color = c_pur; svc = "[CRIT]"; }
    else if (dpt == "25" || dpt == "465" || dpt == "587" || dpt == "143" || dpt == "993" || dpt == "110" || dpt == "995") { tgt_color = c_grn; svc = "[MAIL]"; }
    else { tgt_color = c_wht; svc = "[PROXY]"; }

    # VGT OMEGA: Intelligent Port Aggregation
    if (!ip_port_seen[ip "_" dpt]) {
        ip_port_seen[ip "_" dpt] = 1;
        ip_port_count[ip]++;
        if (ip_ports[ip] == "") ip_ports[ip] = dpt;
        else ip_ports[ip] = ip_ports[ip] "," dpt;
    }

    if (ip_port_count[ip] == 1) {
        tgt_formatted = ip_ports[ip] " " svc;
    } else {
        tgt_formatted = ip_ports[ip];
    }

    if (length(tgt_formatted) > 11) tgt_formatted = substr(tgt_formatted, 1, 8) "...";

    domain_label = "N/A (L4 SYN)"; domain_col = c_gry;
    is_l7_strike = 0; foreign_domain = "";
    
    if ($0 ~ /VGT_L7_EVENT/) {
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
    
    # --- VGT OMEGA: LOGISCHE KASKADE (PROXY FALLTHROUGH) ---
    if (is_l7_strike > 0) { status_msg = "DOM-KILL"; status_col = c_red; }
    else if (svc == "[CRIT]") { status_msg = "SYS-KILL"; status_col = c_pur; }
    else if (ip_burst >= v_limit) { status_msg = "FLASH"; status_col = c_red; }
    else if (l7_viol[ip] > 0 && l7_viol[ip] < l7_limit) { status_msg = "L7-WARN"; status_col = c_ylw; }
    else if (ip_count[ip] >= ip_limit) { status_msg = "IP-KILL"; status_col = c_red; }
    else if (!is_v6 && range_count[range] >= r_limit) { status_msg = "RNG-KILL"; status_col = c_red; }
    else if (!is_v6 && wide_range_count[wide_range] >= wr_limit) { status_msg = "MAC-KILL"; status_col = c_pur; }

    b_col  = (ip_burst >= v_limit) ? c_red : (ip_burst >= (v_limit - 2) ? c_ylw : c_grn);
    h_col  = (ip_count[ip] >= (ip_limit - 3)) ? c_red : c_ylw;
    r_col  = (!is_v6 && range_count[range] >= (r_limit - 5)) ? c_red : c_ylw;
    wr_col = (!is_v6 && wide_range_count[wide_range] >= (wr_limit - 20)) ? c_red : c_ylw;

    disp_b = (ip_burst < 0) ? "XXX" : (ip_burst > 999 ? "999" : ip_burst "");
    disp_h = (ip_count[ip] < 0) ? "XXX" : (ip_count[ip] > 999 ? "999" : ip_count[ip] "");
    disp_r = is_v6 ? "0" : ((range_count[range] < 0) ? "XXX" : (range_count[range] > 999 ? "999" : range_count[range] ""));
    disp_w = is_v6 ? "0" : ((wide_range_count[wide_range] < 0) ? "XXX" : (wide_range_count[wide_range] > 999 ? "999" : wide_range_count[wide_range] ""));

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

    # --- KINETIC STRIKES (DIAMANT IPC EXECUTION) ---
    if (is_l7_strike > 0 && !killed[ip]) {
        killed[ip] = 1; stat_dom++;
        msg = (is_l7_strike == 2) ? "SNI SPOOFING: IP " ip " eliminiert (Fremde Domain: " foreign_domain ")." : "SNI VIOLATION: IP " ip " eliminiert (" l7_viol[ip] "x fehlerhaft).";
        push_kill("[🎯]", msg, c_red);
        execute_strike(ip, is_v6, msg);
        ip_count[ip] = -999; burst_count[sec_key] = -999;
    }
    else if (svc == "[CRIT]" && !killed[ip]) {
        killed[ip] = 1; stat_sys++;
        msg = "SYS-KILL " ip
        push_kill("[🔐]", "ZERO-TOLERANCE: IP " ip " eliminiert (Illegaler Zugriff auf Critical Port " dpt ").", c_pur);
        execute_strike(ip, is_v6, msg);
        ip_count[ip] = -999; burst_count[sec_key] = -999;
    }
    else if (ip_burst >= v_limit && !killed[ip]) {
        killed[ip] = 1; stat_flash++;
        msg = "FLASH-KILL " ip
        push_kill("[⚡]", "VELOCITY STRIKE: IP " ip " eliminiert (" ip_burst " Hits/sek).", c_red);
        execute_strike(ip, is_v6, msg);
        burst_count[sec_key] = -999; 
    } 
    else if (ip_count[ip] == ip_limit && !killed[ip]) {
        killed[ip] = 1; stat_ip++;
        msg = "IP-KILL " ip
        push_kill("[✖]", "RATE-LIMIT: IP " ip " für 24h hingerichtet.", c_red);
        execute_strike(ip, is_v6, msg);
    }
    if (!is_v6 && range_count[range] == r_limit && !killed[range]) {
        killed[range] = 1; stat_infra++;
        msg = "RNG-KILL " range
        push_kill("[☢]", "INFRA-SCHLAG: Range " range " für 24h terminiert.", c_red);
        execute_range_strike(range, msg);
    }
    if (!is_v6 && wide_range_count[wide_range] == wr_limit && !killed[wide_range]) {
        killed[wide_range] = 1; stat_macro++;
        msg = "MAC-KILL " wide_range
        push_kill("[☠]", "MACRO-SCHLAG: Sektor " wide_range " terminiert (Scanner).", c_pur);
        execute_range_strike(wide_range, msg);
    }

    render_frame();
}
'

# ==============================================================================
# MAIN ENGINE
# ==============================================================================
function start_hunt() {
    trap cleanup_ui SIGINT SIGTERM EXIT
    
    if [[ "$VGT_DISPLAY_MODE" == "VISUAL" ]]; then
        echo -ne "${TUI_SMCUP}${TUI_HIDE_CUR}"
        dmesg -D 2>/dev/null || true 
        
        {
            journalctl -n 0 -f --grep="($LOG_PREFIX|$L7_PREFIX)" 2>/dev/null &
            JPID=$!
            trap "kill $JPID 2>/dev/null" EXIT
            while true; do 
                echo "[VGT_TICK] $(date +'%H:%M:%S')"
                if ! pgrep -f vgt_l7_ghost.py > /dev/null; then export VGT_RECOVERY=1; deploy_l7_ghost; fi
                sleep 1
            done
        } | awk -v mode="VISUAL" -v q_pipe="$VGT_QUEUE" -v ip_limit="$IP_THRESHOLD" -v l7_limit="$L7_STRIKE_THRESHOLD" -v r_limit="$RANGE_THRESHOLD" -v wr_limit="$WIDE_RANGE_THRESHOLD" -v v_limit="$VELOCITY_LIMIT" -v set_v4="$IPSET_V4" -v set_v6="$IPSET_V6" -v wl="$WHITELIST_IPS" -v wl_dom="$WHITELIST_DOMAINS" "$AWK_SCRIPT"
    else
        while true; do
            if ! pgrep -f vgt_l7_ghost.py > /dev/null; then export VGT_RECOVERY=1; deploy_l7_ghost; fi
            journalctl -n 0 -f --grep="($LOG_PREFIX|$L7_PREFIX)" 2>/dev/null | awk -v mode="SILENT" -v q_pipe="$VGT_QUEUE" -v ip_limit="$IP_THRESHOLD" -v l7_limit="$L7_STRIKE_THRESHOLD" -v r_limit="$RANGE_THRESHOLD" -v wr_limit="$WIDE_RANGE_THRESHOLD" -v v_limit="$VELOCITY_LIMIT" -v set_v4="$IPSET_V4" -v set_v6="$IPSET_V6" -v wl="$WHITELIST_IPS" -v wl_dom="$WHITELIST_DOMAINS" "$AWK_SCRIPT" || true
            sleep 5
        done
    fi
}

init_defense
start_hunt
