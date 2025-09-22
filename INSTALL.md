# 📖 Installation Guide for ShowOn V.1.0.7

This document provides detailed steps to install, update, and uninstall **ShowOn Script Manager V.1.0.7**.

---

## ⚙️ Requirements
- 🐧 **Ubuntu 18.04 / 20.04 / 22.04 / 24.04**
- Root privileges (sudo or direct root)

---

## 🚀 Installation Methods

### Method 1: Install with `wget`
```bash
wget -O /root/Install https://raw.githubusercontent.com/TspKchn/showon/refs/heads/main/Install
chmod +x /root/Install
/root/Install
```

### Method 2: Install with `curl`
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/TspKchn/showon/refs/heads/main/Install)"
```

### Method 3: Install with `git clone`
```bash
git clone https://github.com/TspKchn/showon.git /opt/showon
cd /opt/showon
cp Install /root/Install
chmod +x /root/Install
/root/Install
```

---

## 🔄 Update Script
To update to the latest version:
```bash
/root/Install
# Select option: 3) Update Script
```

---

## ❌ Uninstall
To remove ShowOn completely:
```bash
/root/Install
# Select option: 2) Uninstall Script
```

---

## 📂 Installed Files
- **/usr/local/bin/**
  - online-check.sh
  - vnstat-traffic.sh
  - v2ray-traffic.sh
  - sysinfo.sh
- **/var/www/html/server/**
  - index.html
  - online_app.json
  - sysinfo.json
  - netinfo.json
  - v2ray_traffic.json
- **/etc/systemd/system/**
  - online-check.service
  - vnstat-traffic.service
  - v2ray-traffic.service
  - sysinfo.service
