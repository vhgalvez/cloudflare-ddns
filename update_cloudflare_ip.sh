#!/bin/bash

# ⚙️ CONFIGURACIÓN
ZONE_ID="TU_ZONE_ID"
RECORD_ID="TU_RECORD_ID"
API_TOKEN="TU_API_TOKEN"
RECORD_NAME="socialdevs.site"
TTL=120
PROXY=false

# Obtener IP pública actual
IP=$(curl -s https://api.ipify.org)

# Obtener IP actual del DNS
CURRENT_IP=$(dig +short $RECORD_NAME)

# Si cambió la IP, actualizamos en Cloudflare
if [[ "$IP" != "$CURRENT_IP" ]]; then
  echo "➡️ IP ha cambiado: $CURRENT_IP → $IP. Actualizando..."

  RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
     -H "Authorization: Bearer $API_TOKEN" \
     -H "Content-Type: application/json" \
     --data "{\"type\":\"A\",\"name\":\"$RECORD_NAME\",\"content\":\"$IP\",\"ttl\":$TTL,\"proxied\":$PROXY}")

  if echo "$RESPONSE" | grep -q '"success":true'; then
    echo "✅ IP actualizada exitosamente en Cloudflare: $IP"
  else
    echo "❌ Error al actualizar IP:"
    echo "$RESPONSE"
  fi
else
  echo "🟢 IP no ha cambiado: $IP"
fi
