#!/bin/bash
# ==============================================================================
# VISIONGAIA TECHNOLOGY: AUTO-PUNISHER (V3.0 - SUPREME OS EDITION)
# STATUS: DIAMANT VGT SUPREME
# LICENCE: MIT / SOVEREIGN GEEK
# ZWECK: Automatisches Verhaltens-basiertes Blockieren von Angreifern im Kernel.
# FEATURES: Dual-Stack (IPv4/v6), Neon UI, Self-Healing Init, SSH-Heartbeat.
# ==============================================================================

# --- KONFIGURATION ---
IPSET_V4="VGT_BANNED_V4"
IPSET_V6="VGT_BANNED_V6"
IP_THRESHOLD=15           # Hits bis zum Einzel-IP Ban
RANGE_THRESHOLD=30        # Hits bis zum /24 Subnetz Ban (Nur IPv4)
LOG_PREFIX="[VGT_ANOMALY]"

# --- WHITELIST (Souveräne Ausnahme-Liste) ---
# Adressen, die NIEMALS gebannt werden dürfen. Link-Local (fe80) inklusive.
WHITELIST_IPS="127.0.0.1 ::1 0.0.0.0 :: fe80::/10"

# --- ANSI FARBEN (NEON UI) ---
C_RED='\033[1;31m'
C_GREEN='\033[1;32m'
C_YELLOW='\033[1;33m'
C_CYAN='\033[1;36m'
C_PURPLE='\033[1;35m'
C_GRAY='\033[1;30m'
C_RESET='\033[0m'

# --- AUTOMATISCHE INITIALISIERUNG (SELF-HEALING) ---
function init_defense() {
    echo -e "${C_GRAY}[VGT] Initialisiere System-Integritäts-Check...${C_RESET}"

    if [[ $EUID -ne 0 ]]; then 
       echo -e "${C_RED}[FEHLER] Root-Privilegien erforderlich!${C_RESET}"
       exit 1
    fi

    # Tool-Check
    for tool in ipset iptables ip6tables journalctl awk; do
        if ! command -v $tool &> /dev/null; then
            echo -e "${C_YELLOW}[!] $tool fehlt. Installiere Abhängigkeiten...${C_RESET}"
            apt-get update && apt-get install -y ipset iptables
        fi
    done

    # IPv4 Setup (Tabellen & Regeln)
    if ! ipset list "$IPSET_V4" > /dev/null 2>&1; then
        ipset create "$IPSET_V4" hash:net family inet maxelem 1000000 -exist
    fi
    if ! iptables -C INPUT -m set --match-set "$IPSET_V4" src -j DROP > /dev/null 2>&1; then
        iptables -I INPUT 1 -m set --match-set "$IPSET_V4" src -j DROP
    fi
    if ! iptables -S | grep -q "$LOG_PREFIX"; then
        iptables -I INPUT 2 ! -i lo -p tcp --syn -j LOG --log-prefix "$LOG_PREFIX "
    fi

    # IPv6 Setup (Tabellen & Regeln) - Fehler ignorieren, falls OS kein IPv6 unterstützt
    if ! ipset list "$IPSET_V6" > /dev/null 2>&1; then
        ipset create "$IPSET_V6" hash:net family inet6 maxelem 1000000 -exist 2>/dev/null || true
    fi
    if ! ip6tables -C INPUT -m set --match-set "$IPSET_V6" src -j DROP > /dev/null 2>&1; then
        ip6tables -I INPUT 1 -m set --match-set "$IPSET_V6" src -j DROP 2>/dev/null || true
    fi
    if ! ip6tables -S 2>/dev/null | grep -q "$LOG_PREFIX"; then
        ip6tables -I INPUT 2 ! -i lo -p tcp --syn -j LOG --log-prefix "$LOG_PREFIX " 2>/dev/null || true
    fi

    if [ ! -d /etc/iptables ]; then mkdir -p /etc/iptables; fi
    echo -e "${C_GREEN}[VGT] System-Integrität bestätigt. Dual-Stack Schilde sind aktiv.${C_RESET}"
    sleep 1
}

# --- START DER JAGD ---
clear
init_defense
clear

echo -e "${C_PURPLE}============================================================================${C_RESET}"
echo -e "${C_CYAN}   VGT AUTO-PUNISHER - OPEN SOURCE DEFENSE ENGINE (V3.0)                    ${C_RESET}"
echo -e "${C_PURPLE}   Status:${C_RESET} DUAL STACK SUPREME (IPv4 & IPv6 Monitoring)                    "
echo -e "${C_PURPLE}============================================================================${C_RESET}"
echo -e "   ${C_GRAY}IP-Limit:${C_RESET} ${C_YELLOW}${IP_THRESHOLD}${C_RESET} | ${C_GRAY}Range-Limit:${C_RESET} ${C_RED}${RANGE_THRESHOLD}${C_RESET}"
echo -e "   ${C_GRAY}Whitelist:${C_RESET} ${C_GREEN}${WHITELIST_IPS}${C_RESET}"
echo -e "   ${C_GRAY}Features:${C_RESET}  Anti-Freeze Heartbeat, Neon-Matrix, Self-Healing Sensors"
echo -e "${C_PURPLE}----------------------------------------------------------------------------${C_RESET}"

