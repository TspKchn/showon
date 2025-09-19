#!/bin/bash
# Generate netinfo.json from vnstat + V2Ray totals
set -euo pipefail

CONF="/etc/showon.conf"
source "$CONF"

OUT="$WWW_DIR/netinfo.json"
TMP_COOKIE="/tmp/showon_cookie_traffic_$$"

log() { echo "[$(date '+%F %T')][NET] $*" >> "$DEBUG_LOG"; }

# --- vnstat ---
RX=0; TX=0
if vnstat --json -i "$NET_IFACE" >/tmp/vn.json 2>/dev/null; then
  RX=$(jq -r '.interfaces[0].traffic.total.rx // 0' /tmp/vn.json)
  TX=$(jq -r '.interfaces[0].traffic.total.tx // 0' /tmp/vn.json)
  rm -f /tmp/vn.json
fi

# --- V2Ray totals (sum up/down) ---
VUP=0; VDOWN=0
if [[ -n "${PANEL_URL}" ]]; then
  LOGIN_OK=false
  if curl -sk -c "$TMP_COOKIE" -X POST "$PANEL_URL/login" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      --data "username=${XUI_USER}&password=${XUI_PASS}" | grep -q '"success":true'; then
    LOGIN_OK=true
  else
    if curl -sk -c "$TMP_COOKIE" -X POST "$PANEL_URL/login" \
        -H "Content-Type: application/json" \
        -d "{\"username\":\"${XUI_USER}\",\"password\":\"${XUI_PASS}\"}" | grep -q '"success":true'; then
      LOGIN_OK=true
    fi
  fi
  if $LOGIN_OK; then
    LIST=$(curl -sk -b "$TMP_COOKIE" "$PANEL_URL/panel/api/inbounds/list" 2>/dev/null || echo "")
    VUP=$(echo "$LIST"   | jq '[.obj[]?.up]   | add // 0')
    VDOWN=$(echo "$LIST" | jq '[.obj[]?.down] | add // 0')
  fi
fi

# ✅ ห่อด้วย [] และบีบให้อยู่บรรทัดเดียว
JSON=$(jq -nc \
  --argjson rx "$RX" \
  --argjson tx "$TX" \
  --argjson up "$VUP" \
  --argjson down "$VDOWN" \
  '[{vnstat:{rx:$rx,tx:$tx}, v2ray:{up:$up,down:$down}}]')

echo -n "$JSON" > "$OUT"
log "netinfo: $JSON"

rm -f "$TMP_COOKIE" || true
