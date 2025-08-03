#!/usr/bin/env bash
# install.sh — Cloudflare-DDNS + systemd
# Autor: @vhgalvez · MIT

set -euo pipefail
IFS=$'\n\t'

: "${CF_API_TOKEN:=}"
DEFAULT_ZONE="socialdevs.site"
DEFAULT_RECORDS="socialdevs.site,public.socialdevs.site"

# ──────────────── Rutas ────────────────
ROOT_DIR="$(cd -- "$(dirname "$0")" && pwd)"

SRC_UPDATE="$ROOT_DIR/update_cloudflare_ip.sh"
SRC_SERVICE="$ROOT_DIR/cloudflare-ddns.service"
SRC_TIMER="$ROOT_DIR/cloudflare-ddns.timer"

BIN_DST="/usr/local/bin/update_cloudflare_ip.sh"
UNIT_SERVICE_DST="/etc/systemd/system/cloudflare-ddns.service"
UNIT_TIMER_DST="/etc/systemd/system/cloudflare-ddns.timer"

CFG_DIR="/etc/cloudflare-ddns"
ENV_FILE="$CFG_DIR/.env"
LOG_FILE="/var/log/cloudflare-ddns.log"

log() { printf '[%(%F %T)T] %b\n' -1 "$*"; }

# ───── Escalada ─────
[[ $EUID -eq 0 ]] || exec sudo -E -- "$0" "$@"

# ───── Dependencias ─────
for pkg in curl jq; do
  command -v "$pkg" &>/dev/null && continue
  log "📦 Instalando $pkg…"
  if command -v dnf &>/dev/null; then dnf -y install "$pkg"
  elif command -v yum &>/dev/null; then yum -y install "$pkg"
  elif command -v apt-get &>/dev/null; then apt-get -y install "$pkg"
  else log "❌ Gestor de paquetes no soportado"; exit 1; fi
done

# ───── Validación de archivos ─────
[[ -f $SRC_UPDATE  ]] || { log "❌ Falta $SRC_UPDATE"; exit 1; }
[[ -f $SRC_SERVICE ]] || { log "❌ Falta $SRC_SERVICE"; exit 1; }
[[ -f $SRC_TIMER   ]] || { log "❌ Falta $SRC_TIMER"; exit 1; }

# ───── Preliminar: detener y limpiar versiones anteriores ─────
log "🧹 Eliminando servicios antiguos (si existen)…"
systemctl disable --now cloudflare-ddns.timer 2>/dev/null || true
systemctl disable --now cloudflare-ddns.service 2>/dev/null || true
rm -f "$UNIT_SERVICE_DST" "$UNIT_TIMER_DST"

# ───── Copia e instalación ─────
log "🚀 Copiando $SRC_UPDATE → $BIN_DST"
install -Dm755 "$SRC_UPDATE" "$BIN_DST"   # PERMISOS 755

log "⚙️ Copiando unidades systemd"
install -Dm644 "$SRC_SERVICE" "$UNIT_SERVICE_DST"
install -Dm644 "$SRC_TIMER" "$UNIT_TIMER_DST"

log "📂 Creando directorio de configuración → $CFG_DIR"
install -d -m700 "$CFG_DIR"

if [[ ! -f $ENV_FILE ]]; then
  log "📝 Generando $ENV_FILE"
  cat >"$ENV_FILE" <<EOF
CF_API_TOKEN=$CF_API_TOKEN
ZONE_NAME=$DEFAULT_ZONE
RECORD_NAMES=$DEFAULT_RECORDS
EOF
  chmod 600 "$ENV_FILE"
else
  log "ℹ️ $ENV_FILE ya existe. Conservado."
fi

log "📄 Verificando log → $LOG_FILE"
touch "$LOG_FILE"
chmod 644 "$LOG_FILE"
chown root:root "$LOG_FILE"

# ───── Ajuste final de permisos ─────
chmod 755 "$BIN_DST"
chmod 644 "$UNIT_SERVICE_DST" "$UNIT_TIMER_DST"
chmod 600 "$ENV_FILE"

# ───── Recarga y habilitación ─────
log "🔄 Recargando systemd…"
systemctl daemon-reexec
systemctl daemon-reload

log "⏱️ Activando servicio y temporizador"
systemctl enable --now cloudflare-ddns.timer
systemctl start cloudflare-ddns.service

# ───── Resumen ─────
log "✅ Instalación completada"

cat <<EOF

Credenciales   : $ENV_FILE
Log del script : $LOG_FILE

Comandos útiles
───────────────
sudo systemctl status cloudflare-ddns.service
sudo journalctl -u cloudflare-ddns.service -n 50 --no-pager
sudo systemctl list-timers --all | grep cloudflare
EOF