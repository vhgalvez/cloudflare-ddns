#!/bin/bash
# install.sh
# Instala y configura un servicio de actualización de IP pública en Cloudflare

set -e

echo "📦 Instalando dependencias necesarias..."
sudo dnf install -y curl jq > /dev/null

# === Variables ===
SCRIPT_SRC="update_cloudflare_ip.sh"
SCRIPT_DEST="/usr/local/bin/update_cloudflare_ip.sh"
ENV_DIR="/etc/cloudflare-ddns"
ENV_FILE="$ENV_DIR/.env"
LOG_FILE="/var/log/cloudflare_ddns.log"
SERVICE_FILE="/etc/systemd/system/cloudflare-ddns.service"
TIMER_FILE="/etc/systemd/system/cloudflare-ddns.timer"

# === Validación previa ===
echo "🔍 Verificando archivos necesarios..."
[[ ! -f "$SCRIPT_SRC" ]] && echo "❌ Error: $SCRIPT_SRC no encontrado." && exit 1
[[ ! -f "cloudflare-ddns.service" ]] && echo "❌ Error: cloudflare-ddns.service no encontrado." && exit 1
[[ ! -f "cloudflare-ddns.timer" ]] && echo "❌ Error: cloudflare-ddns.timer no encontrado." && exit 1

# === Copiar script principal ===
echo "🚀 Copiando script a $SCRIPT_DEST..."
sudo cp "$SCRIPT_SRC" "$SCRIPT_DEST"
sudo chmod 755 "$SCRIPT_DEST"

# === Crear carpeta de configuración ===
echo "📁 Asegurando directorio de configuración $ENV_DIR..."
sudo mkdir -p "$ENV_DIR"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "📝 Creando archivo de configuración vacío en $ENV_FILE (recuerda completarlo)..."
  sudo touch "$ENV_FILE"
  sudo chmod 600 "$ENV_FILE"
  sudo chown root:root "$ENV_FILE"
fi

# === Crear archivo de log ===
echo "📄 Asegurando archivo de log $LOG_FILE..."
sudo touch "$LOG_FILE"
sudo chmod 644 "$LOG_FILE"
sudo chown root:root "$LOG_FILE"

# === Copiar archivos systemd ===
echo "⚙️ Instalando archivos de servicio..."
sudo cp cloudflare-ddns.service "$SERVICE_FILE"
sudo cp cloudflare-ddns.timer "$TIMER_FILE"

# === Activar systemd ===
echo "🔄 Recargando systemd y activando el timer..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable --now cloudflare-ddns.timer

echo "✅ Instalación completa. Puedes revisar el estado con:"
echo "   sudo systemctl status cloudflare-ddns.timer"
echo "   sudo tail -f /var/log/cloudflare_ddns.log"