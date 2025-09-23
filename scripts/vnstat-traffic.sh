#!/bin/bash
# =====================================================
# vnstat-traffic.sh - ShowOn vnStat + V2Ray Traffic JSON Generator
# Author: TspKchn + ChatGPT
# =====================================================

set -euo pipefail
trap 'echo "[ERROR] line $LINENO: $BASH_COMMAND" >> "$DEBUG_LOG"' ERR

CONF="/etc/showon.conf"
source "$CONF"

OUT="$WWW_DIR/netinfo.json"
TMP_COOKIE=$(mktemp /tmp/showon_cookie_XXXXXX)

VN_RX=0
VN_TX=0
V2_UP=0
V2_DOWN=0

# ==== vnStat ====
if command -v vnstat >/dev/null 2>&1; then
  VN_RX=$(vnstat --json h | jq -r '.interfaces[0].traffic.hour[0].rx // 0')
  VN_TX=$(vnstat --json h | jq -r '.interfaces[0].traffic.hour[0].tx // 0')
fi

# ==== V2Ray / Xray (3x-ui API) ====
if [[ -n "${PANEL_URL:-}" ]]; then
  LOGIN_OK=false

  if curl -sk -c "$TMP_COOKIE" -X POST "$PANEL_URL/login" \
       -H "Content-Type: application/x-www-form-urlencoded" \
       --data "username=$XUI_USER&password=$XUI_PASS" | grep -q '"success":true'; then
    LOGIN_OK=true
  elif curl -sk -c "$TMP_COOKIE" -X POST "$PANEL_URL/login" \
       -H "Content-Type: application/json" \
       -d "{\"username\":\"$XUI_USER\",\"password\":\"$XUI_PASS\"}" | grep -q '"success":true'; then
    LOGIN_OK=true
  fi

  if $LOGIN_OK; then
    RESP=$(curl -sk -b "$TMP_COOKIE" "$PANEL_URL/panel/api/inbounds/list" || true)
    if echo "$RESP" | grep -q '"success":true'; then
      V2_UP=$(echo "$RESP" | jq '[.obj[]?.clientStats[]?.up // 0] | add')
      V2_DOWN=$(echo "$RESP" | jq '[.obj[]?.clientStats[]?.down // 0] | add')
    fi
  fi
fi

# ==== JSON Export (string values, compact) ====
JSON=$(jq -c -n \
  --arg rx "$VN_RX" \
  --arg tx "$VN_TX" \
  --arg up "$V2_UP" \
  --arg down "$V2_DOWN" \
  '[{"vnstat_rx":$rx,"vnstat_tx":$tx,"v2ray_up":$up,"v2ray_down":$down}]')

mkdir -p "$WWW_DIR"
echo -n "$JSON" > "$OUT"

{
  echo "[$(date '+%F %T')] vnStat/V2Ray traffic"
  echo "$JSON"
  echo
} >> "$DEBUG_LOG"

rm -f "$TMP_COOKIE"
