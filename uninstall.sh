#!/bin/bash
# =====================================================
# ShowOn Script Manager - Uninstaller
# Author: TspKchn + ChatGPT
# =====================================================

set -euo pipefail

# ===== Path Definitions =====
BIN_DIR="/usr/local/bin"
WWW_DIR="/var/www/html/server"
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

# ===== Colors =====
GREEN="\e[32m"; RED="\e[31m"; YELLOW="\e[33m"; CYAN="\e[36m"; NC="\e[0m"

echo -e "${CYAN}[INFO]${NC} Uninstalling ShowOn Script..."

# ---- Stop and disable services ----
systemctl stop online-check.service vnstat-traffic.service v2ray-traffic.service sysinfo.service 2>/dev/null || true
systemctl disable online-check.service vnstat-traffic.service v2ray-traffic.service sysinfo.service 2>/dev/null || true

# ---- Remove services ----
rm -f "$SERVICE_ONLINE" "$SERVICE_VNSTAT" "$SERVICE_V2RAY" "$SERVICE_SYSINFO"
systemctl daemon-reload

# ---- Remove scripts ----
rm -f "$SCRIPT_ONLINE" "$SCRIPT_VNSTAT" "$SCRIPT_V2RAY" "$SCRIPT_SYSINFO"

# ---- Remove config and logs ----
rm -f "$CONF_FILE" "$DEBUG_LOG" "$DEBUG_LOG.1"

# ---- Remove nginx site config ----
rm -f "$SITE_AV" "$SITE_EN"
if nginx -t 2>/dev/null; then
  systemctl reload nginx 2>/dev/null || true
else
  systemctl restart nginx 2>/dev/null || true
fi

# ---- Remove web files ----
rm -rf "$WWW_DIR"

echo -e "${GREEN}[SUCCESS]${NC} ShowOn Uninstalled completely."
