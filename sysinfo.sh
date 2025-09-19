<FILE:sysinfo.sh>
#!/bin/bash
# =====================================================
# sysinfo.sh - Generate sysinfo.json
# =====================================================
set -euo pipefail

CONF="/etc/showon.conf"
source /usr/local/bin/utils.sh
load_conf

JSON_OUT="$WWW_DIR/sysinfo.json"
mkdir -p "$WWW_DIR"

# -------------------------------
# CPU
# -------------------------------
CPU_CORES=$(nproc)
CPU_LOAD=$(awk '{print $1,$2,$3}' /proc/loadavg)
CPU_USAGE=$(top -bn1 | awk '/^%Cpu/ {print 100 - $8}')

# -------------------------------
# Memory
# -------------------------------
MEM_TOTAL=$(grep MemTotal /proc/meminfo | awk '{print $2}')
MEM_FREE=$(grep MemAvailable /proc/meminfo | awk '{print $2}')

# -------------------------------
# Disk
# -------------------------------
DISK_TOTAL=$(df -BG / | tail -1 | awk '{print $2}' | tr -d 'G')
DISK_USED=$(df -BG / | tail -1 | awk '{print $3}' | tr -d 'G')

# -------------------------------
# Uptime
# -------------------------------
UPTIME=$(awk '{print int($1)}' /proc/uptime)

# -------------------------------
# Build JSON
# -------------------------------
cat > "$JSON_OUT" <<EOF
{
  "cpu": {
    "cores": $CPU_CORES,
    "usage": $CPU_USAGE,
    "load": "$CPU_LOAD"
  },
  "memory": {
    "total": $MEM_TOTAL,
    "free": $MEM_FREE
  },
  "disk": {
    "total": $DISK_TOTAL,
    "used": $DISK_USED
  },
  "uptime": $UPTIME
}
EOF

log "[OK] Updated $JSON_OUT"
</FILE:sysinfo.sh>
