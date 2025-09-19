#!/bin/bash
set -euo pipefail

CONF=/etc/showon.conf
source "$CONF"

JSON_OUT="$WWW_DIR/online_app.json"
TMP_COOKIE=$(mktemp /tmp/showon_cookie_XXXXXX)

NOW_MS=$(date +%s%3N)

SSH_ON=0
OVPN_ON=0
DB_ON=0
V2_ON=0

# --- SSH ---
SSH_ON=$(ss -nt state established | awk '$3 ~ /:22$/ {c++} END{print c+0}')

# --- OpenVPN ---
if [[ -f /etc/openvpn/server/openvpn-status.log ]]; then
  OVPN_ON=$(grep -c '^CLIENT_LIST' /etc/openvpn/server/openvpn-status.log || true)
fi

# --- Dropbear ---
if pgrep dropbear >/dev/null 2>&1; then
  DB_ON=$(pgrep dropbear | wc -l)
fi

# --- V2Ray / 3x-ui ---
if [[ -n "${PANEL_URL:-}" ]]; then
  LOGIN_OK=false

  # login (ลอง 2 แบบ)
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
    RESP=$(curl -sk -b "$TMP_COOKIE" "$PANEL_URL/panel/api/inbounds/list")
    V2_ON=$(echo "$RESP" | jq '[.obj[]?.clientStats[]? | select(.lastOnline > 0)] | length')
  fi
fi

# --- Write JSON ---
mkdir -p "$WWW_DIR"
cat > "$JSON_OUT" <<EOF
{
  "total": $((SSH_ON + OVPN_ON + DB_ON + V2_ON)),
  "ssh": $SSH_ON,
  "openvpn": $OVPN_ON,
  "dropbear": $DB_ON,
  "v2ray": $V2_ON,
  "timestamp": $NOW_MS
}
EOF

rm -f "$TMP_COOKIE"
