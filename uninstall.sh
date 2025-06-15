#!/bin/bash

# uninstall.sh — Desinstala Cloudflare DDNS de forma segura
# Autor: @vhgalvez
# Estilo: programación funcional con validación fuerte

set -euo pipefail
IFS=$'\n\t'

# === Rutas protegidas ===
readonly SCRIPT="/usr/local/bin/update_cloudflare_ip.sh"
readonly ENV_FILE="/etc/cloudflare-ddns/.env"
readonly ENV_DIR="/etc/cloudflare-ddns"
readonly LOG_FILE="/var/log/cloudflare-ddns.log"
readonly SERVICE_FILE="/etc/systemd/system/cloudflare-ddns.service"
readonly TIMER_FILE="/etc/systemd/system/cloudflare-ddns.timer"

# === Función de log con timestamp ===
log() {
    local now
    now=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$now] $1"
}

# === Validar ruta contra un prefijo seguro ===
validate_path() {
    local path="$1"
    local prefix="$2"
    if [[ "$path" != "$prefix"* ]]; then
        log "❌ ERROR: Ruta fuera de ubicación segura: $path (esperado: $prefix)"
        exit 1
    fi
}

# === Detener servicios systemd sin errores fatales ===
stop_services() {
    log "⛔ Deteniendo temporizador y servicio systemd..."
    systemctl disable --now cloudflare-ddns.timer >/dev/null 2>&1 || true
    systemctl stop cloudflare-ddns.service >/dev/null 2>&1 || true
}

# === Eliminar archivo si existe (con validación previa) ===
safe_remove_file() {
    local file="$1"
    local expected_prefix="$2"

    validate_path "$file" "$expected_prefix"
    if [[ -f "$file" ]]; then
        log "🗑️ Eliminando archivo: $file"
        rm -v "$file"
    fi
}

# === Eliminar directorio si está vacío ===
safe_remove_dir() {
    local dir="$1"
    local expected_prefix="$2"

    validate_path "$dir" "$expected_prefix"
    if [[ -d "$dir" ]]; then
        rmdir "$dir" 2>/dev/null && log "📁 Directorio eliminado: $dir" || log "ℹ️  Directorio $dir no está vacío, no se elimina."
    fi
}

# === Recargar systemd ===
reload_systemd() {
    log "🔄 Recargando systemd..."
    systemctl daemon-reexec
    systemctl daemon-reload
}

# === Función principal ===
main() {
    log "🧹 Iniciando desinstalación segura de Cloudflare DDNS..."

    stop_services

    safe_remove_file "$SCRIPT" "/usr/local/bin/"
    safe_remove_file "$ENV_FILE" "/etc/cloudflare-ddns/"
    safe_remove_file "$LOG_FILE" "/var/log/"
    safe_remove_file "$SERVICE_FILE" "/etc/systemd/system/"
    safe_remove_file "$TIMER_FILE" "/etc/systemd/system/"
    safe_remove_dir "$ENV_DIR" "/etc/cloudflare-ddns/"

    reload_systemd

    log "✅ Cloudflare DDNS ha sido desinstalado con seguridad y sin afectar el sistema."
}

main
exit 0