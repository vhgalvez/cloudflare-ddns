#!/usr/bin/env bash
# uninstall.sh — Desinstalador seguro de Cloudflare-DDNS
# Autor: @vhgalvez ─ Licencia MIT

set -euo pipefail
IFS=$'\n\t'

###############################################################################
# 1. Elevar privilegios si no somos root
###############################################################################
if [[ $EUID -ne 0 ]]; then
  exec sudo -E bash "$0" "$@"       # heredamos vars + args
fi

###############################################################################
# 2. Rutas controladas
###############################################################################
readonly SCRIPT_FILE="/usr/local/bin/update_cloudflare_ip.sh"

readonly ENV_DIR="/etc/cloudflare-ddns"
readonly ENV_FILE="$ENV_DIR/.env"

readonly LOG_FILE="/var/log/cloudflare-ddns.log"

readonly SERVICE_FILE="/etc/systemd/system/cloudflare-ddns.service"
readonly TIMER_FILE="/etc/systemd/system/cloudflare-ddns.timer"
readonly TIMER_WANTS_LINK="/etc/systemd/system/timers.target.wants/cloudflare-ddns.timer"

###############################################################################
# 3. Utilidades
###############################################################################
log() { printf '[%(%F %T)T] %b\n' -1 "$*"; }

# Acepta tanto prefijo con / final como sin él
validate_path() {
  local path=$1
  local prefix=${2%/}          # quitamos / final si existe
  if [[ "${path}" != "$prefix"* ]]; then
    log "❌ ERROR: Ruta fuera de ubicación segura → $path  (esperada bajo $prefix)"
    exit 1
  fi
}

safe_rm() {            # $1 -> archivo,  $2 -> prefijo permitido
  local file=$1;  local pref=$2
  validate_path "$file" "$pref"
  [[ -e $file ]] && { log "🗑️  Eliminando $file"; rm -f -- "$file"; }
}

###############################################################################
# 4. Desinstalación
###############################################################################
main() {
  log "🧹 Iniciando desinstalación de Cloudflare-DDNS…"

  # 4.1 Parar/Deshabilitar unidades (ignorar errores si ya no existen)
  log "⛔ Deteniendo unidades systemd…"
  systemctl disable --now cloudflare-ddns.timer  >/dev/null 2>&1 || true
  systemctl stop    cloudflare-ddns.service      >/dev/null 2>&1 || true

  # 4.2 Borrar archivos
  safe_rm "$SCRIPT_FILE"   "/usr/local/bin"
  safe_rm "$ENV_FILE"      "$ENV_DIR"
  safe_rm "$LOG_FILE"      "/var/log"
  safe_rm "$SERVICE_FILE"  "/etc/systemd/system"
  safe_rm "$TIMER_FILE"    "/etc/systemd/system"
  safe_rm "$TIMER_WANTS_LINK" "/etc/systemd/system/timers.target.wants"

  # 4.3 Eliminar directorio de configuración si quedó vacío
  if [[ -d $ENV_DIR && -z $(ls -A "$ENV_DIR") ]]; then
    log "📁 Eliminando directorio vacío $ENV_DIR"
    rmdir --ignore-fail-on-non-empty "$ENV_DIR"
  fi

  # 4.4 Recargar systemd
  log "🔄 Recargando daemon systemd…"
  systemctl daemon-reload
  systemctl reset-failed cloudflare-ddns.service >/dev/null 2>&1 || true

  log "✅ Cloudflare-DDNS desinstalado con éxito."
}

main "$@"
exit 0