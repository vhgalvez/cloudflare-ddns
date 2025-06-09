🛡️ Cloudflare DDNS — Instalación Completa (Systemd)
Este sistema actualiza automáticamente la IP pública de un registro A en Cloudflare. Ideal para redes domésticas con IP dinámica.

📁 Estructura de rutas profesional
swift
Copiar
Editar
/usr/local/bin/update_cloudflare_ip.sh       → Script principal
/etc/cloudflare-ddns/.env                    → Configuración segura
/var/log/cloudflare_ddns.log                 → Archivo de log persistente
/etc/systemd/system/cloudflare-ddns.service  → Servicio systemd
/etc/systemd/system/cloudflare-ddns.timer    → Temporizador systemd
⚙️ PASO 1: Instalar dependencias (si no las tienes)
bash
Copiar
Editar
sudo dnf install curl jq -y  # Rocky/AlmaLinux
# o en Ubuntu/Debian
# sudo apt install curl jq -y
📝 PASO 2: Instalar el script principal
bash
Copiar
Editar
sudo cp update_cloudflare_ip.sh /usr/local/bin/update_cloudflare_ip.sh
sudo chmod 755 /usr/local/bin/update_cloudflare_ip.sh
🔐 PASO 3: Crear archivo .env seguro
bash
Copiar
Editar
sudo mkdir -p /etc/cloudflare-ddns
sudo nano /etc/cloudflare-ddns/.env
Contenido de ejemplo:

env
Copiar
Editar
CF_API_TOKEN=tu_token_api_aquí
ZONE_NAME=socialdevs.site
RECORD_NAME=home.socialdevs.site
Asegurar permisos:

bash
Copiar
Editar
sudo chmod 600 /etc/cloudflare-ddns/.env
sudo chown root:root /etc/cloudflare-ddns/.env
📂 PASO 4: Crear archivo de log
bash
Copiar
Editar
sudo touch /var/log/cloudflare_ddns.log
sudo chmod 644 /var/log/cloudflare_ddns.log
sudo chown root:root /var/log/cloudflare_ddns.log
🛠️ PASO 5: Crear archivos systemd
cloudflare-ddns.service
bash
Copiar
Editar
sudo nano /etc/systemd/system/cloudflare-ddns.service
Pega:

ini
Copiar
Editar
[Unit]
Description=Cloudflare DDNS actualizador de IP pública
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/update_cloudflare_ip.sh
StandardOutput=append:/var/log/cloudflare_ddns.log
StandardError=append:/var/log/cloudflare_ddns.log
cloudflare-ddns.timer
bash
Copiar
Editar
sudo nano /etc/systemd/system/cloudflare-ddns.timer
Pega:

ini
Copiar
Editar
[Unit]
Description=Ejecutar Cloudflare DDNS cada 5 minutos

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
Unit=cloudflare-ddns.service

[Install]
WantedBy=timers.target
🚀 PASO 6: Activar y ejecutar
bash
Copiar
Editar
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable --now cloudflare-ddns.timer
🔎 PASO 7: Verificación y monitoreo
Ver estado general:
bash
Copiar
Editar
systemctl status cloudflare-ddns.timer
systemctl status cloudflare-ddns.service
Ver próximas ejecuciones:
bash
Copiar
Editar
systemctl list-timers --all | grep cloudflare
Ver logs recientes:
bash
Copiar
Editar
sudo tail -n 20 /var/log/cloudflare_ddns.log
sudo journalctl -u cloudflare-ddns.service --since "10 minutes ago"
🔑 ¿Cómo conseguir tu API Token, Zone ID y Record ID?
1. Crear un API Token personalizado aquí
Permisos mínimos:

Zone.Zone → Read

Zone.DNS → Edit

Scope: solo para tu dominio

2. Obtener Zone ID:
bash
Copiar
Editar
curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=TU_DOMINIO" \
     -H "Authorization: Bearer TU_API_TOKEN" \
     -H "Content-Type: application/json" | jq -r '.result[0].id'
3. Obtener Record ID:
bash
Copiar
Editar
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/TU_ZONE_ID/dns_records?name=SUBDOMINIO.TU_DOMINIO" \
     -H "Authorization: Bearer TU_API_TOKEN" \
     -H "Content-Type: application/json" | jq -r '.result[0].i




🛠️ Instrucciones de uso
Dale permisos de ejecución:

bash
Copiar
Editar
chmod +x install.sh
Ejecuta:

bash
Copiar
Editar
sudo ./install.sh
Luego edita el .env para poner tu token y dominios reales:

bash
Copiar
Editar
sudo nano /etc/cloudflare-ddns/.env
