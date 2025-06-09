#!/bin/bash

# === CARGAR VARIABLES DESDE .env ===
ENV_FILE="/etc/cloudflare-ddns/.env"
NOW=$(date "+%Y-%m-%d %H:%M:%S")

if [ -f "$ENV_FILE" ]; then
  export $(grep -v '^#' "$ENV_FILE" | xargs)
else
  echo "[$NOW] ❌ Error: No se encontró el archivo de configuración $ENV_FILE"
  exit 1
fi

# === VALIDACIÓN DE VARIABLES ===
if [[ -z "$CF_API_TOKEN" || -z "$ZONE_NAME" || -z "$RECORD_NAME" ]]; then
  echo "[$NOW] ❌ Error: Faltan variables requeridas en $ENV_FILE"
  exit 1
fi

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