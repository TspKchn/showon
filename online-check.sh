#!/bin/bash
set -euo pipefail
CONF=/etc/showon.conf
source $CONF

JSON_OUT="$WWW_DIR/online_app.json"

SSH_ON=$(ss -nt state established | awk '$3 ~ /:22$/ {c++} END {print c+0}')
OVPN_ON=0
[ -f /etc/openvpn/server/openvpn-status.log ] && OVPN_ON=$(grep -c "^CLIENT_LIST" /etc/openvpn/server/openvpn-status.log)
DB_ON=$(pgrep dropbear | wc -l)

COOKIE=$(mktemp)
LOGIN=$(curl -sk -c "$COOKIE" -X POST "$PANEL_BASE/login" -d "username=$XUI_USER&password=$XUI_PASS")
if echo "$LOGIN" | grep -q '"success":true'; then
    ONLINES=$(curl -sk -b "$COOKIE" -H "Content-Type: application/json" \
      -X POST "$PANEL_BASE/panel/api/inbounds/onlines" -d "{}" | jq -r '.obj[]' 2>/dev/null || echo "")
    DETAILS=$(curl -sk -b "$COOKIE" "$PANEL_BASE/panel/api/inbounds/list")
    V2_ON=0
    CLIENTS=()
    NOW=$(date +%s%3N)
    for EMAIL in $ONLINES; do
        LAST=$(echo "$DETAILS" | jq ".obj[].clientStats[] | select(.email==\"$EMAIL\") | .lastOnline")
        if [[ "$LAST" != "null" && $((NOW - LAST)) -lt 10000 ]]; then
            V2_ON=$((V2_ON+1))
            CLIENTS+=("\"$EMAIL\"")
        fi
    done
else
    V2_ON=0
    CLIENTS=()
fi

cat > "$JSON_OUT" <<EOF
{
  "total": $((SSH_ON + OVPN_ON + DB_ON + V2_ON)),
  "ssh": $SSH_ON,
  "openvpn": $OVPN_ON,
  "dropbear": $DB_ON,
  "v2ray": $V2_ON,
  "clients": [$(IFS=,; echo "${CLIENTS[*]}")]
}
EOF
