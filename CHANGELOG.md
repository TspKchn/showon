# 📜 Changelog - ShowOn

## [1.0.5] - 2025-09-19
### ✨ Added
- แยกสคริปออกเป็นหลายไฟล์ (`online-check.sh`, `sysinfo.sh`, `vnstat-traffic.sh`, `v2ray-traffic.sh`)
- เพิ่ม `index.html` Dashboard รองรับการดึง JSON จากสคริปต่าง ๆ
- รองรับการดึงจำนวน Client Online ของ V2Ray/Xray ผ่าน `3x-ui` API (onlines + lastOnline fallback)
- ระบบ Traffic แสดงข้อมูลจาก vnStat และรวมค่า V2Ray traffic (Up/Down)
- `README.md` พร้อม emoji และตัวอย่างการติดตั้ง
- `CHANGELOG.md` เพื่อบันทึกการเปลี่ยนแปลง

### 🐛 Fixed
- แก้บั๊กค่า `V2Ray` ไม่แสดงออนไลน์จริง (ใช้ lastOnline ตรวจสอบ)
- แก้ JSON output ให้เป็น array ครอบ และบีบให้อยู่บรรทัดเดียว
- ป้องกัน `undefined` ในหน้า Dashboard (ค่า System ค้างไว้ถ้า fetch fail)
- `V2Ray Down` แสดงเป็น GB/TB ไม่ใช่ตัวเลขยาว ๆ

### 🔧 Changed
- Dashboard (`index.html`) ปรับปรุงให้เลือกแสดง vnStat อย่างเดียว หากไม่มีค่า V2Ray
- เพิ่มการตรวจสอบ login ทั้ง `application/json` และ `x-www-form-urlencoded`
- ปรับ refresh interval จาก 60s → 5s

---

## [1.0.4] - 2025-09-15
### ✨ Added
- รองรับ Ubuntu 20.04 / 22.04
- รองรับติดตั้งผ่าน `curl | bash` และ `wget | bash`

### 🐛 Fixed
- แก้ nginx port 82 ซ้ำซ้อน
- แก้ path `/server/` ให้ทำงานถูกต้อง

---

## [1.0.3] - 2025-09-10
- เพิ่มการเชื่อมต่อกับฐานข้อมูล `3x-ui`
- JSON แสดง remarks ของ client

---

## [1.0.2] - 2025-09-05
- ปรับปรุงสคริปให้รองรับ Dropbear, OpenVPN

---

## [1.0.1] - 2025-09-01
- เพิ่มการตรวจสอบ SSH online
- แก้ bug การสร้าง symlink service

---

## [1.0.0] - 2025-08-28
- Initial release: Online checker + Dashboard + Nginx port 82
