# Configuración de Cloudflare Dynamic DNS

## Paso 1: Preparar el script

Copia el script a la ubicación adecuada:

```bash
sudo cp -r update_cloudflare_ip.sh /usr/local/bin/update_cloudflare_ip.sh
```

Hazlo ejecutable:

```bash
sudo chmod 755 /usr/local/bin/update_cloudflare_ip.sh
```

## Paso 2: Configurar una tarea cron (cada 5 minutos)

Edita el cron con:

```bash
crontab -e
```

Agrega la siguiente línea para ejecutar el script y registrar la salida en un archivo de log:

```bash
*/5 * * * * bash -c '/usr/local/bin/update_cloudflare_ip.sh >> /var/log/cloudflare_ddns.log 2>&1'
```

## Paso 3: Configurar el archivo de log

Crea el archivo de log:

```bash
sudo touch /var/log/cloudflare_ddns.log
```

Asigna los permisos adecuados:

```bash
sudo chown root:root /var/log/cloudflare_ddns.log
sudo chmod 644 /var/log/cloudflare_ddns.log
```

## Paso 4: Verificar el funcionamiento

Ejecuta el script manualmente y verifica el log:

```bash
sudo bash -c '/usr/local/bin/update_cloudflare_ip.sh >> /var/log/cloudflare_ddns.log 2>&1'
```

Revisa las últimas 20 líneas del log:

```bash
sudo tail -n 20 /var/log/cloudflare_ddns.log
```

Monitorea el log en tiempo real:

```bash
sudo tail -f /var/log/cloudflare_ddns.log
```

## ¿Cómo conseguir tus IDs?

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

## Comandos adicionales útiles

Listar las tareas cron configuradas:

```bash
sudo crontab -l
```
