#!/bin/bash
# Script: MODO FIREWALL TRADICIONAL (Solo L3/L4)
# Objetivo: Demostrar vulnerabilidad ante ataques de Capa 7

echo "🧱 ACTIVANDO MODO FIREWALL TRADICIONAL..."
echo "---------------------------------------------"

# 1. APAGAR SURICATA (Desactivar IPS)
echo "[-] Deteniendo servicio Suricata (Ojos cerrados)..."
sudo systemctl stop suricata 2>/dev/null
sudo killall -9 suricata 2>/dev/null
sudo rm -f /var/run/suricata.pid 2>/dev/null

# 2. LIMPIEZA DE REGLAS (Quitar desvío NFQUEUE)
echo "[-] Limpiando reglas anteriores..."
sudo iptables -F
sudo iptables -X
sudo iptables -t nat -F

# 3. ACTIVAR FORWARDING (Funcionar como Router)
sudo sysctl -w net.ipv4.ip_forward=1 > /dev/null

# 4. REGLAS DE FIREWALL (Simulación Router Casero)
# Política: Bloquear todo por defecto
sudo iptables -P FORWARD DROP

echo "[+] Configurando reglas de acceso (Allow Rules)..."

# A) Permitir conexiones establecidas (Respuestas)
sudo iptables -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT

# B) Permitir servicios legítimos (Puertos Abiertos)
# El firewall ve el puerto correcto y deja pasar, sin inspeccionar el payload.
sudo iptables -A FORWARD -p tcp --dport 1883 -j ACCEPT # MQTT (IoT)
sudo iptables -A FORWARD -p tcp --dport 5000 -j ACCEPT # API (SmartPlug)
sudo iptables -A FORWARD -p tcp --dport 8080 -j ACCEPT # Web (Admin)
sudo iptables -A FORWARD -p tcp --dport 22 -j ACCEPT   # SSH
sudo iptables -A FORWARD -p icmp -j ACCEPT             # Ping

echo "---------------------------------------------"
echo "✅ MODO FIREWALL ACTIVO."
echo "⚠️  Suricata está DORMIDO. El sistema es vulnerable a ataques de contenido."
