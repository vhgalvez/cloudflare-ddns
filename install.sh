#!/usr/bin/env bash
#
# install.sh – Instalador / configurador de Cloudflare-DDNS con systemd
# Probado en Fedora / RHEL / Rocky / Alma Linux, Debian / Ubuntu y derivados.
# ------------------------------------------------------------------------------

set -euo pipefail
IFS=$'\n\t'

# ========= VARIABLES GLOBALES ==================================================
readonly SCRIPT_SRC="update_cloudflare_ip.sh"
readonly SCRIPT_DEST="/usr/local/bin/update_cloudflare_ip.sh"

readonly ENV_DIR="/etc/cloudflare-ddns"
readonly ENV_FILE="$ENV_DIR/.env"
readonly LOG_FILE="/var/log/cloudflare-ddns.log"

readonly SERVICE_SRC="cloudflare-ddns.service"
readonly TIMER_SRC="cloudflare-ddns.timer"
readonly SERVICE_FILE="/etc/systemd/system/cloudflare-ddns.service"
readonly TIMER_FILE="/etc/systemd/system/cloudflare-ddns.timer"

# Comando sudo (vacío si ya somos root)
SUDO=''
if [[ $EUID -ne 0 ]]; then
  if ! command -v sudo &>/dev/null; then
    echo "❌ Este instalador requiere sudo o ejecutarse como root." >&2
    exit 1
  fi
  SUDO='sudo'
fi

# ========= FUNCIONES AUXILIARES ===============================================
log() {  printf '[%(%F %T)T] %b\n' -1 "$*"; }

install_pkg() {
  local pkg=$1
  if ! command -v "$pkg" &>/dev/null; then
    log "📥 Instalando dependencias ($pkg)…"
    if   command -v dnf  &>/dev/null; then $SUDO dnf  -y install "$pkg"
    elif command -v yum  &>/dev/null; then $SUDO yum  -y install "$pkg"
    elif command -v apt  &>/dev/null; then $SUDO apt-get -y install "$pkg"
    else
      log "❌ Gestor de paquetes no soportado"; exit 1
    fi
  fi
}

validate_sources() {
  log "🔍 Verificando archivos locales…"
  for f in "$SCRIPT_SRC" "$SERVICE_SRC" "$TIMER_SRC"; do
    [[ -f $f ]] || { log "❌ Falta el archivo $f"; exit 1; }
  done
}

copy_script() {
  log "🚀 Copiando $SCRIPT_SRC → $SCRIPT_DEST"
  $SUDO install -Dm750 "$SCRIPT_SRC" "$SCRIPT_DEST"
}

prepare_env() {
  log "📂 Creando directorio de configuración $ENV_DIR"
  $SUDO install -d -m 700 "$ENV_DIR"

  if [[ ! -f $ENV_FILE ]]; then
    log "📝 Generando $ENV_FILE (edítalo después)…"
    $SUDO tee "$ENV_FILE" >/dev/null <<EOF
CF_API_TOKEN=
ZONE_NAME=socialdevs.site
RECORD_NAMES=socialdevs.site,public.socialdevs.site
EOF
    $SUDO chmod 600 "$ENV_FILE"
  fi
}

prepare_log() {
  log "📄 Creando log $LOG_FILE"
  $SUDO install -Dm644 /dev/null "$LOG_FILE"
}

install_units() {
  log "⚙️  Instalando unidades systemd…"
  $SUDO install -Dm644 "$SERVICE_SRC" "$SERVICE_FILE"
  $SUDO install -Dm644 "$TIMER_SRC"   "$TIMER_FILE"
}

enable_systemd() {
  log "🔄 Recargando systemd y habilitando timer…"
  $SUDO systemctl daemon-reload
  $SUDO systemctl enable --now cloudflare-ddns.timer
}

# ========= MAIN ===============================================================
main() {
  # 1. Dependencias básicas
  for bin in curl jq; do install_pkg "$bin"; done

  # 2. Archivos presentes
  validate_sources

  # 3. Copiar recursos al sistema
  copy_script
  prepare_env
  prepare_log
  install_units

  # 4. Activar servicio
  enable_systemd

  # 5. Mensaje final
  log "✅ Instalación completada con éxito."
  cat <<EOF

👉  Edita tus credenciales:
    $SUDO nano $ENV_FILE

🧪 Verifica el temporizador:
    systemctl status cloudflare-ddns.timer

📊 Revisa los logs:
    journalctl -u cloudflare-ddns.service -n 50 --no-pager
    tail -f $LOG_FILE
EOF
}

main "$@"