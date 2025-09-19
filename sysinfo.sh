#!/bin/bash
set -euo pipefail
CONF=/etc/showon.conf
source $CONF

JSON_OUT="$WWW_DIR/sysinfo.json"

CPU=$(top -bn1 | awk '/Cpu/ {print 100-$8}')
MEM_TOTAL=$(grep MemTotal /proc/meminfo | awk '{print $2}')
MEM_FREE=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
DISK_TOTAL=$(df -k / | tail -1 | awk '{print $2}')
DISK_USED=$(df -k / | tail -1 | awk '{print $3}')

cat > "$JSON_OUT" <<EOF
{
  "cpu": $CPU,
  "mem_total": $MEM_TOTAL,
  "mem_free": $MEM_FREE,
  "disk_total": $DISK_TOTAL,
  "disk_used": $DISK_USED
}
EOF
