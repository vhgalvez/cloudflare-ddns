#!/bin/bash

# Cloudflare DDNS - Actualización automática de IP pública
# Autor: @vhgalvez (mejorado con programación funcional)
# Fecha: 2025-06-15

set -euo pipefail
IFS=$'\n\t'

readonly ENV_FILE="/etc/cloudflare-ddns/.env"
readonly LOG_FILE="/var/log/cloudflare-ddns.log"
readonly LOG_TAG="cloudflare-ddns"

# === Función de log: escribe en journal + archivo ===
log() {
    local now
    now=$(date "+%Y-%m-%d %H:%M:%S")
    local msg="[$now] [DDNS] $1"
    echo "$msg" | tee -a "$LOG_FILE"
    logger -t "$LOG_TAG" "$msg"
}

# === Función para manejar errores ===
handle_error() {
    local msg="$1"
    log "❌ ERROR: $msg"
    dmesg | tail -n 20 >> "$LOG_FILE"
    exit 1
}

# === Cargar variables desde el archivo .env ===
load_env() {
    if [[ ! -f "$ENV_FILE" ]]; then
        handle_error "Archivo de configuración no encontrado: $ENV_FILE"
    fi

    set -a
    source "$ENV_FILE"
    set +a

    [[ -z "${CF_API_TOKEN:-}" ]] && log "⚠️ Variable CF_API_TOKEN vacía o no definida"
    [[ -z "${ZONE_NAME:-}" ]]     && log "⚠️ Variable ZONE_NAME vacía o no definida"
    [[ -z "${RECORD_NAME:-}" ]]   && log "⚠️ Variable RECORD_NAME vacía o no definida"

    if [[ -z "${CF_API_TOKEN:-}" || -z "${ZONE_NAME:-}" || -z "${RECORD_NAME:-}" ]]; then
        handle_error "Variables faltantes: CF_API_TOKEN, ZONE_NAME o RECORD_NAME"
    fi
}

# === Obtener la IP pública actual del servidor ===
get_current_ip() {
    local ip
    ip=$(curl -s https://ifconfig.me || true)

    if [[ -z "$ip" ]]; then
        handle_error "No se pudo obtener la IP pública (falló ifconfig.me)"
    fi

    log "🌐 IP pública detectada: $ip"
    echo "$ip"
}

# === Obtener Zone ID de Cloudflare ===
get_zone_id() {
    local id
    id=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$ZONE_NAME" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json" | jq -r '.result[0].id')

    if [[ -z "$id" || "$id" == "null" ]]; then
        handle_error "No se pudo obtener el Zone ID para $ZONE_NAME"
    fi

    log "🔎 Zone ID obtenido: $id"
    echo "$id"
}

# === Obtener Record ID e IP DNS actual ===
get_record_info() {
    local zone_id="$1"
    local response record_id dns_ip

    response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?name=$RECORD_NAME" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json")

    record_id=$(echo "$response" | jq -r '.result[0].id')
    dns_ip=$(echo "$response" | jq -r '.result[0].content')

    if [[ -z "$record_id" || "$record_id" == "null" ]]; then
        handle_error "Registro DNS $RECORD_NAME no encontrado en zona $ZONE_NAME"
    fi

    log "📡 IP actual en DNS: $dns_ip"
    echo "$record_id|$dns_ip"
}

# === Actualizar el registro DNS si es necesario ===
update_dns_record() {
    local record_id="$1"
    local new_ip="$2"

    log "🔁 Actualizando registro A a nueva IP: $new_ip..."

    curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$record_id" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data '{"type":"A","name":"'"$RECORD_NAME"'","content":"'"$new_ip"'","ttl":1,"proxied":true}' > /dev/null

    log "✅ IP actualizada correctamente en Cloudflare."
}

# === Función principal ===
main() {
    log "🚀 Iniciando Cloudflare DDNS..."

    load_env

    local current_ip zone_id record_info record_id dns_ip
    current_ip=$(get_current_ip)
    zone_id=$(get_zone_id)
    record_info=$(get_record_info "$zone_id")
    record_id=$(echo "$record_info" | cut -d'|' -f1)
    dns_ip=$(echo "$record_info" | cut -d'|' -f2)

    if [[ "$current_ip" != "$dns_ip" ]]; then
        update_dns_record "$record_id" "$current_ip"
    else
        log "⚠️  IP sin cambios: $current_ip"
    fi

    log "✅ Proceso terminado correctamente."
}

main
exit 0