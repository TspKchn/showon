#!/bin/bash
# =====================================================
# ShowOn Script Manager Menu (v1.0.6)
# Author: TspKchn + ChatGPT
# =====================================================

CONF_FILE="/etc/showon.conf"
DEBUG_LOG="/var/log/showon-debug.log"
VERSION="V.1.0.6"

# ===== Colors =====
GREEN="\e[32m"; RED="\e[31m"; YELLOW="\e[33m"; CYAN="\e[36m"; NC="\e[0m"

# ===== Function: Service Status =====
service_status() {
  local svc="$1"
  if systemctl is-active --quiet "$svc"; then
    echo -e "${GREEN}ON${NC}"
  else
    echo -e "${RED}OFF${NC}"
  fi
}

# ===== Header =====
header() {
  clear
  echo "==============================="
  echo "   ShowOn Script Manager ${VERSION}"
  echo "==============================="

  echo -e "NginX        : [$(service_status nginx)]"
  echo -e "Online Check : [$(service_status online-check.service)]"
  echo -e "vnStat       : [$(service_status vnstat-traffic.service)]"
  echo -e "V2Ray Traffic: [$(service_status v2ray-traffic.service)]"
  echo -e "SysInfo      : [$(service_status sysinfo.service)]"
  echo "-------------------------------"

  if [[ -f "$CONF_FILE" ]]; then
    echo -e "Status: ${GREEN}Installed${NC}"
  else
    echo -e "Status: ${RED}Not Installed${NC}"
  fi
  echo "==============================="
}

press() { read -rp "Press Enter to return to menu..." _; }

# ===== Check Update =====
check_update() {
  local remote install_raw
  install_raw="$(curl -fsSL https://raw.githubusercontent.com/TspKchn/showon/refs/heads/main/Install || true)"

  if [[ -z "$install_raw" ]]; then
    echo -e "${YELLOW}[WARN]${NC} ไม่สามารถเช็คเวอร์ชันจาก GitHub ได้"
    return
  fi

  remote="$(printf '%s' "$install_raw" | grep -m1 '^VERSION=' | cut -d'"' -f2)"
  if [[ "$VERSION" == "$remote" ]]; then
    echo -e "${GREEN}[OK]${NC} You are using the latest version."
  else
    echo -e "${CYAN}[UPDATE]${NC} มีเวอร์ชันใหม่: $remote (ปัจจุบัน: $VERSION)"
    read -rp "กด Enter เพื่ออัพเดทเป็นเวอร์ชัน $remote หรือ Ctrl+C เพื่อยกเลิก..."
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/TspKchn/showon/refs/heads/main/Install)"
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
  RAM_MB=$(free -m | awk '/^Mem:/ {print $2}')
  if (( RAM_MB <= 512 )); then
    SWAP_MB=1024
  elif (( RAM_MB <= 2048 )); then
    SWAP_MB=2048
  elif (( RAM_MB <= 4096 )); then
    SWAP_MB=4096
  elif (( RAM_MB <= 8192 )); then
    SWAP_MB=8192
  else
    SWAP_MB=16384
  fi

  echo -e "${CYAN}[INFO]${NC} RAM Detected: ${RAM_MB} MB → Swap ${SWAP_MB} MB"

  fallocate -l ${SWAP_MB}M /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=$SWAP_MB
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile

  if ! grep -q "/swapfile" /etc/fstab; then
    echo "/swapfile none swap sw 0 0" >> /etc/fstab
  fi

  echo -e "${GREEN}[OK]${NC} Swap ${SWAP_MB} MB created and enabled."
  press
}

# ===== Menu =====
show_menu() {
  header
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
    1) bash -c "$(curl -fsSL https://raw.githubusercontent.com/TspKchn/showon/refs/heads/main/Install)" ;;
    2) /usr/local/bin/uninstall.sh ;;
    3) bash -c "$(curl -fsSL https://raw.githubusercontent.com/TspKchn/showon/refs/heads/main/Install)" ;;
    4) check_debug ;;
    5) change_limit ;;
    6) setup_swap ;;
    0) exit 0 ;;
    *) echo -e "${RED}[ERROR]${NC} Invalid choice"; sleep 1 ;;
  esac
  show_menu
}

show_menu
