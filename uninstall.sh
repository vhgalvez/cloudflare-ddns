#!/usr/bin/env bash
# uninstall.sh — Desinstalador seguro de Cloudflare-DDNS
# Autor: @vhgalvez — Licencia MIT
# Compatible con Fedora / RHEL / Rocky / Alma / Debian / Ubuntu

set -euo pipefail
IFS=$'\n\t'

###############################################################################
# ░░ 1. Escalada de privilegios ░░
###############################################################################
if [[ $EUID -ne 0 ]]; then
  exec sudo -E bash "$0" "$@"
fi

###############################################################################
# ░░ 2. Variables y rutas controladas ░░
###############################################################################
readonly SCRIPT_FILE="/usr/local/bin/update_cloudflare_ip.sh"
readonly ENV_DIR="/etc/cloudflare-ddns"
readonly ENV_FILE="$ENV_DIR/.env"
readonly LOG_FILE="/var/log/cloudflare-ddns.log"
readonly SERVICE_FILE="/etc/systemd/system/cloudflare-ddns.service"
readonly TIMER_FILE="/etc/systemd/system/cloudflare-ddns.timer"
readonly TIMER_WANTS_LINK="/etc/systemd/system/timers.target.wants/cloudflare-ddns.timer"

###############################################################################
# ░░ 3. Utilidades seguras ░░
###############################################################################
log() {
  [[ "${QUIET:-0}" == "1" ]] && return
  printf '[%(%F %T)T] %b\n' -1 "$*"
}

# Validar que los archivos están dentro del prefijo permitido
validate_path() {
  local path="$1"; local prefix="${2%/}"  # sin / final
  if [[ "$path" != "$prefix"* ]]; then
    log "❌ ERROR: Ruta fuera de ubicación segura → $path (esperado bajo $prefix)"
    exit 1
  fi
}

# Eliminación segura
safe_rm() {
  local file="$1"; local prefix="$2"
  validate_path "$file" "$prefix"
  if [[ -e $file ]]; then
    log "🗑️  Eliminando $file"
    rm -f -- "$file"
  fi
}

###############################################################################
# ░░ 4. Desinstalación ░░
###############################################################################
main() {
  log "🧹 Iniciando desinstalación de Cloudflare-DDNS…"

  # Detener y deshabilitar unidades systemd
  log "⛔ Deteniendo unidades systemd…"
  systemctl disable --now cloudflare-ddns.timer >/dev/null 2>&1 || true
  systemctl stop cloudflare-ddns.service >/dev/null 2>&1 || true

  # Archivos a eliminar
  safe_rm "$SCRIPT_FILE" "/usr/local/bin"
  safe_rm "$ENV_FILE" "$ENV_DIR"
  safe_rm "$LOG_FILE" "/var/log"
  safe_rm "$SERVICE_FILE" "/etc/systemd/system"
  safe_rm "$TIMER_FILE" "/etc/systemd/system"
  safe_rm "$TIMER_WANTS_LINK" "/etc/systemd/system/timers.target.wants"

  # Eliminar directorio de configuración si está vacío
  if [[ -d "$ENV_DIR" && -z $(ls -A "$ENV_DIR") ]]; then
    log "📁 Eliminando directorio vacío $ENV_DIR"
    rmdir --ignore-fail-on-non-empty "$ENV_DIR"
  fi

  # Recargar y limpiar systemd
  log "🔄 Recargando daemon systemd…"
  systemctl daemon-reexec
  systemctl daemon-reload
  systemctl reset-failed cloudflare-ddns.service >/dev/null 2>&1 || true

  log "✅ Cloudflare-DDNS desinstalado con éxito."
}

###############################################################################
# ░░ 5. Soporte modo silencioso (opcional) ░░
###############################################################################
for arg in "$@"; do
  [[ "$arg" == "-q" || "$arg" == "--quiet" ]] && QUIET=1
done

main "$@"
exit 0