#!/bin/bash
# =====================================================
# online-check.sh - ShowOn Online Users Checker
# รองรับ: SSH / OpenVPN / Dropbear / 3x-ui / Xray-Core / AGN-UDP
# Author: TspKchn + ChatGPT
# Compatible: Ubuntu 18.04+
# =====================================================

set -euo pipefail
trap 'echo "[ERROR] line $LINENO: command exited with status $?" >> "$DEBUG_LOG"' ERR

CONF=/etc/showon.conf
source "$CONF"

JSON_OUT="$WWW_DIR/online_app.json"
TMP_COOKIE=$(mktemp /tmp/showon_cookie_XXXXXX)
NOW=$(date +%s%3N)
SERVER_IP=$(hostname -I | awk '{print $1}')

SSH_ON=0; OVPN_ON=0; DB_ON=0; V2_ON=0; AGNUDP_ON=0

# ==== Log Rotate (1MB) ====
rotate_log() {
  local max=1000000
  if [[ -f "$DEBUG_LOG" && $(stat -c%s "$DEBUG_LOG") -gt $max ]]; then
    mv "$DEBUG_LOG" "$DEBUG_LOG.1"
    : > "$DEBUG_LOG"
  fi
}
rotate_log

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
    {
      echo "[$(date '+%F %T')] 3x-ui API response"
      echo "$RESP" | jq '.' 2>/dev/null || echo "$RESP"
      echo "→ Counted clients: $V2_ON"
      echo
    } >> "$DEBUG_LOG"
  fi
else
  if [[ -f /usr/local/etc/xray/config.json || -f /etc/xray/config.json ]]; then
    if [[ -f /var/log/xray/vless_ntls.log ]]; then
      V2_ON=$(grep 'accepted' /var/log/xray/vless_ntls.log | grep 'email:' \
                | awk '{print $3}' | cut -d: -f1 | sort -u | wc -l)
    elif [[ -f /var/log/xray/access.log ]]; then
      V2_ON=$(grep 'accepted' /var/log/xray/access.log | grep 'email:' \
                | awk '{print $3}' | cut -d: -f1 | sort -u | wc -l)
    fi
  fi
fi

# ==== AGN-UDP ====
if [[ -f /etc/hysteria/config.json ]]; then
  AGNUDP_PORT=$(jq -r '.listen // empty' /etc/hysteria/config.json 2>/dev/null \
    | sed -E 's/^\[::\]://; s/^[^:]*://; s/[^0-9].*$//')

  SERVER_IP=$(hostname -I | awk '{print $1}')

  if [[ -n "$AGNUDP_PORT" && "$AGNUDP_PORT" =~ ^[0-9]+$ ]]; then
    if command -v conntrack >/dev/null 2>&1; then
      AGNUDP_ON=$(conntrack -L -p udp 2>/dev/null \
        | grep "dport=$AGNUDP_PORT" \
        | grep 'src=' \
        | awk '{for(i=1;i<=NF;i++) if($i ~ /^src=/) print $i}' \
        | cut -d= -f2- \
        | grep -v "^$SERVER_IP" \
        | sort -u \
        | wc -l)
    else
      AGNUDP_ON=0
    fi
  else
    AGNUDP_ON=0
  fi
else
  AGNUDP_ON=0
fi

TOTAL=$((SSH_ON + OVPN_ON + DB_ON + V2_ON + AGNUDP_ON))

mkdir -p "$WWW_DIR"
echo -n "[{\"onlines\":$TOTAL,\"limite\":$LIMIT,\"ssh\":$SSH_ON,\"openvpn\":$OVPN_ON,\"dropbear\":$DB_ON,\"v2ray\":$V2_ON,\"agnudp\":$AGNUDP_ON,\"timestamp\":$NOW}]" > "$JSON_OUT"

rm -f "$TMP_COOKIE"
