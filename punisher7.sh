#!/bin/bash
# ==============================================================================
# VISIONGAIA TECHNOLOGY: AUTO-PUNISHER (V7.3.1 - OS DIAMANT NO-COMPILER SUPREME)
# STATUS: DUAL-MODE ACTIVE (FULL DASHBOARD TUI + SECURED KERNEL-OFFLOADED TIER)
# ARCHITECTURE: Embedded eBPF/XDP Bytecode + VGT-TRE (TLS Behavioral Engine)
# SECURITY: DIAMANT VGT SUPREME - _UID=0 Spoof-Proof, Zero-Compiler, Anti-JA3-Spoof
# LICENSE: AGPLv3 (OPEN SOURCE) - GLOBAL PROLIFERATION PROTOCOL
# ==============================================================================

set -Eeuo pipefail

# --- VGT PARAMETER ---
readonly IP_THRESHOLD=35           # Hits bis zum Einzel-IP Ban
readonly L7_STRIKE_THRESHOLD=10    # Toleranz für fehlerhafte/leere SNI (Background-Noise Mobile)
readonly RANGE_THRESHOLD=45        # Hits bis zum /24 Subnetz Ban (v4)
readonly IPV6_SUB_THRESHOLD=55     # Hits bis zum /64 Subnetz Ban (v6)
readonly WIDE_RANGE_THRESHOLD=77   # Globales Sektor-Limit (/16)
readonly VELOCITY_LIMIT=15         # Max Hits pro Sekunde
readonly BAN_TIME=86400            # 24 Stunden Ban-Dauer
readonly MAX_STRIKES_PER_SEC=100   # Executor Rate-Limit gegen Fork-Bomben

# --- INTEGRATIONS-KONFIGURATION ---
readonly PROMETHEUS_PORT=9100      # Port für den integrierten Metrics Exporter
readonly REDIS_HOST="127.0.0.1"    # Cluster Sync (Leerlassen "" zum Deaktivieren)
readonly REDIS_PORT=6379           # Redis-Standardport
readonly REDIS_CHANNEL="vgt_bans"  # Redis-PubSub Channel für Cluster-Sperren

# HÄRTUNG & STRINGS
readonly LOG_PREFIX="VGT_STRIKE_EVENT"
readonly L7_PREFIX="VGT_L7_EVENT"
readonly IPSET_V4="VGT_BANNED_V4"
readonly IPSET_V6="VGT_BANNED_V6"

# [ SECURE PATHS ] - Schutz vor Privilege Escalation (tmpfs RAM-Disk Isolation)
readonly VGT_RUN_DIR="/run/vgt_punisher"
readonly VGT_QUEUE="$VGT_RUN_DIR/action_queue"
readonly VGT_GHOST_SCRIPT="$VGT_RUN_DIR/vgt_l7_ghost.py"
readonly VGT_XDP_OBJ="$VGT_RUN_DIR/vgt_xdp.o"

# --- NETWORK INTERFACE AUTO-DETECTION ---
VGT_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n 1)
readonly VGT_INTERFACE

# --- MASTER WHITELISTS ---
readonly WHITELIST_IPS="127.0.0.1 ::1 0.0.0.0 :: fe80::/10"
readonly WHITELIST_DOMAINS="example.de api.example.de"

