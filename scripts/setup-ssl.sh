#!/bin/bash
# =====================================================
# ShowOn SSL Setup Helper
# Author: TspKchn
# =====================================================
set -euo pipefail

CONF="/etc/showon.conf"
source "$CONF"

NGINX_CONF="/etc/nginx/sites-available/showon"
NGINX_LINK="/etc/nginx/sites-enabled/showon"

CERT_DIR="/etc/ssl/showon"
CERT_FILE="$CERT_DIR/fullchain.pem"
KEY_FILE="$CERT_DIR/privkey.pem"

log() { echo "[$(date '+%F %T')][SSL] $*" >> "$DEBUG_LOG"; }

mkdir -p "$CERT_DIR"

# === ค้นหาไฟล์ SSL เดิม ===
FOUND_CERT=""
FOUND_KEY=""

for p in \
  "/root/cert/$HOSTNAME/fullchain.pem:/root/cert/$HOSTNAME/privkey.pem" \
  "/root/cert/${PANEL_URL#*://}/fullchain.pem:/root/cert/${PANEL_URL#*://}/privkey.pem" \
  "/etc/letsencrypt/live/$HOSTNAME/fullchain.pem:/etc/letsencrypt/live/$HOSTNAME/privkey.pem" \
  "/etc/x-ui/server.crt:/etc/x-ui/server.key" \
  "/etc/v2ray/server.crt:/etc/v2ray/server.key"
do
  c="${p%%:*}"
  k="${p##*:}"
  if [[ -f "$c" && -f "$k" ]]; then
    FOUND_CERT="$c"
    FOUND_KEY="$k"
    break
  fi
done

if [[ -n "$FOUND_CERT" && -n "$FOUND_KEY" ]]; then
  cp -f "$FOUND_CERT" "$CERT_FILE"
  cp -f "$FOUND_KEY" "$KEY_FILE"
  log "[OK] ตรวจพบ SSL เดิมที่ $(dirname "$FOUND_CERT") → ใช้งานต่อ"
  echo -e "\e[32m[OK]\e[0m ตรวจพบ SSL เดิมที่ $(dirname "$FOUND_CERT") → ใช้งานต่อ"
else
  log "[WARN] ไม่พบไฟล์ SSL เดิม จะใช้ self-signed cert แทน"
  echo -e "\e[33m[WARN]\e[0m ไม่พบไฟล์ SSL เดิม จะใช้ self-signed cert แทน"

  openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
    -subj "/CN=${HOSTNAME}" \
    -keyout "$KEY_FILE" \
    -out "$CERT_FILE" >/dev/null 2>&1
fi

# === เขียน nginx conf ===
cat >"$NGINX_CONF" <<EOF
# HTTP
server {
    listen 82 default_server;
    server_name _;

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

# HTTPS
server {
    listen 82 ssl;
    server_name ${PANEL_URL#*://};

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

ln -sf "$NGINX_CONF" "$NGINX_LINK"

if nginx -t; then
  systemctl reload nginx
  log "[OK] SSL nginx config applied"
  echo -e "\e[32m[OK]\e[0m SSL nginx config applied"
else
  log "[ERROR] nginx config test failed (SSL)"
  echo -e "\e[31m[ERROR]\e[0m nginx config test failed (SSL)"
  exit 1
fi
