#!/bin/bash
# uninstall.sh — Desinstala Cloudflare DDNS de forma segura

set -euo pipefail

echo "🧹 Desinstalando Cloudflare DDNS..."

# === Variables protegidas ===
SCRIPT="/usr/local/bin/update_cloudflare_ip.sh"
ENV_FILE="/etc/cloudflare-ddns/.env"
ENV_DIR="/etc/cloudflare-ddns"
LOG_FILE="/var/log/cloudflare_ddns.log"
SERVICE_FILE="/etc/systemd/system/cloudflare-ddns.service"
TIMER_FILE="/etc/systemd/system/cloudflare-ddns.timer"

# Validación fuerte de rutas para evitar errores
function validate_path {
  local path="$1"
  local expected_prefix="$2"
  if [[ "$path" != "$expected_prefix"* ]]; then
    echo "❌ Error: $path no está dentro de $expected_prefix — abortando por seguridad."
    exit 1
  fi
}

# Validar rutas antes de eliminar
validate_path "$SCRIPT" "/usr/local/bin/"
validate_path "$ENV_FILE" "/etc/cloudflare-ddns/"
validate_path "$LOG_FILE" "/var/log/"
validate_path "$SERVICE_FILE" "/etc/systemd/system/"
validate_path "$TIMER_FILE" "/etc/systemd/system/"

# Detener systemd
echo "⛔ Deteniendo servicios systemd..."
sudo systemctl disable --now cloudflare-ddns.timer >/dev/null 2>&1 || true
sudo systemctl stop cloudflare-ddns.service >/dev/null 2>&1 || true

# Eliminar archivos solo si existen
echo "🗑️ Eliminando archivos específicos..."
[ -f "$SCRIPT" ] && sudo rm -v "$SCRIPT"
[ -f "$ENV_FILE" ] && sudo rm -v "$ENV_FILE"
[ -d "$ENV_DIR" ] && sudo rmdir "$ENV_DIR" 2>/dev/null || true
[ -f "$LOG_FILE" ] && sudo rm -v "$LOG_FILE"
[ -f "$SERVICE_FILE" ] && sudo rm -v "$SERVICE_FILE"
[ -f "$TIMER_FILE" ] && sudo rm -v "$TIMER_FILE"

# Recargar systemd
echo "🔄 Recargando systemd..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload

echo "✅ Cloudflare DDNS ha sido desinstalado de forma segura."