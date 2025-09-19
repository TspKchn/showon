#!/bin/bash
# Online checker → สร้าง /var/www/html/server/online_app.json

set -u

CONF="/etc/showon.conf"
[[ -f "$CONF" ]] && source "$CONF"

: "${WWW_DIR:=/var/www/html/server}"
: "${LIMIT:=2000}"
: "${DEBUG_LOG:=/var/log/showon-debug.log}"
: "${PANEL_BASE:=}"
: "${XUI_USER:=}"
: "${XUI_PASS:=}"

JSON_OUT="${WWW_DIR}/online_app.json"
COOKIE="/tmp/showon_cookie"

log(){ echo "[$(date '+%F %T')][ONLINE] $*" >>"$DEBUG_LOG"; }

safe_mkdir(){ mkdir -p "$WWW_DIR" 2>/dev/null || true; }

count_ssh(){
  ss -nt state established 2>/dev/null | awk '$3 ~ /:22$/ {c++} END{print c+0}'
}

count_openvpn(){
  [[ -f /etc/openvpn/server/openvpn-status.log ]] && grep -c "CLIENT_LIST" /etc/openvpn/server/openvpn-status.log || echo 0
}

count_dropbear(){
  pgrep dropbear >/dev/null 2>&1 && pgrep dropbear | wc -l || echo 0
}

xui_login(){
  [[ -z "$PANEL_BASE" || -z "$XUI_USER" || -z "$XUI_PASS" ]] && return 1
  local R
  R=$(curl -sk -c "$COOKIE" -X POST "${PANEL_BASE}/login" \
        -d "username=${XUI_USER}&password=${XUI_PASS}" 2>/dev/null)
  echo "$R" | jq -e '.success==true' >/dev/null 2>&1
}

xui_fetch_onlines(){ # echo JSON array of emails
  local ep
  for ep in "/panel/api/inbounds/onlines" "/xui/inbounds/onlines" "/panel/inbound/onlines"; do
    local R
    R=$(curl -sk -b "$COOKIE" -H "Content-Type: application/json" -X POST "${PANEL_BASE}${ep}" -d "{}" 2>/dev/null)
    if echo "$R" | jq -e '.success==true' >/dev/null 2>&1; then
      echo "$R" | jq -r '.obj'
      return 0
    fi
  done
  return 1
}

xui_fetch_list(){ # echo full list (for lastOnline)
  curl -sk -b "$COOKIE" "${PANEL_BASE}/panel/api/inbounds/list" 2>/dev/null
}

v2ray_online_count(){
  # ขั้นตอน:
  # 1) ล็อกอิน (ถ้า cookie ไม่มี/หมดอายุ)
  # 2) POST onlines → ได้รายการ emails
  # 3) GET list → lastOnline ของแต่ละ email
  # 4) นับเฉพาะ email ที่ lastOnline ภายใน 5 วินาที
  [[ -z "$PANEL_BASE" ]] && { echo 0; return; }
  [[ ! -s "$COOKIE" ]] && ! xui_login && { echo 0; return; }

  local O L NOW cnt=0
  O=$(xui_fetch_onlines) || { echo 0; return; }
  L=$(xui_fetch_list) || { echo 0; return; }
  NOW=$(date +%s%3N)

  # วนทีละ email
  while read -r email; do
    [[ -z "$email" ]] && continue
    local last
    last=$(echo "$L" | jq -r ".obj[].clientStats[] | select(.email==\"${email}\") | .lastOnline" 2>/dev/null)
    [[ "$last" == "null" || -z "$last" ]] && continue
    local diff=$((NOW - last))
    if [[ $diff -lt 5000 ]]; then
      cnt=$((cnt+1))
    fi
  done < <(echo "$O" | jq -r '.[]')

  echo "$cnt"
}

main(){
  safe_mkdir
  local SSH_ON OVPN_ON DB_ON V2_ON TOTAL

  SSH_ON=$(count_ssh)
  OVPN_ON=$(count_openvpn)
  DB_ON=$(count_dropbear)
  V2_ON=$(v2ray_online_count)

  TOTAL=$((SSH_ON + OVPN_ON + DB_ON + V2_ON))

  local JSON
  JSON=$(jq -n \
    --argjson onlines "$TOTAL" \
    --argjson limite "$LIMIT" \
    --argjson ssh "$SSH_ON" \
    --argjson openvpn "$OVPN_ON" \
    --argjson dropbear "$DB_ON" \
    --argjson v2ray "$V2_ON" \
    '[{onlines:$onlines,limite:$limite,ssh:$ssh,openvpn:$openvpn,dropbear:$dropbear,v2ray:$v2ray}]')

  echo "$JSON" > "$JSON_OUT"
  log "online: $JSON"
}

main
