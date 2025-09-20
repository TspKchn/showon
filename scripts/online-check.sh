#!/bin/bash
# =====================================================
# online-check.sh - ShowOn Online Users Checker
# รองรับ: SSH / OpenVPN / Dropbear / 3x-ui / Xray-Core (YoLoNET,Givpn)
# Author: TspKchn
# =====================================================

set -euo pipefail

CONF=/etc/showon.conf
source "$CONF"

JSON_OUT="$WWW_DIR/online_app.json"
TMP_COOKIE=$(mktemp /tmp/showon_cookie_XXXXXX)
NOW=$(date +%s%3N)

SSH_ON=0
OVPN_ON=0
DB_ON=0
V2_ON=0

# ==== SSH ====
SSH_ON=$(ss -nt state established | awk '$3 ~ /:22$/ {c++} END {print c+0}')

# ==== OpenVPN ====
if [[ -f /etc/openvpn/server/openvpn-status.log ]]; then
  OVPN_ON=$(grep -c "^CLIENT_LIST" /etc/openvpn/server/openvpn-status.log || true)
fi

# ==== Dropbear ====
if pgrep dropbear >/dev/null 2>&1; then
  DB_ON=$(pgrep -a dropbear | wc -l)
fi

# ==== V2Ray/Xray ====
if [[ -n "${PANEL_URL:-}" ]]; then
  # ===== MODE: 3x-ui =====
  LOGIN_OK=false

  if curl -sk -c "$TMP_COOKIE" -X POST "$PANEL_URL/login" \
       -H "Content-Type: application/x-www-form-urlencoded" \
       --data "username=$XUI_USER&password=$XUI_PASS" | grep -q '"success":true'; then
    LOGIN_OK=true
  else
    if curl -sk -c "$TMP_COOKIE" -X POST "$PANEL_URL/login" \
         -H "Content-Type: application/json" \
         -d "{\"username\":\"$XUI_USER\",\"password\":\"$XUI_PASS\"}" | grep -q '"success":true'; then
      LOGIN_OK=true
    fi
  fi

  if $LOGIN_OK; then
    RESP=$(curl -sk -b "$TMP_COOKIE" -X POST "$PANEL_URL/panel/api/inbounds/onlines" || true)
    if echo "$RESP" | grep -q '"success":true'; then
      V2_ON=$(echo "$RESP" | jq '[.obj[]?] | length')
    else
      RESP=$(curl -sk -b "$TMP_COOKIE" "$PANEL_URL/panel/api/inbounds/onlines" || true)
      if echo "$RESP" | grep -q '"success":true'; then
        V2_ON=$(echo "$RESP" | jq '[.obj[]?] | length')
      else
        RESP=$(curl -sk -b "$TMP_COOKIE" "$PANEL_URL/panel/api/inbounds/list" || true)
        if echo "$RESP" | grep -q '"success":true'; then
          V2_ON=$(echo "$RESP" | jq --argjson now "$NOW" '
            [ .obj[]?.clientStats[]?
              | select(.lastOnline != null and ($now - .lastOnline) < 5000)
            ] | length')
        fi
      fi
    fi
  fi

else
  # ===== MODE: Xray-Core =====
  if [[ -f /usr/local/etc/xray/config.json ]]; then
    # ---- YoLoNET style ----
    if [[ -d /var/log/xray ]]; then
      V2_ON=$(grep -h 'accepted' /var/log/xray/*.log 2>/dev/null \
              | awk '{print $1,$3}' | sort -u | wc -l)
    fi
  elif [[ -f /etc/xray/config.json ]]; then
    # ---- Givpn style ----
    if [[ -f /var/log/xray/access.log ]]; then
      V2_ON=$(awk '{print $1}' /var/log/xray/access.log | sort -u | wc -l)
    fi
  fi
fi

TOTAL=$((SSH_ON + OVPN_ON + DB_ON + V2_ON))

mkdir -p "$WWW_DIR"
echo -n "[{\"onlines\":$TOTAL,\"limite\":$LIMIT,\"ssh\":$SSH_ON,\"openvpn\":$OVPN_ON,\"dropbear\":$DB_ON,\"v2ray\":$V2_ON,\"timestamp\":$NOW}]" > "$JSON_OUT"

rm -f "$TMP_COOKIE"
