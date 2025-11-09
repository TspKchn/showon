#!/bin/bash
# =====================================================
# online-check.sh - ShowOn Online Users Checker (Hybrid Auto+Config)
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

# =====================================================
# SSH DETECTION (Hybrid)
# =====================================================
if [[ -z "${SSH_PORTS:-}" ]]; then
  SSH_PORTS=$(ss -lntp 2>/dev/null | grep sshd | awk '{print $4}' | sed 's/.*://g' | sort -u | tr '\n' ' ')
fi
SSH_REGEX=$(echo "$SSH_PORTS" | sed 's/ /|/g')
if [[ -n "$SSH_REGEX" ]]; then
  SSH_ON=$(ss -nt state established 2>/dev/null | awk -v re=":($SSH_REGEX)$" '$4 ~ re {c++} END {print c+0}')
fi

# =====================================================
# OPENVPN DETECTION
# =====================================================
if [[ -f /etc/openvpn/server/openvpn-status.log ]]; then
  OVPN_ON=$(grep -c "^CLIENT_LIST" /etc/openvpn/server/openvpn-status.log || true)
fi

# =====================================================
# DROPBEAR DETECTION (Hybrid)
# =====================================================
if [[ -z "${DROPBEAR_PORTS:-}" ]]; then
  DROPBEAR_PORTS=$(ss -lntp 2>/dev/null | grep dropbear | awk '{print $4}' | sed 's/.*://g' | sort -u | tr '\n' ' ')
fi
DB_REGEX=$(echo "$DROPBEAR_PORTS" | sed 's/ /|/g')
if [[ -n "$DB_REGEX" ]]; then
  DB_ON=$(ss -nt state established 2>/dev/null | awk -v re=":($DB_REGEX)$" '$4 ~ re {c++} END {print c+0}')
fi

# =====================================================
# V2RAY / XRAY DETECTION (Optional / Same as old)
# =====================================================
# (สามารถเพิ่มการตรวจจาก process หรือพอร์ตเฉพาะในอนาคต)
V2_ON=${V2_ON:-0}

# =====================================================
# AGN-UDP (Hysteria)
# =====================================================
AGNUDP_ON=${AGNUDP_ON:-0}

# =====================================================
# SUMMARIZE
# =====================================================
SSH_ON=${SSH_ON:-0}
OVPN_ON=${OVPN_ON:-0}
DB_ON=${DB_ON:-0}
V2_ON=${V2_ON:-0}
AGNUDP_ON=${AGNUDP_ON:-0}

TOTAL=$((SSH_ON + OVPN_ON + DB_ON + V2_ON + AGNUDP_ON))

# =====================================================
# OUTPUT JSON
# =====================================================
JSON_DATA="[{\"onlines\":\"$TOTAL\",\"limite\":\"$LIMIT\",\"ssh\":\"$SSH_ON\",\"openvpn\":\"$OVPN_ON\",\"dropbear\":\"$DB_ON\",\"v2ray\":\"$V2_ON\",\"agnudp\":\"$AGNUDP_ON\",\"timestamp\":\"$NOW\"}]"

echo -n "$JSON_DATA" > "$WWW_DIR/online_app.json"
echo -n "$JSON_DATA" > "$WWW_DIR/online_app"

# Fallback
[[ ! -f "$WWW_DIR/online_app.json" ]] && echo '[]' > "$WWW_DIR/online_app.json"
[[ ! -f "$WWW_DIR/online_app" ]] && echo '[]' > "$WWW_DIR/online_app"

rm -f "$TMP_COOKIE"