#!/usr/bin/env bash
# Actualiza registros A/AAAA en Cloudflare ― NO borra nada
set -euo pipefail
IFS=$'\n\t'

ENV_FILE="/etc/cloudflare-ddns/.env"
LOG_FILE="/var/log/cloudflare-ddns.log"

log() { printf '[%(%F %T)T] %b\n' -1 "$*" | tee -a "$LOG_FILE"; }

[[ -f "$ENV_FILE" ]] || { log "❌ Falta $ENV_FILE"; exit 1; }
source "$ENV_FILE"

[[ -n ${CF_API_TOKEN:-} ]]   || { log "❌ CF_API_TOKEN vacío";   exit 1; }
[[ -n ${ZONE_NAME:-} ]]      || { log "❌ ZONE_NAME vacío";      exit 1; }
[[ -n ${RECORD_NAMES:-} ]]   || { log "❌ RECORD_NAMES vacío";   exit 1; }

# --- Obtener IP pública actual ---------------------------------------------
CURRENT_IP="$(curl -s https://1.1.1.1/cdn-cgi/trace | grep ip= | cut -d= -f2)"
[[ $CURRENT_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] \
  || { log "❌ IP pública inválida: $CURRENT_IP"; exit 1; }

# --- ID de zona ------------------------------------------------------------
ZONE_ID="$(curl -s -H "Authorization: Bearer $CF_API_TOKEN" \
  "https://api.cloudflare.com/client/v4/zones?name=$ZONE_NAME" | jq -r '.result[0].id')"
[[ $ZONE_ID != null ]] || { log "❌ Zona no encontrada"; exit 1; }

# --- Recorrer registros -----------------------------------------------------
IFS=',' read -ra HOSTS <<< "$RECORD_NAMES"
for HOST in "${HOSTS[@]}"; do
  RECORD_JSON="$(curl -s -H "Authorization: Bearer $CF_API_TOKEN" \
     "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?type=A&name=$HOST")"

  REC_ID="$(echo "$RECORD_JSON" | jq -r '.result[0].id')"
  OLD_IP="$(echo "$RECORD_JSON"  | jq -r '.result[0].content')"

  if [[ "$CURRENT_IP" == "$OLD_IP" ]]; then
      log "➡️  $HOST ya apunta a $CURRENT_IP (sin cambios)"
      continue
  fi

  # Actualizar
  curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$REC_ID" \
       -H "Authorization: Bearer $CF_API_TOKEN" \
       -H "Content-Type: application/json" \
       --data "{\"type\":\"A\",\"name\":\"$HOST\",\"content\":\"$CURRENT_IP\",\"ttl\":300,\"proxied\":false}" \
    | jq -e '.success' >/dev/null \
    && log "✅  $HOST actualizado: $OLD_IP → $CURRENT_IP" \
    || log "❌  Error al actualizar $HOST"
done