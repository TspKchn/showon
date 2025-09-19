#!/bin/bash
# ดึง traffic จาก vnstat + สรุป V2Ray traffic จาก 3x-ui (รวม up/down)
# เขียนเป็น /var/www/html/server/netinfo.json

set -u

CONF="/etc/showon.conf"
[[ -f "$CONF" ]] && source "$CONF"

: "${WWW_DIR:=/var/www/html/server}"
: "${DEBUG_LOG:=/var/log/showon-debug.log}"
: "${NET_IFACE:=eth0}"
: "${PANEL_BASE:=}"
: "${XUI_USER:=}"
: "${XUI_PASS:=}"

OUT="${WWW_DIR}/netinfo.json"
COOKIE="/tmp/showon_cookie"

log(){ echo "[$(date '+%F %T')][NET] $*" >>"$DEBUG_LOG"; }
safe_mkdir(){ mkdir -p "$WWW_DIR" 2>/dev/null || true; }

detect_iface(){
  local IF
  IF=$(ip route 2>/dev/null | awk '/^default/ {print $5; exit}')
  [[ -z "$IF" ]] && IF=$(ip -o -4 addr show 2>/dev/null | awk '$2!="lo"{print $2; exit}')
  [[ -z "$IF" ]] && IF="eth0"
  echo "$IF"
}

vnstat_json(){
  vnstat --json 2>/dev/null
}

vnstat_pick_rx_tx(){
  # เลือก hour ล่าสุดของ iface
  local JSON="$1" IF="$2"
  # หา iface index
  local rx tx
  rx=$(echo "$JSON" | jq -r --arg IF "$IF" '
    .interfaces[] | select(.name==$IF) | .traffic.hour
    | sort_by(.date.year,.date.month,.date.day,.time.hour,.time.minute)
    | last | .rx')
  tx=$(echo "$JSON" | jq -r --arg IF "$IF" '
    .interfaces[] | select(.name==$IF) | .traffic.hour
    | sort_by(.date.year,.date.month,.date.day,.time.hour,.time.minute)
    | last | .tx')
  [[ "$rx" == "null" || -z "$rx" ]] && rx=0
  [[ "$tx" == "null" || -z "$tx" ]] && tx=0
  echo "$rx" "$tx"
}

xui_login(){
  [[ -z "$PANEL_BASE" || -z "$XUI_USER" || -z "$XUI_PASS" ]] && return 1
  local R
  R=$(curl -sk -c "$COOKIE" -X POST "${PANEL_BASE}/login" \
        -d "username=${XUI_USER}&password=${XUI_PASS}" 2>/dev/null)
  echo "$R" | jq -e '.success==true' >/dev/null 2>&1
}

xui_inbounds_list(){
  curl -sk -b "$COOKIE" "${PANEL_BASE}/panel/api/inbounds/list" 2>/dev/null
}

v2ray_sum_up_down(){
  # รวม up/down ของทุก inbound (รวม clientStats)
  [[ -z "$PANEL_BASE" ]] && { echo "0 0"; return; }
  [[ ! -s "$COOKIE" ]] && ! xui_login && { echo "0 0"; return; }
  local L up down
  L=$(xui_inbounds_list) || { echo "0 0"; return; }
  up=$(echo "$L" | jq '[.obj[] | .up + (.clientStats|map(.up)|add // 0)] | add // 0')
  down=$(echo "$L" | jq '[.obj[] | .down + (.clientStats|map(.down)|add // 0)] | add // 0')
  echo "$up" "$down"
}

main(){
  safe_mkdir
  local IF RX TX VU VD
  IF="${NET_IFACE:-$(detect_iface)}"

  local J
  J=$(vnstat_json)
  read -r RX TX < <(vnstat_pick_rx_tx "$J" "$IF")

  read -r VU VD < <(v2ray_sum_up_down)

  local JSON
  JSON=$(jq -n \
    --argjson rx "$RX" \
    --argjson tx "$TX" \
    --argjson vup "$VU" \
    --argjson vdown "$VD" \
    '{vnstat:{rx:$rx,tx:$tx}, v2ray:{up:$vup,down:$vdown}}')

  echo "$JSON" > "$OUT"
  log "netinfo: $JSON"
}

main
