# ShowOn - Online User Checker

สคริปต์ **ShowOn** สำหรับแสดงจำนวนผู้ใช้งานออนไลน์ (SSH, OpenVPN, Dropbear, V2Ray/XRay ผ่าน 3X-UI API)  
พร้อมหน้าเว็บโชว์ผลสวยงามแบบกราฟ และเมนูจัดการผ่าน `showon`  

---

## ✨ Features
- ตรวจสอบผู้ใช้งาน **SSH / OpenVPN / Dropbear / V2Ray**
- ดึงข้อมูลจาก **3X-UI Panel API** อัตโนมัติ
- หน้าเว็บ `:82/server/` แสดงผลเป็น **ตาราง + กราฟ**
- มีเมนู `showon` ใช้งานง่าย
  - `1) Install Script`
  - `2) Restart All Service`
  - `3) Uninstall`
  - `4) Update` (อัปเดตจาก GitHub)
  - `5) View Update Logs`
  - `6) Fix Nginx`
  - `0) Exit`
- รองรับ Ubuntu **18.04 → 24.04**
- ระบบ **Self-Healing** (ถ้า service ล่ม จะรีสตาร์ทอัตโนมัติ)

---

## 🚀 วิธีติดตั้ง
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/TspKchn/showon/refs/heads/main/Install)

📊 วิธีใช้งาน

หลังติดตั้งเสร็จ ใช้คำสั่ง:

showon

เพื่อเข้าเมนูจัดการ

หน้าเว็บแสดงผล (Show Online URL):

http://<YOUR_SERVER_IP>:82/server/


---

📝 Compatibility

Ubuntu 18.04

Ubuntu 20.04

Ubuntu 22.04

Ubuntu 24.04



---

🔖 Version

Installed : V.1.0.0 (Stable Release)

ระบบจะอัปเดตอัตโนมัติด้วยเมนู 4) Update


---
