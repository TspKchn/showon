#!/bin/bash
# Generate online_app.json (every 5s by systemd)
set -euo pipefail

CONF="/etc/showon.conf"
source "$CONF"

JSON_OUT="$WWW_DIR/online_app.json"
TMP_COOKIE="/tmp/showon_cookie_$$"
NOW_MS=$(date +%s%3N)

log() { echo "[$(date '+%F %T')][ONLINE] $*" >> "$DEBUG_LOG"; }

# --- Count SSH / OpenVPN / Dropbear ---
SSH_ON=$(ss -nt state established | awk '$3 ~ /:22$/ {c++} END{print c+0}')
OVPN_ON=0
[[ -f /etc/openvpn/server/openvpn-status.log ]] && OVPN_ON=$(grep -c "CLIENT_LIST" /etc/openvpn/server/openvpn-status.log || true)
DB_ON=$(pgrep dropbear | wc -l | awk '{print $1+0}')

V2_ON=0

if [[ -n "${PANEL_URL}" ]]; then
  # login -> cookie
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
    # online emails
    ONLINES=$(curl -sk -b "$TMP_COOKIE" -H "Content-Type: application/json" \
      -X POST "$PANEL_URL/panel/api/inbounds/onlines" -d "{}" 2>/dev/null || echo "")

    if echo "$ONLINES" | grep -q '"success":true'; then
      # list for lastOnline cross-check
      DETAILS=$(curl -sk -b "$TMP_COOKIE" "$PANEL_URL/panel/api/inbounds/list" 2>/dev/null || echo "")
      # อนุโลม 5000ms ภายใน 5 วิ
      V2_ON=$(echo "$ONLINES" | jq -r '.obj[]?' 2>/dev/null | while read -r EMAIL; do
        LAST=$(echo "$DETAILS" | jq ".obj[].clientStats[] | select(.email==\"$EMAIL\") | .lastOnline" 2>/dev/null)
        if [[ -n "$LAST" && "$LAST" != "null" ]]; then
          DIFF=$(( NOW_MS - LAST ))
          [[ $DIFF -lt 5000 ]] && echo 1 || echo 0
        else
          echo 0
        fi
      done | awk '{s+=$1} END{print s+0}')
    fi
  fi
fi

TOTAL=$(( SSH_ON + OVPN_ON + DB_ON + V2_ON ))

JSON=$(jq -n \
  --argjson onlines "$TOTAL" \
  --argjson limite "$LIMIT" \
  --argjson ssh "$SSH_ON" \
  --argjson openvpn "$OVPN_ON" \
  --argjson dropbear "$DB_ON" \
  --argjson v2ray "$V2_ON" \
  '[{onlines:$onlines, limite:$limite, ssh:$ssh, openvpn:$openvpn, dropbear:$dropbear, v2ray:$v2ray}]')

echo "$JSON" > "$JSON_OUT"
log "online: $JSON"

rm -f "$TMP_COOKIE" || true
