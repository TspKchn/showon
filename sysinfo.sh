#!/bin/bash
# สรุป uptime / cpu / ram / disk → sysinfo.json

set -u
CONF="/etc/showon.conf"
[[ -f "$CONF" ]] && source "$CONF"

: "${WWW_DIR:=/var/www/html/server}"
: "${DEBUG_LOG:=/var/log/showon-debug.log}"
OUT="${WWW_DIR}/sysinfo.json"

log(){ echo "[$(date '+%F %T')][SYS] $*" >>"$DEBUG_LOG"; }

safe_mkdir(){ mkdir -p "$WWW_DIR" 2>/dev/null || true; }

main(){
  safe_mkdir

  local uptime cpu mem disk
  uptime=$(uptime -p 2>/dev/null | sed 's/^up //')
  cpu=$(top -bn1 2>/dev/null | awk -F'[, ]+' '/Cpu\(s\)/{print 100-$8"%"}')
  mem=$(free -m 2>/dev/null | awk 'NR==2{printf "%s / %s MB",$3,$2}')
  disk=$(df -h / 2>/dev/null | awk 'NR==2{print $3 " / " $2}')

  [[ -z "$cpu" ]] && cpu="N/A"
  [[ -z "$mem" ]] && mem="N/A"
  [[ -z "$disk" ]] && disk="N/A"

  jq -n --arg uptime "$uptime" --arg cpu_usage "$cpu" --arg ram_usage "$mem" --arg disk_usage "$disk" \
    '{uptime:$uptime,cpu_usage:$cpu_usage,ram_usage:$ram_usage,disk_usage:$disk_usage}' >"$OUT"

  log "sysinfo updated"
}

main
