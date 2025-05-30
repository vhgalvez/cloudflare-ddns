# Configuración de Cloudflare Dynamic DNS

sudo cp -r update_cloudflare_ip.sh /usr/local/bin/update_cloudflare_ip.sh

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
*/5 * * * * bash -c '/usr/local/bin/update_cloudflare_ip.sh >> /var/log/cloudflare_ddns.log 2>&1'
```

🧠 **¿Cómo conseguir tus IDs?**

**API Token:** Crea uno [aquí](https://dash.cloudflare.com/profile/api-tokens) con los siguientes permisos:

- `Zone.Zone`
- `Zone.DNS`


sudo touch /var/log/cloudflare_ddns.log
sudo chown root:root /var/log/cloudflare_ddns.log
sudo chmod 644 /var/log/cloudflare_ddns.log

sudo bash -c '/usr/local/bin/update_cloudflare_ip.sh >> /var/log/cloudflare_ddns.log 2>&1'
sudo tail -n 20 /var/log/cloudflare_ddns.log
sudo tail -f /var/log/cloudflare_ddns.log



*/5 * * * * bash -c '/usr/local/bin/update_cloudflare_ip.sh >> /var/log/cloudflare_ddns.log 2>&1'




sudo crontab -l
