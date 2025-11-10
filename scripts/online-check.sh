#!/bin/bash
# =====================================================
# online-check.sh - ShowOn Online Users Checker (FINAL)
# รองรับ: SSH / OpenVPN / Dropbear / 3x-ui / Xray-Core / AGN-UDP
# Author: TspKchn + ChatGPT (Final Fix 2025-11)
# Compatible: Ubuntu 18.04+
# =====================================================

set -euo pipefail
trap 'echo "[ERROR] line $LINENO: command exited with status $?" >> /var/log/showon-debug.log' ERR

# ---- CONFIG ----
CONF=/etc/showon.conf
[[ -f "$CONF" ]] && source "$CONF"

# Default Paths
WWW_DIR=${WWW_DIR:-/var/www/html/server}
DEBUG_LOG=${DEBUG_LOG:-/var/log/showon-debug.log}
LIMIT=${LIMIT:-2000}

# Ensure directory exists
mkdir -p "$WWW_DIR"

TMP_COOKIE=$(mktemp /tmp/showon_cookie_XXXXXX)
NOW=$(date +%s%3N)

SSH_ON=0; OVPN_ON=0; DB_ON=0; V2_ON=0; AGNUDP_ON=0

# ---- Rotate Debug Log (1MB limit) ----
rotate_log() {
  local max=1000000
  if [[ -f "$DEBUG_LOG" && $(stat -c%s "$DEBUG_LOG") -gt $max ]]; then
    mv "$DEBUG_LOG" "$DEBUG_LOG.1"
    : > "$DEBUG_LOG"
  fi
}
rotate_log

# ---------------------------
# SSH
# ---------------------------
if command -v ss >/dev/null 2>&1; then
  SSH_ON=$(ss -nt state established 2>/dev/null | awk '$3 ~ /:22$/ {c++} END {print c+0}')
else
  SSH_ON=$(netstat -nt 2>/dev/null | awk '$6 == "ESTABLISHED" && $4 ~ /:22$/ {c++} END {print c+0}')
fi

# ---------------------------
# OpenVPN
# ---------------------------
if [[ -f /etc/openvpn/server/openvpn-status.log ]]; then
  OVPN_ON=$(grep -c "^CLIENT_LIST" /etc/openvpn/server/openvpn-status.log || true)
fi

# ---------------------------
# Dropbear (Fixed Counting)
# ---------------------------
if pgrep dropbear >/dev/null 2>&1; then
  DB_ON=$(expr $(ps aux | grep '[d]ropbear' | grep -v grep | wc -l) - 1)
  [[ "$DB_ON" -lt 0 ]] && DB_ON=0
fi

# ---------------------------
# V2Ray / Xray
# ---------------------------
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
    LOG_FILE="/var/log/xray/access.log"
    [[ -f /var/log/xray/vless_ntls.log ]] && LOG_FILE="/var/log/xray/vless_ntls.log"
    if [[ -f "$LOG_FILE" ]]; then
      V2_ON=$(grep -F 'accepted' "$LOG_FILE" | grep -F 'email:' \
              | awk '{print $3}' | cut -d: -f1 | sort -u | wc -l)
    fi
  fi
fi

# ---------------------------
# AGN-UDP (Hysteria)
# ---------------------------
AGNUDP_ON=0
if [[ -f /etc/hysteria/config.json ]]; then
  PORT=$(jq -r '.listen // empty' /etc/hysteria/config.json 2>/dev/null \
        | sed -E 's/^\[::\]://; s/^[^:]*://; s/[^0-9].*$//' || true)
  if [[ -n "$PORT" && -x "$(command -v conntrack)" ]]; then
    SRC_IPS=$(conntrack -L -p udp 2>/dev/null | grep "dport=$PORT" \
              | grep -oP 'src=\K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | sort -u)
    [[ -n "$SRC_IPS" ]] && AGNUDP_ON=$(echo "$SRC_IPS" | wc -l)
  fi
fi

# ---------------------------
# รวมข้อมูลและเขียนไฟล์ออก
# ---------------------------
TOTAL=$((SSH_ON + OVPN_ON + DB_ON + V2_ON + AGNUDP_ON))
JSON_DATA="[{\"onlines\":\"$TOTAL\",\"limite\":\"$LIMIT\",\"ssh\":\"$SSH_ON\",\"openvpn\":\"$OVPN_ON\",\"dropbear\":\"$DB_ON\",\"v2ray\":\"$V2_ON\",\"agnudp\":\"$AGNUDP_ON\",\"timestamp\":\"$NOW\"}]"

# เขียนข้อมูลหลัก
echo -n "$JSON_DATA" > "$WWW_DIR/online_app.json"
echo -n "$JSON_DATA" > "$WWW_DIR/online_app"

# ถ้าไฟล์ไม่ถูกสร้างเลย ให้ใส่ค่าเริ่มต้นเป็น []
[[ ! -f "$WWW_DIR/online_app.json" ]] && echo '[]' > "$WWW_DIR/online_app.json"
[[ ! -f "$WWW_DIR/online_app" ]] && echo '[]' > "$WWW_DIR/online_app"

# สำรอง fallback ถ้าเขียนไฟล์ล้มเหลว
if [[ ! -s "$WWW_DIR/online_app.json" ]]; then
  mkdir -p /var/www/html/server
  echo "$JSON_DATA" > /var/www/html/server/online_app.json
  echo "$JSON_DATA" > /var/www/html/server/online_app
fi

rm -f "$TMP_COOKIE"

echo "✅ Updated online_app successfully!"
echo "SSH=$SSH_ON | Dropbear=$DB_ON | Total=$TOTAL"
