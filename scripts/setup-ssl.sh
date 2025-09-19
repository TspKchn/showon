#!/bin/bash
# =====================================================
# setup-ssl.sh - SSL Setup for ShowOn
# Author: TspKchn
# =====================================================

CONF="/etc/showon.conf"
SSL_DIR="/etc/ssl/showon"
DEBUG_LOG="/var/log/showon-debug.log"

GREEN="\e[32m"; RED="\e[31m"; YELLOW="\e[33m"; CYAN="\e[36m"; NC="\e[0m"

log() {
  echo -e "[$(date '+%Y-%m-%d %H:%M:%S')][SSL] $*" | tee -a "$DEBUG_LOG"
}

require_root() {
  if [[ $EUID -ne 0 ]]; then
    log "${RED}[ERROR]${NC} Please run as root."
    exit 1
  fi
}

load_domain() {
  if [[ -f "$CONF" ]]; then
    DOMAIN=$(grep '^DOMAIN=' "$CONF" | cut -d'"' -f2)
  fi
  DOMAIN=${DOMAIN:-""}
}

setup_ssl() {
  log "${CYAN}[INFO]${NC} Checking SSL certificates..."

  # โหลดค่า DOMAIN จาก config
  load_domain
  if [[ -n "$DOMAIN" ]]; then
    log "${CYAN}[INFO]${NC} ตรวจเจอโดเมนจาก config → $DOMAIN"
  else
    log "${YELLOW}[WARN]${NC} ไม่พบค่า DOMAIN ใน config → จะใช้ IP ของ VPS แทน"
  fi

  mkdir -p "$SSL_DIR"

  # 1) ตรวจสอบไฟล์ในโฟลเดอร์ ShowOn
  if [[ -f "$SSL_DIR/fullchain.pem" && -f "$SSL_DIR/privkey.pem" ]]; then
    log "${GREEN}[OK]${NC} พบไฟล์ SSL เดิมใน $SSL_DIR → ใช้งานไฟล์นี้"
    return 0
  fi

  # 2) ตรวจสอบ Let's Encrypt (ใช้ DOMAIN ถ้ามี)
  if [[ -n "$DOMAIN" && -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" && -f "/etc/letsencrypt/live/$DOMAIN/privkey.pem" ]]; then
    log "${GREEN}[OK]${NC} ตรวจพบไฟล์ SSL จาก Let's Encrypt ของ $DOMAIN"
    ln -sf "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" "$SSL_DIR/fullchain.pem"
    ln -sf "/etc/letsencrypt/live/$DOMAIN/privkey.pem" "$SSL_DIR/privkey.pem"
    return 0
  fi

  # 3) ตรวจสอบโฟลเดอร์ที่ใช้บ่อย (เช่น 3x-ui, givpn)
  if [[ -f "/root/cert/fullchain.pem" && -f "/root/cert/privkey.pem" ]]; then
    log "${GREEN}[OK]${NC} ตรวจพบไฟล์ SSL ใน /root/cert"
    ln -sf "/root/cert/fullchain.pem" "$SSL_DIR/fullchain.pem"
    ln -sf "/root/cert/privkey.pem" "$SSL_DIR/privkey.pem"
    return 0
  fi

  # 4) สุดท้าย → Self-Signed
  log "${YELLOW}[WARN]${NC} ไม่พบไฟล์ SSL เดิม → จะสร้าง self-signed cert ชั่วคราว"
  openssl req -x509 -nodes -newkey rsa:2048 \
    -keyout "$SSL_DIR/privkey.pem" \
    -out "$SSL_DIR/fullchain.pem" \
    -days 365 \
    -subj "/C=TH/ST=Bangkok/L=Bangkok/O=ShowOn/OU=IT/CN=${DOMAIN:-$(hostname -I | awk '{print $1}')}"

  if [[ -f "$SSL_DIR/fullchain.pem" && -f "$SSL_DIR/privkey.pem" ]]; then
    log "${GREEN}[OK]${NC} สร้าง self-signed SSL สำเร็จ (365 วัน)"
  else
    log "${RED}[ERROR]${NC} สร้าง SSL ไม่สำเร็จ"
    return 1
  fi
}

require_root
setup_ssl
