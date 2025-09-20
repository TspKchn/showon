#!/bin/bash
# =====================================================
# ShowOn Script Manager Menu
# =====================================================

VERSION="V.1.0.6"
REPO_RAW="https://raw.githubusercontent.com/TspKchn/showon/refs/heads/main"

# โหลดฟังก์ชัน install จากไฟล์ Install
source <(curl -fsSL "$REPO_RAW/Install")

GREEN="\e[32m"; RED="\e[31m"; NC="\e[0m"

header() {
  clear
  echo "==============================="
  echo "   ShowOn Script Manager ${VERSION}"
  echo "==============================="
}

show_menu() {
  header
  echo "1) Install Script"
  echo "2) Uninstall Script"
  echo "3) Update Script"
  echo "0) Exit"
  echo "==============================="
  read -rp "Choose an option [0-3]: " choice
  case "$choice" in
    1) install_script ;;
    2) echo "ยังไม่ได้เขียน uninstall.sh" ;;
    3) echo "ยังไม่ได้เขียน update" ;;
    0) exit 0 ;;
    *) echo -e "${RED}[ERROR]${NC} Invalid choice";;
  esac
  read -rp "Press Enter..." _
  show_menu
}

show_menu
