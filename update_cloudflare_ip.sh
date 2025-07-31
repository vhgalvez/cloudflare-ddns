#!/bin/bash

# Cloudflare DDNS - Actualización automática de IP pública (multi-registro)
# update_cloudflare_ip.sh


set -euo pipefail
IFS=$'\n\t'

readonly ENV_FILE="/etc/cloudflare-ddns/.env"
readonly LOG_FILE="/var/log/cloudflare-ddns.log"
readonly LOG_TAG="cloudflare-ddns"

# === Logging ===
log() {
    local now msg
    now=$(date "+%Y-%m-%d %H:%M:%S")
    msg="[$now] [DDNS] $1"
    echo "$msg" | tee -a "$LOG_FILE"
    logger -t "$LOG_TAG" "$msg"
}

# === Manejo de errores ===
handle_error() {
    log "❌ ERROR: $1"
    exit 1
}

# === Cargar .env ===
load_env() {
    if [[ ! -f "$ENV_FILE" ]]; then
        handle_error "Archivo de configuración no encontrado: $ENV_FILE"
    fi
    set -a
    source "$ENV_FILE"
    set +a

    if [[ -z "${CF_API_TOKEN:-}" || -z "${ZONE_NAME:-}" || -z "${RECORD_NAMES:-}" ]]; then
        handle_error "Variables faltantes: CF_API_TOKEN, ZONE_NAME o RECORD_NAMES"
    fi
}

# === Obtener IP pública actual ===
get_current_ip() {
    local ip
    ip=$(curl -s https://ifconfig.me || true)
    if [[ -z "$ip" ]]; then
        handle_error "No se pudo obtener la IP pública (falló ifconfig.me)"
    fi
    log "🌐 IP pública detectada: $ip"
    echo "$ip"
}

# === Obtener Zone ID ===
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

# === Obtener info del registro DNS (ID e IP actual) ===
get_record_info() {
    local zone_id="$1"
    local record_name="$2"

    local response record_id dns_ip
    response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?name=$record_name" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json")

    record_id=$(echo "$response" | jq -r '.result[0].id')
    dns_ip=$(echo "$response" | jq -r '.result[0].content')

    echo "$record_id|$dns_ip"
}

# === Crear registro si no existe ===
create_dns_record() {
    local zone_id="$1"
    local name="$2"
    local ip="$3"

    log "🆕 Registro DNS $name no existe. Creando con IP $ip..."

    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data '{"type":"A","name":"'"$name"'","content":"'"$ip"'","ttl":1,"proxied":true}' > /dev/null

    log "✅ Registro $name creado."
}

# === Actualizar IP si es necesario ===
update_dns_record() {
    local zone_id="$1"
    local record_id="$2"
    local name="$3"
    local new_ip="$4"

    log "🔁 Actualizando $name → $new_ip..."

    curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$record_id" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data '{"type":"A","name":"'"$name"'","content":"'"$new_ip"'","ttl":1,"proxied":true}' > /dev/null

    log "✅ IP de $name actualizada."
}

# === Proceso por cada record ===
process_record() {
    local name="$1"
    local ip="$2"
    local record_info record_id dns_ip

    record_info=$(get_record_info "$ZONE_ID" "$name")
    record_id=$(echo "$record_info" | cut -d'|' -f1)
    dns_ip=$(echo "$record_info" | cut -d'|' -f2)

    if [[ -z "$record_id" || "$record_id" == "null" ]]; then
        create_dns_record "$ZONE_ID" "$name" "$ip"
    elif [[ "$ip" != "$dns_ip" ]]; then
        update_dns_record "$ZONE_ID" "$record_id" "$name" "$ip"
    else
        log "⚠️  IP sin cambios en $name ($ip)"
    fi
}

# === MAIN ===
main() {
    log "🚀 Iniciando actualización DDNS Cloudflare"

    load_env
    readonly CURRENT_IP=$(get_current_ip)
    readonly ZONE_ID=$(get_zone_id)

    IFS=',' read -ra RECORD_ARRAY <<< "$RECORD_NAMES"
    for record in "${RECORD_ARRAY[@]}"; do
        process_record "$record" "$CURRENT_IP"
    done

    log "✅ Proceso completo para todos los registros."
}

main
exit 0