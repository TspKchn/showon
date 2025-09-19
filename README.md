<h1 align="center">
  <img src="ShowOn.png" alt="ShowOn Logo" width="300"/>
</h1>

# 🚀 ShowOn Dashboard V.1.0.5

Dashboard สำหรับตรวจสอบสถานะ Online ของผู้ใช้งาน VPN  
✅ รองรับ SSH / OpenVPN / Dropbear / V2Ray(Xray)  
✅ แสดง System Info (Uptime, CPU, RAM, Disk)  
✅ แสดง Traffic จาก vnStat และ V2Ray รวมทุก inbound  
✅ แสดงผลผ่าน Web Dashboard ที่ใช้งานง่าย (Nginx port 82)

---

## 📦 Supported OS
- 🐧 **Ubuntu 18.04 LTS**
- 🐧 **Ubuntu 20.04 LTS** (recommended)
- 🐧 **Ubuntu 22.04 LTS**

---

## ⚙️ วิธีติดตั้ง (Installation)

### วิธีที่ 1: ใช้ `curl`
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/TspKchn/showon/refs/heads/main/Install)"

```

### วิธีที่ 2: ใช้ `wget`
```bash
wget -O /root/Install https://raw.githubusercontent.com/TspKchn/showon/refs/heads/main/Install
chmod +x /root/Install
/root/Install

```

### วิธีที่ 3: ใช้ `git clone`
```bash
git clone https://github.com/TspKchn/showon.git /opt/showon
cd /opt/showon
cp Install /root/Install
chmod +x /root/Install
/root/Install

```

---

## 📂 โครงสร้างไฟล์ (Project Structure)
```
/script/
├── Install
├── sysinfo.sh
├── online-check.sh
├── v2ray-traffic.sh
├── vnstat-traffic.sh
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
