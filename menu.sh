#!/bin/bash
# =====================================================
# ShowOn Script Manager Menu (Separated)
# Version: 1.0.6
# Author: TspKchn + ChatGPT
# =====================================================

VERSION="V.1.0.6"
CONF_FILE="/etc/showon.conf"
DEBUG_LOG="/var/log/showon-debug.log"
WWW_DIR="/var/www/html/server"
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

# ===== Log Rotate (1MB) =====
rotate_log() {
  local max=1000000
  if [[ -f "$DEBUG_LOG" && $(stat -c%s "$DEBUG_LOG") -gt $max ]]; then
    mv "$DEBUG_LOG" "$DEBUG_LOG.1"
    : > "$DEBUG_LOG"
  fi
}

# ===== Check Update =====
check_update() {
  local remote install_raw
  REPO_RAW="https://raw.githubusercontent.com/TspKchn/showon/refs/heads/main"
  install_raw="$(curl -fsSL "$REPO_RAW/Install" || true)"

  if [[ -z "$install_raw" ]]; then
    echo -e "${YELLOW}[WARN]${NC} ไม่สามารถเช็คเวอร์ชันจาก GitHub ได้"
    return
  fi

  remote="$(printf '%s' "$install_raw" | grep -m1 '^VERSION=' | cut -d'"' -f2)"
  if [[ -z "$remote" ]]; then
    echo -e "${YELLOW}[WARN]${NC} พบไฟล์ Install ใน GitHub แต่หา VERSION ไม่เจอ"
    return
  fi

  if [[ "$VERSION" == "$remote" ]]; then
    echo -e "${GREEN}[OK]${NC} You are using the latest version."
  else
    echo -e "${CYAN}[UPDATE]${NC} มีเวอร์ชันใหม่: $remote (ปัจจุบัน: $VERSION)"
    read -rp "กด Enter เพื่ออัพเดทเป็น $remote หรือ Ctrl+C เพื่อยกเลิก..." _
    bash /root/Install
    exit 0
  fi
}

# ===== Debug Log =====
check_debug() {
  rotate_log
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
  echo -e "${CYAN}[INFO]${NC} Checking RAM and setting up swap..."

  MEM_MB=$(free -m | awk '/^Mem:/{print $2}')
  SWAP_MB=0

  if (( MEM_MB <= 512 )); then
    SWAP_MB=1024
  elif (( MEM_MB <= 1024 )); then
    SWAP_MB=2048
  elif (( MEM_MB <= 2048 )); then
    SWAP_MB=4096
  elif (( MEM_MB <= 4096 )); then
    SWAP_MB=8192
  else
    SWAP_MB=2048
  fi

  SWAP_FILE="/swapfile"

  if [[ -f "$SWAP_FILE" ]]; then
    echo -e "${YELLOW}[WARN]${NC} Swap file already exists → recreating..."
    swapoff "$SWAP_FILE"
    rm -f "$SWAP_FILE"
  fi

  fallocate -l ${SWAP_MB}M "$SWAP_FILE" || dd if=/dev/zero of="$SWAP_FILE" bs=1M count=$SWAP_MB
  chmod 600 "$SWAP_FILE"
  mkswap "$SWAP_FILE"
  swapon "$SWAP_FILE"

  if ! grep -q "$SWAP_FILE" /etc/fstab; then
    echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab
  fi

  echo -e "${GREEN}[OK]${NC} Swap setup completed (${SWAP_MB} MB)"
  free -h
  press
}

# ===== Service Status =====
check_services() {
  local services=("nginx" "online-check" "vnstat-traffic" "v2ray-traffic" "sysinfo")
  echo "-------------------------------"
  for s in "${services[@]}"; do
    if systemctl is-active --quiet "$s"; then
      echo -e "$s : [${GREEN}ON${NC}]"
    else
      echo -e "$s : [${RED}OFF${NC}]"
    fi
  done
  echo "-------------------------------"
}

# ===== Menu =====
show_menu() {
  header
  check_update
  check_services
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
    1) bash /root/Install ;;
    2) bash /root/uninstall.sh ;;   # ✅ เรียกไฟล์ uninstall.sh ตรงๆ
    3) bash /root/Install ;;
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
