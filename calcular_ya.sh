#!/bin/bash
# Uso: ./calcular_ya.sh <ID> <SID> <ATTACKS> <TIPO_CARPETA>

EXP_ID=$1
SID=$2
TOTAL_ATTACKS=$3
TYPE=${4:-metrics} 

BASE_DIR="/vagrant/results/exp${EXP_ID}_${TYPE}"

echo "📊 Calculando métricas en: $BASE_DIR"

if [ ! -d "$BASE_DIR" ]; then
    echo "❌ Error: La carpeta $BASE_DIR no existe."
    exit 1
fi

python3 - <<END_PYTHON
import json
import os
from datetime import datetime

base_dir = "$BASE_DIR"
target_sid = int("$SID")
total_attacks = int("$TOTAL_ATTACKS")
eve_file = os.path.join(base_dir, "eve.json")
run_start_file = os.path.join(base_dir, "run_start.txt")

try:
    total_alerts = 0
    sid_alerts = 0
    blocked_count = 0
    first_ts = None
    start_ts = None

    # Leer Start Time
    if os.path.exists(run_start_file):
        with open(run_start_file) as f:
            start_ts = datetime.fromisoformat(f.read().strip())

    if os.path.exists(eve_file):
        with open(eve_file, 'r') as f:
            for line in f:
                try:
                    event = json.loads(line)
                    if event['event_type'] == 'alert':
                        total_alerts += 1
                        if event['alert']['signature_id'] == target_sid:
                            sid_alerts += 1
                            # Check de bloqueo (Métrica PDB)
                            action = event['alert'].get('action', 'allowed')
                            if action == 'blocked' or action == 'drop':
                                blocked_count += 1
                            
                            # TTF
                            if first_ts is None:
                                ts_str = event['timestamp'].replace('+0000', '+00:00')
                                first_ts = datetime.fromisoformat(ts_str)
                except: continue
    
    # --- CÁLCULOS ---
    if total_attacks > 0:
        # TPR (Tasa de acierto)
        tpr = (sid_alerts / total_attacks) * 100
        # FNR (Tasa de Falsos Negativos)
        # FN = Total Ataques - Alertas Detectadas
        fn_count = total_attacks - sid_alerts
        # FNR = FN / Total Ataques
        fnr = (fn_count / total_attacks) * 100
    else:
        tpr = 0
        fnr = 0

    # Imprimir
    print(f"🔸 Total Alertas SID {target_sid}: {sid_alerts}")
    print(f"🔸 Acciones de BLOQUEO (PDB): {blocked_count}")
    print(f"🔸 TPR (True Positive Rate):  {tpr:.2f}%")
    print(f"🔸 FNR (False Negative Rate): {fnr:.2f}%")
    
    if start_ts and first_ts and start_ts < first_ts: # Asegurar que el cálculo de TTF es positivo
        ttf = (first_ts - start_ts).total_seconds() * 1000
        print(f"🔸 TTF:                     {ttf:.2f} ms")

except Exception as e:
    print(f"Error en Python: {e}")

END_PYTHON
