<h1 align="center">
  <img src="ShowOn.png" alt="ShowOn Logo" width="400"/>
</h1>

# 🚀 ShowOn Dashboard V.1.0.5

Dashboard สำหรับตรวจสอบสถานะ Online ของผู้ใช้งาน VPN  
✅ รองรับ SSH / OpenVPN / Dropbear / V2Ray(Xray)  
✅ แสดง System Info (Uptime, CPU, RAM, Disk)  
✅ แสดง Traffic จาก vnStat และ V2Ray รวมทุก inbound  
✅ แสดงผลผ่าน Web Dashboard ที่ใช้งานง่าย (Nginx port 82)

---

## 📦 Supported OS
- 🐧 **Ubuntu 20.04 LTS** (recommended)
- 🐧 **Ubuntu 22.04 LTS**
- 🐧 **Ubuntu 18.04 LTS** (ยังรองรับแต่ไม่แนะนำ)

---

## ⚙️ วิธีติดตั้ง (Installation)

### วิธีที่ 1: ใช้ `curl`
```bash
curl -fsSL https://raw.githubusercontent.com/your-repo/showon/main/install.sh | bash
```

### วิธีที่ 2: ใช้ `wget`
```bash
wget -qO- https://raw.githubusercontent.com/your-repo/showon/main/install.sh | bash
```

### วิธีที่ 3: ใช้ `git clone`
```bash
git clone https://github.com/your-repo/showon.git
cd showon
chmod +x *.sh
./install.sh
```

---

## 🔄 อัปเดต (Update)
```bash
cd /script/
git pull origin main
./install.sh
```

---

## ❌ ถอนการติดตั้ง (Uninstall)
```bash
bash /script/uninstall.sh
reboot
```

---

## 📂 โครงสร้างไฟล์ (Project Structure)
```
/script/
├── install.sh
├── uninstall.sh
├── online-check.sh
├── sysinfo.sh
├── vnstat-traffic.sh
├── v2ray-traffic.sh
├── /var/www/html/server/
    ├── index.html
    ├── online_app.json
    ├── sysinfo.json
    ├── netinfo.json
    └── v2ray_traffic.json
```

---

## 📝 Changelog
ดูเพิ่มเติมที่ [CHANGELOG.md](CHANGELOG.md)

---

## ❤️ Credits
พัฒนาโดย **คุณ** และ AI ผู้ช่วย 🤖
