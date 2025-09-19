#!/bin/bash
# Optional: generate v2ray_traffic.json only (sum up/down)
set -euo pipefail

CONF="/etc/showon.conf"
source "$CONF"

OUT="$WWW_DIR/v2ray_traffic.json"
TMP_COOKIE="/tmp/showon_cookie_v2_$$"
log() { echo "[$(date '+%F %T')][V2TRAFFIC] $*" >> "$DEBUG_LOG"; }

UP=0; DOWN=0

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
    UP=$(echo "$LIST"   | jq '[.obj[]?.up]   | add // 0')
    DOWN=$(echo "$LIST" | jq '[.obj[]?.down] | add // 0')
  fi
fi

# --- JSON แบบ [] ครอบ และบรรทัดเดียว ---
JSON=$(jq -nc --argjson up "$UP" --argjson down "$DOWN" '[{up:$up, down:$down}]')

echo -n "$JSON" > "$OUT"
log "v2: $JSON"

rm -f "$TMP_COOKIE" || true
