Guárdalo como /usr/local/bin/update_cloudflare_ip.sh
Y hazlo ejecutable:

bash
Copiar
Editar
chmod +x /usr/local/bin/update_cloudflare_ip.sh
🔁 Paso 2: Tarea cron (cada 5 minutos)
Edita el cron con:

bash
Copiar
Editar
crontab -e
Agrega:

bash
Copiar
Editar
*/5 * * * * /usr/local/bin/update_cloudflare_ip.sh >> /var/log/cloudflare_ddns.log 2>&1
🧠 ¿Cómo conseguir tus IDs?
API Token: Crea uno aquí con permiso de:

Zone.Zone

Zone.DNS

Alcance: solo para la zona de tu dominio.

Zone ID y Record ID: Puedes obtenerlos con estos comandos:

bash
Copiar
Editar
# Obtener Zone ID
curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=socialdevs.site" \
     -H "Authorization: Bearer TU_API_TOKEN" \
     -H "Content-Type: application/json" | jq '.result[0].id'

# Obtener Record ID
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/TU_ZONE_ID/dns_records?name=socialdevs.site" \
     -H "Authorization: Bearer TU_API_TOKEN" \
     -H "Content-Type: application/json" | jq '.result[0].id