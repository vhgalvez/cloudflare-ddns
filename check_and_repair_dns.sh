#!/usr/bin/env bash
# check_and_repair_dns.sh — Verifica y repara registros DNS críticos
# © 2025 @vhgalvez · MIT
# Uso: sudo ./check_and_repair_dns.sh

set -euo pipefail
IFS=$'\n\t'

ENV_FILE="/etc/cloudflare-ddns/.env"
LOG_FILE="/var/log/cloudflare-ddns.log"

log() { printf '[%(%F %T)T] [CHK] %b\n' -1 "$*" | tee -a "$LOG_FILE"; }

[[ -f "$ENV_FILE" ]] || { echo "❌ Falta $ENV_FILE"; exit 1; }
# shellcheck disable=SC1090
source "$ENV_FILE"

: "${TTL:=300}"
: "${PROXIED:=false}"
: "${CNAME_TARGET:=$ZONE_NAME}"

[[ -n ${CF_API_TOKEN:-} ]] || { log "CF_API_TOKEN vacío"; exit 1; }
[[ -n ${ZONE_NAME:-}    ]] || { log "ZONE_NAME vacío";    exit 1; }
[[ -n ${RECORD_NAMES:-} ]] || { log "RECORD_NAMES vacío"; exit 1; }

ZONE_ID=$(curl -s -H "Authorization: Bearer $CF_API_TOKEN" \
  "https://api.cloudflare.com/client/v4/zones?name=$ZONE_NAME&status=active&match=all" |
  jq -r '.result[0].id')

[[ -n $ZONE_ID && $ZONE_ID != null ]] || { log "Zona no encontrada"; exit 1; }

IPV4=$(curl -s https://1.1.1.1/cdn-cgi/trace | grep '^ip=' | cut -d= -f2 || true)
[[ $IPV4 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || { log "IP pública inválida"; exit 1; }

repair_record() {
  local host=$1
  local type=$2
  local expected=$3
  local proxied=$4
  local record_json rec_id old_value

  record_json=$(curl -s -H "Authorization: Bearer $CF_API_TOKEN" \
    "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=$type&name=$host&match=all&per_page=1")

  if [[ $(echo "$record_json" | jq '.result | length') -eq 0 ]]; then
    log "⚠️  Falta $host ($type) → creando"
    curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
      -H "Authorization: Bearer $CF_API_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"$type\",\"name\":\"$host\",\"content\":\"$expected\",\"ttl\":$TTL,\"proxied\":$proxied}" >/dev/null \
      && log "✅  $host ($type) creado"
    return
  fi

  rec_id=$(echo "$record_json" | jq -r '.result[0].id')
  old_value=$(echo "$record_json" | jq -r '.result[0].content')

  if [[ "$old_value" != "$expected" ]]; then
    log "🔄  Corrigiendo $host ($type): $old_value → $expected"
    curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$rec_id" \
      -H "Authorization: Bearer $CF_API_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"$type\",\"name\":\"$host\",\"content\":\"$expected\",\"ttl\":$TTL,\"proxied\":$proxied}" >/dev/null \
      && log "✅  $host ($type) actualizado"
  else
    log "✅  $host ($type) correcto ($expected)"
  fi
}

# Reparar todos los registros A deseados
IFS=',' read -ra HOSTS <<< "$RECORD_NAMES"
for H in "${HOSTS[@]}"; do
  repair_record "$H" "A" "$IPV4" "$PROXIED"
done

# Reparar CNAME www
repair_record "www" "CNAME" "$CNAME_TARGET" "true"

log "🏁 Verificación completa"
exit 0
