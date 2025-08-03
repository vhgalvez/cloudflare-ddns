# 🛡️ Cloudflare DDNS — Instalación Profesional con systemd

Este sistema actualiza automáticamente la IP pública de uno o varios registros DNS A/AAAA en Cloudflare. Es ideal para entornos con IP dinámica como redes domésticas, servidores autohospedados, routers, firewalls o VPS sin IP fija.

---

## 📁 Estructura del sistema

```bash
/usr/local/bin/update_cloudflare_ip.sh        # Script principal
/etc/cloudflare-ddns/.env                     # Variables sensibles y configuración
/var/log/cloudflare_ddns.log                  # Log persistente
/etc/systemd/system/cloudflare-ddns.service   # Servicio systemd
/etc/systemd/system/cloudflare-ddns.timer     # Temporizador cada 5 minutos
```

⚠️ **Importante:** el archivo `.env` debe ubicarse exactamente en `/etc/cloudflare-ddns/.env`. El script lo buscará ahí de forma predeterminada.

---

## ⚙️ Paso 1: Instalar dependencias

```bash
# Para Rocky / AlmaLinux / RHEL
sudo dnf install curl jq -y

# Para Debian / Ubuntu
sudo apt install curl jq -y
```

---

## 🛠️ Paso 2: Clonar el repositorio

```bash
git clone https://github.com/vhgalvez/cloudflare-ddns.git
cd cloudflare-ddns
```

---

## 🔄 Paso 3: Instalación automática con install.sh (RECOMENDADO)

```bash
export CF_API_TOKEN="yTuTokenSegur0_234df23"
sudo chmod +x install.sh
sudo -E ./install.sh
```

Después, edita el archivo `.env` generado:

```bash
sudo mkdir -p /etc/cloudflare-ddns
sudo chmod 700 /etc/cloudflare-ddns
sudo chown root:root /etc/cloudflare-ddns
sudo nano /etc/cloudflare-ddns/.env
```

Ejemplo de contenido:

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

---

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

---

## 🚀 Paso 4: Activar el sistema

```bash
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable --now cloudflare-ddns.timer
```

---

## 🔎 Paso 5: Verificar funcionamiento

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

---

## 🧪 Prueba manual del script

Puedes probar la ejecución manual así:

```bash
sudo /usr/local/bin/update_cloudflare_ip.sh
```

---

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

---

## 🧽 Desinstalación segura (recomendada)

```bash
sudo chmod +x uninstall.sh
sudo ./uninstall.sh
```

✅ Elimina solo archivos del sistema relacionados con este DDNS. No toca otros servicios.

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

## 🔐 Seguridad

- `.env` contiene el token API → protegido con permisos 600.
- No se sube a Git, ni se comparte, ni se empaqueta.
- Acceso restringido a root.

---

## 🌍 Resumen del sistema

| Característica                     | Estado                         |
| ---------------------------------- | ------------------------------ |
| IP dinámica → DNS en Cloudflare    | ✅ Activo                      |
| Intervalo                          | 5 minutos                      |
| Registro de logs                   | `/var/log/cloudflare_ddns.log` |
| Gestión automática con systemd     | ✅ Incluida                    |
| Compatible con múltiples registros | ✅                             |

---

## 🧠 ¿Qué hace este sistema?

Detecta tu IP pública periódicamente y actualiza automáticamente los registros A en Cloudflare si tu IP ha cambiado, usando un token de API y systemd.timer.

---

## 📂 Archivos clave

| Archivo                        | Rol                                                             |
| ------------------------------ | --------------------------------------------------------------- |
| `install.sh`                   | Instala todo: dependencias, script principal, servicios systemd |
| `update_cloudflare_ip.sh`      | Script que consulta tu IP y actualiza Cloudflare vía API        |
| `cloudflare-ddns.service`      | Servicio systemd que ejecuta el script de actualización         |
| `cloudflare-ddns.timer`        | Temporizador systemd que ejecuta el servicio cada 5 minutos     |
| `uninstall.sh`                 | Elimina todo de forma segura (servicios, script, config, logs)  |
| `/etc/cloudflare-ddns/.env`    | Variables de entorno sensibles: API token, zona y registros     |
| `/var/log/cloudflare-ddns.log` | Log persistente de cada actualización                           |

---

## 🛠️ 1. `install.sh` — Instalador principal

Este script:

### 🔍 Fase 1: Prepara el entorno

