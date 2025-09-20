#!/bin/bash
# =====================================================
# ShowOn Script Manager V.1.0.6 - Menu
# Author: TspKchn + ChatGPT
# =====================================================

VERSION="V.1.0.6"
REPO_RAW="https://raw.githubusercontent.com/TspKchn/showon/refs/heads/main"

# ===== Install Paths =====
WWW_DIR="/var/www/html/server"
BIN_DIR="/usr/local/bin"
CONF_FILE="/etc/showon.conf"
DEBUG_LOG="/var/log/showon-debug.log"

SCRIPT_ONLINE="$BIN_DIR/online-check.sh"
SCRIPT_VNSTAT="$BIN_DIR/vnstat-traffic.sh"
SCRIPT_V2RAY="$BIN_DIR/v2ray-traffic.sh"
SCRIPT_SYSINFO="$BIN_DIR/sysinfo.sh"

SERVICE_ONLINE="online-check.service"
SERVICE_VNSTAT="vnstat-traffic.service"
SERVICE_V2RAY="v2ray-traffic.service"
SERVICE_SYSINFO="sysinfo.service"

SITE_AV="/etc/nginx/sites-available/showon"
SITE_EN="/etc/nginx/sites-enabled/showon"

# ===== Colors =====
GREEN="\e[32m"; RED="\e[31m"; YELLOW="\e[33m"; CYAN="\e[36m"; NC="\e[0m"

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERROR]${NC} Please run as root."
    exit 1
  fi
}

header() {
  clear
  echo "==============================="
  echo "   ShowOn Script Manager ${VERSION}"
  echo "==============================="
}

press() { read -rp "Press Enter to return to menu..." _; }

# ===== Service Status =====
service_status() {
  local svc="$1"
  if systemctl is-active --quiet "$svc"; then
    echo -e "[${GREEN}ON${NC}]"
  else
    echo -e "[${RED}OFF${NC}]"
  fi
}

show_status() {
  echo -n "NginX        : "
  if systemctl is-active --quiet nginx; then
    echo -e "[${GREEN}ON${NC}]"
  else
    echo -e "[${RED}OFF${NC}]"
  fi

  echo -n "Online Check : "; service_status "$SERVICE_ONLINE"
  echo -n "vnStat       : "; service_status "$SERVICE_VNSTAT"
  echo -n "V2Ray Traffic: "; service_status "$SERVICE_V2RAY"
  echo -n "SysInfo      : "; service_status "$SERVICE_SYSINFO"
  echo "-------------------------------"

  if [[ -f "$CONF_FILE" ]]; then
    echo "Status: Installed"
  else
    echo "Status: Not Installed"
  fi
}

# ===== Check Update =====
check_update() {
  local remote install_raw
  install_raw="$(curl -fsSL "$REPO_RAW/Install" || true)"
  if [[ -z "$install_raw" ]]; then
    echo -e "${YELLOW}[WARN]${NC} ไม่สามารถเช็คเวอร์ชันจาก GitHub ได้"
    return
  fi

  remote="$(printf '%s' "$install_raw" | grep -m1 '^VERSION=' | cut -d'"' -f2)"
  if [[ "$VERSION" == "$remote" ]]; then
    echo -e "${GREEN}[OK]${NC} You are using the latest version."
  else
    echo -e "${CYAN}[UPDATE]${NC} มีเวอร์ชันใหม่: $remote (ปัจจุบัน: $VERSION)"
    read -rp "กด Enter เพื่ออัพเดททันที หรือ Ctrl+C เพื่อยกเลิก..."
    bash -c "$(curl -fsSL $REPO_RAW/Install)"
    exit 0
  fi
}

# ===== Debug Log =====
check_debug() {
  if [[ -f "$DEBUG_LOG" ]]; then
    tail -n 100 "$DEBUG_LOG"
  else
    echo "No debug log yet."
  fi
  press
}

# ===== Change Limit =====
change_limit() {
  if [[ ! -f "$CONF_FILE" ]]; then
    echo -e "${RED}[ERROR]${NC} Config file not found!"
    press; return
  fi

  source "$CONF_FILE"
  echo -e "${CYAN}[INFO]${NC} Current Limit User Online: ${LIMIT:-2000}"
  read -rp "Enter new Limit User Online: " NEW_LIMIT
  if [[ -z "$NEW_LIMIT" ]]; then
    echo -e "${YELLOW}[WARN]${NC} ไม่ได้เปลี่ยนค่า"
    press; return
  fi

  sed -i "s/^LIMIT=.*/LIMIT=${NEW_LIMIT}/" "$CONF_FILE"
  echo -e "${GREEN}[OK]${NC} คุณได้เปลี่ยน Limit User Online แล้วเป็น ${NEW_LIMIT} คน"
  press
}

# ===== Setup Swap =====
setup_swap() {
  MEM_TOTAL=$(free -m | awk '/^Mem:/{print $2}')
  SWAP_SIZE=$(( MEM_TOTAL * 2 ))

  echo -e "${CYAN}[INFO]${NC} RAM = ${MEM_TOTAL}MB → สร้าง Swap ${SWAP_SIZE}MB"
  fallocate -l ${SWAP_SIZE}M /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab >/dev/null
  echo -e "${GREEN}[OK]${NC} Swap พร้อมใช้งานแล้ว"
  press
}

# ===== Menu =====
show_menu() {
  header
  show_status
  echo "==============================="
  check_update
  echo "1) Install Script"
  echo "2) Uninstall Script"
  echo "3) Update Script"
  echo "4) Check Debug Log"
  echo "5) Change Limit User Online"
  echo "6) Setup Swap"
  echo "0) Exit"
  echo "==============================="
  read -rp "Choose an option [0-6]: " choice
  case "$choice" in
    1) bash -c "$(curl -fsSL $REPO_RAW/Install)" ;;
    2) bash -c "$(curl -fsSL $REPO_RAW/uninstall.sh)" ;;
    3) bash -c "$(curl -fsSL $REPO_RAW/Install)" ;;
    4) check_debug ;;
    5) change_limit ;;
    6) setup_swap ;;
    0) exit 0 ;;
    *) echo -e "${RED}[ERROR]${NC} Invalid choice"; sleep 1 ;;
  esac
  show_menu
}

require_root
show_menu
