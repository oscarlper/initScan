#!/bin/bash

# Obtener la interfaz de red desde el argumento
IFACE="$1"

if [[ -z "$IFACE" ]]; then
    echo "Uso: $0 <interfaz>"
    exit 1
fi

# Definir directorio base en el home del usuario actual
BASE_DIR="$HOME/pentest"
mkdir -p "$BASE_DIR/init"

echo "[+] Escaneando red en $IFACE..."
sudo nmap -sn -oG "$BASE_DIR/init/hosts_scan.txt" $(ip -4 addr show "$IFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' | cut -d '/' -f1)/24

# Extraer IPs activas excluyendo la del atacante
grep 'Up$' "$BASE_DIR/init/hosts_scan.txt" | awk '{print $2}' | grep -v "$(hostname -I | awk '{print $1}')" > "$BASE_DIR/init/active_hosts.txt"

# Crear directorios para cada host encontrado
for ip in $(cat "$BASE_DIR/init/active_hosts.txt"); do
    mkdir -p "$BASE_DIR/$ip"
done

# Escaneo de puertos
TARGETS=$(cat "$BASE_DIR/init/active_hosts.txt" | tr '\n' ' ')
echo "[+] Escaneando puertos abiertos en: $TARGETS"

sudo nmap -sS -Pn --min-rate 5000 -p- --open -oN "$BASE_DIR/init/tcp_scan.txt" $TARGETS

# Extraer y ordenar puertos
grep '^[0-9]' "$BASE_DIR/init/tcp_scan.txt" | cut -d '/' -f1 | sort -u | xargs | tr ' ' ',' > "$BASE_DIR/init/ports_$IFACE.txt"

# Escaneo detallado con los puertos encontrados
echo "[+] Escaneo completo en progreso..."
sudo nmap -sC -sV --open -Pn -oN "$BASE_DIR/init/full_scan_$IFACE.txt" -p "$(cat $BASE_DIR/init/ports_$IFACE.txt)" $TARGETS

echo "[+] Escaneo terminado. Resultados guardados en $BASE_DIR/"

# Procesar la salida para limpiar y colorear
OUTPUT_FILE="$SCAN_DIR/init/clean_scan_${IFACE}.txt"
awk '
    /^Nmap scan report/{print "\033[1;32mIP:\033[0m", $NF}
    /^[0-9]/ {printf "\033[1;34m%-10s\033[0m %-20s %-20s\n", $1, $3, $4 " " $5 " " $6 " " $7 " " $8 " " $9 " " $10}
' "$HOME/pentest/init/full_scan_${IFACE}.txt" > "$HOME/pentest/init/clean_scan_${IFACE}.txt"

echo "[*] Resultado formateado guardado en $HOME/pentest/init/full_scan_${IFACE}.txt"
echo "[*] Visualiza con: less -R $HOME/pentest/init/full_scan_${IFACE}.txt"

less -R "$HOME/pentest/init/full_scan_${IFACE}.txt"
