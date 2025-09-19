#!/bin/bash
# =====================================================
# ShowOn - Online Users JSON Generator (Fixed Edition)
# =====================================================
set -euo pipefail

CONF="/etc/showon.conf"
source "$CONF"

JSON_OUT="$WWW_DIR/online_app.json"
TMP_COOKIE="/tmp/showon_cookie_$$"
NOW_MS=$(date +%s%3N)

SSH_ON=0
OVPN_ON=0
DB_ON=0
V2_ON=0
CLIENTS_JSON="[]"

# ==== SSH ====
SSH_ON=$(ss -nt state established 2>/dev/null | awk '$3 ~ /:22$/ {c++} END{print c+0}')

# ==== OpenVPN ====
if [[ -f /etc/openvpn/server/openvpn-status.log ]]; then
  OVPN_ON=$(grep -c '^CLIENT_LIST' /etc/openvpn/server/openvpn-status.log || true)
fi

# ==== Dropbear ====
if pgrep dropbear >/dev/null 2>&1; then
  DB_ON=$(pgrep dropbear | wc -l)
fi

# ==== 3x-ui (V2Ray/Xray) ====
if [[ -n "${PANEL_URL:-}" ]]; then
  # login
  if curl -sk -c "$TMP_COOKIE" -X POST "$PANEL_URL/login" \
      -H "Content-Type: application/json" \
      -d "{\"username\":\"$XUI_USER\",\"password\":\"$XUI_PASS\"}" \
      | grep -q '"success":true'; then

    RESP=$(curl -sk -b "$TMP_COOKIE" "$PANEL_URL/xui/inbound/list" || echo "")
    CLIENTS=$(echo "$RESP" | jq -r '.obj[]?.clientStats[]?' 2>/dev/null || echo "")

    if [[ -n "$CLIENTS" ]]; then
      CLIENTS_JSON=$(echo "$CLIENTS" | jq -c --argjson now "$NOW_MS" '
        [ . | select(.online == true or ((.lastOnline|tonumber) > ($now - 5000)))
          | {email, up, down, total: (.up + .down), lastOnline} ]')
      V2_ON=$(echo "$CLIENTS_JSON" | jq 'length')
    fi
  fi
fi

# ==== รวม JSON ====
TOTAL=$((SSH_ON + OVPN_ON + DB_ON + V2_ON))
mkdir -p "$WWW_DIR"

cat > "$JSON_OUT" <<EOF
{
  "total": $TOTAL,
  "ssh": $SSH_ON,
  "openvpn": $OVPN_ON,
  "dropbear": $DB_ON,
  "v2ray": $V2_ON,
  "clients": $CLIENTS_JSON,
  "timestamp": $NOW_MS
}
EOF

rm -f "$TMP_COOKIE"
