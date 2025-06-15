#!/bin/bash

# install.sh
# Instala y configura un servicio DDNS con Cloudflare en Linux (Fedora, RHEL, Rocky)

set -euo pipefail
IFS=$'\n\t'

# === Rutas ===
readonly SCRIPT_SRC="update_cloudflare_ip.sh"
readonly SCRIPT_DEST="/usr/local/bin/update_cloudflare_ip.sh"
readonly ENV_DIR="/etc/cloudflare-ddns"
readonly ENV_FILE="$ENV_DIR/.env"
readonly LOG_FILE="/var/log/cloudflare-ddns.log"
readonly SERVICE_FILE="/etc/systemd/system/cloudflare-ddns.service"
readonly TIMER_FILE="/etc/systemd/system/cloudflare-ddns.timer"

# === Función de log ===
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# === Instalación de dependencias ===
install_dependencies() {
    log "📦 Instalando dependencias necesarias..."
    sudo dnf install -y curl jq > /dev/null
}

# === Validar archivos fuente ===
validate_sources() {
    log "🔍 Verificando archivos necesarios..."
    [[ ! -f "$SCRIPT_SRC" ]] && log "❌ Error: $SCRIPT_SRC no encontrado." && exit 1
    [[ ! -f "cloudflare-ddns.service" ]] && log "❌ Error: cloudflare-ddns.service no encontrado." && exit 1
    [[ ! -f "cloudflare-ddns.timer" ]] && log "❌ Error: cloudflare-ddns.timer no encontrado." && exit 1
}

# === Copiar script ===
install_script() {
    log "🚀 Copiando script a $SCRIPT_DEST..."
    sudo cp "$SCRIPT_SRC" "$SCRIPT_DEST"
    sudo chmod 750 "$SCRIPT_DEST"
    sudo chown root:root "$SCRIPT_DEST"
}

# === Preparar entorno de configuración ===
prepare_env() {
    log "📁 Asegurando directorio de configuración en $ENV_DIR..."
    sudo mkdir -p "$ENV_DIR"
    if [[ ! -f "$ENV_FILE" ]]; then
        log "📝 Creando archivo .env vacío en $ENV_FILE (recuerda editarlo)..."
        sudo touch "$ENV_FILE"
        sudo chmod 600 "$ENV_FILE"
        sudo chown root:root "$ENV_FILE"
    fi
}

# === Crear archivo de log ===
prepare_log_file() {
    log "📄 Asegurando archivo de log en $LOG_FILE..."
    sudo touch "$LOG_FILE"
    sudo chmod 644 "$LOG_FILE"
    sudo chown root:root "$LOG_FILE"
}

# === Instalar archivos systemd ===
install_systemd_units() {
    log "⚙️ Instalando unidades systemd..."
    sudo cp cloudflare-ddns.service "$SERVICE_FILE"
    sudo cp cloudflare-ddns.timer "$TIMER_FILE"
}

# === Activar y recargar systemd ===
enable_service() {
    log "🔄 Recargando systemd y activando timer..."
    sudo systemctl daemon-reexec
    sudo systemctl daemon-reload
    sudo systemctl enable --now cloudflare-ddns.timer
}

# === Función principal ===
main() {
    install_dependencies
    validate_sources
    install_script
    prepare_env
    prepare_log_file
    install_systemd_units
    enable_service

    log "✅ Instalación completa."
    echo
    echo "🧪 Verifica el estado con:"
    echo "   sudo systemctl status cloudflare-ddns.timer"
    echo "   sudo journalctl -t cloudflare-ddns -n 50 --no-pager"
    echo "   sudo tail -f $LOG_FILE"
}

main