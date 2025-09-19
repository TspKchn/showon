#!/bin/bash
# =====================================================
# ShowOn - Online Users JSON Generator
# =====================================================

set -euo pipefail
CONF=/etc/showon.conf
source "$CONF"

JSON_OUT="$WWW_DIR/online_app.json"
TMP_COOKIE="/tmp/showon_cookie_$$"

# ---------- ค่าเริ่มต้น ----------
SSH_ON=0
OVPN_ON=0
DB_ON=0
V2_ON=0

# ---------- SSH ----------
SSH_ON=$(ss -nt state established | awk '$3 ~ /:22$/ {c++} END {print c+0}')

# ---------- OpenVPN ----------
if [[ -f /etc/openvpn/server/openvpn-status.log ]]; then
  OVPN_ON=$(grep -c "^CLIENT_LIST" /etc/openvpn/server/openvpn-status.log || echo 0)
fi

# ---------- Dropbear ----------
DB_ON=$(pgrep dropbear | wc -l || echo 0)

# ---------- V2Ray / 3x-ui ----------
V2_ON=0
CLIENTS=()
if [[ -n "${PANEL_URL}" ]]; then
  COOKIE_FILE=$(mktemp)

  # login -> cookie
  if curl -sk -c "$COOKIE_FILE" -X POST "$PANEL_URL/login" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      --data "username=$XUI_USER&password=$XUI_PASS" | grep -q '"success":true'; then

    CLIENTS_JSON=$(curl -sk -b "$COOKIE_FILE" "$PANEL_URL/xui/inbound/list" || echo "")
    if [[ -n "$CLIENTS_JSON" ]]; then
      V2_ON=$(echo "$CLIENTS_JSON" | jq '[.obj[]?.clientStats[]? | select(.online==true)] | length')
      CLIENTS=$(echo "$CLIENTS_JSON" | jq '[.obj[]?.clientStats[]? | {email: .email, up: .up, down: .down, online: .online}]')
    fi
  fi
  rm -f "$COOKIE_FILE"
fi

# ---------- รวมทั้งหมด ----------
TOTAL=$((SSH_ON + OVPN_ON + DB_ON + V2_ON))

cat >"$JSON_OUT" <<EOF
{
  "total": $TOTAL,
  "limit": $LIMIT,
  "ssh": $SSH_ON,
  "openvpn": $OVPN_ON,
  "dropbear": $DB_ON,
  "v2ray": $V2_ON,
  "clients": $CLIENTS
}
EOF

chmod 644 "$JSON_OUT"
