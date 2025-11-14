#!/bin/bash
# ===============================================
#  ShowOn Online Checker (Fixed / Unified)
#  - Ubuntu 18.04 / 20.04 / 22.04
#  - ใช้ค่าจาก /etc/showon.conf (Install script)
#  - Outputs:
#      $WWW_DIR/online_app
#      $WWW_DIR/online_app.json
# ===============================================

# ไม่ใช้ -e เพื่อกัน service ตายง่ายเกินไป
set -u -o pipefail

# -------- Default config --------
CONF="/etc/showon.conf"

WWW_DIR_DEFAULT="/var/www/html/server"
DEBUG_LOG_DEFAULT="/var/log/showon-debug.log"
LIMIT_DEFAULT=2000
NET_IFACE_DEFAULT="eth0"

# ค่า default เริ่มต้น
WWW_DIR="$WWW_DIR_DEFAULT"
DEBUG_LOG="$DEBUG_LOG_DEFAULT"
LIMIT="$LIMIT_DEFAULT"
NET_IFACE="$NET_IFACE_DEFAULT"
PANEL_URL=""
XUI_USER=""
XUI_PASS=""
AGN_PRESENT=0
AGN_PORT=""

# โหลด config ถ้ามี
if [[ -f "$CONF" ]]; then
  # shellcheck disable=SC1090
  . "$CONF"
fi

# กันค่าที่ว่าง / null
WWW_DIR=${WWW_DIR:-$WWW_DIR_DEFAULT}
DEBUG_LOG=${DEBUG_LOG:-$DEBUG_LOG_DEFAULT}
LIMIT=${LIMIT:-$LIMIT_DEFAULT}
NET_IFACE=${NET_IFACE:-$NET_IFACE_DEFAULT}
PANEL_URL=${PANEL_URL:-""}
XUI_USER=${XUI_USER:-""}
XUI_PASS=${XUI_PASS:-""}
AGN_PRESENT=${AGN_PRESENT:-0}
AGN_PORT=${AGN_PORT:-""}

# -------- เตรียมโฟลเดอร์ / log --------
mkdir -p "$WWW_DIR"
mkdir -p "$(dirname "$DEBUG_LOG")"
touch "$DEBUG_LOG"

ONLINE_JSON="$WWW_DIR/online_app.json"
ONLINE_TXT="$WWW_DIR/online_app"
NOW="$(date +%s%3N)"

# cookie ชั่วคราวสำหรับ 3X-UI
TMP_COOKIE="$(mktemp /tmp/showon_cookie_XXXXXX || echo /tmp/showon_cookie_cookie)"

# -------- Logging helpers --------
log() {
  echo "[$(date '+%F %T')] $*" >> "$DEBUG_LOG"
}

log_debug() {
  echo "[$(date '+%F %T')] $*" >> "$DEBUG_LOG"
}

# -------- Log rotation (1MB) --------
rotate_log() {
  local max=1000000 size=0
  if [[ -f "$DEBUG_LOG" ]]; then
    size=$(stat -c%s "$DEBUG_LOG" 2>/dev/null || echo 0)
    if (( size > max )); then
      : > "$DEBUG_LOG"
    fi
  fi
}
rotate_log

log "=== ONLINE CHECK START ==="

# -------- Regex IP ภายใน / Local --------
INTERNAL_REGEX='^(127\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.|169\.254\.)'

local_ipv4_regex() {
  ip -o -4 addr show up scope global 2>/dev/null \
    | awk '{print $4}' \
    | cut -d/ -f1 \
    | paste -sd '|' - 2>/dev/null || true
}

LOCAL_IPS_REGEX="$(local_ipv4_regex || true)"

# ===============================================
#  1) SSH Online (Universal, Accurate)
# ===============================================
count_ssh() {
  SSH_ON=$(ps -eo comm,args \
    | grep "[s]shd:" \
    | grep -v "sshd: .*priv" \
    | grep -v "sshd: .*notty" \
    | wc -l)

  # หากขึ้นค้าง 0 แต่ ss -tn ยังเห็น connection → fallback
  if [[ "$SSH_ON" -eq 0 ]]; then
    SSH_ON=$(ss -tn state established 2>/dev/null \
      | grep -E ":22\s" \
      | wc -l)
  fi
}
count_ssh
log_debug "SSH sessions: $SSH_ON"

