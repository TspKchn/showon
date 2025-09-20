#!/bin/bash
# =====================================================
# ShowOn Menu Script V.1.0.6
# Author: TspKchn + ChatGPT
# =====================================================

VERSION="V.1.0.6"
CONF_FILE="/etc/showon.conf"
DEBUG_LOG="/var/log/showon-debug.log"
REPO_RAW="https://raw.githubusercontent.com/TspKchn/showon/refs/heads/main"

# ===== Colors =====
GREEN="\e[32m"; RED="\e[31m"; YELLOW="\e[33m"; CYAN="\e[36m"; NC="\e[0m"

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERROR]${NC} Please run as root."
    exit 1
  fi
}

# ===== Rotate Debug Log =====
rotate_log() {
  local max=1000000
  if [[ -f "$DEBUG_LOG" && $(stat -c%s "$DEBUG_LOG") -gt $max ]]; then
    mv "$DEBUG_LOG" "$DEBUG_LOG.1"
    : > "$DEBUG_LOG"
  fi
}

# ===== Check Update =====
check_update() {
  local remote
  local install_raw

  install_raw="$(curl -fsSL "$REPO_RAW/Install" || true)"
  if [[ -z "$install_raw" ]]; then
    echo -e "${YELLOW}[WARN]${NC} ไม่สามารถเช็คเวอร์ชันจาก GitHub ได้"
    return
  fi

  remote="$(printf '%s' "$install_raw" | grep -m1 '^VERSION=' | cut -d'"' -f2)"
  if [[ -z "$remote" ]]; then
    echo -e "${YELLOW}[WARN]${NC} พบไฟล์ Install แต่ไม่มีค่า VERSION"
    return
  fi

  if [[ "$VERSION" == "$remote" ]]; then
    echo -e "${GREEN}[OK]${NC} You are using the latest version."
  else
    echo -e "${CYAN}[UPDATE]${NC} พบเวอร์ชันใหม่: $remote (ปัจจุบัน: $VERSION)"
    echo -e "${CYAN}[INFO]${NC} กด Enter เพื่ออัปเดตเป็น $remote หรือ Ctrl+C เพื่อยกเลิก"
    read
    /usr/local/bin/uninstall.sh >/dev/null 2>&1 || true
    bash -c "$(curl -fsSL "$REPO_RAW/Install")"
    exit 0
  fi
}

# ===== Show Service Status =====
service_status() {
  local name="$1"
  local svc="$2"
  if systemctl is-active --quiet "$svc"; then
    echo -e "$name : [${GREEN}ON${NC}]"
  else
    echo -e "$name : [${RED}OFF${NC}]"
  fi
}

# ===== Header =====
header() {
  clear
  echo "==============================="
  echo "   ShowOn Script Manager ${VERSION}"
  echo "==============================="
  check_update
  echo
  service_status "NginX" "nginx"
  service_status "Online Check" "online-check.service"
  service_status "vnStat" "vnstat-traffic.service"
  service_status "V2Ray Traffic" "v2ray-traffic.service"
  service_status "SysInfo" "sysinfo.service"
  echo
  if [[ -f "$CONF_FILE" ]]; then
    echo -e "Status: ${GREEN}Installed${NC}"
  else
    echo -e "Status: ${RED}Not Installed${NC}"
  fi
  echo "==============================="
}

press() { read -rp "Press Enter to return to menu..." _; }

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
  echo -e "${GREEN}[OK]${NC} เปลี่ยน Limit User Online เป็น ${NEW_LIMIT} คน"
  press
}

# ===== Setup Swap =====
setup_swap() {
  local mem_total swap_size
  mem_total=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)

  if (( mem_total <= 512 )); then
    swap_size=1024
  elif (( mem_total <= 1024 )); then
    swap_size=2048
  elif (( mem_total <= 2048 )); then
    swap_size=3072
  elif (( mem_total <= 4096 )); then
    swap_size=4096
  elif (( mem_total <= 8192 )); then
    swap_size=8192
  else
    swap_size=16384
  fi

  echo -e "${CYAN}[INFO]${NC} RAM: ${mem_total} MB → สร้าง Swap ${swap_size} MB"

  fallocate -l ${swap_size}M /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=${swap_size}
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile

  if ! grep -q "/swapfile" /etc/fstab; then
    echo "/swapfile none swap sw 0 0" >> /etc/fstab
  fi

  echo -e "${GREEN}[OK]${NC} Swap setup completed."
  free -h
  press
}

# ===== Menu =====
show_menu() {
  header
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
    2) /usr/local/bin/uninstall.sh ;;
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
