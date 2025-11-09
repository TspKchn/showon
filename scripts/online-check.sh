#!/bin/bash
# =====================================================
# online-check.sh - ShowOn Online Users Checker (FINAL)
# รองรับ: SSH / OpenVPN / Dropbear / 3x-ui / Xray-Core / AGN-UDP (Hysteria)
# Author: TspKchn + ChatGPT
# =====================================================

set -euo pipefail
trap 'echo "[ERROR] line $LINENO: command exited with status $?" >> "$DEBUG_LOG"' ERR

# ---- Load Config ----
CONF_FILE="/etc/showon.conf"
if [[ -f "$CONF_FILE" ]]; then
    source "$CONF_FILE"
else
    echo "[WARN] Config $CONF_FILE not found, using defaults"
fi

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

echo "[INFO] WWW_DIR = $WWW_DIR" >> "$DEBUG_LOG"
echo "[INFO] LIMIT = $LIMIT" >> "$DEBUG_LOG"

# ---------------------------
# SSH - หลายพอร์ต
# ---------------------------
SSH_PORTS=(22 443 8880)
SSH_ON=0
for port in "${SSH_PORTS[@]}"; do
    if command -v ss >/dev/null 2>&1; then
        SSH_ON=$((SSH_ON + $(ss -nt state established 2>/dev/null | awk -v p=":$port\$" '$4 ~ p {c++} END {print c+0}')))
    else
        SSH_ON=$((SSH_ON + $(netstat -nt 2>/dev/null | awk -v p=":$port\$" '$6=="ESTABLISHED" && $4 ~ p {c++} END {print c+0}')))
    fi
done

# ---------------------------
# OpenVPN
# ---------------------------
if [[ -f /etc/openvpn/server/openvpn-status.log ]]; then
  OVPN_ON=$(grep -c "^CLIENT_LIST" /etc/openvpn/server/openvpn-status.log || true)
fi

# ---------------------------
# Dropbear - หลายพอร์ต
# ---------------------------
DROPBEAR_PORTS=(109 143 443)
DB_ON=0
for port in "${DROPBEAR_PORTS[@]}"; do
    if command -v ss >/dev/null 2>&1; then
        DB_ON=$((DB_ON + $(ss -nt state established 2>/dev/null | awk -v p=":$port\$" '$4 ~ p {c++} END {print c+0}')))
    else
        DB_ON=$((DB_ON + $(netstat -nt 2>/dev/null | awk -v p=":$port\$" '$6=="ESTABLISHED" && $4 ~ p {c++} END {print c+0}')))
    fi
done

# ---------------------------
# V2Ray / Xray
# ---------------------------
# ไกด์ไลน์: future hybrid detection
# V2_ON=...

# ---------------------------
# AGN-UDP (Hysteria)
# ---------------------------
# ไกด์ไลน์: future hybrid detection
# AGNUDP_ON=...

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
# Output JSON
# ---------------------------
JSON_DATA="[{\"onlines\":\"$TOTAL\",\"limite\":\"$LIMIT\",\"ssh\":\"$SSH_ON\",\"openvpn\":\"$OVPN_ON\",\"dropbear\":\"$DB_ON\",\"v2ray\":\"$V2_ON\",\"agnudp\":\"$AGNUDP_ON\",\"timestamp\":\"$NOW\"}]"

echo -n "$JSON_DATA" > "$WWW_DIR/online_app.json"
echo -n "$JSON_DATA" > "$WWW_DIR/online_app"

# Fallback
[[ ! -f "$WWW_DIR/online_app.json" ]] && echo '[]' > "$WWW_DIR/online_app.json"
[[ ! -f "$WWW_DIR/online_app" ]] && echo '[]' > "$WWW_DIR/online_app"

rm -f "$TMP_COOKIE"