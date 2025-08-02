#!/usr/bin/env bash
#
# uninstall.sh — Desinstala Cloudflare-DDNS de forma segura
# Autor:  @vhgalvez
# -----------------------------------------------------------------------------

set -euo pipefail
IFS=$'\n\t'

# ========= RUTAS PROTEGIDAS ===================================================
readonly SCRIPT_FILE="/usr/local/bin/update_cloudflare_ip.sh"
readonly ENV_DIR="/etc/cloudflare-ddns"
readonly ENV_FILE="$ENV_DIR/.env"
readonly LOG_FILE="/var/log/cloudflare-ddns.log"
readonly SERVICE_FILE="/etc/systemd/system/cloudflare-ddns.service"
readonly TIMER_FILE="/etc/systemd/system/cloudflare-ddns.timer"

# ========= HELPERS ============================================================
log() { printf '[%(%F %T)T] %b\n' -1 "$*"; }

need_root() {
  if [[ $EUID -ne 0 ]]; then
    log "❌ Este script debe ejecutarse como root (o con sudo)."
    exit 1
  fi
}

# Acepta coincidencia exacta o que empiece por el prefijo
validate_path() {
  local p="$1" pref="$2"
  [[ "$p" == "$pref"* ]] || { log "❌ Ruta fuera de ubicación segura: $p (esperado prefijo: $pref)"; exit 1; }
}

safe_rm() {
  local file="$1" safe_prefix="$2"
  validate_path "$file" "$safe_prefix"
  [[ -e $file ]] && { log "🗑️  Eliminando $file"; rm -f "$file"; }
}

safe_rmdir() {
  local dir="$1" safe_prefix="$2"
  validate_path "$dir" "$safe_prefix"
  if [[ -d $dir ]]; then
    if rmdir "$dir" 2>/dev/null; then
      log "📁 Directorio eliminado: $dir"
    else
      log "ℹ️  $dir no está vacío; conserva contenido del usuario."
    fi
  fi
}

stop_units() {
  log "⛔ Deteniendo servicio/temporizador (si existen)…"
  systemctl disable --now cloudflare-ddns.timer 2>/dev/null || true
  systemctl disable --now cloudflare-ddns.service 2>/dev/null || true
  systemctl reset-failed cloudflare-ddns.{service,timer} 2>/dev/null || true
}

reload_systemd() {
  log "🔄 Recargando configuración de systemd…"
  systemctl daemon-reload
}

# ========= MAIN ==============================================================
main() {
  need_root
  log "🧹 Comenzando desinstalación de Cloudflare-DDNS…"

  stop_units

  safe_rm   "$SCRIPT_FILE"  "/usr/local/bin/"
  safe_rm   "$ENV_FILE"     "$ENV_DIR/"
  safe_rm   "$LOG_FILE"     "/var/log/"
  safe_rm   "$SERVICE_FILE" "/etc/systemd/system/"
  safe_rm   "$TIMER_FILE"   "/etc/systemd/system/"
  safe_rmdir "$ENV_DIR"     "/etc/cloudflare-ddns"

  reload_systemd
  log "✅ Cloudflare-DDNS eliminado con éxito."
}

main "$@"