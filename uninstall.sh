#!/usr/bin/env bash
# uninstall.sh — Desinstalador seguro de Cloudflare-DDNS
# Autor: @vhgalvez — Licencia MIT

set -euo pipefail
IFS=$'\n\t'

# Escalada de privilegios
[[ $EUID -eq 0 ]] || exec sudo -E bash "$0" "$@"

# Rutas instaladas
readonly SCRIPT_FILE="/usr/local/bin/update_cloudflare_ip.sh"
readonly ENV_DIR="/etc/cloudflare-ddns"
readonly ENV_FILE="$ENV_DIR/.env"
readonly LOG_FILE="/var/log/cloudflare-ddns.log"
readonly SERVICE_FILE="/etc/systemd/system/cloudflare-ddns.service"
readonly TIMER_FILE="/etc/systemd/system/cloudflare-ddns.timer"

# Rutas generadas desde el instalador, por si se dejaron en el directorio original
readonly INSTALL_DIR="$(cd -- "$(dirname "$0")" && pwd)"
readonly SRC_SERVICE="$INSTALL_DIR/cloudflare-ddns.service"
readonly SRC_TIMER="$INSTALL_DIR/cloudflare-ddns.timer"

log() {
  [[ "${QUIET:-0}" == "1" ]] && return
  printf '[%(%F %T)T] %b\n' -1 "$*"
}

validate_path() {
  local path="$1"; local prefix="${2%/}"
  [[ "$path" == "$prefix"* ]] || {
    log "❌ Ruta fuera de ubicación segura → $path (esperado bajo $prefix)"
    exit 1
  }
}

safe_rm() {
  local file="$1"; local prefix="$2"
  validate_path "$file" "$prefix"
  [[ -e $file ]] && { log "🗑️  Eliminando $file"; rm -f -- "$file"; }
}

main() {
  log "🧹 Iniciando desinstalación de Cloudflare-DDNS…"

  log "⛔ Deteniendo unidades systemd…"
  systemctl disable --now cloudflare-ddns.timer >/dev/null 2>&1 || true
  systemctl stop cloudflare-ddns.service       >/dev/null 2>&1 || true

  # Archivos instalados
  safe_rm "$SCRIPT_FILE" "/usr/local/bin"
  safe_rm "$ENV_FILE" "$ENV_DIR"
  safe_rm "$LOG_FILE" "/var/log"
  safe_rm "$SERVICE_FILE" "/etc/systemd/system"
  safe_rm "$TIMER_FILE" "/etc/systemd/system"

  # Symlinks del timer
  find /etc/systemd/system/timers.target.wants -type l -name 'cloudflare-ddns.timer' -exec rm -f {} \;

  # Archivos fuente generados por el instalador (si existen)
  safe_rm "$SRC_SERVICE" "$INSTALL_DIR"
  safe_rm "$SRC_TIMER" "$INSTALL_DIR"

  [[ -d "$ENV_DIR" && -z "$(ls -A "$ENV_DIR")" ]] && {
    log "📁 Eliminando directorio vacío $ENV_DIR"
    rmdir --ignore-fail-on-non-empty "$ENV_DIR"
  }

  log "🔄 Recargando systemd…"
  systemctl daemon-reload
  systemctl reset-failed cloudflare-ddns.service >/dev/null 2>&1 || true

  log "✅ Cloudflare-DDNS desinstalado con éxito."
}

# Soporte modo silencioso
for arg in "$@"; do
  [[ "$arg" == "-q" || "$arg" == "--quiet" ]] && QUIET=1
done

main "$@"
exit 0