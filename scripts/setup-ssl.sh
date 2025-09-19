#!/bin/bash
# =====================================================
# ShowOn SSL Setup Helper (Fixed v3)
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

# === หาไฟล์ SSL เดิม ===
FOUND_CERT=""
FOUND_KEY=""

SEARCH_PATHS=(
  "/root/cert/bm.xq-vpn.com/fullchain.pem:/root/cert/bm.xq-vpn.com/privkey.pem"
  "/etc/letsencrypt/live/bm.xq-vpn.com/fullchain.pem:/etc/letsencrypt/live/bm.xq-vpn.com/privkey.pem"
  "/etc/x-ui/server.crt:/etc/x-ui/server.key"
  "/etc/v2ray/server.crt:/etc/v2ray/server.key"
)

for p in "${SEARCH_PATHS[@]}"; do
  c="${p%%:*}"
  k="${p##*:}"
  if [[ -s "$c" && -s "$k" ]]; then
    FOUND_CERT="$c"
    FOUND_KEY="$k"
    break
  fi
done

# === ถ้าพบ ใช้ไฟล์นั้น ===
if [[ -n "$FOUND_CERT" && -n "$FOUND_KEY" ]]; then
  cp -f "$FOUND_CERT" "$CERT_FILE"
  cp -f "$FOUND_KEY" "$KEY_FILE"
  log "[OK] ตรวจพบ SSL เดิมที่ $(dirname "$FOUND_CERT") → ใช้งานต่อ"
  echo -e "\e[32m[OK]\e[0m ตรวจพบ SSL เดิมที่ $(dirname "$FOUND_CERT") → ใช้งานต่อ"
else
  # ถ้าไม่เจอ → gen self-signed
  log "[WARN] ไม่พบไฟล์ SSL เดิม → generate self-signed"
  echo -e "\e[33m[WARN]\e[0m ไม่พบไฟล์ SSL เดิม → generate self-signed"

  openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
    -subj "/CN=$(hostname -f)" \
    -keyout "$KEY_FILE" \
    -out "$CERT_FILE" >/dev/null 2>&1
fi

# === ลบ HTTPS block เก่าออกก่อน ===
sed -i '/# HTTPS START/,/# HTTPS END/d' "$NGINX_CONF"

# === เพิ่ม HTTPS block ===
if [[ -s "$CERT_FILE" && -s "$KEY_FILE" ]]; then
cat >>"$NGINX_CONF" <<EOF

# HTTPS START
server {
    listen 82 ssl;
    server_name _;

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
# HTTPS END
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
else
  log "[ERROR] ไม่สามารถสร้าง/หาไฟล์ cert ได้ → HTTPS ปิด"
  echo -e "\e[31m[ERROR]\e[0m ไม่สามารถสร้าง/หาไฟล์ cert ได้ → HTTPS ปิด"
fi
