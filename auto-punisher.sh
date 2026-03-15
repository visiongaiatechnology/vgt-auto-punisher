#!/bin/bash
# ==============================================================================
# VISIONGAIA TECHNOLOGY: AUTO-PUNISHER (OPEN SOURCE SUPREME)
# STATUS: DIAMANT VGT SUPREME
# LICENCE: MIT / SOUVEREIGN GEEK
# ZWECK: Automatisches Verhaltens-basiertes Blockieren von Angreifern im Kernel.
# UPDATE: Heartbeat (Anti-Freeze), IPv6-Support & Dynamische Whitelist.
# ==============================================================================

# --- KONFIGURATION ---
IPSET_NAME="VGT_AUTO_BANNED"
IP_THRESHOLD=30           # Hits bis zum Einzel-IP Ban
RANGE_THRESHOLD=60        # Hits bis zum /24 Subnetz Ban
LOG_PREFIX="[VGT_ANOMALY]" # Muss mit der iptables LOG-Regel übereinstimmen

# --- WHITELIST (Souveräne Ausnahme-Liste) ---
# Adressen, die NIEMALS gebannt werden dürfen.
WHITELIST_IPS="127.0.0.1 ::1 0.0.0.0"

# --- AUTOMATISCHE INITIALISIERUNG (SELF-HEALING) ---
function init_defense() {
    echo "[VGT] Initialisiere System-Integritäts-Check..."

    if [[ $EUID -ne 0 ]]; then 
       echo "[FEHLER] Root-Privilegien erforderlich!"
       exit 1
    fi

    # Tool-Check
    for tool in ipset iptables journalctl awk; do
        if ! command -v $tool &> /dev/null; then
            echo "[!] $tool fehlt. Installiere Abhängigkeiten..."
            apt-get update && apt-get install -y ipset iptables
        fi
    done

    # IPSET-Check
    if ! ipset list "$IPSET_NAME" > /dev/null 2>&1; then
        echo "[+] Erstelle IPSET-Tabelle: $IPSET_NAME"
        ipset create "$IPSET_NAME" hash:net maxelem 1000000 -exist
    fi

    # IPTables-Check: DROP-Regel
    if ! iptables -C INPUT -m set --match-set "$IPSET_NAME" src -j DROP > /dev/null 2>&1; then
        echo "[+] Verknüpfe IPSET mit Firewall (Position 1)..."
        iptables -I INPUT 1 -m set --match-set "$IPSET_NAME" src -j DROP
    fi

    # IPTables-Check: LOG-Regel (Sensor)
    if ! iptables -S | grep -q "$LOG_PREFIX"; then
        echo "[+] Installiere Anomalie-Sensor (Log-Regel)..."
        iptables -I INPUT 2 ! -i lo -p tcp --syn -j LOG --log-prefix "$LOG_PREFIX "
    fi

    if [ ! -d /etc/iptables ]; then mkdir -p /etc/iptables; fi
    echo "[VGT] System-Integrität bestätigt. Schilde sind aktiv."
}

# --- START DER JAGD ---
clear
echo "=========================================================="
echo "   VGT AUTO-PUNISHER - OPEN SOURCE DEFENSE ENGINE         "
echo "   Status: DIAMANT VGT SUPREME (READY FOR GITHUB)         "
echo "=========================================================="
echo "   IP-Limit: $IP_THRESHOLD | Range-Limit: $RANGE_THRESHOLD"
echo "   Whitelist: $WHITELIST_IPS"
echo "   Sicherheit: Anti-Freeze Heartbeat & v4/v6 Support"
echo "----------------------------------------------------------"

init_defense

# --- VGT SSH ANTI-FREEZE HEARTBEAT ---
# Erzeugt ein unsichtbares Signal, um PuTTY/SSH-Timeouts zu verhindern.
(
    while true; do
        sleep 45
        printf "\033[s\033[u" # Save & Restore Cursor Position
    done
) &
HEARTBEAT_PID=$!
# Killt den Heartbeat-Prozess sauber beim Beenden des Skripts
trap 'kill $HEARTBEAT_PID 2>/dev/null; echo -e "\n[VGT] Jagd beendet. Schilde bleiben aktiv."; exit' EXIT INT TERM

echo "ZEITSTEMPEL         | QUELL-IP        | HITS | RANGE-HITS"
echo "----------------------------------------------------------"

# Der Kern: Analyse des Kernel-Streams via AWK
journalctl -kf --grep="$LOG_PREFIX" | awk -v ip_limit="$IP_THRESHOLD" -v range_limit="$RANGE_THRESHOLD" -v set_name="$IPSET_NAME" -v wl_list="$WHITELIST_IPS" '
    /SRC=/ {
        # Dual-Stack Regex (v4 & v6)
        match($0, /SRC=([0-9a-fA-F:.]+)/, arr);
        ip = arr[1];

        # Whitelist Check
        if (index(" " wl_list " ", " " ip " ") > 0 || ip == "") {
            next; 
        }
        
        zeit = $1 " " $2 " " $3;

        # IPv4 Subnetz-Logik (/24)
        if (ip ~ /\./) {
            split(ip, octets, ".");
            range = octets[1] "." octets[2] "." octets[3] ".0/24";
        } else {
            range = "IPv6_STRIKE"; 
        }

        ip_count[ip]++;
        if (range != "IPv6_STRIKE") {
            range_count[range]++;
        }

        printf "%-19s | %-15s | %4d | %4d\n", zeit, ip, ip_count[ip], (range == "IPv6_STRIKE" ? 0 : range_count[range]);

        # PUNISH: IP
        if (ip_count[ip] == ip_limit) {
            print "\n[!!!] PUNISH: IP " ip " terminiert (Limit " ip_limit " erreicht).";
            system("ipset add " set_name " " ip " -exist");
            system("iptables-save > /etc/iptables/rules.v4");
            print "----------------------------------------------------------";
        }

        # PUNISH: Range (v4 only)
        if (range != "IPv6_STRIKE" && range_count[range] == range_limit) {
            print "\n[!!!] INFRA-SCHLAG: Range " range " terminiert (Limit " range_limit " erreicht).";
            system("ipset add " set_name " " range " -exist");
            system("iptables-save > /etc/iptables/rules.v4");
            print "----------------------------------------------------------";
        }
        
        fflush();
    }
'
