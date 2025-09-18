# Changelog

## V.1.0.3
- เพิ่มตัวเลือก Protocol (http/https) สำหรับ 3x-ui Panel
- ปรับขั้นตอน Uninstall ลบสะอาดหมดจด แต่ไม่ reboot → สามารถ Install ใหม่ได้ทันที
- รักษาโค้ด index.html และ service ให้เหมือน V.1.0.2

## V.1.0.2
- แก้บั๊ก online_app.json ให้เก็บค่า `onlines` + `limite`
- เพิ่มระบบ Auto-Update Installer (ตรวจเช็คเวอร์ชันใหม่จาก GitHub)
- เพิ่มเมนู ShowOn Script Manager (1=Install, 2=Uninstall, 0=Exit)
- หน้าเว็บ index.html ออกแบบใหม่:
  - แสดงจำนวนผู้ใช้งานออนไลน์ (รวม/แยกตามโปรโตคอล)
  - แสดง Limit User Online
  - แสดง System Info (Uptime, CPU, RAM, Disk)
  - อัปเดตทุก 5 วินาทีแบบเรียลไทม์
- Uninstall Script → reboot หลังลบเสร็จ (ก่อนจะแก้ใน V.1.0.3)

## V.1.0.1
- รองรับโหมด Xray-core (2 แบบ)
  - Config `/usr/local/etc/xray/config.json` + logs `/var/log/xray/*.log`
  - Config `/etc/xray/config.json` + logs `/var/log/xray/access.log`
- รองรับโหมด 3x-ui Panel:
  - ใช้ API `/panel/inbound/onlines`
  - ดึงค่าผ่าน cookie login
- รวมการเช็ค online ของ SSH, OpenVPN, Dropbear, V2Ray ไว้ด้วยกัน
- สร้าง JSON `online_app.json` สำหรับให้หน้าเว็บเรียกใช้งาน

## V.1.0.0
- Initial release
- ฟีเจอร์หลัก:
  - สคริปต์ตรวจสอบผู้ใช้งานออนไลน์ (SSH/OpenVPN/Dropbear/V2Ray)
  - บันทึกค่าออกมาเป็น `online_app.json`
  - Nginx serve ไฟล์ JSON บน port 82
- ยังไม่มีหน้าเว็บ index.html (มีแต่ JSON)
- ยังไม่มีระบบ auto update
