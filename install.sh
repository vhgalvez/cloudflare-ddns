#!/usr/bin/env bash
# install.sh — Instalador auto-contenido de Cloudflare-DDNS (systemd)
# Autor: @vhgalvez — Licencia MIT

set -euo pipefail
IFS=$'\n\t'

: "${CF_API_TOKEN:=}"  # Puede venir del entorno

# ─────────────────────────────────────────────────────────────────────────────
# ░░ Variables ░░
# ─────────────────────────────────────────────────────────────────────────────
readonly SCRIPT_SRC="update_cloudflare_ip.sh"
readonly SCRIPT_DEST="/usr/local/bin/update_cloudflare_ip.sh"

readonly ENV_DIR="/etc/cloudflare-ddns"
readonly ENV_FILE="$ENV_DIR/.env"
readonly LOG_FILE="/var/log/cloudflare-ddns.log"

readonly SERVICE_SRC="cloudflare-ddns.service"
readonly TIMER_SRC="cloudflare-ddns.timer"
readonly SERVICE_DEST="/etc/systemd/system/cloudflare-ddns.service"
readonly TIMER_DEST="/etc/systemd/system/cloudflare-ddns.timer"

readonly DEFAULT_ZONE="socialdevs.site"
readonly DEFAULT_RECORDS="socialdevs.site,public.socialdevs.site"

log() { printf '[%(%F %T)T] %b\n' -1 "$*"; }

# ─────────────────────────────────────────────────────────────────────────────
# ░░ 1. Escalada de privilegios ░░
# ─────────────────────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then exec sudo -E bash "$0" "$@"; fi

# ─────────────────────────────────────────────────────────────────────────────
# ░░ 2. Verificar dependencias ░░
# ─────────────────────────────────────────────────────────────────────────────
need_pkg() {
  local p="$1"
  command -v "$p" &>/dev/null && return
  log "📦 Instalando dependencia: $p"
  if   command -v dnf &>/dev/null;     then dnf -y install "$p"
  elif command -v yum &>/dev/null;     then yum -y install "$p"
  elif command -v apt-get &>/dev/null; then apt-get -y install "$p"
  else log "❌ No se detecta gestor de paquetes soportado"; exit 1; fi
}
for b in curl jq; do need_pkg "$b"; done

# ─────────────────────────────────────────────────────────────────────────────
# ░░ 3. Verificar script base ░░
# ─────────────────────────────────────────────────────────────────────────────
[[ -f "$SCRIPT_SRC" ]] || { log "❌ Falta $SCRIPT_SRC"; exit 1; }

# ─────────────────────────────────────────────────────────────────────────────
# ░░ 4. Autogenerar unidades systemd ░░
# ─────────────────────────────────────────────────────────────────────────────
generate_unit_files() {
  if [[ ! -f $SERVICE_SRC ]]; then
    cat > "$SERVICE_SRC" <<EOF
[Unit]
Description=Cloudflare DDNS – actualizador de IP pública
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$SCRIPT_DEST
StandardOutput=append:$LOG_FILE
StandardError=append:$LOG_FILE
EOF
    log "🛠️  Generado unit file local → $SERVICE_SRC"
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
    log "🛠️  Generado unit file local → $TIMER_SRC"
  fi
}
generate_unit_files

# ─────────────────────────────────────────────────────────────────────────────
# ░░ 5. Instalar archivos ░░
# ─────────────────────────────────────────────────────────────────────────────
log "🚀 Instalando script → $SCRIPT_DEST"
install -Dm755 "$SCRIPT_SRC" "$SCRIPT_DEST"

log "📂 Creando directorio $ENV_DIR"
install -d -m700 "$ENV_DIR"

if [[ ! -f $ENV_FILE ]]; then
  log "📝 Generando $ENV_FILE (con token si aplica)"
  cat > "$ENV_FILE" <<EOF
CF_API_TOKEN=$CF_API_TOKEN
ZONE_NAME=$DEFAULT_ZONE
RECORD_NAMES=$DEFAULT_RECORDS
EOF
  chmod 600 "$ENV_FILE"
fi

log "📄 Asegurando log → $LOG_FILE"
install -Dm644 /dev/null "$LOG_FILE"

# ─────────────────────────────────────────────────────────────────────────────
# ░░ 6. Instalar y activar systemd ░░
# ─────────────────────────────────────────────────────────────────────────────
log "⚙️  Instalando unidades en systemd"
if [[ -f "$SERVICE_SRC" ]]; then install -Dm644 "$SERVICE_SRC" "$SERVICE_DEST"; else log "❌ No se generó $SERVICE_SRC"; exit 1; fi
if [[ -f "$TIMER_SRC" ]];   then install -Dm644 "$TIMER_SRC"   "$TIMER_DEST";   else log "❌ No se generó $TIMER_SRC"; exit 1; fi

log "🔄 Recargando y habilitando timer"
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now cloudflare-ddns.timer || {
  log "⚠️  Error habilitando cloudflare-ddns.timer"
  exit 1
}

# ─────────────────────────────────────────────────────────────────────────────
# ░░ 7. Mensaje final ░░
# ─────────────────────────────────────────────────────────────────────────────
log "✅ Instalación completada correctamente."

cat <<EOF

📌 Archivo de credenciales : $ENV_FILE
📌 Token cargado           : ${CF_API_TOKEN:-«vacío, edítalo»}

▶️ Estado del timer:
   systemctl status cloudflare-ddns.timer

▶️ Ejecutar inmediatamente:
   sudo systemctl start cloudflare-ddns.service

▶️ Logs:
   journalctl -u cloudflare-ddns.service -n 50 --no-pager
   tail -f $LOG_FILE
EOF