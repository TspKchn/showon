<FILE:online-check.sh>
#!/bin/bash
# =====================================================
# online-check.sh - Generate online_app.json
# =====================================================
set -euo pipefail

CONF="/etc/showon.conf"
source /usr/local/bin/utils.sh
load_conf

JSON_OUT="$WWW_DIR/online_app.json"

SSH_ON=0
OVPN_ON=0
DB_ON=0
V2_ON=0

# -------------------------------
# 1) SSH
# -------------------------------
SSH_ON=$(ss -nt state established | awk '$3 ~ /:22$/ {c++} END{print c+0}')

# -------------------------------
# 2) OpenVPN
# -------------------------------
if [[ -f /etc/openvpn/server/openvpn-status.log ]]; then
    OVPN_ON=$(grep -c "^CLIENT_LIST" /etc/openvpn/server/openvpn-status.log || echo 0)
fi

# -------------------------------
# 3) Dropbear
# -------------------------------
if pgrep dropbear >/dev/null 2>&1; then
    DB_ON=$(pgrep dropbear | wc -l)
fi

# -------------------------------
# 4) V2Ray (3x-ui)
# -------------------------------
V2_ON=0
CLIENTS=()

DETAILS=$(api_call GET "$PANEL_BASE/panel/api/inbounds/list" "")
ONLINE_LIST=$(api_call POST "$PANEL_BASE/panel/api/inbounds/onlines" "{}" | jq -r '.obj[]?')

NOW=$(date +%s%3N)

for EMAIL in $ONLINE_LIST; do
    LAST=$(echo "$DETAILS" | jq ".obj[].clientStats[] | select(.email==\"$EMAIL\") | .lastOnline")
    if [[ "$LAST" != "null" && $((NOW - LAST)) -lt 5000 ]]; then
        CLIENTS+=("\"$EMAIL\"")
        V2_ON=$((V2_ON+1))
    fi
done

# -------------------------------
# Build JSON
# -------------------------------
TOTAL=$((SSH_ON + OVPN_ON + DB_ON + V2_ON))

mkdir -p "$WWW_DIR"

cat > "$JSON_OUT" <<EOF
{
  "total": $TOTAL,
  "ssh": $SSH_ON,
  "openvpn": $OVPN_ON,
  "dropbear": $DB_ON,
  "v2ray": $V2_ON,
  "clients": [$(IFS=,; echo "${CLIENTS[*]}")]
}
EOF

log "[OK] Updated $JSON_OUT"
</FILE:online-check.sh>