# ===============================================
#  2) Dropbear Online (Accurate via ps)
# ===============================================
DB_ON=0

count_dropbear() {
  # Dropbear จะมี 1 main process + 1 ต่อ 1 connection
  # เราลบ 1 ออกไป
  DB_ON=$(expr $(ps aux | grep '[d]ropbear' | wc -l) - 1)

  # ถ้าติดลบ → ตั้งเป็น 0
  [[ $DB_ON -lt 0 ]] && DB_ON=0

  log_debug "Dropbear accurate count: $DB_ON"
}

count_dropbear

# ===============================================
#  3) OpenVPN Online (จาก openvpn-status.log)
# ===============================================
OVPN_ON=0

count_openvpn() {
  local status="/etc/openvpn/server/openvpn-status.log"
  if [[ -f "$status" ]]; then
    # นับบรรทัด CLIENT_LIST
    if ! OVPN_ON=$(grep -c '^CLIENT_LIST' "$status" 2>/dev/null); then
      OVPN_ON=0
    fi
  else
    OVPN_ON=0
  fi
}

count_openvpn
log_debug "OpenVPN count: $OVPN_ON"

# ===============================================
#  4) V2Ray / Xray — รองรับ 3X-UI + XrayCore
# ===============================================
V2_ON=0

if [[ -n "${PANEL_URL:-}" ]]; then
  LOGIN_OK=false
  RESP=""

  # --- TRY LOGIN (FORM) ---
  if curl -sk -c "$TMP_COOKIE" -X POST "$PANEL_URL/login" \
       -H "Content-Type: application/x-www-form-urlencoded" \
       --data "username=$XUI_USER&password=$XUI_PASS" 2>/dev/null \
       | grep -q '"success":true'; then
    LOGIN_OK=true
  fi

  # --- TRY LOGIN (JSON BODY) ---
  if ! $LOGIN_OK; then
    if curl -sk -c "$TMP_COOKIE" -X POST "$PANEL_URL/login" \
         -H "Content-Type: application/json" \
         -d "{\"username\":\"$XUI_USER\",\"password\":\"$XUI_PASS\"}" 2>/dev/null \
         | grep -q '"success":true'; then
      LOGIN_OK=true
    fi
  fi

  if $LOGIN_OK; then
    # --- 1) ลอง /inbounds/onlines ก่อน ---
    RESP="$(curl -sk -b "$TMP_COOKIE" "$PANEL_URL/panel/api/inbounds/onlines" 2>/dev/null || true)"

    if echo "$RESP" | grep -q '"success":true'; then
      V2_ON=$(echo "$RESP" | jq '[.obj[]?] | length' 2>/dev/null || echo 0)
    else
      # --- 2) ถ้า onlines ใช้ไม่ได้ → fallback /inbounds/list ---
      RESP="$(curl -sk -b "$TMP_COOKIE" "$PANEL_URL/panel/api/inbounds/list" 2>/dev/null || true)"
      if echo "$RESP" | grep -q '"success":true'; then
        V2_ON=$(echo "$RESP" | jq --argjson now "$NOW" '
          [ .obj[]?.clientStats[]?
            | select(.lastOnline != null and ($now - .lastOnline) < 5000)
          ] | length' 2>/dev/null || echo 0)
      fi
    fi

    # Debug log 3X-UI
    {
      echo "[$(date '+%F %T')] 3x-ui API response"
      echo "$RESP" | jq '.' 2>/dev/null || echo "$RESP"
      echo "→ V2 clients counted: $V2_ON"
      echo
    } >> "$DEBUG_LOG"
  else
    log "3x-ui login failed (PANEL_URL set but auth not success)"
  fi

else
  # ========== NO PANEL_URL → Xray-core log fallback ==========
  if [[ -f /usr/local/etc/xray/config.json || -f /etc/xray/config.json ]]; then
    if [[ -f /var/log/xray/vless_ntls.log ]]; then
      V2_ON=$(
        grep -F 'accepted' /var/log/xray/vless_ntls.log 2>/dev/null \
          | grep -F 'email:' 2>/dev/null \
          | awk '{print $3}' \
          | cut -d: -f1 \
          | sort -u | wc -l
      )
    elif [[ -f /var/log/xray/access.log ]]; then
      V2_ON=$(
        grep -F 'accepted' /var/log/xray/access.log 2>/dev/null \
          | grep -F 'email:' 2>/dev/null \
          | awk '{print $3}' \
          | cut -d: -f1 \
          | sort -u | wc -l
      )
    fi
  fi
fi

log_debug "V2/Xray count: $V2_ON"

# ===============================================
#  5) AGN-UDP / Hysteria Online (via conntrack)
# ===============================================
AGNUDP_ON=0

count_agnudp() {
  # ต้องมี AGN_PRESENT=1 + AGN_PORT + conntrack
  if [[ "${AGN_PRESENT}" != "1" ]]; then
    AGNUDP_ON=0
    return
  fi
  if [[ -z "${AGN_PORT}" ]]; then
    AGNUDP_ON=0
    return
  fi
  if ! command -v conntrack >/dev/null 2>&1; then
    AGNUDP_ON=0
    return
  fi

  local raw filtered
  raw="$(
    conntrack -L -p udp 2>/dev/null \
      | grep -F "dport=${AGN_PORT}" 2>/dev/null \
      | awk '{
          for (i=1;i<=NF;i++) {
            if ($i ~ /^src=/) {
              gsub(/^src=/,"",$i);
              print $i
            }
          }
        }'
  )"

  if [[ -z "$raw" ]]; then
    AGNUDP_ON=0
    return
  fi

  filtered="$(
    echo "$raw" \
      | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' 2>/dev/null \
      | grep -Ev "$INTERNAL_REGEX" 2>/dev/null
  )"

  if [[ -n "$LOCAL_IPS_REGEX" ]]; then
    filtered="$(echo "$filtered" | grep -Ev "$LOCAL_IPS_REGEX" 2>/dev/null || true)"
  fi

  if [[ -n "$filtered" ]]; then
    AGNUDP_ON="$(echo "$filtered" | sort -u | wc -l)"
  else
    AGNUDP_ON=0
  fi
}

