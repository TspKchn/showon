#!/bin/bash
# =====================================================
# ShowOn Uninstall Script V.1.0.6
# Author: TspKchn + ChatGPT
# =====================================================

# ===== Paths =====
BIN_DIR="/usr/local/bin"
CONF_FILE="/etc/showon.conf"
DEBUG_LOG="/var/log/showon-debug.log"

SCRIPT_ONLINE="$BIN_DIR/online-check.sh"
SCRIPT_VNSTAT="$BIN_DIR/vnstat-traffic.sh"
SCRIPT_V2RAY="$BIN_DIR/v2ray-traffic.sh"
SCRIPT_SYSINFO="$BIN_DIR/sysinfo.sh"

SERVICE_ONLINE="/etc/systemd/system/online-check.service"
SERVICE_VNSTAT="/etc/systemd/system/vnstat-traffic.service"
SERVICE_V2RAY="/etc/systemd/system/v2ray-traffic.service"
SERVICE_SYSINFO="/etc/systemd/system/sysinfo.service"

SITE_AV="/etc/nginx/sites-available/showon"
SITE_EN="/etc/nginx/sites-enabled/showon"

WWW_DIR="/var/www/html/server"

# ===== Colors =====
GREEN="\e[32m"; RED="\e[31m"; CYAN="\e[36m"; NC="\e[0m"

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERROR]${NC} Please run as root."
    exit 1
  fi
}

uninstall_script() {
  echo -e "${CYAN}[INFO]${NC} Uninstalling ShowOn Script..."

  # ===== Stop & Disable services =====
  systemctl stop online-check.service vnstat-traffic.service v2ray-traffic.service sysinfo.service 2>/dev/null || true
  systemctl disable online-check.service vnstat-traffic.service v2ray-traffic.service sysinfo.service 2>/dev/null || true

  # ===== Remove service files =====
  rm -f "$SERVICE_ONLINE" "$SERVICE_VNSTAT" "$SERVICE_V2RAY" "$SERVICE_SYSINFO"
  systemctl daemon-reload

  # ===== Remove scripts =====
  rm -f "$SCRIPT_ONLINE" "$SCRIPT_VNSTAT" "$SCRIPT_V2RAY" "$SCRIPT_SYSINFO"
  rm -f "$CONF_FILE" "$DEBUG_LOG"

  # ===== Remove web files =====
  rm -f "$SITE_AV" "$SITE_EN"
  rm -rf "$WWW_DIR"

  if nginx -t 2>/dev/null; then
    systemctl reload nginx 2>/dev/null || true
  else
    systemctl restart nginx 2>/dev/null || true
  fi

  echo -e "${GREEN}[SUCCESS]${NC} Uninstalled completely."
}

require_root
uninstall_script
