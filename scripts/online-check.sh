#!/usr/bin/env bash
set -euo pipefail

CONF="/etc/showon.conf"
source "$CONF"

JSON_OUT="$WWW_DIR/online_app.json"
TMP_COOKIE="$(mktemp -p /tmp showon_cookie_XXXXXX)"
NOW_MS="$(date +%s%3N)"

log() {
  local msg="$1"
  printf '[%(%F %T)T][ONLINE] %s\n' -1 "$msg" >> "$DEBUG_LOG" 2>/dev/null || true
}

# ---- SSH / OpenVPN / Dropbear ----
SSH_ON=$(ss -nt state established | awk '$3 ~ /:22$/ {c++} END{print c+0}')

if [[ -f /etc/openvpn/server/openvpn-status.log ]]; then
  OVPN_ON=$(grep -c '^CLIENT_LIST' /etc/openvpn/server/openvpn-status.log || true)
else
  OVPN_ON=0
fi

DB_ON=$(pgrep -x dropbear | wc -l | awk '{print $1+0}')

# ---- V2Ray via 3x-ui ----
V2_ON=0
if [[ -n "${PANEL_URL:-}" && -n "${XUI_USER:-}" && -n "${XUI_PASS:-}" ]]; then
  LOGIN_OK=false
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
    ONLINES_JSON=$(
      curl -sk -b "$TMP_COOKIE" -H "Content-Type: application/json" \
        -X POST "$PANEL_URL/panel/api/inbounds/onlines" \
        -d '{}' 2>/dev/null \
      | jq -c '.obj // []' 2>/dev/null || echo '[]'
    )
    # นับจำนวนอีเมลที่ออนไลน์จริง
    V2_ON=$(echo "$ONLINES_JSON" | jq 'length' 2>/dev/null || echo 0)
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
