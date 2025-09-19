#!/bin/bash
# =====================================================
# setup-ssl.sh - SSL Certificate Manager for ShowOn
# Author: TspKchn
# =====================================================

set -euo pipefail

CONF="/etc/showon.conf"
DEBUG_LOG="/var/log/showon-debug.log"

SSL_DIR="/etc/ssl/showon"
SSL_CERT="$SSL_DIR/fullchain.pem"
SSL_KEY="$SSL_DIR/privkey.pem"

log() { echo "[$(date '+%F %T')][SSL] $*" | tee -a "$DEBUG_LOG"; }

# โหลด config เดิม
if [[ -f "$CONF" ]]; then
  source "$CONF"
else
  log "[ERROR] Config file $CONF not found!"
  exit 1
fi

mkdir -p "$SSL_DIR"

# ================== ค้นหา cert ที่มีอยู่แล้ว ==================
find_existing_cert() {
  local base_dirs=(
    "/etc/letsencrypt/live"
    "/root/cert"
    "/etc/x-ui"
    "/etc/nginx/ssl"
  )

  for base in "${base_dirs[@]}"; do
    if [[ -d "$base" ]]; then
      pem=$(find "$base" -type f -name "fullchain.pem" | head -n1 || true)
      key=$(find "$base" -type f -name "privkey.pem" | head -n1 || true)
      if [[ -n "$pem" && -n "$key" ]]; then
        echo "$pem|$key"
        return 0
      fi
    fi
  done
  return 1
}

CERT_FOUND=$(find_existing_cert || true)
if [[ -n "$CERT_FOUND" ]]; then
  CERT_PATH=$(echo "$CERT_FOUND" | cut -d'|' -f1)
  KEY_PATH=$(echo "$CERT_FOUND" | cut -d'|' -f2)
  cp "$CERT_PATH" "$SSL_CERT"
  cp "$KEY_PATH" "$SSL_KEY"
  log "[OK] ตรวจพบ SSL เดิมที่ $(dirname "$CERT_PATH") → ใช้งานต่อ"
else
  log "[WARN] ไม่พบไฟล์ SSL เดิม จะใช้ self-signed cert แทน"
  openssl req -x509 -nodes -newkey rsa:2048 \
    -keyout "$SSL_KEY" -out "$SSL_CERT" \
    -days 365 \
    -subj "/CN=$(hostname -f)" >/dev/null 2>&1
  log "[OK] Self-signed cert created at $SSL_DIR"
fi
