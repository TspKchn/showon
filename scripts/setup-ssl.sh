#!/bin/bash
# =====================================================
# Setup SSL for ShowOn (with logging)
# =====================================================

CONF="/etc/showon.conf"
source "$CONF"

CERT_DIR="/etc/letsencrypt/live/default"
CERT_FILE="$CERT_DIR/fullchain.pem"
KEY_FILE="$CERT_DIR/privkey.pem"

log() {
  echo "[$(date '+%F %T')][SSL] $*" >> "$DEBUG_LOG"
}

mkdir -p "$CERT_DIR"

if [[ -f "$CERT_FILE" && -f "$KEY_FILE" ]]; then
  echo "[OK] ตรวจพบ SSL เดิม → ใช้งานต่อ"
  log "Found existing SSL at $CERT_DIR"
  exit 0
fi

# auto-detect certs from common dirs
for path in \
  "/root/cert/*/fullchain.pem" \
  "/etc/letsencrypt/live/*/fullchain.pem" \
  "/etc/x-ui/server.pem"
do
  f=$(ls $path 2>/dev/null | head -n1 || true)
  if [[ -n "$f" ]]; then
    d=$(dirname "$f")
    echo "[OK] ตรวจพบ SSL เดิมที่ $d → ใช้งานต่อ"
    log "Using existing SSL from $d"
    ln -sf "$d/fullchain.pem" "$CERT_FILE"
    ln -sf "$d/privkey.pem" "$KEY_FILE"
    exit 0
  fi
done

# fallback → self-signed
echo "[WARN] ไม่พบ SSL → สร้าง self-signed"
log "Generating self-signed SSL"
openssl req -x509 -nodes -newkey rsa:2048 \
  -subj "/CN=localhost" \
  -keyout "$KEY_FILE" \
  -out "$CERT_FILE" \
  -days 365 >/dev/null 2>&1

exit 0
