#!/bin/bash
# =====================================================
# v2ray-traffic.sh - ShowOn V2Ray-Only Traffic JSON Generator
# Author: TspKchn + ChatGPT
# =====================================================

set -euo pipefail
trap 'echo "[ERROR] line $LINENO: $BASH_COMMAND" >> "$DEBUG_LOG"' ERR

CONF="/etc/showon.conf"
source "$CONF"

OUT="$WWW_DIR/v2ray_traffic.json"
TMP_COOKIE=$(mktemp /tmp/showon_cookie_XXXXXX)

V2_UP=0
V2_DOWN=0

# ==== V2Ray / Xray (3x-ui API) ====
if [[ -n "${PANEL_URL:-}" ]]; then
  LOGIN_OK=false

  # login: form-data
  if curl -sk -c "$TMP_COOKIE" -X POST "$PANEL_URL/login" \
       -H "Content-Type: application/x-www-form-urlencoded" \
       --data "username=$XUI_USER&password=$XUI_PASS" | grep -q '"success":true'; then
    LOGIN_OK=true
  # login: json
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

# ==== JSON Export (compact, no spaces/newlines) ====
JSON=$(jq -c -n \
  --argjson up "$V2_UP" \
  --argjson down "$V2_DOWN" \
  '[{"v2ray":{"up":$up,"down":$down}}]')

mkdir -p "$WWW_DIR"
echo -n "$JSON" > "$OUT"

{
  echo "[$(date '+%F %T')] V2Ray-only traffic"
  echo "$JSON"
  echo
} >> "$DEBUG_LOG"

rm -f "$TMP_COOKIE"