- Verifica privilegios (`sudo`).
- Instala `curl` y `jq` si no están presentes.
- Valida que `update_cloudflare_ip.sh` exista y sea ejecutable.

### 🛠️ Fase 2: Genera archivos systemd

- Escribe los archivos `cloudflare-ddns.service` y `.timer` en `/etc/systemd/system`.
- El `.service` ejecuta el script una sola vez (`Type=oneshot`).
- El `.timer` lanza el servicio cada 5 minutos (`OnUnitActiveSec=300`).

### 📂 Fase 3: Instala archivos

- Copia `update_cloudflare_ip.sh` a `/usr/local/bin/`.
- Crea `~/.env` con las variables necesarias (si no existe).
- Crea el log en `/var/log/cloudflare-ddns.log`.

### ♻️ Fase 4: Activa y ejecuta

- Habilita y arranca el timer.
- Ejecuta manualmente una primera actualización para verificar que todo funcione.

---

## 🌐 2. `update_cloudflare_ip.sh` — Script de actualización

Este script se ejecuta:

- Al instalar (manualmente).
- Cada 5 minutos (automáticamente desde `systemd.timer`).

### 🔍 ¿Qué hace?

1. Carga las variables desde `.env` (`CF_API_TOKEN`, `ZONE_NAME`, `RECORD_NAMES`).
2. Detecta la IP pública consultando Cloudflare (`https://1.1.1.1/cdn-cgi/trace`).
3. Consulta la zona DNS en Cloudflare (usando el nombre y el token).
4. Para cada registro A, compara si la IP actual coincide con la de Cloudflare.
5. Si ha cambiado, lanza un `PUT` a la API de Cloudflare para actualizar el registro.
6. Registra todo en `/var/log/cloudflare-ddns.log`.

---

## 🔁 3. `cloudflare-ddns.service` y `.timer`

### `cloudflare-ddns.service`

```ini
[Service]
Type=oneshot
ExecStart=/usr/local/bin/update_cloudflare_ip.sh
```

Se ejecuta una vez cada vez que lo llama el timer.

### `cloudflare-ddns.timer`

```ini
[Timer]
OnBootSec=60           # 1 minuto después de arrancar el sistema
OnUnitActiveSec=300    # Luego cada 5 minutos
Unit=cloudflare-ddns.service
```

Activa el `.service` automáticamente cada 5 minutos.

---

## 🧹 4. `uninstall.sh` — Desinstalador seguro

Este script:

- Detiene y deshabilita los servicios.
- Elimina:
  - Script de actualización.
  - Archivos systemd.
  - `.env` y log.
  - Directorio de config si está vacío.
- Recarga systemd.
- Incluye validación de rutas para evitar borrar cosas fuera de lo permitido.

---

## 🔁 Flujo completo resumido

```mermaid
graph TD
    A[install.sh] --> B[/usr/local/bin/update_cloudflare_ip.sh]
    A --> C[/etc/systemd/system/cloudflare-ddns.service]
    A --> D[/etc/systemd/system/cloudflare-ddns.timer]
    A --> E[/etc/cloudflare-ddns/.env]
    A --> F[systemctl enable --now cloudflare-ddns.timer]
    F --> G[systemd ejecuta .service cada 5 min]
    G --> H[update_cloudflare_ip.sh actualiza Cloudflare]
    H --> I[Registra en /var/log/cloudflare-ddns.log]
```

---

## ✅ Ventajas de este sistema

- **Automático y persistente:** sin cron, sin docker, sin monitoreo externo.
- **Seguro:** no expone tokens ni hace borrados peligrosos.
- **Simple y portable:** 100% bash + systemd.
- **Escalable:** puedes añadir IPv6 o registros AAAA fácilmente.

---


📌 Cómo usarlos
Bootstrap inicial (una sola vez):

bash
Copiar
Editar
sudo chmod +x bootstrap_dns.sh
sudo ./bootstrap_dns.sh
Chequeo / reparación cuando lo necesites:

bash
Copiar
Editar
sudo chmod +x check_and_repair_dns.sh
sudo ./check_and_repair_dns.sh

## 👤 Autor y Licencia

- **Autor:** Victor Galvez (@vhgalvez)
- **Licencia:** MIT

Repositorio oficial:  
[https://github.com/vhgalvez/cloudflare-ddns](https://github.com/vhgalvez/cloudflare-ddns)
