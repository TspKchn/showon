#!/bin/bash
set -euo pipefail
CONF=/etc/showon.conf
source $CONF

JSON_OUT="$WWW_DIR/netinfo.json"

IFACE=$(ip -o -4 route show to default | awk '{print $5}')
VNSTAT_JSON=$(vnstat --json -i "$IFACE")

RX=$(echo "$VNSTAT_JSON" | jq '.interfaces[0].traffic.total.rx')
TX=$(echo "$VNSTAT_JSON" | jq '.interfaces[0].traffic.total.tx')

COOKIE=$(mktemp)
curl -sk -c "$COOKIE" -X POST "$PANEL_BASE/login" -d "username=$XUI_USER&password=$XUI_PASS" >/dev/null
DETAILS=$(curl -sk -b "$COOKIE" "$PANEL_BASE/panel/api/inbounds/list")

UP=$(echo "$DETAILS" | jq '[.obj[].clientStats[].up] | add')
DOWN=$(echo "$DETAILS" | jq '[.obj[].clientStats[].down] | add')

cat > "$JSON_OUT" <<EOF
{
  "vnstat": {
    "rx": $RX,
    "tx": $TX
  },
  "v2ray": {
    "up": $UP,
    "down": $DOWN
  }
}
EOF
