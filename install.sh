#!/usr/bin/env bash
#
# install.sh – Instalador de Cloudflare-DDNS con systemd
# Compatible con Fedora / RHEL / Rocky / Alma, Debian / Ubuntu y derivados
# -----------------------------------------------------------------------------

set -euo pipefail
IFS=$'\n\t'

# ────────────── RUTAS ────────────────────────────────────────────────────────
readonly SCRIPT_SRC="update_cloudflare_ip.sh"
readonly SCRIPT_DEST="/usr/local/bin/update_cloudflare_ip.sh"

readonly ENV_DIR="/etc/cloudflare-ddns"
readonly ENV_FILE="$ENV_DIR/.env"
readonly LOG_FILE="/var/log/cloudflare-ddns.log"

readonly SERVICE_SRC="cloudflare-ddns.service"
readonly TIMER_SRC="cloudflare-ddns.timer"
readonly SERVICE_DEST="/etc/systemd/system/cloudflare-ddns.service"
readonly TIMER_DEST="/etc/systemd/system/cloudflare-ddns.timer"

# ────────────── UTILIDADES ───────────────────────────────────────────────────
SUDO=''                   # Añadimos sudo solo si no somos root
if [[ $EUID -ne 0 ]]; then
    command -v sudo   >/dev/null || { echo "❌ Se necesita sudo"; exit 1; }
    SUDO='sudo'
fi

log() { printf '[%(%F %T)T] %b\n' -1 "$*"; }

install_pkg() {
    local pkg=$1
    command -v "$pkg" &>/dev/null && return   # ya instalado
    log "📥 Instalando dependencia: $pkg …"
    if   command -v dnf  &>/dev/null; then $SUDO dnf  -y install "$pkg"
        elif command -v yum  &>/dev/null; then $SUDO yum  -y install "$pkg"
        elif command -v apt  &>/dev/null; then $SUDO apt -y  install "$pkg"
        elif command -v apt-get &>/dev/null; then $SUDO apt-get -y install "$pkg"
    else
        log "❌ No se detectó un gestor de paquetes soportado"; exit 1
    fi
}

# ────────────── PASO 1 – Verificar fuentes ───────────────────────────────────
validate_sources() {
    log "🔍 Verificando archivos locales…"
    for f in "$SCRIPT_SRC" "$SERVICE_SRC" "$TIMER_SRC"; do
        [[ -f $f ]] || { log "❌ Falta el archivo $f"; exit 1; }
    done
}

# ────────────── PASO 2 – Copiar script ───────────────────────────────────────
copy_script() {
    log "🚀 Copiando $SCRIPT_SRC → $SCRIPT_DEST"
    $SUDO install -Dm750 "$SCRIPT_SRC" "$SCRIPT_DEST"
}

# ────────────── PASO 3 – Preparar .env ───────────────────────────────────────
prepare_env() {
    log "📂 Creando directorio $ENV_DIR"
    $SUDO install -d -m 700 "$ENV_DIR"
    
    if [[ ! -f $ENV_FILE ]]; then
        log "📝 Generando $ENV_FILE (recuerda editarlo)…"
    $SUDO tee "$ENV_FILE" >/dev/null <<EOF
CF_API_TOKEN=
ZONE_NAME=socialdevs.site
RECORD_NAMES=socialdevs.site,public.socialdevs.site
EOF
        $SUDO chmod 600 "$ENV_FILE"
    fi
}

# ────────────── PASO 4 – Preparar log ────────────────────────────────────────
prepare_log() {
    log "📄 Creando log $LOG_FILE"
    $SUDO install -Dm644 /dev/null "$LOG_FILE"
}

# ────────────── PASO 5 – Instalar unidades systemd ───────────────────────────
install_units() {
    log "⚙️  Instalando unidades systemd…"
    $SUDO install -Dm644 "$SERVICE_SRC" "$SERVICE_DEST"
    $SUDO install -Dm644 "$TIMER_SRC"   "$TIMER_DEST"
}

# ────────────── PASO 6 – Recargar y habilitar ────────────────────────────────
enable_systemd() {
    log "🔄 Recargando systemd y habilitando timer…"
    $SUDO systemctl daemon-reload
    $SUDO systemctl enable --now cloudflare-ddns.timer
}

# ────────────── MAIN ─────────────────────────────────────────────────────────
main() {
    for pkg in curl jq; do install_pkg "$pkg"; done
    validate_sources
    copy_script
    prepare_env
    prepare_log
    install_units
    enable_systemd
    
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