<h1 align="center">
  <img src="ShowOn.png" alt="ShowOn Logo" width="300"/>
</h1>

# 🚀 ShowOn Dashboard V.1.0.7

Dashboard สำหรับตรวจสอบสถานะ Online ของผู้ใช้งาน VPN  
✅ รองรับ SSH / OpenVPN / Dropbear / V2Ray(Xray) / AGN-UDP (Hysteria)  
✅ แสดง System Info (Uptime, CPU, RAM, Disk)  
✅ แสดง Traffic จาก vnStat และ V2Ray รวมทุก inbound  
✅ แสดงผลผ่าน Web Dashboard ที่ใช้งานง่าย (Nginx port 82)  
✅ ปรับค่า conntrack UDP timeout → 5s (ลดปัญหาค่าออนไลน์ค้าง)  
✅ ระบบเมนูใหม่ แสดงสถานะ ✔ Installed / ✘ Not Installed  

---

## 📦 Supported OS
- 🐧 **Ubuntu 18.04 LTS**
- 🐧 **Ubuntu 20.04 LTS** (recommended)
- 🐧 **Ubuntu 22.04 LTS**
- 🐧 **Ubuntu 24.04 LTS**

---

## ⚙️ วิธีติดตั้ง (Installation)

### วิธีที่ 1: ใช้ `wget`
```bash
wget -O /root/Install https://raw.githubusercontent.com/TspKchn/showon/refs/heads/main/Install
chmod +x /root/Install
/root/Install

```

### วิธีที่ 2: ใช้ `curl`
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/TspKchn/showon/refs/heads/main/Install)"

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
/scripts/
├── Install
├── sysinfo.sh
├── online-check.sh
├── v2ray-traffic.sh
├── vnstat-traffic.sh
/var/www/html/server/
├── index.html
├── online_app.json
├── sysinfo.json
├── netinfo.json
└── v2ray_traffic.json
```

---

## 📝 Changelog
- **V.1.0.7**
  - เพิ่มการตรวจจับ AGN-UDP (Hysteria) จริง (ไม่ค้างค่า 1)  
  - ปรับค่า `nf_conntrack_udp_timeout` เป็น 5 วินาที (ลด delay disconnect)  
  - เพิ่มระบบแสดงผล `✔ Installed` / `✘ Not Installed`  
  - ปรับปรุงเมนูอัปเดต script (refresh ทันทีหลัง update)  

ดูเพิ่มเติมที่ [CHANGELOG.md](CHANGELOG.md)

---

## ❤️ Credits
พัฒนาโดย **คุณ** และ AI ผู้ช่วย 🤖
