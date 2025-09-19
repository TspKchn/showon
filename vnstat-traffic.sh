<FILE:vnstat-traffic.sh>
#!/bin/bash
# =====================================================
# vnstat-traffic.sh - Generate netinfo.json
# =====================================================
set -euo pipefail

CONF="/etc/showon.conf"
source /usr/local/bin/utils.sh
load_conf

JSON_OUT="$WWW_DIR/netinfo.json"

# -------------------------------
# 1) ตรวจสอบ interface หลัก
# -------------------------------
IFACE=$(ip -o -4 route show to default | awk '{print $5}')
[[ -z "$IFACE" ]] && IFACE="eth0"

# -------------------------------
# 2) vnstat traffic
# -------------------------------
VN_RX=$(vnstat --json d | jq -r ".interfaces[] | select(.name==\"$IFACE\") | .traffic.day[-1].rx // 0")
VN_TX=$(vnstat --json d | jq -r ".interfaces[] | select(.name==\"$IFACE\") | .traffic.day[-1].tx // 0")

# -------------------------------
# 3) V2Ray traffic (รวมทุก inbound)
# -------------------------------
V2_UP=0
V2_DOWN=0

DETAILS=$(api_call GET "$PANEL_BASE/panel/api/inbounds/list" "")
if [[ -n "$DETAILS" ]]; then
    V2_UP=$(echo "$DETAILS" | jq '[.obj[].up] | add')
    V2_DOWN=$(echo "$DETAILS" | jq '[.obj[].down] | add')
fi

# -------------------------------
# Build JSON
# -------------------------------
mkdir -p "$WWW_DIR"

cat > "$JSON_OUT" <<EOF
{
  "vnstat": {
    "rx": $VN_RX,
    "tx": $VN_TX
  },
  "v2ray": {
    "up": $V2_UP,
    "down": $V2_DOWN
  }
}
EOF

log "[OK] Updated $JSON_OUT"
</FILE:vnstat-traffic.sh>
