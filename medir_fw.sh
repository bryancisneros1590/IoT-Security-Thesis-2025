#!/bin/bash
# Script de Medición - MODO FIREWALL (L3/L4 Control) - VERSIÓN LIMPIA
# Uso: ./medir_fw.sh <ID_EXP> <SID> <TOTAL_ATAQUES> <SEGUNDOS_ESPERA>

EXP_ID=$1
SID=$2
TOTAL_ATTACKS=$3
WAIT_TIME=${4:-20}

export EXP_NAME="exp${EXP_ID}_FW"
export BASE_DIR="/vagrant/results/${EXP_NAME}"

# --- FUNCIÓN DE LIMPIEZA (TRAP) ---
# Evita el glitch visual matando procesos correctamente
cleanup() {
    sudo kill $TCP_PID 2>/dev/null
    kill $VM_PID 2>/dev/null
    # Restaurar configuración de terminal por si acaso
    stty sane 2>/dev/null
}
trap cleanup EXIT

echo "🧱 PRUEBA FIREWALL (CONTROL) - EXP${EXP_ID}"
echo "------------------------------------------------"
echo "📂 Guardando en: $BASE_DIR"

# 1. Preparación
sudo mkdir -p "$BASE_DIR"
sudo chown -R vagrant:vagrant "$BASE_DIR"

# 2. Asegurar que Suricata esté MUERTO
if pgrep "suricata" > /dev/null; then
    echo "⚠️  Suricata estaba corriendo. Matándolo..."
    sudo systemctl stop suricata 2>/dev/null
    sudo killall -9 suricata 2>/dev/null
    sudo rm -f /var/run/suricata.pid 2>/dev/null
fi

# 3. GRABACIÓN
echo "🔴  GRABANDO TRÁFICO Y RECURSOS... Tienes $WAIT_TIME segundos."
date --iso-8601=seconds | tee "${BASE_DIR}/run_start.txt"

# Capturamos tráfico (Evidencia de que el ataque pasó)
sudo tcpdump -i eth1 -n -w "${BASE_DIR}/capture.pcap" >/dev/null 2>&1 &
TCP_PID=$!

# Capturamos CPU/RAM (Debería ser bajo)
vmstat 1 > "${BASE_DIR}/vmstat.log" &
VM_PID=$!

# Cuenta regresiva
for i in $(seq $WAIT_TIME -1 1); do
    echo -ne "Tiempo restante: $i s  \r"
    sleep 1
done
echo -e "\n🛑  TIEMPO AGOTADO."

# 4. Finalización
date --iso-8601=seconds | tee "${BASE_DIR}/run_end.txt"
# La función cleanup se encarga de matar los procesos aquí

# Creamos archivo dummy para que el calculador no falle
touch "${BASE_DIR}/eve.json" 
sudo chown -R vagrant:vagrant "$BASE_DIR"

# 5. Calcular Métricas
echo "📊 Calculando..."
./calcular_ya.sh $EXP_ID $SID $TOTAL_ATTACKS FW
