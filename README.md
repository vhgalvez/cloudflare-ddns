# 🛡️ Cloudflare DDNS — Instalación Profesional con systemd

Este sistema actualiza automáticamente la IP pública de uno o varios registros DNS A/AAAA en Cloudflare. Es ideal para entornos con IP dinámica como redes domésticas, servidores autohospedados, routers, firewalls o VPS sin IP fija.

## 📁 Estructura del sistema

```bash
/usr/local/bin/update_cloudflare_ip.sh        # Script principal
/etc/cloudflare-ddns/.env                     # Variables sensibles y configuración
/var/log/cloudflare_ddns.log                  # Log persistente
/etc/systemd/system/cloudflare-ddns.service   # Servicio systemd
/etc/systemd/system/cloudflare-ddns.timer     # Temporizador cada 5 minutos
```

⚠️ **Importante:** el archivo `.env` debe ubicarse exactamente en `/etc/cloudflare-ddns/.env`. El script lo buscará ahí de forma predeterminada.

## ⚙️ Paso 1: Instalar dependencias

```bash
# Para Rocky / AlmaLinux / RHEL
sudo dnf install curl jq -y

# Para Debian / Ubuntu
sudo apt install curl jq -y
```

## 🛠️ Paso 2: Clonar el repositorio

```bash
git clone https://github.com/vhgalvez/cloudflare-ddns.git
cd cloudflare-ddns
```

## 🔄 Paso 3: Instalación automática con install.sh (RECOMENDADO)

```bash
sudo export CF_API_TOKEN="yTuTokenSegur0_234df23"
```


```bash
sudo chmod +x install.sh
sudo -E ./install.sh
```

Después, edita el archivo `.env` generado:

sudo mkdir -p /etc/cloudflare-ddns


```bash
sudo chmod 700 /etc/cloudflare-ddns
sudo chown root:root /etc/cloudflare-ddns
```

```bash
sudo nano /etc/cloudflare-ddns/.env
```

```bash
sudo chmod 600 /etc/cloudflare-ddns/.env
sudo chown root:root /etc/cloudflare-ddns/.env
```

```bash
sudo nano /etc/cloudflare-ddns/.env
```

## 🔐 Paso 4: Configurar archivo .env

Ejemplo:

```env
CF_API_TOKEN=tu_token_de_cloudflare
ZONE_NAME=socialdevs.site
RECORD_NAMES=home.socialdevs.site,public.socialdevs.site
```

Asegura los permisos:

```bash
sudo chmod 600 /etc/cloudflare-ddns/.env
sudo chown root:root /etc/cloudflare-ddns/.env
```

## 🗒️ Estructura de los archivos systemd

### `/etc/systemd/system/cloudflare-ddns.service`

```ini
[Unit]
Description=Cloudflare DDNS actualizador de IP pública
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/update_cloudflare_ip.sh
StandardOutput=append:/var/log/cloudflare_ddns.log
StandardError=append:/var/log/cloudflare_ddns.log
```

### `/etc/systemd/system/cloudflare-ddns.timer`

```ini
[Unit]
Description=Ejecutar Cloudflare DDNS cada 5 minutos

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
Unit=cloudflare-ddns.service

[Install]
WantedBy=timers.target
```

## 🚀 Paso 5: Activar el sistema

```bash
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable --now cloudflare-ddns.timer
```

## 🔎 Paso 6: Verificar funcionamiento

Ver estado del temporizador y servicio:

```bash
sudo systemctl status cloudflare-ddns.timer
sudo systemctl status cloudflare-ddns.service
```

Ver próximas ejecuciones programadas:

```bash
systemctl list-timers --all | grep cloudflare
```

Últimos logs del sistema:

```bash
journalctl -u cloudflare-ddns.service -n 50 --no-pager
```

Log directo del archivo:

```bash
sudo tail -f /var/log/cloudflare_ddns.log
```

## 🧪 Prueba manual del script

Puedes probar la ejecución manual así:

```bash
sudo /usr/local/bin/update_cloudflare_ip.sh
```

## 🔑 Cómo obtener tu API Token, Zone ID y Record ID

1️⃣ Crear un token en Cloudflare:  
🔗 [Crear Token personalizado](https://dash.cloudflare.com/profile/api-tokens)

Permisos requeridos:

- `Zone.Zone` → Read
- `Zone.DNS` → Edit

Scope: Solo la zona correspondiente

2️⃣ Obtener Zone ID:

```bash
curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=TU_DOMINIO" \
  -H "Authorization: Bearer TU_API_TOKEN" \
  -H "Content-Type: application/json" | jq -r '.result[0].id'
```

3️⃣ Obtener Record ID (opcional si haces gestión avanzada):

```bash
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/TU_ZONE_ID/dns_records?name=SUBDOMINIO.TU_DOMINIO" \
  -H "Authorization: Bearer TU_API_TOKEN" \
  -H "Content-Type: application/json" | jq -r '.result[0].id'
```

## 🧽 Desinstalación segura (recomendada)




```bash
sudo chmod +x uninstall.sh
sudo ./uninstall.sh
```

✅ Elimina solo archivos del sistema relacionados con este DDNS. No toca otros servicios.

## ❌ Desinstalación manual

```bash
sudo systemctl stop cloudflare-ddns.service
sudo systemctl disable --now cloudflare-ddns.timer
sudo rm /etc/systemd/system/cloudflare-ddns.{service,timer}
sudo rm /usr/local/bin/update_cloudflare_ip.sh
sudo rm -rf /etc/cloudflare-ddns
sudo rm /var/log/cloudflare-ddns.log
sudo systemctl daemon-reload
```

## 🔐 Seguridad

- `.env` contiene el token API → protegido con permisos 600.
- No se sube a Git, ni se comparte, ni se empaqueta.
- Acceso restringido a root.

## 🌍 Resumen del sistema

| Característica                        | Estado       |
|--------------------------------------|--------------|
| IP dinámica → DNS en Cloudflare      | ✅ Activo    |
| Intervalo                            | 5 minutos    |
| Registro de logs                     | `/var/log/cloudflare_ddns.log` |
| Gestión automática con systemd       | ✅ Incluida  |
| Compatible con múltiples registros   | ✅           |

## 👤 Autor y Licencia

- **Autor:** Victor Galvez (@vhgalvez)
- **Licencia:** MIT

Repositorio oficial:  
[https://github.com/vhgalvez/cloudflare-ddns](https://github.com/vhgalvez/cloudflare-ddns)