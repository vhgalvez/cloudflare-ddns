#!/usr/bin/env bash
# update_cloudflare_ip.sh — Cloudflare DDNS + systemd
# © @vhgalvez · MIT

set -euo pipefail
IFS=$'\n\t'

###############################################################################
# ░░ Rutas y utilidades ░░
###############################################################################
ENV_FILE="/etc/cloudflare-ddns/.env"
LOG_FILE="/var/log/cloudflare-ddns.log"

log() { printf '[%(%F %T)T] %b\n' -1 "$*" | tee -a "$LOG_FILE"; }

[[ -f "$ENV_FILE" ]] || { log "❌ Falta $ENV_FILE"; exit 1; }
# shellcheck disable=SC1090
source "$ENV_FILE"

: "${TTL:=300}"          # segundos
: "${PROXIED:=false}"    # true | false

[[ -n ${CF_API_TOKEN:-} ]] || { log "❌ CF_API_TOKEN vacío";   exit 1; }
[[ -n ${ZONE_NAME:-}    ]] || { log "❌ ZONE_NAME vacío";      exit 1; }
[[ -n ${RECORD_NAMES:-} ]] || { log "❌ RECORD_NAMES vacío";   exit 1; }

###############################################################################
# ░░ 1. Detectar IP pública (IPv4 / IPv6) ░░
###############################################################################
IPV4=$(curl -s https://1.1.1.1/cdn-cgi/trace | grep '^ip=' | cut -d= -f2 || true)
IPV6=$(curl -6s https://ifconfig.co/ip 2>/dev/null || true)

[[ $IPV4 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || IPV4=""
[[ $IPV6 =~ : ]] || IPV6=""

[[ -n $IPV4 || -n $IPV6 ]] || { log "❌ No se pudo obtener IP pública"; exit 1; }

###############################################################################
# ░░ 2. Obtener ID de zona ░░
###############################################################################
ZONE_ID=$(curl -s -H "Authorization: Bearer $CF_API_TOKEN" \
  "https://api.cloudflare.com/client/v4/zones?name=$ZONE_NAME&status=active&match=name" |
  jq -r '.result[0].id')

[[ $ZONE_ID != null && -n $ZONE_ID ]] || { log "❌ Zona no encontrada → $ZONE_NAME"; exit 1; }

###############################################################################
# ░░ 3. Procesar cada registro ░░
###############################################################################
IFS=',' read -ra HOSTS <<< "$RECORD_NAMES"

for HOST in "${HOSTS[@]}"; do
  for TYPE in A AAAA; do
    [[ $TYPE == A    && -z $IPV4 ]] && continue
    [[ $TYPE == AAAA && -z $IPV6 ]] && continue

    NEW_IP=$([[ $TYPE == A ]] && echo "$IPV4" || echo "$IPV6")

    # 3.1 Consultar el registro exacto
    RECORD_JSON=$(curl -s -H "Authorization: Bearer $CF_API_TOKEN" \
      "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=$TYPE&name=$HOST&match=name&per_page=1")

    SUCCESS=$(echo "$RECORD_JSON" | jq -r '.success')

    if [[ $SUCCESS != "true" ]]; then
      msg=$(echo "$RECORD_JSON" | jq -c '.errors')
      log "❌  Error al consultar $HOST ($TYPE): $msg"
      continue
    fi

    REC_EXISTS=$(echo "$RECORD_JSON" | jq '.result | length')

    ############################################################
    # 3.2 Crear registro si no existe
    ############################################################
    if [[ $REC_EXISTS -eq 0 ]]; then
      RESP=$(curl -s -X POST \
        "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"$TYPE\",\"name\":\"$HOST\",\"content\":\"$NEW_IP\",\"ttl\":$TTL,\"proxied\":$PROXIED}")

      if echo "$RESP" | jq -e '.success' >/dev/null; then
        log "🆕  $HOST ($TYPE) creado → $NEW_IP"
      else
        msg=$(echo "$RESP" | jq -c '.errors')
        log "❌  Error al CREAR $HOST ($TYPE): $msg"
      fi
      continue
    fi

    ############################################################
    # 3.3 Actualizar si la IP cambió
    ############################################################
    REC_ID=$(echo "$RECORD_JSON" | jq -r '.result[0].id')
    OLD_IP=$(echo "$RECORD_JSON" | jq -r '.result[0].content')

    if [[ "$NEW_IP" == "$OLD_IP" ]]; then
      log "➡️  $HOST ($TYPE) sin cambios ($NEW_IP)"
      continue
    fi

    RESP=$(curl -s -X PUT \
      "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$REC_ID" \
      -H "Authorization: Bearer $CF_API_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"$TYPE\",\"name\":\"$HOST\",\"content\":\"$NEW_IP\",\"ttl\":$TTL,\"proxied\":$PROXIED}")

    if echo "$RESP" | jq -e '.success' >/dev/null; then
      log "✅  $HOST ($TYPE) actualizado: $OLD_IP → $NEW_IP"
    else
      msg=$(echo "$RESP" | jq -c '.errors')
      log "❌  Error al actualizar $HOST ($TYPE): $msg"
    fi
  done
done
###############################################################################
# ░░ Fin del script ░░
###############################################################################
exit 0