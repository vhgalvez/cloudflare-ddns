# 🛡️ Cloudflare DDNS — Instalación Completa con systemd

Este sistema actualiza automáticamente la IP pública de un registro A en Cloudflare. Ideal para redes domésticas con IP dinámica, servidores caseros o entornos autohospedados.

---

## 📁 Estructura profesional del sistema

```
/usr/local/bin/update_cloudflare_ip.sh        # Script principal
/etc/cloudflare-ddns/.env                     # Archivo de configuración
/var/log/cloudflare_ddns.log                  # Log persistente
/etc/systemd/system/cloudflare-ddns.service   # Servicio systemd
/etc/systemd/system/cloudflare-ddns.timer     # Temporizador systemd
```

> ✅ **El archivo `.env` debe ir exactamente en:** `/etc/cloudflare-ddns/.env`
> El script `update_cloudflare_ip.sh` lo carga desde ahí.
> **No se debe mover ni renombrar.**

---

## ⚙️ Paso 1: Instalar dependencias

```bash
# Para Rocky/AlmaLinux/RHEL
sudo dnf install curl jq -y

# Para Debian/Ubuntu
sudo apt install curl jq -y
```

---

## 🗘️ Paso 2: Instalar el script principal

```bash
sudo cp update_cloudflare_ip.sh /usr/local/bin/update_cloudflare_ip.sh
sudo chmod 755 /usr/local/bin/update_cloudflare_ip.sh
```

---

## 🔐 Paso 3: Crear el archivo .env seguro

```bash
sudo mkdir -p /etc/cloudflare-ddns
sudo nano /etc/cloudflare-ddns/.env
```

Ejemplo de contenido:

```env
CF_API_TOKEN=tu_token_api_aquí
ZONE_NAME=socialdevs.site
RECORD_NAME=home.socialdevs.site
```

Asegura los permisos:

```bash
sudo chmod 600 /etc/cloudflare-ddns/.env
sudo chown root:root /etc/cloudflare-ddns/.env
```

---

## 🗒️ Paso 4: Crear archivo de log

```bash
sudo touch /var/log/cloudflare_ddns.log
sudo chmod 644 /var/log/cloudflare_ddns.log
sudo chown root:root /var/log/cloudflare_ddns.log
```

---

## 🛠️ Paso 5: Crear archivos systemd

### 1. Servicio: `/etc/systemd/system/cloudflare-ddns.service`

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

### 2. Temporizador: `/etc/systemd/system/cloudflare-ddns.timer`

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

---

## 🚀 Paso 6: Activar el sistema

```bash
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable --now cloudflare-ddns.timer
```

---

## 🔎 Paso 7: Verificación y monitoreo

### Estado del temporizador y servicio

```bash
systemctl status cloudflare-ddns.timer
systemctl status cloudflare-ddns.service
```

### Próximas ejecuciones programadas

```bash
systemctl list-timers --all | grep cloudflare
```

### Últimos logs generados

```bash
sudo tail -n 20 /var/log/cloudflare_ddns.log
```

### Últimos 50 logs desde systemd

```bash
journalctl -u cloudflare-ddns.service -n 50 --no-pager
```


### Historial completo desde systemd

```bash
journalctl -u cloudflare-ddns.service
```

---

## 🔑 Obtener tu API Token, Zone ID y Record ID

### 1. Crear token personalizado

[https://dash.cloudflare.com/profile/api-tokens](https://dash.cloudflare.com/profile/api-tokens)

Permisos necesarios:

* `Zone.Zone` → Read
* `Zone.DNS` → Edit

> Scope: solo la zona correspondiente

### 2. Obtener Zone ID

```bash
curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=TU_DOMINIO" \
  -H "Authorization: Bearer TU_API_TOKEN" \
  -H "Content-Type: application/json" | jq -r '.result[0].id'
```

### 3. Obtener Record ID

```bash
curl -s -X GET "https://api.cloudflare.com/client/v4/zones/TU_ZONE_ID/dns_records?name=SUBDOMINIO.TU_DOMINIO" \
  -H "Authorization: Bearer TU_API_TOKEN" \
  -H "Content-Type: application/json" | jq -r '.result[0].id'
```

---

## 🔄 Instalación asistida con install.sh (recomendado)

```bash
chmod +x install.sh
sudo ./install.sh
```

Luego edita el archivo `.env` generado:

```bash
sudo nano /etc/cloudflare-ddns/.env
```

---

## 🌐 Resumen del proyecto

Actualiza automáticamente tu dirección IP pública en Cloudflare. Ideal para redes con IP dinámica (conexiones domésticas o VPS sin IP fija).

### ✅ Características

* Actualización automática si cambia la IP.
* Systemd timer cada 5 minutos.
* Registra logs en `/var/log/cloudflare_ddns.log`.
* Configuración aislada y segura en `.env`.

---

## 📄 Desinstalación

```bash
chmod +x uninstall.sh
sudo ./uninstall.sh
```

> ❌ Esto elimina solo archivos del proyecto. No afecta otros servicios del sistema.

---

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

---

## 🔒 Seguridad

* El archivo `.env` contiene credenciales sensibles.
* Se almacena en `/etc/cloudflare-ddns/` con permisos `600`.
* Nunca se sube a Git ni se incluye en `install.sh`.

---

## 🧠 Créditos

* Desarrollado por: **Victor Galvez**
* Licencia: **MIT**

---

## ❓ Soporte

* Si encuentras errores o tienes mejoras, abre un issue o pull request en:
  [https://github.com/vhgalvez/cloudflare-ddns](https://github.com/vhgalvez/cloudflare-ddns)
