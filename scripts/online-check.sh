#!/bin/bash
# =====================================================
# online-check.sh - ShowOn Online Users Checker (FINAL)
# รองรับ: SSH / OpenVPN / Dropbear / 3x-ui / Xray-Core / AGN-UDP (Hysteria)
# Author: TspKchn + ChatGPT
# Compatible: Ubuntu 18.04+
# =====================================================

set -euo pipefail
trap 'echo "[ERROR] line $LINENO: command exited with status $?" >> "${DEBUG_LOG:-/var/log/showon-debug.log}"' ERR

# ---- Load Config ----
CONF=/etc/showon.conf
[[ -f "$CONF" ]] && source "$CONF"

# ---- Fallback Defaults ----
WWW_DIR=${WWW_DIR:-/var/www/html/server}
LIMIT=${LIMIT:-2000}
DEBUG_LOG=${DEBUG_LOG:-/var/log/showon-debug.log}

mkdir -p "$WWW_DIR"

# ---- Temporary cookie ----
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
# Helper: join local IPv4s as regex
# ---------------------------
local_ipv4_regex() {
  ip -o -4 addr show up scope global \
    | awk '{print $4}' \
    | cut -d/ -f1 \
    | paste -sd'|' -
}

INTERNAL_REGEX='^(127\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.|172\.17\.|169\.254\.)'

# ---------------------------
# SSH (unique IP across multiple ports)
# ---------------------------
SSH_PORTS=(22 443 8880)
SSH_IPS=()
for port in "${SSH_PORTS[@]}"; do
    if command -v ss >/dev/null 2>&1; then
        IPS=$(ss -nt state established 2>/dev/null | awk -v p=":$port$" '$4 ~ p {print $5}' | cut -d: -f1)
    else
        IPS=$(netstat -nt 2>/dev/null | awk -v p=":$port$" '$6=="ESTABLISHED" && $4 ~ p {print $5}' | cut -d: -f1)
    fi
    SSH_IPS+=($IPS)
done
SSH_ON=$(printf "%s\n" "${SSH_IPS[@]}" | grep -Ev "$INTERNAL_REGEX" | sort -u | wc -l)

# ---------------------------
# Dropbear (unique IP across multiple ports)
# ---------------------------
DB_PORTS=(109 143 443)
DB_IPS=()
for port in "${DB_PORTS[@]}"; do
    if command -v ss >/dev/null 2>&1; then
        IPS=$(ss -nt state established 2>/dev/null | awk -v p=":$port$" '$4 ~ p {print $5}' | cut -d: -f1)
    else
        IPS=$(netstat -nt 2>/dev/null | awk -v p=":$port$" '$6=="ESTABLISHED" && $4 ~ p {print $5}' | cut -d: -f1)
    fi
    DB_IPS+=($IPS)
done
DB_ON=$(printf "%s\n" "${DB_IPS[@]}" | grep -Ev "$INTERNAL_REGEX" | sort -u | wc -l)

# ---------------------------
# OpenVPN
# ---------------------------
if [[ -f /etc/openvpn/server/openvpn-status.log ]]; then
  OVPN_ON=$(grep -c "^CLIENT_LIST" /etc/openvpn/server/openvpn-status.log || true)
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

LOCAL_IPS_REGEX="$(local_ipv4_regex || true)"
if [[ -n "${AGNUDP_PORT:-}" && "$AGNUDP_PORT" =~ ^[0-9]+$ && -x "$(command -v conntrack)" ]]; then
  RAW_SRC=$(conntrack -L -p udp 2>/dev/null \
              | grep -F "dport=$AGNUDP_PORT" \
              | awk '{for(i=1;i<=NF;i++) if($i ~ /^src=/) {sub(/^src=/,"",$i); print $i}}' \
              | awk 'NF') || true

  if [[ -n "${RAW_SRC:-}" ]]; then
    FILTERED=$(echo "$RAW_SRC" \
      | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' \
      | { if [[ -n "$LOCAL_IPS_REGEX" ]]; then grep -Ev "$LOCAL_IPS_REGEX"; else cat; fi; } \
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
LIMIT=${LIMIT:-2000}

TOTAL=$((SSH_ON + OVPN_ON + DB_ON + V2_ON + AGNUDP_ON))

# ---------------------------
# Output JSON
# ---------------------------
mkdir -p "$WWW_DIR"
JSON_DATA="[{\"onlines\":\"$TOTAL\",\"limite\":\"$LIMIT\",\"ssh\":\"$SSH_ON\",\"openvpn\":\"$OVPN_ON\",\"dropbear\":\"$DB_ON\",\"v2ray\":\"$V2_ON\",\"agnudp\":\"$AGNUDP_ON\",\"timestamp\":\"$NOW\"}]"

echo -n "$JSON_DATA" > "$WWW_DIR/online_app.json"
echo -n "$JSON_DATA" > "$WWW_DIR/online_app"

# Fallback
[[ ! -f "$WWW_DIR/online_app.json" ]] && echo '[]' > "$WWW_DIR/online_app.json"
[[ ! -f "$WWW_DIR/online_app" ]] && echo '[]' > "$WWW_DIR/online_app"

rm -f "$TMP_COOKIE"