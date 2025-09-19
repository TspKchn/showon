#!/bin/bash
# =====================================================
# setup-ssl.sh - SSL/HTTPS Config for ShowOn
# Author: TspKchn
# =====================================================

set -euo pipefail

CONF="/etc/showon.conf"
DEBUG_LOG="/var/log/showon-debug.log"

SSL_DIR="/etc/nginx/ssl"
SSL_CERT="$SSL_DIR/fullchain.pem"
SSL_KEY="$SSL_DIR/privkey.pem"
SITE_AV="/etc/nginx/sites-available/showon"
SITE_EN="/etc/nginx/sites-enabled/showon"

log() { echo "[$(date '+%F %T')][SSL] $*" | tee -a "$DEBUG_LOG"; }

# โหลด config เดิม
if [[ -f "$CONF" ]]; then
  source "$CONF"
else
  log "[ERROR] Config file $CONF not found!"
  exit 1
fi

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
  mkdir -p "$SSL_DIR"
  cp "$CERT_PATH" "$SSL_CERT"
  cp "$KEY_PATH" "$SSL_KEY"
  log "[OK] ตรวจพบ SSL เดิมที่ $(dirname "$CERT_PATH") → ใช้งานต่อ"
else
  log "[WARN] ไม่พบไฟล์ SSL เดิม จะใช้ self-signed cert แทน"
  mkdir -p "$SSL_DIR"
  openssl req -x509 -nodes -newkey rsa:2048 \
    -keyout "$SSL_KEY" -out "$SSL_CERT" \
    -days 365 \
    -subj "/CN=$(hostname -f)" >/dev/null 2>&1
  log "[OK] Self-signed cert created at $SSL_DIR"
fi

# ================== เขียน config nginx ใหม่ ==================
cat >"$SITE_AV" <<EOF
server {
    listen 82 ssl http2;
    server_name _;

    ssl_certificate     $SSL_CERT;
    ssl_certificate_key $SSL_KEY;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    location = / {
        return 302 /server/;
    }
    location /server/ {
        alias $WWW_DIR/;
        index index.html;
        autoindex off;
        add_header Cache-Control "no-store";
    }
}
EOF

ln -sf "$SITE_AV" "$SITE_EN"

# ================== Reload nginx ==================
if nginx -t; then
  systemctl reload nginx || systemctl restart nginx || true
  log "[OK] Nginx SSL enabled on :82 (HTTP+HTTPS)"
else
  log "[ERROR] nginx config test failed (SSL)"
  exit 1
fi