# --- VGT SSH ANTI-FREEZE HEARTBEAT ---
(
    while true; do
        sleep 45
        printf "\033[s\033[u" # Save & Restore Cursor
    done
) &
HEARTBEAT_PID=$!
trap 'kill $HEARTBEAT_PID 2>/dev/null; echo -e "\n${C_PURPLE}[VGT] Jagd beendet. Schilde bleiben aktiv.${C_RESET}"; exit' EXIT INT TERM

# Tabellen-Kopf (Abgestimmt auf IPv6 Breite)
echo -e "${C_GRAY}ZEITSTEMPEL         | QUELL-IP                                | HITS | RANGE${C_RESET}"
echo -e "${C_GRAY}----------------------------------------------------------------------------${C_RESET}"

# --- DIE INTELLIGENZ-MATRIX (AWK mit ANSI-Injection & Dual-Stack Logic) ---
journalctl -kf --grep="$LOG_PREFIX" | awk -v ip_limit="$IP_THRESHOLD" -v range_limit="$RANGE_THRESHOLD" -v set_v4="$IPSET_V4" -v set_v6="$IPSET_V6" -v wl_list="$WHITELIST_IPS" '
    BEGIN {
        c_res = "\033[0m"; c_gry = "\033[1;30m"; c_cyn = "\033[1;36m"; 
        c_ylw = "\033[1;33m"; c_red = "\033[1;31m"; c_grn = "\033[1;32m";
    }
    /SRC=/ {
        match($0, /SRC=([0-9a-fA-F:.]+)/, arr);
        ip = arr[1];

        # FIX: IPv6 Unspecified Bug (0000:0000...) kondensieren
        if (ip == "0000:0000:0000:0000:0000:0000:0000:0000" || ip == "0:0:0:0:0:0:0:0") {
            ip = "::";
        }

        # Whitelist Check
        if (index(" " wl_list " ", " " ip " ") > 0 || ip == "" || tolower(ip) ~ /^fe80:/) {
            next; 
        }
        
        zeit = $1 " " $2 " " $3;

        # DUAL-STACK ROUTING LOGIK
        if (ip ~ /:/) {
            # IPv6 Detektiert
            target_set = set_v6;
            save_cmd = "ip6tables-save > /etc/iptables/rules.v6 2>/dev/null || true";
            range = "IPv6_SINGLE"; # Range-Kills bei IPv6 vorerst deaktiviert
        } else {
            # IPv4 Detektiert
            target_set = set_v4;
            save_cmd = "iptables-save > /etc/iptables/rules.v4 2>/dev/null || true";
            split(ip, octets, ".");
            range = octets[1] "." octets[2] "." octets[3] ".0/24";
        }

        ip_count[ip]++;
        if (range != "IPv6_SINGLE") {
            range_count[range]++;
        }

        # Dynamische Farb-Warnstufen
        h_col = (ip_count[ip] >= (ip_limit - 5)) ? c_red : c_ylw;
        r_col = (range != "IPv6_STRIKE" && range_count[range] >= (range_limit - 10)) ? c_red : c_ylw;
        if (range == "IPv6_SINGLE") r_col = c_gry;

        # Formatierter Tabellen-Output
        printf "%s%-19s%s | %s%-39s%s | %s%4d%s | %s%4d%s\n", c_gry, zeit, c_res, c_cyn, ip, c_res, h_col, ip_count[ip], c_res, r_col, (range == "IPv6_SINGLE" ? 0 : range_count[range]), c_res;

        # KINETIC STRIKE: IP
        if (ip_count[ip] == ip_limit) {
            print "\n" c_red "[!!!] PUNISH: IP " ip " terminiert (Limit erreicht)." c_res;
            system("ipset add " target_set " " ip " -exist");
            system(save_cmd);
            print c_gry "----------------------------------------------------------------------------" c_res;
        }

        # KINETIC STRIKE: RANGE (Nur IPv4)
        if (range != "IPv6_SINGLE" && range_count[range] == range_limit) {
            print "\n" c_red "[!!!] INFRA-SCHLAG: Range " range " terminiert (Limit erreicht)." c_res;
            system("ipset add " target_set " " range " -exist");
            system(save_cmd);
            print c_gry "----------------------------------------------------------------------------" c_res;
        }
        
        fflush();
    }
'
