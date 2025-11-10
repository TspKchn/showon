#!/bin/bash
# =====================================================
# online-check.sh - ShowOn Online Users Checker (FINAL)
# รองรับ: SSH / OpenVPN / Dropbear / 3x-ui / Xray-Core / AGN-UDP (Hysteria)
# Author: TspKchn + ChatGPT
# Compatible: Ubuntu 18.04+
# =====================================================

set -euo pipefail
trap 'echo "[ERROR] line $LINENO: command exited with status $?" >> "$DEBUG_LOG"' ERR

CONF=/etc/showon.conf
[[ -f "$CONF" ]] && source "$CONF"

# ---- Fallback Defaults ----
WWW_DIR=${WWW_DIR:-/var/www/html/server}
LIMIT=${LIMIT:-2000}
DEBUG_LOG=${DEBUG_LOG:-/var/log/showon-debug.log}

mkdir -p "$WWW_DIR"

TMP_COOKIE=$(mktemp /tmp/showon_cookie_XXXXXX)
NOW=$(date +%s%3N)

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

LOCAL_IPS=$(hostname -I | tr ' ' '|')
INTERNAL_REGEX='^(127\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.|172\.17\.|169\.254\.)'

# ---------------------------
# SSH (นับ process แบบ givpn)
# ---------------------------
SSH_ON=$(ps aux | grep '[s]shd:' | grep -v root | grep -v grep | awk 'NR>1{c++} END{print c+0}')

# ---------------------------
# Dropbear (นับ process แบบ givpn)
# ---------------------------
DB_ON=$(expr $(ps aux | grep '[d]ropbear' | grep -v grep | wc -l) - 1)
if [[ $DB_ON -lt 0 ]]; then DB_ON=0; fi

# ---------------------------
# OpenVPN
# ---------------------------
if [[ -f /etc/openvpn/server/openvpn-status.log ]]; then
  OVPN_ON=$(grep -c "^CLIENT_LIST" /etc/openvpn/server/openvpn-status.log || true)
fi

# ---------------------------
# V2Ray / Xray
# ---------------------------
V2_ON=0
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
  fi
else
  if [[ -f /usr/local/etc/xray/config.json || -f /etc/xray/config.json ]]; then
    if [[ -f /var/log/xray/vless_ntls.log ]]; then
      V2_ON=$(grep -F 'accepted' /var/log/xray/vless_ntls.log | grep -F 'email:' \
                | awk '{print $3}' | cut -d: -f1 | sort -u | wc -l)
    elif [[ -f /var/log/xray/access.log ]]; then
      V2_ON=$(grep -F 'accepted' /var/log/xray/access.log | grep -F 'email:' \
                | awk '{print $3}' | cut -d: -f1 | sort -u | wc -l)
    fi
  fi
fi

# ---------------------------
# AGN-UDP (Hysteria)
# ---------------------------
AGNUDP_ON=0
AGNUDP_PORT=$(jq -r '.listen // empty' /etc/hysteria/config.json 2>/dev/null \
  | sed -E 's/^\[::\]://; s/^[^:]*://; s/[^0-9].*$//' || true)

if [[ -n "${AGNUDP_PORT:-}" && "$AGNUDP_PORT" =~ ^[0-9]+$ && -x "$(command -v conntrack)" ]]; then
  RAW_SRC=$(conntrack -L -p udp 2>/dev/null \
              | grep -F "dport=$AGNUDP_PORT" \
              | awk '{for(i=1;i<=NF;i++) if($i ~ /^src=/) {sub(/^src=/,"",$i); print $i}}' \
              | awk 'NF') || true

  if [[ -n "${RAW_SRC:-}" ]]; then
    FILTERED=$(echo "$RAW_SRC" \
      | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' \
      | grep -Ev "$LOCAL_IPS" \
      | grep -Ev "$INTERNAL_REGEX" \
      | sort -u) || true

    if [[ -n "${FILTERED:-}" ]]; then
      AGNUDP_ON=$(echo "$FILTERED" | wc -l)
    fi
  fi
fi

# ---------------------------
# Ensure numeric defaults
# ---------------------------
SSH_ON=${SSH_ON:-0}
OVPN_ON=${OVPN_ON:-0}
DB_ON=${DB_ON:-0}
V2_ON=${V2_ON:-0}
AGNUDP_ON=${AGNUDP_ON:-0}

TOTAL=$((SSH_ON + OVPN_ON + DB_ON + V2_ON + AGNUDP_ON))

# ---------------------------
# Output JSON (compact one-line)
# ---------------------------
JSON_DATA="[{\"onlines\":\"$TOTAL\",\"limite\":\"$LIMIT\",\"ssh\":\"$SSH_ON\",\"openvpn\":\"$OVPN_ON\",\"dropbear\":\"$DB_ON\",\"v2ray\":\"$V2_ON\",\"agnudp\":\"$AGNUDP_ON\",\"timestamp\":\"$NOW\"}]"

echo -n "$JSON_DATA" > "$WWW_DIR/online_app.json"
echo -n "$JSON_DATA" > "$WWW_DIR/online_app"

[[ ! -f "$WWW_DIR/online_app.json" ]] && echo '[]' > "$WWW_DIR/online_app.json"
[[ ! -f "$WWW_DIR/online_app" ]] && echo '[]' > "$WWW_DIR/online_app"

rm -f "$TMP_COOKIE"
