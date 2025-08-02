#!/usr/bin/env bash
# install.sh — Instalador auto-contenedor de Cloudflare-DDNS (systemd)
# Compatible con Fedora / RHEL / Rocky / Alma / Debian / Ubuntu

set -euo pipefail
IFS=$'\n\t'

###############################################################################
# ░░ Configuración opcional vía variable de entorno ░░
###############################################################################
: "${CF_API_TOKEN:=}"          # token opcional export CF_API_TOKEN="xxx"
DEFAULT_ZONE="socialdevs.site"
DEFAULT_RECORDS="socialdevs.site,public.socialdevs.site"

###############################################################################
# ░░ Escalada de privilegios una sola vez ░░
###############################################################################
if [[ $EUID -ne 0 ]]; then exec sudo -E bash "$0" "$@"; fi

###############################################################################
# ░░ Rutas ░░
###############################################################################
SCRIPT_SRC="update_cloudflare_ip.sh"
SCRIPT_DEST="/usr/local/bin/update_cloudflare_ip.sh"

ENV_DIR="/etc/cloudflare-ddns"
ENV_FILE="$ENV_DIR/.env"
LOG_FILE="/var/log/cloudflare-ddns.log"

SERVICE_SRC="cloudflare-ddns.service"
TIMER_SRC="cloudflare-ddns.timer"
SERVICE_DEST="/etc/systemd/system/cloudflare-ddns.service"
TIMER_DEST="/etc/systemd/system/cloudflare-ddns.timer"

log(){ printf '[%(%F %T)T] %b\n' -1 "$*"; }

###############################################################################
# ░░ 1. Dependencias mínimas ░░
###############################################################################
need_pkg(){
  local p=$1
  command -v "$p" &>/dev/null && return
  log "📦 Instalando dependencia: $p"
  if   command -v dnf &>/dev/null;      then dnf  -y install "$p"
  elif command -v yum &>/dev/null;      then yum  -y install "$p"
  elif command -v apt-get &>/dev/null;  then apt-get -y install "$p"
  else log "❌ No se detecta gestor de paquetes soportado"; exit 1; fi
}
for b in curl jq; do need_pkg "$b"; done

###############################################################################
# ░░ 2. Verificar script principal ░░
###############################################################################
[[ -f $SCRIPT_SRC ]] || { log "❌ Falta $SCRIPT_SRC"; exit 1; }

###############################################################################
# ░░ 3. Autogenerar unit files si no existen ░░
###############################################################################
generate_unit_files(){
  if [[ ! -f $SERVICE_SRC ]]; then
cat > "$SERVICE_SRC" <<EOF
[Unit]
Description=Cloudflare DDNS – actualizador de IP pública
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$SCRIPT_DEST
StandardOutput=file:$LOG_FILE
StandardError=file:$LOG_FILE
EOF
    log "🛠️  Generado unit file $SERVICE_SRC"
  fi

  if [[ ! -f $TIMER_SRC ]]; then
cat > "$TIMER_SRC" <<EOF
[Unit]
Description=Ejecutar Cloudflare DDNS cada 5 minutos

[Timer]
OnBootSec=60
OnUnitActiveSec=300
Unit=cloudflare-ddns.service

[Install]
WantedBy=timers.target
EOF
    log "🛠️  Generado unit file $TIMER_SRC"
  fi
}
generate_unit_files

###############################################################################
# ░░ 4. Instalar binario, .env y log ░░
###############################################################################
log "🚀 Instalando $SCRIPT_SRC → $SCRIPT_DEST"
install -Dm755 "$SCRIPT_SRC" "$SCRIPT_DEST"

log "📂 Preparando $ENV_DIR"
install -d -m700 "$ENV_DIR"

if [[ ! -f $ENV_FILE ]]; then
  log "📝 Creando $ENV_FILE (token auto-inyectado si existe)"
  cat > "$ENV_FILE" <<EOF
CF_API_TOKEN=$CF_API_TOKEN
ZONE_NAME=$DEFAULT_ZONE
RECORD_NAMES=$DEFAULT_RECORDS
EOF
  chmod 600 "$ENV_FILE"
fi

log "📄 Asegurando log en $LOG_FILE"
install -Dm644 /dev/null "$LOG_FILE"

###############################################################################
# ░░ 5. Copiar units a systemd y habilitar ░░
###############################################################################
log "⚙️  Instalando units systemd"
install -Dm644 "$SERVICE_SRC" "$SERVICE_DEST"
install -Dm644 "$TIMER_SRC"   "$TIMER_DEST"

log "🔄 Recargando systemd y activando timer"
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now cloudflare-ddns.timer

###############################################################################
# ░░ 6. Fin ░░
###############################################################################
log "✅ Instalación completada con éxito."

cat <<EOF

📌 Archivo de credenciales : $ENV_FILE
📌 Token cargado           : ${CF_API_TOKEN:-«vacío, edítalo»}

▶️ Estado del timer:
   systemctl status cloudflare-ddns.timer

▶️ Ejecutar inmediatamente:
   systemctl start cloudflare-ddns.service

▶️ Logs:
   journalctl -u cloudflare-ddns.service -n 50 --no-pager
   tail -F $LOG_FILE
EOF