count_agnudp
log_debug "AGN-UDP count: $AGNUDP_ON"

# ===============================================
#  6) สรุปผลรวม + เขียน JSON
# ===============================================
SSH_ON=${SSH_ON:-0}
DB_ON=${DB_ON:-0}
OVPN_ON=${OVPN_ON:-0}
V2_ON=${V2_ON:-0}
AGNUDP_ON=${AGNUDP_ON:-0}
LIMIT=${LIMIT:-2000}

TOTAL=$(( SSH_ON + DB_ON + OVPN_ON + V2_ON + AGNUDP_ON ))

JSON_DATA=$(
  cat <<EOF
[{"onlines":"$TOTAL","limite":"$LIMIT","ssh":"$SSH_ON","openvpn":"$OVPN_ON","dropbear":"$DB_ON","v2ray":"$V2_ON","agnudp":"$AGNUDP_ON","timestamp":"$NOW"}]
EOF
)

echo -n "$JSON_DATA" > "$ONLINE_JSON"
echo -n "$JSON_DATA" > "$ONLINE_TXT"

# ===============================================
#  7) แก้ permission กัน 403 / Loading...
# ===============================================
chmod 755 /var/www/html 2>/dev/null || true
chmod 755 "$WWW_DIR" 2>/dev/null || true
find "$WWW_DIR" -type f -exec chmod 644 {} \; 2>/dev/null || true

log "ONLINE: total=$TOTAL ssh=$SSH_ON ovpn=$OVPN_ON dropbear=$DB_ON v2=$V2_ON agnudp=$AGNUDP_ON"
log "Wrote: $ONLINE_JSON (and online_app)"
log "=== ONLINE CHECK END ==="

# ลบ cookie ชั่วคราว
rm -f "$TMP_COOKIE" 2>/dev/null || true

# ===============================================
#  8) Console output (สำหรับรันด้วยมือ)
# ===============================================
echo "---------------------------------------------"
echo "  🟢 SSH Online      : $SSH_ON"
echo "  🟢 Dropbear Online : $DB_ON"
echo "  🟢 OpenVPN Online  : $OVPN_ON"
echo "  🟢 V2Ray Online    : $V2_ON"
echo "  🟢 AGN UDP Online  : $AGNUDP_ON"
echo "---------------------------------------------"
echo "  🔸 TOTAL ONLINE    : $TOTAL"
echo "  🔸 OUTPUT FILE     : $ONLINE_JSON"
echo "---------------------------------------------"

exit 0
