#!/usr/bin/env bash
# ShowOn - online-check (V.1.0.5 logic)
set -euo pipefail

CONF="/etc/showon.conf"
source "$CONF"

JSON_OUT="$WWW_DIR/online_app.json"
TMP_COOKIE="$(mktemp -p /tmp showon_cookie_XXXXXX)"
NOW_MS="$(date +%s%3N)"

# กำหนดหน้าต่างเวลา lastOnline (มิลลิวินาที)
LAG_MS=5000

log() {
  local msg="$1"
  printf '[%(%F %T)T][ONLINE] %s\n' -1 "$msg" >> "$DEBUG_LOG" 2>/dev/null || true
}

# -------- นับ SSH / OpenVPN / Dropbear ----------
# SSH: นับ TCP established ไปยังพอร์ต 22 แบบง่าย ๆ
SSH_ON=$(ss -nt state established | awk '$3 ~ /:22$/ {c++} END{print c+0}')

# OpenVPN: ถ้ามีไฟล์ status ให้ดูจำนวน CLIENT_LIST
if [[ -f /etc/openvpn/server/openvpn-status.log ]]; then
  OVPN_ON=$(grep -c '^CLIENT_LIST' /etc/openvpn/server/openvpn-status.log || true)
else
  OVPN_ON=0
fi

# Dropbear: นับโปรเซส dropbear (เชื่อมต่อ)
DB_ON=$(pgrep -x dropbear | wc -l | awk '{print $1+0}')

# ค่าเริ่มต้น V2Ray
V2_ON=0

# ---------------- V2Ray via 3x-ui ----------------
if [[ -n "${PANEL_URL:-}" && -n "${XUI_USER:-}" && -n "${XUI_PASS:-}" ]]; then
  LOGIN_OK=false

  # ล็อกอิน (ลองแบบ form ก่อน ถ้าไม่ติดค่อยลอง JSON)
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
    # 1) ดึงรายชื่อที่ 3x-ui บอกว่า "ออนไลน์ตอนนี้"
    #    ต้อง POST "{}" และบอก Content-Type: application/json
    ONLINES_JSON=$(
      curl -sk -b "$TMP_COOKIE" -H "Content-Type: application/json" \
        -X POST "$PANEL_URL/panel/api/inbounds/onlines" \
        -d '{}' 2>/dev/null \
      | jq -c '.obj // []' 2>/dev/null || echo '[]'
    )

    # 2) ดึงรายละเอียด clientStats (มี lastOnline)
    LIST_JSON=$(
      curl -sk -b "$TMP_COOKIE" "$PANEL_URL/panel/api/inbounds/list" 2>/dev/null \
      | jq -c '.' 2>/dev/null || echo '{"obj":[]}'
    )

    # 3) เอา onlines (อีเมลที่ระบบบอกว่าออนไลน์) มาเช็คซ้ำด้วย lastOnline ภายใน 5 วิ
    V2_ON=$(
      jq -n \
        --argjson now "$NOW_MS" \
        --argjson lag "$LAG_MS" \
        --argjson on  "$ONLINES_JSON" \
        --argjson ls  "$LIST_JSON" '
          # รวม clientStats ทุก inbound เป็นอาเรย์เดียว
          ( $ls.obj // [] ) as $ibs
          | ( $ibs | map(.clientStats) | add // [] ) as $stats
          # นับเฉพาะอีเมลที่อยู่ใน onlines และ lastOnline ยังสดภายใน lag
          | [ ($on // [])[] as $e
              | ($stats[]? | select(.email == $e) | .lastOnline // 0)
              | select(($now - .) < $lag)
            ] | length
        ' 2>/dev/null
    )

  else
    log "login failed"
  fi

fi

TOTAL=$(( SSH_ON + OVPN_ON + DB_ON + V2_ON ))

mkdir -p "$WWW_DIR"
cat > "$JSON_OUT" <<EOF
{
  "total": $TOTAL,
  "ssh": $SSH_ON,
  "openvpn": $OVPN_ON,
  "dropbear": $DB_ON,
  "v2ray": $V2_ON,
  "timestamp": $NOW_MS
}
EOF

log "online_app.json updated: total=$TOTAL ssh=$SSH_ON ovpn=$OVPN_ON db=$DB_ON v2=$V2_ON"
rm -f "$TMP_COOKIE"
