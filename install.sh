#!/usr/bin/env bash
# install.sh — Cloudflare-DDNS + systemd
# © @vhgalvez · MIT

set -euo pipefail
IFS=$'\n\t'

###############################################################################
# ░░ Configuración opcional por variable de entorno ░░
###############################################################################
: "${CF_API_TOKEN:=}"
DEFAULT_ZONE="socialdevs.site"
DEFAULT_RECORDS="socialdevs.site,public.socialdevs.site"

###############################################################################
# ░░ Rutas ░░
###############################################################################
ROOT_DIR=$(cd -- "$(dirname "$0")" && pwd)

SRC_UPDATE="$ROOT_DIR/update_cloudflare_ip.sh"
BIN_DST="/usr/local/bin/update_cloudflare_ip.sh"

UNIT_SERVICE_DST="/etc/systemd/system/cloudflare-ddns.service"
UNIT_TIMER_DST="/etc/systemd/system/cloudflare-ddns.timer"

CFG_DIR="/etc/cloudflare-ddns"
ENV_FILE="$CFG_DIR/.env"
LOG_FILE="/var/log/cloudflare-ddns.log"

###############################################################################
log(){ printf '[%(%F %T)T] %b\n' -1 "$*"; }
die(){ log "❌ $1"; exit 1; }

###############################################################################
# ░░ 1. Escalada de privilegios ░░
###############################################################################
[[ $EUID -eq 0 ]] || exec sudo -E -- "$0" "$@"

###############################################################################
# ░░ 2. Dependencias mínimas ░░
###############################################################################
need_pkg() {
  command -v "$1" &>/dev/null && return
  log "📦 Instalando $1…"
  if   command -v dnf &>/dev/null; then dnf -y install "$1"
  elif command -v yum &>/dev/null; then yum -y install "$1"
  elif command -v apt-get &>/dev/null; then apt-get -y install "$1"
  else die "No hay gestor de paquetes compatible"; fi
}
for p in curl jq; do need_pkg "$p"; done

###############################################################################
# ░░ 3. Validaciones previas ░░
###############################################################################
[[ -f $SRC_UPDATE ]]  || die "Falta $SRC_UPDATE"

# ✅ Forzar permisos de ejecución por si vienen sin chmod
chmod +x "$SRC_UPDATE"

[[ -x $SRC_UPDATE ]]  || die "$SRC_UPDATE no es ejecutable"

###############################################################################
# ░░ 4. Crear plantillas systemd ░░
###############################################################################
log "⚙️ Generando archivos .service y .timer"

cat <<'EOF' >"/tmp/cloudflare-ddns.service"
[Unit]
Description=Cloudflare DDNS actualizador de IP pública
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/update_cloudflare_ip.sh
StandardOutput=journal
StandardError=journal
EOF

cat <<'EOF' >"/tmp/cloudflare-ddns.timer"
[Unit]
Description=Ejecutar Cloudflare DDNS cada 5 minutos

[Timer]
OnBootSec=60
OnUnitActiveSec=300
Unit=cloudflare-ddns.service

[Install]
WantedBy=timers.target
EOF

###############################################################################
# ░░ 5. Limpiar instalación previa ░░
###############################################################################
log "🧹 Eliminando instalaciones anteriores…"
systemctl disable --now cloudflare-ddns.timer  >/dev/null 2>&1 || true
systemctl disable --now cloudflare-ddns.service>/dev/null 2>&1 || true
rm -f "$UNIT_SERVICE_DST" "$UNIT_TIMER_DST"

###############################################################################
# ░░ 6. Copia de archivos ░░
###############################################################################
log "🚀 Instalando script principal"
install -Dm750 "$SRC_UPDATE" "$BIN_DST"

log "⚙️ Instalando unidades systemd"
install -Dm644 /tmp/cloudflare-ddns.service "$UNIT_SERVICE_DST"
install -Dm644 /tmp/cloudflare-ddns.timer   "$UNIT_TIMER_DST"
rm -f /tmp/cloudflare-ddns.*

log "📂 Creando configuración en $CFG_DIR"
install -d -m700 "$CFG_DIR"

if [[ ! -f $ENV_FILE ]]; then
  [[ -n $CF_API_TOKEN ]] || log "⚠️  Token no exportado; luego edita $ENV_FILE"
  log "📝 Generando $ENV_FILE"
  cat >"$ENV_FILE" <<EOF
CF_API_TOKEN=$CF_API_TOKEN
ZONE_NAME=$DEFAULT_ZONE
RECORD_NAMES=$DEFAULT_RECORDS
EOF
  chmod 600 "$ENV_FILE"
fi

log "📄 Verificando log → $LOG_FILE"
install -Dm640 /dev/null "$LOG_FILE"

###############################################################################
# ░░ 7. Recargar systemd y habilitar ░░
###############################################################################
log "🔄 Recargando systemd"
systemctl daemon-reload

log "⏱️ Habilitando y arrancando temporizador"
systemctl enable --now cloudflare-ddns.timer

###############################################################################
# ░░ 8. Ejecutar primer actualización manualmente ░░
###############################################################################
log "📡 Ejecutando actualización inicial manualmente…"
if "$BIN_DST"; then
  log "✅ Actualización inicial completada"
else
  log "⚠️  Error durante la actualización inicial. Revisa el log: $LOG_FILE"
fi

###############################################################################
# ░░ 9. Resumen final ░░
###############################################################################
log "✅ Instalación completada"

cat <<EOF

Credenciales   : $ENV_FILE
Log del script : $LOG_FILE

Comandos útiles
───────────────

sudo systemctl status cloudflare-ddns.service
sudo journalctl -u cloudflare-ddns.service -n 50 --no-pager
sudo systemctl list-timers --all | grep cloudflare

sudo systemctl status cloudflare-ddns.timer
sudo systemctl status cloudflare-ddns.service

EOF

exit 0
###############################################################################
# ░░ Fin del script ░░
###############################################################################