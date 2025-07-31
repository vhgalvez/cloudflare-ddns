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
    log "📦 Verificando dependencias necesarias..."
    for cmd in curl jq systemctl; do
        if ! command -v "$cmd" &>/dev/null; then
            log "📥 Instalando $cmd..."
            sudo dnf install -y "$cmd" > /dev/null
        fi
    done
}

# === Validar archivos fuente ===
validate_sources() {
    log "🔍 Verificando archivos necesarios..."
    [[ ! -f "$SCRIPT_SRC" ]] && log "❌ Error: $SCRIPT_SRC no encontrado." && exit 1
    [[ ! -f "cloudflare-ddns.service" ]] && log "❌ Error: cloudflare-ddns.service no encontrado." && exit 1
    [[ ! -f "cloudflare-ddns.timer" ]] && log "❌ Error: cloudflare-ddns.timer no encontrado." && exit 1
}

# === Copiar script principal ===
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
        log "📝 Creando archivo .env base en $ENV_FILE (recuerda editarlo)..."
        sudo tee "$ENV_FILE" > /dev/null <<EOF
CF_API_TOKEN=
ZONE_NAME=socialdevs.site
RECORD_NAMES=socialdevs.site,public.socialdevs.site
EOF
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
    sudo chmod 644 "$SERVICE_FILE"
    sudo chown root:root "$SERVICE_FILE"

    sudo cp cloudflare-ddns.timer "$TIMER_FILE"
    sudo chmod 644 "$TIMER_FILE"
    sudo chown root:root "$TIMER_FILE"
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

    log "✅ Instalación completada con éxito."
    echo
    echo "🧩 Edita el archivo .env con tus credenciales:"
    echo "   sudo nano $ENV_FILE"
    echo
    echo "🧪 Verifica el estado del timer con:"
    echo "   sudo systemctl status cloudflare-ddns.timer"
    echo
    echo "📊 Consulta logs del servicio con:"
    echo "   sudo journalctl -u cloudflare-ddns.service -n 50 --no-pager"
    echo "   sudo tail -f $LOG_FILE"
}

main