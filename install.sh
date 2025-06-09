#!/bin/bash

set -e

echo "📦 Instalando Cloudflare DDNS..."

# === Variables ===
SCRIPT_SRC="./update_cloudflare_ip.sh"
SCRIPT_DST="/usr/local/bin/update_cloudflare_ip.sh"
ENV_DIR="/etc/cloudflare-ddns"
ENV_FILE="$ENV_DIR/.env"
LOG_FILE="/var/log/cloudflare_ddns.log"
SERVICE_FILE="/etc/systemd/system/cloudflare-ddns.service"
TIMER_FILE="/etc/systemd/system/cloudflare-ddns.timer"

# === Verificar dependencias ===
echo "🔍 Verificando dependencias..."
for cmd in curl jq systemctl; do
  if ! command -v $cmd &>/dev/null; then
    echo "❌ Error: '$cmd' no está instalado. Instálalo primero."
    exit 1
  fi
done

# === Instalar script principal ===
echo "📁 Copiando script a $SCRIPT_DST..."
sudo cp "$SCRIPT_SRC" "$SCRIPT_DST"
sudo chmod 755 "$SCRIPT_DST"

# === Crear archivo .env si no existe ===
echo "🔐 Configurando variables en $ENV_FILE..."
sudo mkdir -p "$ENV_DIR"
if [ ! -f "$ENV_FILE" ]; then
  sudo bash -c "cat > $ENV_FILE" <<EOF
CF_API_TOKEN=tu_token_api_aquí
ZONE_NAME=dominio.com
RECORD_NAME=subdominio.dominio.com
EOF
  echo "⚠️  Edita el archivo $ENV_FILE con tus datos reales."
fi
sudo chmod 600 "$ENV_FILE"
sudo chown root:root "$ENV_FILE"

# === Crear archivo de log ===
echo "📝 Preparando archivo de log en $LOG_FILE..."
sudo touch "$LOG_FILE"
sudo chmod 644 "$LOG_FILE"
sudo chown root:root "$LOG_FILE"

# === Crear servicio systemd ===
echo "⚙️ Creando archivo de servicio en $SERVICE_FILE..."
sudo bash -c "cat > $SERVICE_FILE" <<EOF
[Unit]
Description=Cloudflare DDNS actualizador de IP pública
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$SCRIPT_DST
StandardOutput=append:$LOG_FILE
StandardError=append:$LOG_FILE
EOF

# === Crear temporizador ===
echo "⏱️  Creando archivo de temporizador en $TIMER_FILE..."
sudo bash -c "cat > $TIMER_FILE" <<EOF
[Unit]
Description=Ejecutar Cloudflare DDNS cada 5 minutos

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
Unit=cloudflare-ddns.service

[Install]
WantedBy=timers.target
EOF

# === Activar servicio ===
echo "🚀 Activando servicio y temporizador..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable --now cloudflare-ddns.timer

echo "✅ Instalación completada."
echo "📄 Edita $ENV_FILE con tu API token y dominio."
echo "📡 Verifica estad
