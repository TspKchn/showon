# ShowOn Dashboard

แสดงข้อมูล **Online Users / System / Traffic** จากเซิร์ฟเวอร์ VPN  
รองรับ SSH, OpenVPN, Dropbear, และ V2Ray/Xray (3x-ui)

## 📂 โครงสร้างไฟล์

```
/usr/local/bin/
  ├─ online-check.sh      # สร้าง online_app.json
  ├─ sysinfo.sh           # สร้าง sysinfo.json
  ├─ vnstat-traffic.sh    # สร้าง netinfo.json
  └─ v2ray-traffic.sh     # (optional) สร้าง v2ray_traffic.json

/var/www/html/server/
  ├─ index.html           # Dashboard หน้าเว็บ
  ├─ online_app.json      # JSON แสดงจำนวนออนไลน์
  ├─ sysinfo.json         # JSON ข้อมูลระบบ
  ├─ netinfo.json         # JSON ข้อมูลการใช้งานเน็ต
  └─ v2ray_traffic.json   # JSON เฉพาะ V2Ray (optional)
```

## ⚙️ การตั้งค่า

ไฟล์ config: `/etc/showon.conf`

```bash
VERSION=V.1.0.5
WWW_DIR=/var/www/html/server
LIMIT=2000
DEBUG_LOG=/var/log/showon-debug.log

PANEL_URL="https://your-domain:port/randomPath"
XUI_USER="admin"
XUI_PASS="yourpassword"
NET_IFACE="ens3"
```

## 🚀 วิธีใช้งาน

รันสคริปต์แต่ละตัวเพื่ออัปเดต JSON

```bash
bash /usr/local/bin/online-check.sh
bash /usr/local/bin/sysinfo.sh
bash /usr/local/bin/vnstat-traffic.sh
bash /usr/local/bin/v2ray-traffic.sh   # optional
```

## 🔄 ตั้งค่า systemd service + timer

ตัวอย่าง: `/etc/systemd/system/online-check.service`

```ini
[Unit]
Description=ShowOn Online Users JSON Generator

[Service]
Type=simple
ExecStart=/usr/local/bin/online-check.sh
Restart=always
```

ตัวอย่าง timer `/etc/systemd/system/online-check.timer`

```ini
[Unit]
Description=Run online-check every 5s

[Timer]
OnUnitActiveSec=5s
AccuracySec=1s

[Install]
WantedBy=timers.target
```

เปิดใช้งาน:

```bash
systemctl enable --now online-check.timer
```

ทำเช่นเดียวกันกับ `sysinfo`, `vnstat-traffic`, `v2ray-traffic`

## 🌐 เปิดใช้งาน Dashboard

เปิดเบราว์เซอร์ไปที่:

```
http://YOUR_SERVER:82/server/
```
