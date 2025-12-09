#!/bin/bash
# Script IPS - ESTRATEGIA DE COLA DINÁMICA
# Uso: ./medir_ips.sh <ID> <SID> <ATKS> <WAIT> <COLA>

EXP_ID=$1
SID=$2
TOTAL_ATTACKS=$3
WAIT_TIME=${4:-20}
QUEUE_NUM=${5:-100} # Por defecto usa la 100 si no pones nada

export EXP_NAME="exp${EXP_ID}_IPS"
export BASE_DIR="/vagrant/results/${EXP_NAME}"

# Limpieza al salir
cleanup() {
    sudo kill $TCP_PID 2>/dev/null
    kill $VM_PID 2>/dev/null
    sudo killall -9 suricata 2>/dev/null
    sudo iptables -F
    sudo iptables -X
}
trap cleanup EXIT

echo "🛡️  PRUEBA IPS - EXP${EXP_ID} en COLA ${QUEUE_NUM}"
echo "------------------------------------------------"

# Preparación
sudo mkdir -p "$BASE_DIR"
sudo chown -R vagrant:vagrant "$BASE_DIR"

# 1. KIT DE EMERGENCIA (Siempre lo aplicamos por si acaso)
sudo ethtool -K eth1 tx off rx off sg off gso off gro off
sudo ethtool -K eth2 tx off rx off sg off gso off gro off
sudo sysctl -w net.ipv4.ip_forward=1 2>/dev/null

# 2. Matar Suricata viejo
sudo systemctl stop suricata 2>/dev/null
sudo killall -9 suricata 2>/dev/null
sudo rm -f /var/log/suricata/fast.log /var/log/suricata/eve.json /var/run/suricata.pid 2>/dev/null

# 3. Configurar IPTABLES a la COLA ESPECÍFICA
sudo iptables -F
sudo iptables -X
sudo iptables -N SURICATA_IPS
sudo iptables -A FORWARD -j SURICATA_IPS
# Aquí usamos la variable $QUEUE_NUM
sudo iptables -A SURICATA_IPS -j NFQUEUE --queue-num $QUEUE_NUM

echo "[Wait] Iniciando Suricata IPS en Cola $QUEUE_NUM..."
sudo suricata -c /etc/suricata/suricata.yaml -q $QUEUE_NUM -l /var/log/suricata -D
sleep 15 

# Grabación
echo "🔴  GRABANDO... Tienes $WAIT_TIME segundos."
date --iso-8601=seconds | tee "${BASE_DIR}/run_start.txt"
sudo tcpdump -i eth1 -n -w "${BASE_DIR}/capture.pcap" >/dev/null 2>&1 &
TCP_PID=$!
vmstat 1 > "${BASE_DIR}/vmstat.log" &
VM_PID=$!

# Espera
for i in $(seq $WAIT_TIME -1 1); do
    echo -ne "Tiempo restante: $i s  \r"
    sleep 1
done
echo -e "\n🛑  TIEMPO AGOTADO."

# Fin
date --iso-8601=seconds | tee "${BASE_DIR}/run_end.txt"
sudo cp /var/log/suricata/fast.log "${BASE_DIR}/fast.log"
sudo cp /var/log/suricata/eve.json "${BASE_DIR}/eve.json"
sudo chown -R vagrant:vagrant "$BASE_DIR"

# Calcular
./calcular_ya.sh $EXP_ID $SID $TOTAL_ATTACKS IPS
