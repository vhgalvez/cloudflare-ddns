# Configuración de Cloudflare Dynamic DNS

Guárdalo como `/usr/local/bin/update_cloudflare_ip.sh` y hazlo ejecutable:

```bash
sudo chmod 755 /usr/local/bin/update_cloudflare_ip.sh
```

🔁 **Paso 2: Configurar una tarea cron (cada 5 minutos)**
Edita el cron con:

```bash
crontab -e
```

Agrega la siguiente línea para ejecutar el script y registrar la salida en un archivo de log:

```bash
*/5 * * * * /usr/local/bin/update_cloudflare_ip.sh >> /var/log/cloudflare_ddns.log 2>&1
```

🧠 **¿Cómo conseguir tus IDs?**

**API Token:** Crea uno [aquí](https://dash.cloudflare.com/profile/api-tokens) con los siguientes permisos:

- `Zone.Zone`
- `Zone.DNS`

**Alcance:** Solo para la zona de tu dominio.

**Zone ID y Record ID:** Puedes obtenerlos con los siguientes comandos:

```bash
# Obtener Zone ID
curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=TU_DOMINIO" \
     -H "Authorization: Bearer TU_API_TOKEN" \
     -H "Content-Type: application/json" | jq -r '.result[0].id'

# Obtener Record ID
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/TU_ZONE_ID/dns_records?name=TU_DOMINIO" \
     -H "Authorization: Bearer TU_API_TOKEN" \
     -H "Content-Type: application/json" | jq -r '.result[0].id'
```