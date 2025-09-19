#!/bin/bash
# =====================================================
# setup-ssl.sh - SSL/TLS Setup for ShowOn
# =====================================================
set -euo pipefail

CERT_DIR="/etc/showon/certs"
mkdir -p "$CERT_DIR"

# 1. ใช้ cert ของ x-ui ถ้ามี
if [[ -f "/etc/x-ui/server.crt" && -f "/etc/x-ui/server.key" ]]; then
    echo "[OK] Found x-ui cert → linking"
    ln -sf /etc/x-ui/server.crt  "$CERT_DIR/fullchain.pem"
    ln -sf /etc/x-ui/server.key  "$CERT_DIR/privkey.pem"
    exit 0
fi

# 2. ใช้ cert ของ certbot ถ้ามี
if [[ -d "/etc/letsencrypt/live" ]]; then
    LATEST=$(ls -dt /etc/letsencrypt/live/* | head -n1)
    if [[ -f "$LATEST/fullchain.pem" && -f "$LATEST/privkey.pem" ]]; then
        echo "[OK] Found certbot cert → linking"
        ln -sf "$LATEST/fullchain.pem" "$CERT_DIR/fullchain.pem"
        ln -sf "$LATEST/privkey.pem"  "$CERT_DIR/privkey.pem"
        exit 0
    fi
fi

# 3. ถ้าไม่พบเลย → generate self-signed
if [[ ! -f "$CERT_DIR/fullchain.pem" || ! -f "$CERT_DIR/privkey.pem" ]]; then
    echo "[WARN] No existing cert found → generating self-signed"
    openssl req -x509 -nodes -newkey rsa:2048 \
        -keyout "$CERT_DIR/privkey.pem" \
        -out "$CERT_DIR/fullchain.pem" \
        -days 365 \
        -subj "/CN=$(hostname -I | awk '{print $1}')"
    echo "[OK] Self-signed cert created at $CERT_DIR"
fi
