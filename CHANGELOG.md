# Changelog

## v1.0.5 - 2025-09-19
### Added
- แยกสคริปต์ออกเป็นหลายไฟล์ (`online.sh`, `sysinfo.sh`, `vnstat-traffic.sh`, `v2ray-traffic.sh`)
- รองรับการ fetch API จาก 3x-ui แบบ fallback (POST/GET → inbounds/list + lastOnline)
- Dashboard UI (`index.html`) แสดงผล:
  - Online Summary
  - System
  - Traffic (vnStat + V2Ray)

### Fixed
- V2Ray Down แสดงผลแบบ human-readable (GB/TB) แทนค่าตัวเลขยาวๆ
- System panel ไม่ขึ้นค่า `undefined` อีกแล้ว หาก fetch ล้มเหลวจะคงค่าเก่าไว้
- online_app.json, sysinfo.json, netinfo.json บันทึกเป็น JSON แบบบรรทัดเดียว (minified)

### Changed
- online_app.json เปลี่ยน field `total` → `onlines` และ `limit` → `limite`
- แสดงเฉพาะข้อมูลที่มีจริง (เช่น ถ้าไม่มี V2Ray → Traffic จะโชว์แค่ vnStat)