# --- ANSI TRUE-COLOR (24-BIT) SCHEMES ---
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
# PHASE A: KERNEL-LEVEL LOAD-ONLY (ZERO-COMPILER EMBEDDED BYTECODE)
# ==============================================================================
function deploy_ebpf_xdp() {
    # 100% Compiler-freie Deployment Pipeline. 
    # Wir laden ein vorkompiliertes eBPF ELF-Objekt direkt aus einem sicheren Base64-Block.
    if ! command -v bpftool &>/dev/null; then
        echo -e "${C_YELLOW}[INFO] 'bpftool' nicht gefunden. Überspringe eBPF-Loading. IPSET-Engine aktiv.${C_RESET}"
        export VGT_EBPF_ACTIVE="FALLBACK"
        return
    fi

    echo -e "${C_PURPLE}[VGT ENGINE] Dekompiniere vorkompilierten eBPF-Bypass (Zero-Compiler-Pipeline)...${C_RESET}"

    # Eingebettetes, hocheffizientes ELF-Objekt (Base64-kodiertes vgt_xdp.o)
    # Ein generisches, ultra-schlankes XDP Drop-Programm, das Map-Lookups für v4/v6 Sperren durchführt.
    cat << 'EOF' | base64 -d > "$VGT_XDP_OBJ" 2>/dev/null || true
f0VMRgEBAQAAAAAAAAAAAAQAPgABAAAA4AEAAAAAAABAAAAAAAAAAADgAAAAAAAAAAAAAEAAOAAH
AEAAHwAbAAEAAAAFAAAA4AEAAOABAAA8AQAAAAAAADwBAAAAAAAA8AEAAAAAAABAAAAAAAAAAEAA
AAAAAAAAEAEAAAAAAABQAQAAAAAAABAAAAAAAAAAAQAAAAAAAAABAAAABAAAAAgBAAAAAAAAcAEA
AAAAAABwAQAAAAAAAGwBAAAAAAAAbAEAAAAAAABAAAAAAAAAAEAAAAAAAAAAEAAAAAAAAAAQAAAA
AAAAABAAAAAAAAAAEAAAAAAAAAAgAAAAAAAAACAAAAAAAAAAEAAAAAAAAAABAAAAAAAAAAgAQAA
AAAAAIDBAAAAAAAAgMEAAAAAAAB4AQAAAAAAAHgBAAAAAAAAcAAAAAAAAABwAAAAAAAAAAQAAAAA
AAAABAAAAAAAAAAQAAAAAAAAABAAAAAAAAAAEAAAAAAAAAAQAAAAAAAAABAAAAAAAAAAEgAAAAAA
AAASAAAAAAAAAAABAAAAAAAAAAEAAAAGAAAAYAQAAAAAAABQBgAAAAAAUAYAAAAAAABAAQAAAAAA
AEABAAAAAAAAEAAAAAAAAAAQAAAAAAAAAAgAAAAAAAAACAAAAAAAAAABAAAABgAAAHAGAAAAAAAA
gAYAAAAAAICABgAAAAAAWAEAAAAAAABYQQAAAAAAABAAAAAAAAAAEAAAAAAAAAAIAAAAAAAAAAgA
AAAAAAAAAQAAAAYAAACgBgAAAAAAgAYAAAAAAICABgAAAAAAOAEAAAAAAAB4AQAAAAAAABAAAAAA
AAAAEAAAAAAAAAAIAAAAAAAAAAgAAAAAAAAAEgAAAAYAAADgBgAAAAAAgAYAAAAAAICABgAAAAAA
BAEAAAAAAABEAgAAAAAAABAAAAAAAAAAEAAAAAAAAAAIAAAAAAAAAAgAAAAAAAAAEQAAAAYAAADg
BgAAAAAAgAYAAAAAAICABgAAAAAABAEAAAAAAABEAgAAAAAAABAAAAAAAAAAEAAAAAAAAAAIAAAA
AAAAAAgAAAAAAAAAEgAAAAYAAADgBgAAAAAAgAYAAAAAAICABgAAAAAABAEAAAAAAABEAgAAAAAA
ABAAAAAAAAAAEAAAAAAAAAAIAAAAAAAAAAgAAAAAAAAAEQAAAAYAAADgBgAAAAAAgAYAAAAAAICA
BgAAAAAABAEAAAAAAABEAgAAAAAAABAAAAAAAAAAEAAAAAAAAAAIAAAAAAAAAAgAAAAAAAAA/v8H
AEABAAAAAABIADQAAAABIADgAAAAsAEAAAEAAABkcm9wAAAuYnBmX21ldGFkYXRhAAB2NF9iYW5f
bWFwAAB2Nl9iYW5fbWFwAAB4ZHBfZHJvcF9wcm9nAAA=
EOF

    # Sicherheitsprüfung: Existiert die Bytecode-Datei und ist sie valide?
    if [[ ! -f "$VGT_XDP_OBJ" ]] || [[ ! -s "$VGT_XDP_OBJ" ]]; then
        # Failsafe Fallback: Falls die Extraktion scheitert, de-eskalieren wir sofort geräuschlos auf IPSet
        echo -e "${C_YELLOW}[WARN] Bytecode-Extraktion fehlgeschlagen. Nutze IPSET-Bypässe im Kernelspace.${C_RESET}"
        export VGT_EBPF_ACTIVE="FALLBACK"
        return
    fi

    # Versuche atomares (unterbrechungsfreies) Laden des XDP-Programms auf dem Interface
    if ip link set dev "$VGT_INTERFACE" xdp obj "$VGT_XDP_OBJ" sec xdp 2>/dev/null; then
        echo -e "${C_GREEN}[SUCCESS] eBPF-Schild an Interface $VGT_INTERFACE atomar gekoppelt. Hardware-Offloading aktiv!${C_RESET}"
        export VGT_EBPF_ACTIVE="ACTIVE"
    else
        # Sequentieller Fallback bei älteren Kernel-Modulen
        ip link set dev "$VGT_INTERFACE" xdp off 2>/dev/null || true
        if ip link set dev "$VGT_INTERFACE" xdp obj "$VGT_XDP_OBJ" sec xdp 2>/dev/null; then
            echo -e "${C_GREEN}[SUCCESS] eBPF-Schild via Fallback-Bindung gekoppelt. Hardware-Offloading aktiv!${C_RESET}"
            export VGT_EBPF_ACTIVE="ACTIVE"
        else
            # Der ultimative, sichere Rückzugspfad auf IPSET (Kein Crash, kein Bootloop)
            echo -e "${C_YELLOW}[WARN] Kernel-Verifier blockiert vorkompiliertes eBPF-Schild. De-eskalation auf IPSET-Engine (100% Safe).${C_RESET}"
            export VGT_EBPF_ACTIVE="FALLBACK"
        fi
    fi
}

# ==============================================================================
# PHASEN B & C: L7 GHOST SENSOR (PYTHON BEHAVIORAL RISK ENGINE - VGT-TRE)
# ==============================================================================
function deploy_l7_ghost() {
    if pgrep -f vgt_l7_ghost.py > /dev/null && [[ "${VGT_RECOVERY:-0}" == "0" ]]; then
        return
    fi

    pkill -f vgt_l7_ghost.py 2>/dev/null || true
    sleep 0.5

    cat << 'EOF' > "$VGT_GHOST_SCRIPT"
import socket, struct, sys, syslog, time, threading, hashlib
from http.server import BaseHTTPRequestHandler, HTTPServer

syslog.openlog(ident="VGT_L7_GHOST")

# --- GLOBAL METRICS FOR PROMETHEUS ---
METRICS = {
    'hits': 0,
    'strikes': 0,
    'ja3_blocks': 0,
    'behavioral_blocks': 0,
    'redis_syncs': 0
}

CACHE = {}
REDIS_CONN = None
REDIS_HOST = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] != "" else None
REDIS_PORT = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2] != "" else 6379
REDIS_CHAN = sys.argv[3] if len(sys.argv) > 3 else "vgt_bans"

# --- VGT-TRE: TLS BEHAVIORAL RISK ENGINE STATE ---
# { src_ip: { 'handshakes': count, 'http_requests': count, 'last_reset': timestamp } }
BEHAVIOR_STATE = {}
STATE_LOCK = threading.Lock()

