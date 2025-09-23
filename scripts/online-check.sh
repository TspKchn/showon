#!/bin/bash
# =====================================================
# online-check.sh - ShowOn Online Users Checker (FIXED AGN-UDP COUNT)
# รองรับ: SSH / OpenVPN / Dropbear / 3x-ui / Xray-Core / AGN-UDP (Hysteria)
# Author: TspKchn + ChatGPT
# Compatible: Ubuntu 18.04+
# =====================================================

set -euo pipefail
trap 'echo "[ERROR] line $LINENO: command exited with status $?" >> "$DEBUG_LOG"' ERR

CONF=/etc/showon.conf
# shellcheck disable=SC1090
source "$CONF"

JSON_OUT="$WWW_DIR/online_app.json"
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

# ---------------------------
# Helper: join local IPv4s as regex (for filtering self/addrs)
# ---------------------------
local_ipv4_regex() {
  ip -o -4 addr show up scope global \
    | awk '{print $4}' \
    | cut -d/ -f1 \
    | paste -sd'|' -
}

# ---------------------------
# SSH (tcp/22 established)
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
# Dropbear
# ---------------------------
if pgrep dropbear >/dev/null 2>&1; then
  # นับเฉพาะ process session ไม่ใช่ master
  DB_ON=$(pgrep -a dropbear | grep -c 'dropbear\(\|_convert\|key\)\? ' || true)
  # ถ้าดูแล้วไม่นิ่ง ให้ fallback เป็นจำนวนบรรทัดทั้งหมด
  [[ "$DB_ON" -eq 0 ]] && DB_ON=$(pgrep -a dropbear | wc -l)
fi

# ---------------------------
# V2Ray / Xray
# ---------------------------
if [[ -n "${PANEL_URL:-}" ]]; then
  LOGIN_OK=false
  # ลอง 2 รูปแบบ form/json
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
      echo "→ V2 clients counted: $V2_ON"
      echo
    } >> "$DEBUG_LOG"
  fi
else
  # Xray-core only (fallback via logs)
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
# AGN-UDP (Hysteria) — FIX: อย่าให้ "ค้าง 1" อีก
# แนวคิด:
#   1) ดึงพอร์ตจาก /etc/hysteria/config.json
#   2) ดึงรายชื่อ IPv4 ของเครื่องทั้งหมด เพื่อเอาไปกรองทิ้ง
#   3) อ่าน conntrack UDP เฉพาะ dport ตรงกับ Hysteria
#   4) กรอง src ที่เป็น IP เครื่องเอง, loopback, docker/kube, link-local
#   5) unique และนับ
# ---------------------------
AGNUDP_ON=0

# 1) port
AGNUDP_PORT=$(jq -r '.listen // empty' /etc/hysteria/config.json 2>/dev/null \
  | sed -E 's/^\[::\]://; s/^[^:]*://; s/[^0-9].*$//')

# 2) local addresses (เครื่องนี้ทุก interface)
LOCAL_IPS_REGEX="$(local_ipv4_regex || true)"
# regex สำหรับเครือข่ายภายใน/พิเศษ ที่ไม่ใช่ client ภายนอกจริง
# - 127.0.0.0/8, 10.0.0.0/8, 172.16-31, 192.168.0.0/16, docker 172.17, link-local 169.254
INTERNAL_REGEX='^(127\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.|172\.17\.|169\.254\.)'

if [[ -n "${AGNUDP_PORT:-}" && "$AGNUDP_PORT" =~ ^[0-9]+$ && -x "$(command -v conntrack)" ]]; then
  # 3) อ่าน conntrack
  # หมายเหตุ: บางดิสโทร conntrack แสดงเป็น "dport=XXXXX" บางครั้ง "dst=<ip> sport=XXXXX dport=YYYYY"
  # เรา grep ด้วย "dport=<PORT>" โดยตรง
  RAW_SRC=$(conntrack -L -p udp 2>/dev/null \
              | grep -F "dport=$AGNUDP_PORT" \
              | awk '{for(i=1;i<=NF;i++) if($i ~ /^src=/) {sub(/^src=/,"",$i); print $i}}' \
              | awk 'NF') || true

  if [[ -n "${RAW_SRC:-}" ]]; then
    # 4) กรอง: ip เครื่องเอง + internal ranges
    FILTERED=$(echo "$RAW_SRC" \
      | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' \
      | { if [[ -n "$LOCAL_IPS_REGEX" ]]; then grep -Ev "$LOCAL_IPS_REGEX"; else cat; fi; } \
      | grep -Ev "$INTERNAL_REGEX" \
      | sort -u) || true

    # 5) นับ
    if [[ -n "${FILTERED:-}" ]]; then
      AGNUDP_ON=$(echo "$FILTERED" | wc -l)
    else
      AGNUDP_ON=0
    fi
  else
    AGNUDP_ON=0
  fi
fi

# กัน null → 0
AGNUDP_ON=${AGNUDP_ON:-0}

# Debug block
{
  echo "[$(date '+%F %T')] AGN-UDP DEBUG"
  echo "Hysteria port: ${AGNUDP_PORT:-N/A}"
  echo "Local IP regex: ${LOCAL_IPS_REGEX:-<none>}"
  echo "Filtered AGN-UDP client IPs:"
  if [[ -n "${FILTERED:-}" ]]; then
    echo "$FILTERED"
  else
    echo "<none>"
  fi
  echo "Count: $AGNUDP_ON"
  echo
} >> "$DEBUG_LOG"

# ---------------------------
# Ensure numeric defaults
# ---------------------------
SSH_ON=${SSH_ON:-0}
OVPN_ON=${OVPN_ON:-0}
DB_ON=${DB_ON:-0}
V2_ON=${V2_ON:-0}
AGNUDP_ON=${AGNUDP_ON:-0}
LIMIT=${LIMIT:-2000}

TOTAL=$((SSH_ON + OVPN_ON + DB_ON + V2_ON + AGNUDP_ON))

# ---------------------------
# Output JSON (overwrite)
# ---------------------------
mkdir -p "$WWW_DIR"
JSON_DATA="[{"onlines":$TOTAL,"limite":$LIMIT,"ssh":$SSH_ON,"openvpn":$OVPN_ON,"dropbear":$DB_ON,"v2ray":$V2_ON,"agnudp":$AGNUDP_ON,"timestamp":$NOW}]"

# export เป็น online_app.json
echo -n "$JSON_DATA" > "$WWW_DIR/online_app.json"

# export เป็น online_app.js (เนื้อหาเดียวกัน)
echo -n "$JSON_DATA" > "$WWW_DIR/online_app"

rm -f "$TMP_COOKIE"
