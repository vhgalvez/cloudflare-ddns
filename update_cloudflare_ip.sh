#!/bin/bash

# === CONFIGURACIÓN ===
CF_API_TOKEN="tu_token_api_aquí"
ZONE_NAME="socialdevs.site"
RECORD_NAME="home.socialdevs.site"

# === OBTENER IP ACTUAL ===
CURRENT_IP=$(curl -s https://ifconfig.me)

# === OBTENER ZONE ID ===
ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$ZONE_NAME" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" | jq -r '.result[0].id')

# === OBTENER RECORD ID E IP ACTUAL EN DNS ===
RECORD_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$RECORD_NAME" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json")

RECORD_ID=$(echo "$RECORD_RESPONSE" | jq -r '.result[0].id')
DNS_IP=$(echo "$RECORD_RESPONSE" | jq -r '.result[0].content')

# === ACTUALIZAR SOLO SI CAMBIÓ LA IP ===
if [ "$CURRENT_IP" != "$DNS_IP" ]; then
  echo "Actualizando IP en Cloudflare: $DNS_IP → $CURRENT_IP"
  curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json" \
    --data '{"type":"A","name":"'"$RECORD_NAME"'","content":"'"$CURRENT_IP"'","ttl":1,"proxied":true}' > /dev/null
else
  echo "IP sin cambios: $CURRENT_IP"
fi