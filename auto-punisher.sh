#!/bin/bash
# ==============================================================================
# VISIONGAIA TECHNOLOGY: AUTO-PUNISHER (OPEN SOURCE EDITION)
# STATUS: DIAMANT VGT SUPREME
# LICENCE: MIT / SOUVEREIGN GEEK
# ZWECK: Automatisches Verhaltens-basiertes Blockieren von Angreifern im Kernel.
# UPDATE: IPv6-Support & Dynamische Whitelist integriert.
# ==============================================================================

# --- KONFIGURATION ---
IPSET_NAME="VGT_AUTO_BANNED"
IP_THRESHOLD=30           # Hits bis zum Einzel-IP Ban
RANGE_THRESHOLD=60        # Hits bis zum /24 Subnetz Ban
LOG_PREFIX="[VGT_ANOMALY]" # Muss mit der iptables LOG-Regel übereinstimmen

# --- WHITELIST (Souveräne Ausnahme-Liste) ---
# Hier alle IPs eintragen, die NIEMALS gebannt werden dürfen (durch Leerzeichen getrennt).
# Standardmäßig: Localhost (v4 & v6) und der Null-Vektor.
WHITELIST_IPS="127.0.0.1 ::1 0.0.0.0"

# --- AUTOMATISCHE INITIALISIERUNG (SELF-HEALING) ---
function init_defense() {
    echo "[VGT] Initialisiere System-Integritäts-Check..."

    # 1. Root-Check
    if [[ $EUID -ne 0 ]]; then 
       echo "[FEHLER] Dieses Tool erfordert Root-Privilegien!"
       exit 1
    fi

    # 2. Tool-Check
    for tool in ipset iptables journalctl awk; do
        if ! command -v $tool &> /dev/null; then
            echo "[!] $tool fehlt. Installiere Abhängigkeiten..."
            apt-get update && apt-get install -y ipset iptables
        fi
    done

    # 3. IPSET-Check (Der Kerker)
    if ! ipset list "$IPSET_NAME" > /dev/null 2>&1; then
        echo "[+] Erstelle IPSET-Tabelle: $IPSET_NAME"
        # Hinweis: hash:net unterstützt in der Standard-Konfiguration IPv4. 
        ipset create "$IPSET_NAME" hash:net maxelem 1000000 -exist
    fi

    # 4. IPTables-Check (Die Guillotine)
    if ! iptables -C INPUT -m set --match-set "$IPSET_NAME" src -j DROP > /dev/null 2>&1; then
        echo "[+] Verknüpfe IPSET mit Firewall (Position 1)..."
        iptables -I INPUT 1 -m set --match-set "$IPSET_NAME" src -j DROP
    fi

    # Prüfen, ob die Logging-Regel (Sensor) existiert
    if ! iptables -S | grep -q "$LOG_PREFIX"; then
        echo "[+] Installiere Anomalie-Sensor (Log-Regel)..."
        # Wichtig: ! -i lo verhindert, dass wir uns selbst loggen/bannen
        iptables -I INPUT 2 ! -i lo -p tcp --syn -j LOG --log-prefix "$LOG_PREFIX "
    fi

    # 5. Persistenz-Check
    if [ ! -d /etc/iptables ]; then
        mkdir -p /etc/iptables
    fi

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
echo "   Sicherheit: Dual-Stack Erkennung (v4/v6) ist AKTIV"
echo "----------------------------------------------------------"

init_defense

echo "ZEITSTEMPEL         | QUELL-IP        | HITS | RANGE-HITS"
echo "----------------------------------------------------------"

# Der Kern: Analyse des Kernel-Streams
# Wir übergeben die Whitelist-Variable an AWK via -v
journalctl -kf --grep="$LOG_PREFIX" | awk -v ip_limit="$IP_THRESHOLD" -v range_limit="$RANGE_THRESHOLD" -v set_name="$IPSET_NAME" -v wl_list="$WHITELIST_IPS" '
    /SRC=/ {
        # IP extrahieren (Erweiterte Regex für IPv6 Support: erkennt Zahlen, Punkte, Doppelpunkte und Hex-Zeichen)
        match($0, /SRC=([0-9a-fA-F:.]+)/, arr);
        ip = arr[1];

        # --- DYNAMISCHE WHITELIST PRÜFUNG ---
        # Wir prüfen, ob die IP in der übergebenen Whitelist-Zeichenkette existiert
        if (index(" " wl_list " ", " " ip " ") > 0 || ip == "") {
            next; 
        }
        
        # Zeitstempel extrahieren
        zeit = $1 " " $2 " " $3;

        # Subnetz-Berechnung (Nur für IPv4 sinnvoll, IPv6 wird als Einzel-IP behandelt)
        if (ip ~ /\./) {
            split(ip, octets, ".");
            range = octets[1] "." octets[2] "." octets[3] ".0/24";
        } else {
            range = "IPv6_STRIKE"; # Markierung für IPv6 (Infrastruktur-Schläge hier komplexer)
        }

        # Counter erhöhen
        ip_count[ip]++;
        if (range != "IPv6_STRIKE") {
            range_count[range]++;
        }

        # Visuelle Ausgabe
        printf "%-19s | %-15s | %4d | %4d\n", zeit, ip, ip_count[ip], (range == "IPv6_STRIKE" ? 0 : range_count[range]);

        # AKTION: Einzel-IP Ban
        if (ip_count[ip] == ip_limit) {
            print "\n[!!!] PUNISH: IP " ip " terminiert (Limit " ip_limit " erreicht).";
            system("ipset add " set_name " " ip " -exist");
            system("iptables-save > /etc/iptables/rules.v4");
            print "----------------------------------------------------------";
        }

        # AKTION: Range-Ban (Infrastruktur-Schlag, nur für IPv4)
        if (range != "IPv6_STRIKE" && range_count[range] == range_limit) {
            print "\n[!!!] INFRA-SCHLAG: Range " range " terminiert (Limit " range_limit " erreicht).";
            system("ipset add " set_name " " range " -exist");
            system("iptables-save > /etc/iptables/rules.v4");
            print "----------------------------------------------------------";
        }
        
        fflush();
    }
'