#!/usr/bin/env bash
# bootstrap_dns.sh — Crea los registros DNS base en Cloudflare
# © 2025 @vhgalvez · MIT
# Uso: sudo ./bootstrap_dns.sh
#      (solo necesitas ejecutarlo una vez por proyecto/zona)

set -euo pipefail
IFS=$'\n\t'

ENV_FILE="/etc/cloudflare-ddns/.env"
LOG_FILE="/var/log/cloudflare-ddns.log"

log() { printf '[%(%F %T)T] [BOOT] %b\n' -1 "$*" | tee -a "$LOG_FILE"; }

[[ -f "$ENV_FILE" ]] || { echo "❌ Falta $ENV_FILE"; exit 1; }
# shellcheck disable=SC1090
source "$ENV_FILE"

: "${TTL:=300}"
: "${PROXIED:=false}"
: "${CNAME_TARGET:=$ZONE_NAME}"

[[ -n ${CF_API_TOKEN:-} ]] || { log "CF_API_TOKEN vacío"; exit 1; }
[[ -n ${ZONE_NAME:-}    ]] || { log "ZONE_NAME vacío";    exit 1; }
[[ -n ${RECORD_NAMES:-} ]] || { log "RECORD_NAMES vacío"; exit 1; }

# Obtener IDs y IP actual
ZONE_ID=$(curl -s -H "Authorization: Bearer $CF_API_TOKEN" \
  "https://api.cloudflare.com/client/v4/zones?name=$ZONE_NAME&status=active&match=all" |
  jq -r '.result[0].id')

[[ -n $ZONE_ID && $ZONE_ID != null ]] || { log "Zona no encontrada"; exit 1; }

IPV4=$(curl -s https://1.1.1.1/cdn-cgi/trace | grep '^ip=' | cut -d= -f2 || true)
[[ $IPV4 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || { log "IP pública inválida"; exit 1; }

create_A() {
  local host=$1
  local type=${2:-A}
  log "🔧 Creando $host ($type) → $IPV4"
  curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
    -H "Authorization: Bearer $CF_API_TOKEN" -H "Content-Type: application/json" \
    --data "{\"type\":\"$type\",\"name\":\"$host\",\"content\":\"$IPV4\",\"ttl\":$TTL,\"proxied\":$PROXIED}" \
    | jq -e '.success' >/dev/null \
    && log "✅  $host ($type) creado" \
    || log "❌  Fallo creando $host"
}

create_CNAME_www() {
  log "🔧 Creando CNAME www → $CNAME_TARGET"
  curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
    -H "Authorization: Bearer $CF_API_TOKEN" -H "Content-Type: application/json" \
    --data "{\"type\":\"CNAME\",\"name\":\"www\",\"content\":\"$CNAME_TARGET\",\"proxied\":true}" \
    | jq -e '.success' >/dev/null \
    && log "✅  CNAME www creado" || log "❌  Fallo creando CNAME www"
}

# Crear todos los registros A indicados en RECORD_NAMES (si no existen)
IFS=',' read -ra HOSTS <<< "$RECORD_NAMES"
for H in "${HOSTS[@]}"; do
  EXISTS=$(curl -s -H "Authorization: Bearer $CF_API_TOKEN" \
    "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=A&name=$H&match=all" |
    jq '.result | length')
  [[ $EXISTS -eq 0 ]] && create_A "$H" || log "➡️  $H ya existe (skip)"
done

# Crear CNAME www si no existe
EXISTS_WWW=$(curl -s -H "Authorization: Bearer $CF_API_TOKEN" \
  "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=CNAME&name=www.$ZONE_NAME&match=all" |
  jq '.result | length')
[[ $EXISTS_WWW -eq 0 ]] && create_CNAME_www || log "➡️  CNAME www ya existe (skip)"

log "🏁 Bootstrap completo"
exit 0
