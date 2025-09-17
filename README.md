<p align="center">
  <img src="ShowOn.png" alt="ShowOn Logo" width="300">
</p>

# ShowOn Script Manager

![Ubuntu Supported](https://img.shields.io/badge/Ubuntu-20.04%20%7C%2022.04-orange?logo=ubuntu)
![Version](https://img.shields.io/badge/version-V.1.0.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Status](https://img.shields.io/badge/status-stable-success)

ShowOn คือสคริปต์สำหรับตรวจสอบจำนวนผู้ใช้งาน **SSH / OpenVPN / Dropbear / V2Ray (3x-ui)**  
พร้อมทั้งแสดงข้อมูล **System Info** (Uptime, CPU, RAM, Disk) แบบเรียลไทม์  
ผ่าน **Nginx Web UI (Port 82)**

---

## ✨ Features
- ✅ แสดงจำนวนผู้ใช้งาน **ออนไลน์** ของ SSH / OpenVPN / Dropbear / V2Ray
- ✅ ดึงข้อมูล **System Info** ทุก 5 วินาที
- ✅ หน้าเว็บ UI (HTML/JS) ดูง่าย สวยงาม รองรับมือถือ
- ✅ มีเมนูจัดการ (`showon`) :
  - Install Script
  - Uninstall Script
  - Auto Update (ตรวจสอบเวอร์ชันจาก GitHub อัตโนมัติ)
- ✅ อัปเดตอัตโนมัติเมื่อมีเวอร์ชันใหม่ใน GitHub
- ✅ รองรับ Ubuntu 20.04 / 22.04+

---

## 🚀 Installation

```bash
wget -O Install https://raw.githubusercontent.com/TspKchn/showon/refs/heads/main/Install
chmod +x Install
./Install

จากนั้นใช้คำสั่ง:

showon

เพื่อเปิดเมนูการจัดการ


---

🌐 Access Web UI

หลังติดตั้งเสร็จ สามารถเปิดเว็บได้ที่:

http://<YOUR_SERVER_IP>:82/server/

ตัวอย่างเช่น:

http://127.0.xxx.xxx:82/server/


---

🛠 Uninstall

เลือก 2) Uninstall Script จากเมนู showon
ระบบจะทำการลบทุกอย่างออก และ reboot เครื่องอัตโนมัติ


---

🔄 Update

ระบบจะตรวจสอบเวอร์ชันอัตโนมัติทุกครั้งที่เปิด showon

ถ้ามีเวอร์ชันใหม่ จะถามให้กด Enter เพื่ออัปเดตทันที



---

📜 Log

Log ของการทำงานจะถูกเก็บไว้ที่:

/var/log/showon.log


---

🖼 Screenshot

> 📌 แนะนำให้พี่เพิ่มรูป หน้าเว็บ Online Summary และ เมนู showon มีสี ตรงนี้ จะทำให้ repo ดูน่าใช้มากขึ้น




---

📄 License

MIT License – ใช้งาน แก้ไข และเผยแพร่ได้อิสระ

---
