#!/usr/bin/env bash
# install.sh – Instalador auto-contenido de Cloudflare-DDNS (systemd)
# Autor: @vhgalvez — MIT

set -euo pipefail
IFS=$'\n\t'
: "${CF_API_TOKEN:=}"

# rutas ----------------------------------------------------------------------
DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_SRC="$DIR/update_cloudflare_ip.sh"
SERVICE_SRC="$DIR/cloudflare-ddns.service"
TIMER_SRC="$DIR/cloudflare-ddns.timer"

SCRIPT_DEST="/usr/local/bin/update_cloudflare_ip.sh"
SERVICE_DEST="/etc/systemd/system/cloudflare-ddns.service"
TIMER_DEST="/etc/systemd/system/cloudflare-ddns.timer"

ENV_DIR="/etc/cloudflare-ddns"
ENV_FILE="$ENV_DIR/.env"
LOG_FILE="/var/log/cloudflare-ddns.log"

DEFAULT_ZONE="socialdevs.site"
DEFAULT_RECORDS="socialdevs.site,public.socialdevs.site"

log() { printf '[%(%F %T)T] %b\n' -1 "$*"; }

# root -----------------------------------------------------------------------
[[ $EUID -eq 0 ]] || exec sudo -E "$0" "$@"

# dependencias ---------------------------------------------------------------
need_pkg() {
  local p="$1"
  if ! command -v "$p" &>/dev/null; then
    log "📦 Instalando $p"
    if   command -v dnf &>/dev/null;     then dnf -y install "$p"
    elif command -v yum &>/dev/null;     then yum -y install "$p"
    elif command -v apt-get &>/dev/null; then apt-get -y install "$p"
    else log "❌ No se detecta gestor de paquetes compatible"; exit 1
    fi
  fi
}
for p in curl jq; do need_pkg "$p"; done

# validar updater ------------------------------------------------------------
[[ -f "$SCRIPT_SRC" ]] || { log "❌ $SCRIPT_SRC no encontrado"; exit 1; }
grep -q "Cloudflare" "$SCRIPT_SRC" || { log "❌ El updater no parece válido"; exit 1; }

# instalar archivos ----------------------------------------------------------
log "📥 Instalando script → $SCRIPT_DEST"
install -Dm755 "$SCRIPT_SRC" "$SCRIPT_DEST"
chmod +x "$SCRIPT_DEST"  # 🔧 Corrección explícita

log "📄 Instalando unidad systemd"
install -Dm644 "$SERVICE_SRC" "$SERVICE_DEST"
install -Dm644 "$TIMER_SRC"   "$TIMER_DEST"

log "📂 Creando directorio $ENV_DIR"
install -d -m700 "$ENV_DIR"

if [[ -z "${CF_API_TOKEN}" ]]; then
  log "⚠️  Token no proporcionado. El archivo .env quedará incompleto."
fi

if [[ ! -f $ENV_FILE ]]; then
  log "📝 Generando archivo de entorno $ENV_FILE"
  cat > "$ENV_FILE" <<EOF
CF_API_TOKEN=$CF_API_TOKEN
ZONE_NAME=$DEFAULT_ZONE
RECORD_NAMES=$DEFAULT_RECORDS
EOF
  chmod 600 "$ENV_FILE"
fi

log "🗂️  Creando archivo de log $LOG_FILE"
install -Dm644 /dev/null "$LOG_FILE"

# habilitar systemd ----------------------------------------------------------
log "🔄 Recargando systemd y activando timer"
systemctl daemon-reload

if systemctl enable --now cloudflare-ddns.timer; then
  log "✅ Timer activado correctamente"
else
  log "❌ Fallo al habilitar cloudflare-ddns.timer"
  exit 1
fi

# resumen final --------------------------------------------------------------
log "✅ Instalación completada correctamente."

cat <<EOF

📌 Archivo de credenciales : $ENV_FILE
📌 Token cargado           : ${CF_API_TOKEN:-"(vacío, edítalo manualmente)"}

▶️ Estado del timer:
   systemctl status cloudflare-ddns.timer

▶️ Ejecutar inmediatamente:
   sudo systemctl start cloudflare-ddns.service

▶️ Logs:
   journalctl -u cloudflare-ddns.service -n 50 --no-pager
   tail -f $LOG_FILE
EOF
# fin del script -------------------------------------------------------------
exit 0