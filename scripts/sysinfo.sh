#!/bin/bash
# Generate sysinfo.json
set -euo pipefail

CONF="/etc/showon.conf"
source "$CONF"

OUT="$WWW_DIR/sysinfo.json"
log() { echo "[$(date '+%F %T')][SYS] $*" >> "$DEBUG_LOG"; }

uptime=$(uptime -p | sed 's/^up //')
cpu_free=$(top -bn1 | awk '/Cpu\(s\)/ {print $8}')
cpu_use=$(awk -v f="$cpu_free" 'BEGIN{printf("%.1f%%",100-f)}')
ram="$(free -m | awk 'NR==2{printf "%s / %s MB", $3,$2}')"
disk="$(df -h / | awk 'NR==2{print $3 " / " $2}')"

# ✅ ห่อด้วย [] และบีบให้อยู่บรรทัดเดียว
JSON=$(jq -nc \
  --arg uptime "$uptime" \
  --arg cpu "$cpu_use" \
  --arg ram "$ram" \
  --arg disk "$disk" \
  '[{uptime:$uptime, cpu_usage:$cpu, ram_usage:$ram, disk_usage:$disk}]')

echo -n "$JSON" > "$OUT"
log "sysinfo: $JSON"