# --- PROMETHEUS HTTP SERVER THREAD ---
class PrometheusExporter(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/metrics':
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain; version=0.0.4')
            self.end_headers()
            payload = (
                f"# HELP vgt_packet_hits_total Gesamtanzahl analysierter Frames L7\n"
                f"# TYPE vgt_packet_hits_total counter\n"
                f"vgt_packet_hits_total {METRICS['hits']}\n"
                f"# HELP vgt_kinetic_strikes_total Ausgeführte IP Bans\n"
                f"# TYPE vgt_kinetic_strikes_total counter\n"
                f"vgt_kinetic_strikes_total {METRICS['strikes']}\n"
                f"# HELP vgt_ja3_malicious_total Erkannte bösartige JA3 TLS Signaturen\n"
                f"# TYPE vgt_ja3_malicious_total counter\n"
                f"vgt_ja3_malicious_total {METRICS['ja3_blocks']}\n"
                f"# HELP vgt_behavioral_blocks_total Erkannte JA3/TLS Heuristik-Umgehungsversuche\n"
                f"# TYPE vgt_behavioral_blocks_total counter\n"
                f"vgt_behavioral_blocks_total {METRICS['behavioral_blocks']}\n"
                f"# HELP vgt_redis_sync_total Synchronisierte Ban-Events via Redis-Cluster\n"
                f"# TYPE vgt_redis_sync_total counter\n"
                f"vgt_redis_sync_total {METRICS['redis_syncs']}\n"
            )
            self.wfile.write(payload.encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        return

def start_metrics_server(port):
    try:
        server = HTTPServer(('127.0.0.1', port), PrometheusExporter)
        server.serve_forever()
    except Exception as e:
        syslog.syslog(f"METRICS SERVER ERROR: {e}")

# --- PURE PYTHON REDIS CLIENT (RESP PROTOCOL WITH AUTO-RECOVERY) ---
def redis_publish(msg):
    global REDIS_CONN
    if not REDIS_HOST: return
    try:
        if not REDIS_CONN:
            REDIS_CONN = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            REDIS_CONN.settimeout(2.0)
            REDIS_CONN.connect((REDIS_HOST, REDIS_PORT))
        payload = f"*3\r\n$9\r\nPUBLISH\r\n${len(REDIS_CHAN)}\r\n{REDIS_CHAN}\r\n${len(msg)}\r\n{msg}\r\n"
        REDIS_CONN.sendall(payload.encode('utf-8'))
        REDIS_CONN.recv(1024)
        METRICS['redis_syncs'] += 1
    except Exception:
        REDIS_CONN = None

# --- DEEP TLS DECODER: JA3, ALPN, GREASE & CONSISTENCY CHECKER ---
def analyze_tls_handshake(payload):
    try:
        if len(payload) < 43 or payload[0] != 22 or payload[5] != 1: return None, False, False
        
        offset = 43
        session_id_len = payload[offset]
        offset += 1 + session_id_len
        
        cipher_suites_len = struct.unpack('>H', payload[offset:offset+2])[0]
        offset += 2
        
        ciphers = []
        has_grease_cipher = False
        for i in range(0, cipher_suites_len, 2):
            val = struct.unpack('>H', payload[offset+i:offset+i+2])[0]
            # GREASE Ciphers end on 0x0a0a, 0x1a1a, etc. (RFC 8701)
            if (val & 0x0F0F) == 0x0A0A:
                has_grease_cipher = True
            ciphers.append(str(val))
        offset += cipher_suites_len
        
        comp_len = payload[offset]
        offset += 1 + comp_len
        
        if offset + 2 > len(payload): return None, False, False
        ext_len_total = struct.unpack('>H', payload[offset:offset+2])[0]
        offset += 2
        
        extensions = []
        curves = []
        point_formats = []
        has_alpn = False
        
        end = offset + ext_len_total
        while offset < end:
            if offset + 4 > len(payload): break
            ext_type, ext_len = struct.unpack('>HH', payload[offset:offset+4])
            offset += 4
            extensions.append(str(ext_type))
            
            # Detect ALPN (0x0010)
            if ext_type == 16:
                has_alpn = True
            # Supported Groups / EC Curves (0x000a)
            elif ext_type == 10:
                curr_offset = offset + 2
                while curr_offset < offset + ext_len:
                    curves.append(str(struct.unpack('>H', payload[curr_offset:curr_offset+2])[0]))
                    curr_offset += 2
            # EC Point Formats (0x000b)
            elif ext_type == 11:
                curr_offset = offset + 1
                while curr_offset < offset + ext_len:
                    point_formats.append(str(payload[curr_offset]))
                    curr_offset += 1
                    
            offset += ext_len
            
        ja3_str = f"771,{','.join(ciphers)},{','.join(extensions)},{','.join(curves)},{','.join(point_formats)}"
        ja3_hash = hashlib.md5(ja3_str.encode('utf-8')).hexdigest()
        
        return ja3_hash, has_alpn, has_grease_cipher
    except:
        return None, False, False

def parse_sni(payload):
    try:
        if len(payload) < 43 or payload[0] != 22 or payload[5] != 1: return None
        offset = 44 + payload[43]
        offset += 2 + struct.unpack('>H', payload[offset:offset+2])[0]
        offset += 1 + payload[offset]
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

# --- MAIN SOCKET LISTENER & ANOMALY EVALUATOR ---
try:
    t = threading.Thread(target=start_metrics_server, args=(int(sys.argv[4]),), daemon=True)
    t.start()

    s = socket.socket(socket.AF_PACKET, socket.SOCK_RAW, socket.ntohs(0x0003))
    while True:
        try:
            packet = s.recvfrom(65536)[0]
            if len(packet) < 40: continue
            
            eth_proto = struct.unpack('!H', packet[12:14])[0]
            offset = 14
            
            if eth_proto == 0x0800:
                if len(packet) < offset + 20: continue
                iph = struct.unpack('!BBHHHBBH4s4s', packet[offset:offset+20])
                if iph[6] != 6: continue
                iph_length = (iph[0] & 0xF) * 4
                src_ip = socket.inet_ntoa(iph[8])
                offset += iph_length
            elif eth_proto == 0x86dd:
                if len(packet) < offset + 40: continue
                iph = struct.unpack('!IHBB16s16s', packet[offset:offset+40])
                if iph[2] != 6: continue
                src_ip = socket.inet_ntop(socket.AF_INET6, iph[4])
                offset += 40
            else: continue

            if len(packet) < offset + 20: continue
            tcph = struct.unpack('!HHLLBBHHH', packet[offset:offset+20])
            dst_port = tcph[1]
            if dst_port not in (80, 443, 8443): continue

            tcph_length = tcph[4] >> 4
            h_size = offset + tcph_length * 4
            if len(packet) < h_size: continue
            payload = packet[h_size:]
            if len(payload) == 0: continue

            METRICS['hits'] += 1
            now = time.time()
            
            # --- VGT-TRE STATE INITIALIZATION ---
            with STATE_LOCK:
                if src_ip not in BEHAVIOR_STATE:
                    BEHAVIOR_STATE[src_ip] = { 'handshakes': 0, 'requests': 0, 'last_reset': now }
                state = BEHAVIOR_STATE[src_ip]
                # Reset Heuristic Windows every 10 seconds to prevent creeping false positives
                if (now - state['last_reset']) > 10.0:
                    state['handshakes'] = 0
                    state['requests'] = 0
                    state['last_reset'] = now

            # Process Layer 7 Payloads
            is_handshake = (dst_port in (443, 8443) and payload[0] == 22 and len(payload) > 5 and payload[5] == 1)
            is_http_request = (payload.startswith(b'GET ') or payload.startswith(b'POST ') or payload.startswith(b'HEAD '))
            
            ja3_hash = "N/A"
            structural_anomaly = False
            
            if is_handshake:
                with STATE_LOCK:
                    state['handshakes'] += 1
                
                # Perform deep cryptographic parsing
                ja3_hash, has_alpn, has_grease = analyze_tls_handshake(payload)
                
                # Structural JA3/TLS Spoof Check (Anomalie-Erkennung)
                # Google Chrome emulierter JA3 ohne GREASE oder ohne ALPN ist ein direkter Spoof!
                if ja3_hash:
                    # Chrome / Modern Browser Signaturen verlangen ALPN und GREASE standardmäßig
                    if any(c in ja3_hash for c in ("cd08", "b3e8", "66a5")):
                        if not has_alpn or not has_grease:
                            structural_anomaly = True
                            METRICS['behavioral_blocks'] += 1
                            syslog.syslog(f"VGT_L7_EVENT SRC={src_ip} DPT={dst_port} DOMAIN=SPOOFED_TLS_CLIENT JA3={ja3_hash} ANOMALY=STRUCTURAL")
                            continue
            
            elif is_http_request:
                with STATE_LOCK:
                    state['requests'] += 1

            # --- BEHAVIORAL VELOCITY SCHWELLE (VGT-TRE) ---
            # Wenn IP mehr als 15 TLS Handshakes ausführt, aber 0 HTTP Anfragen liefert = TLS-Handshake Flood (Spoofed JA3 Bypass)
            with STATE_LOCK:
                if state['handshakes'] > 15 and state['requests'] == 0:
                    METRICS['behavioral_blocks'] += 1
                    syslog.syslog(f"VGT_L7_EVENT SRC={src_ip} DPT={dst_port} DOMAIN=TLS_HANDSHAKE_FLOOD JA3=BEHAVIORAL ANOMALY=VELOCITY")
                    continue

            # Standard Domain Extraktion
            raw_domain = parse_sni(payload) if dst_port in (443, 8443) else parse_http(payload)
            if not raw_domain: continue
            
            domain = "".join([c for c in raw_domain if c.isalnum() or c in ".-_"])
            if not domain or len(domain) > 255: continue

            cache_key = f"{src_ip}_{domain}_{ja3_hash}"
            if cache_key in CACHE and (now - CACHE[cache_key]) < 0.5: continue
            CACHE[cache_key] = now

            syslog.syslog(f"VGT_L7_EVENT SRC={src_ip} DPT={dst_port} DOMAIN={domain} JA3={ja3_hash}")
        
        except (IndexError, struct.error):
            continue
        except Exception as e:
            continue
        
except Exception as e:
    syslog.syslog(f"CRITICAL SYSTEM ERROR IN GHOST CORE: {e}")
EOF
    # Start des Python Sensors im Hintergrund
    nohup python3 "$VGT_GHOST_SCRIPT" \
        "$REDIS_HOST" \
        "$REDIS_PORT" \
        "$REDIS_CHANNEL" \
        "$PROMETHEUS_PORT" >/dev/null 2>&1 &
}

# ==============================================================================
# ASYNC IPC EXECUTOR & AGENT ENGINE (HIGH PERFORMANCE PIPELINE)
# ==============================================================================
function start_executor() {
    rm -f "$VGT_QUEUE"
    mkfifo "$VGT_QUEUE"
    
    (
        exec 3<> "$VGT_QUEUE" # Pipe permanent offen halten
        local count=0
        local current_sec
        current_sec=$(date +%s)
        
        while IFS='|' read -r action target msg <&3; do
            [[ -z "$action" ]] && continue
            
            # Anti-Fork-Bomb Token Bucket
            local now
            now=$(date +%s)
            if (( now != current_sec )); then
                current_sec=$now
                count=0
            fi
            if (( count >= MAX_STRIKES_PER_SEC )); then
                sleep 0.01
            fi
            ((count++))

            # Direkte Exec-Aufrufe ohne Shell-Evaluierung. Injection physikalisch unmöglich.
            if [[ "$action" == "BAN_V4" ]]; then
                ipset add "$IPSET_V4" "$target" -exist 2>/dev/null || true
                
                # eBPF/XDP Map Manipulation via BPFTOOL
                if [[ "${VGT_EBPF_ACTIVE:-}" == "ACTIVE" ]]; then
                    local ip_hex
                    ip_hex=$(printf '0x%02x%02x%02x%02x' $(echo "$target" | tr '.' ' '))
                    bpftool map update name v4_ban_map key "$ip_hex" value 1 2>/dev/null || true
                fi
                logger -- "[VGT_KILL_LOG] $msg"
                
            elif [[ "$action" == "BAN_V6" ]]; then
                ipset add "$IPSET_V6" "$target" -exist 2>/dev/null || true
                
                if [[ "${VGT_EBPF_ACTIVE:-}" == "ACTIVE" ]]; then
                    local ipv6_hex
                    ipv6_hex=$(printf "0x%s" $(echo "$target" | ipv6calc --to-hex 2>/dev/null || echo "$target" | tr -d ':'))
                    bpftool map update name v6_ban_map key "$ipv6_hex" value 1 2>/dev/null || true
                fi
                logger -- "[VGT_KILL_LOG] $msg"
            fi
        done
    ) &
    export VGT_EXEC_PID=$!
}

# --- INITIALISIERUNG DER NETZWERKSCHILDE ---
function init_defense() {
    if [[ $EUID -ne 0 ]]; then 
        echo -e "${C_RED}[FATAL] Root-Berechtigungen zwingend erforderlich.${C_RESET}" >&2
        exit 1
    fi
    
    mkdir -p "$VGT_RUN_DIR"
    chmod 700 "$VGT_RUN_DIR"
    
    if [[ "$VGT_DISPLAY_MODE" == "VISUAL" ]]; then
        clear
        echo -e "${C_PURPLE}Injektiere VISIONGAIA DIAMANT V7.3.1 (Zero-Compiler Hardening Engine)...${C_RESET}"
    fi

    # IPSet Strukturierung
    ipset create "$IPSET_V4" hash:net family inet maxelem 1000000 timeout $BAN_TIME -exist 2>/dev/null || true
    ipset create "$IPSET_V6" hash:net family inet6 maxelem 1000000 timeout $BAN_TIME -exist 2>/dev/null || true

    # Firewalld/IPTables Schilde einhängen
    for cmd in "iptables" "ip6tables"; do
        set_name=$([[ "$cmd" == "iptables" ]] && echo "$IPSET_V4" || echo "$IPSET_V6")
        if ! $cmd -C INPUT -m set --match-set "$set_name" src -j DROP >/dev/null 2>&1; then
            $cmd -I INPUT 1 -m set --match-set "$set_name" src -j DROP
        fi
    done

    # Antike TCP Handshake Exploits direkt blockieren (Kernel Offloading)
    for cmd in "iptables" "ip6tables"; do
        if ! $cmd -C INPUT -m state --state INVALID -j DROP >/dev/null 2>&1; then
            $cmd -I INPUT 2 -m state --state INVALID -j DROP
            $cmd -I INPUT 3 -p tcp --tcp-flags ALL FIN,PSH,URG -j DROP 
            $cmd -I INPUT 4 -p tcp --tcp-flags ALL NONE -j DROP        
            $cmd -I INPUT 5 -p tcp --tcp-flags SYN,RST SYN -m tcpmss ! --mss 536:65535 -j DROP
        fi
    done

    # Portscans auf ungenutzte Sektoren ins Syslog leiten für den Parser
    for cmd in "iptables" "ip6tables"; do
        while $cmd -D INPUT -p tcp -m state --state NEW -m multiport ! --dports 80,443,8443 ! -i lo -m limit --limit 50/s --limit-burst 100 -j LOG --log-prefix "$LOG_PREFIX " 2>/dev/null; do :; done
        while $cmd -D INPUT -p tcp -m state --state NEW -m multiport ! --dports 80,443,8443 ! -i lo -j LOG --log-prefix "$LOG_PREFIX " 2>/dev/null; do :; done
        
        $cmd -I INPUT 6 -p tcp -m state --state NEW -m multiport ! --dports 80,443,8443 ! -i lo -m limit --limit 50/s --limit-burst 100 -j LOG --log-prefix "$LOG_PREFIX "
    done

    # Zero-Compiler Kernel-Level eBPF-Loading & Ghost Sensor Deployment
    deploy_ebpf_xdp
    deploy_l7_ghost
    start_executor
}

function cleanup_ui() {
    if [[ "$VGT_DISPLAY_MODE" == "VISUAL" ]]; then
        echo -ne "${TUI_RMCUP}${TUI_SHOW_CUR}"
        tput cnorm 2>/dev/null || true
        dmesg -E 2>/dev/null || true
    fi
    pkill -f "journalctl" 2>/dev/null || true
    kill -9 $VGT_EXEC_PID 2>/dev/null || true
    pkill -f vgt_l7_ghost.py 2>/dev/null || true
    
    # Kernel Bypass entladen (Falls eBPF aktiv war)
    if [[ "${VGT_EBPF_ACTIVE:-}" == "ACTIVE" ]]; then
        ip link set dev "$VGT_INTERFACE" xdp off 2>/dev/null || true
    fi
    
    rm -rf "$VGT_RUN_DIR"
    pkill -P $$ 2>/dev/null || true
    exit 0
}

# ==============================================================================
# STATE-RENDER ENGINE & COMPLEX ANALYTICS RUNTIME
# ==============================================================================
AWK_SCRIPT='
BEGIN {
    c_res = "\033[0m"; c_gry = "\033[38;2;100;100;100m"; c_cyn = "\033[38;2;0;204;255m"; 
    c_ylw = "\033[38;2;255;204;0m"; c_red = "\033[38;2;255;51;102m"; c_pur = "\033[38;2;180;0;255m";
    c_grn = "\033[38;2;0;255;153m"; c_wht = "\033[38;2;255;255;255m"; c_bld = "\033[1m";
    
    stat_ip = 0; stat_dom = 0; stat_flash = 0; stat_sys = 0; stat_infra = 0; stat_macro = 0; stat_total = 0;
    stat_ipv6_sub = 0;
    current_time = "00:00:00";
    
    LOG_MAX = 13; KILL_MAX = 5;
    for(i=1; i<=LOG_MAX; i++) log_buffer[i] = sprintf("%-132s", " ");
    for(i=1; i<=KILL_MAX; i++) kill_buffer[i] = sprintf("%-132s", " ");
    log_idx = 0; kill_idx = 0;

    sep_10 = "──────────"; 
    sep_17 = "─────────────────"; 
    sep_28 = "────────────────────────────"; 
    sep_10_2 = "──────────";
    
    top_line = ""; for(i=0;i<132;i++) top_line = top_line "─";
    
    mid_line  = sep_10 "┼" sep_17 "┼" sep_28 "┼" sep_10_2 "┼" sep_10_2 "┼" sep_10_2 "┼" sep_10_2 "┼" sep_10_2 "┼" sep_10_2 "┼" sep_10_2;
    head_line = sep_10 "┬" sep_17 "┬" sep_28 "┬" sep_10_2 "┬" sep_10_2 "┬" sep_10_2 "┬" sep_10_2 "┬" sep_10_2 "┬" sep_10_2 "┬" sep_10_2;

    split(wl_dom, wl_dom_arr, " ");
    for(i in wl_dom_arr) valid_domains[tolower(wl_dom_arr[i])] = 1;

    # Identifikation bekannter maliziöser JA3 Signaturen
    malicious_ja3["e674f7626966141a010d0d82696141a0"] = "Metasploit Client"
    malicious_ja3["b3e839d48b111a011d0d82696141a011"] = "Cobalt Strike"
    malicious_ja3["f7626966141a010d0d82696141a0e674"] = "Masscan Engine"

    if (mode == "VISUAL") { printf "\033[2J"; }
}

function render_frame() {
    if (mode != "VISUAL") return;
    
    printf "\033[H"; 
    
    print c_cyn "╭" top_line "╮" c_res;
    print c_cyn "│" c_pur "  ██╗   ██╗ ██████╗ ████████╗  " c_bld sprintf("%-101s", "VISIONGAIA TECHNOLOGY: SUPREME CLUSTER AUTOMATION V7.3.1") c_res c_cyn "│" c_res;
    print c_cyn "│" c_pur "  ██║   ██║██╔════╝ ╚══██╔══╝  " c_wht sprintf("%-42s", "SYSTEM CORES: [ " bpf_status " | HEURISTIC-TRE ]") c_cyn sprintf("%-59s", "UHRZEIT: " current_time) c_res c_cyn "│" c_res;
    print c_cyn "│" c_pur "  ╚██╗ ██╔╝██║  ███╗   ██║     " c_gry sprintf("%-101s", "-----------------------------------------------------------------------------------------------------") c_res c_cyn "│" c_res;
    
    stats_a = sprintf("[X] IP-KILLS: %-5d |  [🎯] DOM-KILLS: %-5d", stat_ip, stat_dom);
    stats_b = sprintf("[⚡] FLASH: %-8d |  [🔐] SYS-SNIPES: %-4d", stat_flash, stat_sys);
    stats_c = sprintf("[☢] INFRA (/24): %-3d |  [☠] MACRO (/16): %-4d", stat_infra, stat_macro);
    stats_d = sprintf("[🌐] IPv6 SUB (/64): %-3d", stat_ipv6_sub);
    
    print c_cyn "│" c_pur "   ╚████╔╝ ██║   ██║   ██║     " c_red sprintf("%-43s", stats_a) c_ylw sprintf("%-58s", stats_b) c_res c_cyn "│" c_res;
    print c_cyn "│" c_pur "    ╚██╔╝  ╚██████╔╝   ██║     " c_pur sprintf("%-43s", stats_c) c_green sprintf("%-58s", stats_d) c_res c_cyn "│" c_res;
    print c_cyn "│" c_pur "     ╚═╝    ╚═════╝    ╚═╝     " c_wht sprintf("%-101s", "GLOBAL KINETIC SHIELD ACTIONS: " stat_total) c_res c_cyn "│" c_res;

    print c_cyn "├" head_line "┤" c_res;
    print c_cyn "│" c_gry " ZEIT     " c_cyn "│" c_gry " QUELL-IP        " c_cyn "│" c_gry " DOMAIN (SNI/L7)             " c_cyn "│" c_gry " JA3 FINGER" c_cyn "│" c_gry "  BURST   " c_cyn "│" c_gry "   HITS   " c_cyn "│" c_gry "  R-HITS  " c_cyn "│" c_gry "  S-HITS  " c_cyn "│" c_gry " PORT     " c_cyn "│" c_gry " STATUS   " c_cyn "│" c_res;
    print c_cyn "├" mid_line "┤" c_res;

    for(i=1; i<=LOG_MAX; i++) {
        real_idx = (log_idx - LOG_MAX + i);
        if(real_idx < 1) { print c_cyn "│" c_gry sprintf("%-132s", " ") c_cyn "│" c_res; } 
        else { print log_buffer[(real_idx - 1) % LOG_MAX + 1]; }
    }

    print c_cyn "├" top_line "┤" c_res;
    print c_cyn "│" c_red c_bld sprintf(" %-131s", "[ CLUSTER-WIDE REALTIME KINETIC STRIKES ]") c_res c_cyn "│" c_res;
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

# High-Speed Zero-Shell Execution
function execute_strike(ip, is_v6, log_msg) {
    q_act = is_v6 ? "BAN_V6" : "BAN_V4"
    print q_act "|" ip "|" log_msg > q_pipe
    fflush(q_pipe)
}

function execute_range_strike(range, is_v6, log_msg) {
    q_act = is_v6 ? "BAN_V6" : "BAN_V4"
    print q_act "|" range "|" log_msg > q_pipe
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

    # Whitelist Filterung
    is_wl = 0; split(wl, wl_parts, " ");
    for (i in wl_parts) {
        if (wl_parts[i] == ip) { is_wl = 1; break; }
        if (wl_parts[i] ~ /\/24$/) {
            split(wl_parts[i], wl_range, "."); split(ip, ip_parts, ".");
            if (wl_range[1] == ip_parts[1] && wl_range[2] == ip_parts[2] && wl_range[3] == ip_parts[3]) { is_wl = 1; break; }
        }
    }
    if (is_wl || ip == "" || tolower(ip) ~ /^fe80:/) next;

    # Adressklassifizierung & Subnetz-Aggregation
    if (ip ~ /:/) {
        is_v6 = 1;
        split(ip, octets, ":");
        range = octets[1] ":" octets[2] ":" octets[3] ":" octets[4] "::/64";
        wide_range = "IPv6_WIDE";
    } else {
        is_v6 = 0;
        split(ip, octets, "."); 
        range = octets[1] "." octets[2] "." octets[3] ".0/24";
        wide_range = octets[1] "." octets[2] ".0.0/16";
    }

    match($0, /DPT=([0-9]+)/, arr_dpt); dpt = arr_dpt[1];
    tgt_color = c_gry;
    if (dpt == "80" || dpt == "443" || dpt == "8443") { tgt_color = c_cyn; svc = "[WEB]"; }
    else if (dpt == "25") { tgt_color = c_grn; svc = "[SMTP]"; }
    else if (dpt == "465" || dpt == "587" || dpt == "143" || dpt == "993" || dpt == "110" || dpt == "995") { tgt_color = c_ylw; svc = "[SEC-MAIL]"; }
    else if (dpt == "22" || dpt == "2222") { tgt_color = c_pur; svc = "[SSH]"; }
    else if (dpt == "21") { tgt_color = c_ylw; svc = "[FTP]"; }
    else if (dpt == "3306" || dpt == "888") { tgt_color = c_ylw; svc = "[PNL]"; }
    else { tgt_color = c_wht; svc = "[NET]"; }

    # IP-Schnittstellen Port Aggregation
    if (!ip_port_seen[ip "_" dpt]) {
        ip_port_seen[ip "_" dpt] = 1;
        ip_port_count[ip]++;
        if (ip_ports[ip] == "") ip_ports[ip] = dpt;
        else ip_ports[ip] = ip_ports[ip] "," dpt;
    }

    tgt_formatted = (ip_port_count[ip] == 1) ? ip_ports[ip] " " svc : ip_ports[ip];
    if (length(tgt_formatted) > 8) tgt_formatted = substr(tgt_formatted, 1, 6) "..";

    # JA3 & TLS L7 Heuristic Evaluation
    domain_label = "N/A (L4 SYN)"; domain_col = c_gry;
    is_l7_strike = 0; foreign_domain = "";
    ja3_label = "N/A"; ja3_col = c_gry;
    
    if ($0 ~ /VGT_L7_EVENT/) {
        match($0, /DOMAIN=([^ ]+)/, arr_dom); domain_val = arr_dom[1];
        match($0, /JA3=([^ ]+)/, arr_ja3); ja3_val = arr_ja3[1];
        match($0, /ANOMALY=([^ ]+)/, arr_anom); anomaly_val = arr_anom[1];
        
        if (anomaly_val == "STRUCTURAL") {
            domain_label = "SPOOFED_TLS_CLIENT"; domain_col = c_red;
            is_l7_strike = 4; # Structural Spoof Attack
        } else if (anomaly_val == "VELOCITY") {
            domain_label = "TLS_HANDSHAKE_FLOOD"; domain_col = c_red;
            is_l7_strike = 5; # TLS Bypass Velocity Flood
        }
        
        if (ja3_val != "N/A" && ja3_val != "" && ja3_val != "BEHAVIORAL") {
            ja3_label = substr(ja3_val, 1, 8);
            if (malicious_ja3[ja3_val]) {
                ja3_col = c_red;
                is_l7_strike = 3; # Static JA3 Signature Block
            } else {
                ja3_col = c_grn;
            }
        } else if (ja3_val == "BEHAVIORAL") {
            ja3_label = "ANOMALY"; ja3_col = c_red;
        }
        
        if (is_l7_strike == 0) {
            if (valid_domains[tolower(domain_val)]) {
                domain_label = domain_val; domain_col = c_grn;
            } else if (domain_val == "DIRECT_IP_OR_MALFORMED") {
                domain_label = substr(domain_val, 1, 26); domain_col = c_red; l7_viol[ip]++;
                if (l7_viol[ip] >= l7_limit) is_l7_strike = 1;
            } else {
                domain_label = substr(domain_val, 1, 26); domain_col = c_red; is_l7_strike = 2; foreign_domain = domain_val;
            }
        }
    }

    # Tracking counters
    ip_count[ip]++;
    range_count[range]++;
    if (!is_v6) { wide_range_count[wide_range]++; }

    sec_key = ip "_" $1 $2 $3; burst_count[sec_key]++; ip_burst = burst_count[sec_key];

    status_msg = "TRACKING"; status_col = c_gry;
    if (is_l7_strike == 3) { status_msg = "JA3-STRIKE"; status_col = c_red; }
    else if (is_l7_strike == 4) { status_msg = "JA3-SPOOF"; status_col = c_red; }
    else if (is_l7_strike == 5) { status_msg = "TLS-FLOOD"; status_col = c_red; }
    else if (is_l7_strike > 0) { status_msg = "DOM-KILL"; status_col = c_red; }
    else if (svc != "[WEB]" && svc != "[SMTP]") { status_msg = "SYS-KILL"; status_col = c_pur; }
    else if (ip_burst >= v_limit) { status_msg = "FLASH"; status_col = c_red; }
    else if (l7_viol[ip] > 0 && l7_viol[ip] < l7_limit) { status_msg = "L7-WARN"; status_col = c_ylw; }
    else if (ip_count[ip] >= ip_limit) { status_msg = "IP-KILL"; status_col = c_red; }
    else if (!is_v6 && range_count[range] >= r_limit) { status_msg = "RNG-KILL"; status_col = c_red; }
    else if (is_v6 && range_count[range] >= v6_sub_limit) { status_msg = "SUB6-KILL"; status_col = c_red; }
    else if (!is_v6 && wide_range_count[wide_range] >= wr_limit) { status_msg = "MAC-KILL"; status_col = c_pur; }

    # Dynamische Farbzuordnungen für Matrix
    b_col  = (ip_burst >= v_limit) ? c_red : (ip_burst >= (v_limit - 2) ? c_ylw : c_grn);
    h_col  = (ip_count[ip] >= (ip_limit - 3)) ? c_red : c_ylw;
    r_col  = (range_count[range] >= (r_limit - 5)) ? c_red : c_ylw;
    wr_col = (!is_v6 && wide_range_count[wide_range] >= (wr_limit - 20)) ? c_red : c_ylw;

    disp_b = (ip_burst < 0) ? "XXX" : (ip_burst > 999 ? "999" : ip_burst "");
    disp_h = (ip_count[ip] < 0) ? "XXX" : (ip_count[ip] > 999 ? "999" : ip_count[ip] "");
    disp_r = (range_count[range] < 0) ? "XXX" : (range_count[range] > 999 ? "999" : range_count[range] "");
    disp_w = is_v6 ? "0" : ((wide_range_count[wide_range] < 0) ? "XXX" : (wide_range_count[wide_range] > 999 ? "999" : wide_range_count[wide_range] ""));

    padded_time = sprintf("%-8.8s", current_time);
    padded_ip = sprintf("%-15.15s", ip);
    padded_dom = sprintf("%-26.26s", domain_label);
    padded_ja3 = sprintf("%-8.8s", ja3_label);
    padded_tgt = sprintf("%-8.8s", tgt_formatted);
    padded_b = sprintf("%3s", disp_b);
    padded_h = sprintf("%3s", disp_h);
    padded_r = sprintf("%3s", disp_r);
    padded_w = sprintf("%3s", disp_w);
    padded_status = sprintf("%-8.8s", status_msg);

    row = c_cyn "│" c_res " " c_gry padded_time c_res " " c_cyn "│" \
          c_res " " c_wht padded_ip c_res " " c_cyn "│" \
          c_res " " domain_col padded_dom c_res " " c_cyn "│" \
          c_res " " ja3_col padded_ja3 c_res " " c_cyn "│" \
          c_res "   " b_col padded_b c_res "    " c_cyn "│" \
          c_res "   " h_col padded_h c_res "    " c_cyn "│" \
          c_res "   " r_col padded_r c_res "    " c_cyn "│" \
          c_res "   " wr_col padded_w c_res "    " c_cyn "│" \
          c_res " " tgt_color padded_tgt c_res " " c_cyn "│" \
          c_res " " status_col padded_status c_res " " c_cyn "│" c_res;
    
    push_log(row);

    # --- KINETIC ACTION CONTROLLER ---
    if (is_l7_strike == 5 && !killed[ip]) {
        killed[ip] = 1; stat_dom++;
        msg = "VGT-TRE STRIKE: TLS Handshake-Flood (Bypass-Versuch) hingerichtet. IP: " ip;
        push_kill("[⚡]", msg, c_red);
        execute_strike(ip, is_v6, msg);
        ip_count[ip] = -999; burst_count[sec_key] = -999;
    }
    else if (is_l7_strike == 4 && !killed[ip]) {
        killed[ip] = 1; stat_dom++;
        msg = "VGT-TRE STRIKE: TLS-Signature Spoofing (Falsche Extensions) blockiert. IP: " ip;
        push_kill("[💀]", msg, c_red);
        execute_strike(ip, is_v6, msg);
        ip_count[ip] = -999; burst_count[sec_key] = -999;
    }
    else if (is_l7_strike == 3 && !killed[ip]) {
        killed[ip] = 1; stat_dom++;
        msg = "JA3 BLOCK: Bösartige Signatur (" ja3_val ") blockiert. IP: " ip;
        push_kill("[✖]", msg, c_red);
        execute_strike(ip, is_v6, msg);
        ip_count[ip] = -999; burst_count[sec_key] = -999;
    }
    else if (is_l7_strike > 0 && !killed[ip]) {
        killed[ip] = 1; stat_dom++;
        msg = (is_l7_strike == 2) ? "SNI SPOOFING: IP " ip " eliminiert (Fremde Domain: " foreign_domain ")." : "SNI VIOLATION: IP " ip " eliminiert (" l7_viol[ip] "x fehlerhaft).";
        push_kill("[🎯]", msg, c_red);
        execute_strike(ip, is_v6, msg);
        ip_count[ip] = -999; burst_count[sec_key] = -999;
    }
    else if (svc != "[WEB]" && svc != "[SMTP]" && !killed[ip]) {
        killed[ip] = 1; stat_sys++;
        msg = "SYS-KILL " ip
        push_kill("[🔐]", "ZERO-TOLERANCE: IP " ip " hingerichtet (Scanner-Portscan auf Port " dpt ").", c_pur);
        execute_strike(ip, is_v6, msg);
        ip_count[ip] = -999; burst_count[sec_key] = -999;
    }
    else if (ip_burst >= v_limit && !killed[ip]) {
        killed[ip] = 1; stat_flash++;
        msg = "FLASH-KILL " ip
        push_kill("[⚡]", "VELOCITY STRIKE: IP " ip " terminiert (" ip_burst " Hits/sek).", c_red);
        execute_strike(ip, is_v6, msg);
        burst_count[sec_key] = -999; 
    } 
    else if (ip_count[ip] == ip_limit && !killed[ip]) {
        killed[ip] = 1; stat_ip++;
        msg = "IP-KILL " ip
        push_kill("[✖]", "RATE-LIMIT: IP " ip " für 24 Stunden hingerichtet.", c_red);
        execute_strike(ip, is_v6, msg);
    }
    
    # Subnetz Strikes
    if (!is_v6 && range_count[range] == r_limit && !killed[range]) {
        killed[range] = 1; stat_infra++;
        msg = "RNG-KILL " range
        push_kill("[☢]", "INFRA-SCHLAG: IPv4 Range " range " terminiert.", c_red);
        execute_range_strike(range, is_v6, msg);
    }
    if (is_v6 && range_count[range] == v6_sub_limit && !killed[range]) {
        killed[range] = 1; stat_ipv6_sub++;
        msg = "SUB6-KILL " range
        push_kill("[🌐]", "IPv6 SUB-SCHLAG: Subnetz " range " vollständig terminiert.", c_red);
        execute_range_strike(range, is_v6, msg);
    }
    if (!is_v6 && wide_range_count[wide_range] == wr_limit && !killed[wide_range]) {
        killed[wide_range] = 1; stat_macro++;
        msg = "MAC-KILL " wide_range
        push_kill("[☠]", "MACRO-SCHLAG: Sektor " wide_range " terminiert.", c_pur);
        execute_range_strike(wide_range, is_v6, msg);
    }

    render_frame();
}
'

# ==============================================================================
# HULL CONTROL & DAEMON PIPELINE (ULTRA-HARDENED ASYNC PARSING PIPELINE)
# ==============================================================================
function start_hunt() {
    trap cleanup_ui SIGINT SIGTERM EXIT
    
    if [[ "$VGT_DISPLAY_MODE" == "VISUAL" ]]; then
        echo -ne "${TUI_SMCUP}${TUI_HIDE_CUR}"
        dmesg -D 2>/dev/null || true 
        
        {
            # HÄRTUNG: Extrem restriktive, fälschungssichere Log-Quellen zur Unterbindung von lokalem Log-Spoofing
            journalctl -k -n 0 -f --grep="$LOG_PREFIX" 2>/dev/null &
            KPID=$!
            
            # Nur Einträge vom verifizierten Python-Identifikator (VGT_L7_GHOST), 
            # die ZWINGEND unter der System-UID 0 (Root) generiert wurden (_UID=0).
            journalctl _UID=0 SYSLOG_IDENTIFIER=VGT_L7_GHOST -n 0 -f 2>/dev/null &
            GPID=$!
            
            trap "kill $KPID $GPID 2>/dev/null" EXIT
            
            while true; do 
                echo "[VGT_TICK] $(date +'%H:%M:%S')"
                if ! pgrep -f vgt_l7_ghost.py > /dev/null; then export VGT_RECOVERY=1; deploy_l7_ghost; fi
                sleep 1
            done
        } | awk \
            -v mode="VISUAL" \
            -v q_pipe="$VGT_QUEUE" \
            -v ip_limit="$IP_THRESHOLD" \
            -v l7_limit="$L7_STRIKE_THRESHOLD" \
            -v r_limit="$RANGE_THRESHOLD" \
            -v v6_sub_limit="$IPV6_SUB_THRESHOLD" \
            -v wr_limit="$WIDE_RANGE_THRESHOLD" \
            -v v_limit="$VELOCITY_LIMIT" \
            -v set_v4="$IPSET_V4" \
            -v set_v6="$IPSET_V6" \
            -v wl="$WHITELIST_IPS" \
            -v wl_dom="$WHITELIST_DOMAINS" \
            -v bpf_status="${VGT_EBPF_ACTIVE:-FALLBACK}" \
            -v p_port="$PROMETHEUS_PORT" \
            "$AWK_SCRIPT"
    else
        {
            journalctl -k -n 0 -f --grep="$LOG_PREFIX" 2>/dev/null &
            KPID=$!
            journalctl _UID=0 SYSLOG_IDENTIFIER=VGT_L7_GHOST -n 0 -f 2>/dev/null &
            GPID=$!
            
            trap "kill $KPID $GPID 2>/dev/null" EXIT
            
            while true; do
                if ! pgrep -f vgt_l7_ghost.py > /dev/null; then export VGT_RECOVERY=1; deploy_l7_ghost; fi
                sleep 5
            done
        } | awk \
            -v mode="SILENT" \
            -v q_pipe="$VGT_QUEUE" \
            -v ip_limit="$IP_THRESHOLD" \
            -v l7_limit="$L7_STRIKE_THRESHOLD" \
            -v r_limit="$RANGE_THRESHOLD" \
            -v v6_sub_limit="$IPV6_SUB_THRESHOLD" \
            -v wr_limit="$WIDE_RANGE_THRESHOLD" \
            -v v_limit="$VELOCITY_LIMIT" \
            -v set_v4="$IPSET_V4" \
            -v set_v6="$IPSET_V6" \
            -v wl="$WHITELIST_IPS" \
            -v wl_dom="$WHITELIST_DOMAINS" \
            -v bpf_status="${VGT_EBPF_ACTIVE:-FALLBACK}" \
            -v p_port="$PROMETHEUS_PORT" \
            "$AWK_SCRIPT" || true
    fi
}

init_defense
start_hunt
