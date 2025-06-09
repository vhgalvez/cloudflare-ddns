#!/bin/bash

# === CONFIGURACIÓN ===
CF_API_TOKEN="tu_token_api_aquí"
ZONE_NAME="socialdevs.site"
RECORD_NAME="home.socialdevs.site"

# === FECHA Y HORA ACTUAL ===
NOW=$(date "+%Y-%m-%d %H:%M:%S")

# === OBTENER IP PÚBLICA ACTUAL ===
CURRENT_IP=$(curl -s https://ifconfig.me)

if [[ -z "$CURRENT_IP" ]]; then
  echo "[$NOW] ❌ Error: No se pudo obtener la IP pública."
  exit 1
fi

# === OBTENER ZONE ID DE CLOUDFLARE ===
ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$ZONE_NAME" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" | jq -r '.result[0].id')

if [[ -z "$ZONE_ID" || "$ZONE_ID" == "null" ]]; then
  echo "[$NOW] ❌ Error: No se pudo obtener el Zone ID para $ZONE_NAME"
  exit 1
fi

# === OBTENER RECORD ID E IP ACTUAL EN DNS ===
RECORD_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$RECORD_NAME" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json")

RECORD_ID=$(echo "$RECORD_RESPONSE" | jq -r '.result[0].id')
DNS_IP=$(echo "$RECORD_RESPONSE" | jq -r '.result[0].content')

if [[ -z "$RECORD_ID" || "$RECORD_ID" == "null" ]]; then
  echo "[$NOW] ❌ Error: No se encontró un registro DNS para $RECORD_NAME"
  exit 1
fi

# === VERIFICAR Y ACTUALIZAR SI LA IP HA CAMBIADO ===
if [ "$CURRENT_IP" != "$DNS_IP" ]; then
  echo "[$NOW] ✅ IP cambiada: ${DNS_IP:-null} → $CURRENT_IP. Actualizando en Cloudflare..."
  curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json" \
    --data '{"type":"A","name":"'"$RECORD_NAME"'","content":"'"$CURRENT_IP"'","ttl":1,"proxied":true}' > /dev/null
  echo "[$NOW] ✅ Actualización completada."
else
  echo "[$NOW] ⚠️  IP sin cambios: $CURRENT_IP"
fi
