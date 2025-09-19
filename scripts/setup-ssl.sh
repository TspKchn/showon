#!/bin/bash
# =====================================================
# setup-ssl.sh - Auto SSL Setup for ShowOn
# Version: 1.0.6
# Author: TspKchn
# =====================================================

set -euo pipefail
CONF="/etc/showon.conf"
source "$CONF"

SSL_DIR="/etc/ssl/showon"
DOMAIN=""
CERT_FILE="$SSL_DIR/fullchain.pem"
KEY_FILE="$SSL_DIR/privkey.pem"

log() {
  echo "[$(date '+%F %T')][SSL] $*" | tee -a "$DEBUG_LOG"
}

mkdir -p "$SSL_DIR"

# --- Detect domain from PANEL_URL or fallback to IP ---
if [[ -n "${PANEL_URL:-}" ]]; then
  DOMAIN=$(echo "$PANEL_URL" | sed -E 's#^https?://([^:/]+).*#\1#')
else
  DOMAIN=$(hostname -I | awk '{print $1}')
fi

# --- Common existing cert locations to scan ---
SEARCH_PATHS=(
  "/etc/letsencrypt/live/$DOMAIN"
  "/root/cert/$DOMAIN"
  "/etc/x-ui/cert"
  "/etc/nginx/ssl/$DOMAIN"
)

FOUND_CERT=""
FOUND_KEY=""

for path in "${SEARCH_PATHS[@]}"; do
  if [[ -f "$path/fullchain.pem" && -f "$path/privkey.pem" ]]; then
    FOUND_CERT="$path/fullchain.pem"
    FOUND_KEY="$path/privkey.pem"
    break
  fi
done

# --- If existing cert found, reuse ---
if [[ -n "$FOUND_CERT" && -n "$FOUND_KEY" ]]; then
  cp "$FOUND_CERT" "$CERT_FILE"
  cp "$FOUND_KEY" "$KEY_FILE"
  log "[OK] ตรวจพบ SSL เดิมที่ $FOUND_CERT → ใช้งานต่อ"
else
  # --- Try to install certbot if not exist ---
  if ! command -v certbot >/dev/null 2>&1; then
    log "[INFO] Installing certbot..."
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y certbot >/dev/null 2>&1 || true
  fi

  if command -v certbot >/dev/null 2>&1; then
    log "[INFO] Requesting Let's Encrypt certificate for $DOMAIN"
    if certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos -m admin@$DOMAIN; then
      cp "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "$CERT_FILE"
      cp "/etc/letsencrypt/live/$DOMAIN/privkey.pem" "$KEY_FILE"
      log "[OK] SSL certificate issued for $DOMAIN"
    else
      log "[WARN] ไม่สามารถออก SSL Certificate ได้ → ใช้ HTTP เท่านั้น"
      exit 0
    fi
  else
    log "[WARN] certbot ไม่พร้อมใช้งาน → ใช้ HTTP เท่านั้น"
    exit 0
  fi
fi

# --- Write nginx config with both HTTP/HTTPS ---
NGINX_CONF="/etc/nginx/sites-available/showon"

cat >"$NGINX_CONF" <<EOF
server {
    listen 82 default_server;
    listen 82 ssl;
    server_name $DOMAIN;

    ssl_certificate     $CERT_FILE;
    ssl_certificate_key $KEY_FILE;

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

ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/showon

if nginx -t; then
  systemctl reload nginx || systemctl restart nginx
  log "[OK] Nginx reloaded with SSL for $DOMAIN"
else
  log "[ERROR] nginx config test failed (SSL)"
  exit 1
fi
