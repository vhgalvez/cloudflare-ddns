#!/usr/bin/env bash
# install.sh – Cloudflare-DDNS + systemd (distros RPM/Deb)

set -euo pipefail
IFS=$'\n\t'

# ─────────── 1. Elevar privilegios una sola vez ────────────
if [[ $EUID -ne 0 ]]; then
  exec sudo -E bash "$0" "$@"        # heredamos variables/args
fi

# ─────────── 2. Rutas de trabajo ───────────────────────────
SCRIPT_SRC="update_cloudflare_ip.sh"
SCRIPT_DEST="/usr/local/bin/update_cloudflare_ip.sh"

ENV_DIR="/etc/cloudflare-ddns"
ENV_FILE="$ENV_DIR/.env"
LOG_FILE="/var/log/cloudflare_ddns.log"

SERVICE_SRC="cloudflare-ddns.service"
TIMER_SRC="cloudflare-ddns.timer"
SERVICE_DEST="/etc/systemd/system/cloudflare-ddns.service"
TIMER_DEST="/etc/systemd/system/cloudflare-ddns.timer"

log(){ printf '[%(%F %T)T] %b\n' -1 "$*"; }

# ─────────── 3. Dependencias mínimas ───────────────────────
install_pkg(){
  local p=$1
  command -v "$p" &>/dev/null && return
  log "📦 Instalando $p …"
  if   command -v dnf &>/dev/null;      then dnf  -y install "$p"
  elif command -v yum &>/dev/null;      then yum  -y install "$p"
  elif command -v apt-get &>/dev/null;  then apt-get -y install "$p"
  else log "❌ Gestor de paquetes no soportado"; exit 1; fi
}

for bin in curl jq; do install_pkg "$bin"; done

# ─────────── 4. Ficheros fuente presentes ──────────────────
for f in "$SCRIPT_SRC" "$SERVICE_SRC" "$TIMER_SRC"; do
  [[ -f $f ]] || { log "❌ Falta $f"; exit 1; }
done

# ─────────── 5. Instalar binario & config ──────────────────
install -Dm750 "$SCRIPT_SRC"  "$SCRIPT_DEST"

install -d  -m700 "$ENV_DIR"
if [[ ! -f $ENV_FILE ]]; then
  log "📝 Creando $ENV_FILE (edítalo)…"
  cat >"$ENV_FILE" <<EOF
CF_API_TOKEN=
ZONE_NAME=socialdevs.site
RECORD_NAMES=socialdevs.site,public.socialdevs.site
EOF
  chmod 600 "$ENV_FILE"
fi

install -Dm644 /dev/null "$LOG_FILE"

# ─────────── 6. Unidades systemd ───────────────────────────
install -Dm644 "$SERVICE_SRC" "$SERVICE_DEST"
install -Dm644 "$TIMER_SRC"   "$TIMER_DEST"

# Verificación post-copia
for f in "$SERVICE_DEST" "$TIMER_DEST"; do
  [[ -f $f ]] || { log "❌ No se pudo copiar $f"; exit 1; }
done

systemctl daemon-reload
systemctl enable --now cloudflare-ddns.timer

log "✅ Instalación completada."

cat <<EOF

👉  Edita tus credenciales:
   nano $ENV_FILE

🧪 Comprueba:
   systemctl status cloudflare-ddns.timer
   systemctl status cloudflare-ddns.service

📊 Logs:
   journalctl -u cloudflare-ddns.service -n 50 --no-pager
   tail -f $LOG_FILE
EOF