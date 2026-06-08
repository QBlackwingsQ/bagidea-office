# bagidea CLI — คุมออฟฟิศจากเทอร์มินัล

ตัวติดตั้งผูกคำสั่ง `bagidea` เข้า PATH ให้แล้ว (ติดตั้งเอง: ใช้ `bagidea.cmd`
ที่ root ของ repo หรือเพิ่มโฟลเดอร์ repo เข้า PATH)

## คำสั่งทั้งหมด

```
โปรแกรม
  bagidea start                 เปิดออฟฟิศ (ถ้ายังไม่เปิด)
  bagidea stop                  ปิดทั้งชุด
  bagidea status                ภาพรวมระบบ + agents + โปรเจค + keys
  bagidea stats                 📊 สถิติงาน 7 วัน + ค่าใช้จ่าย + กราฟ
  bagidea update                อัปเดต + รีสตาร์ท
  bagidea version               commit ปัจจุบัน

คุยกับออฟฟิศ
  bagidea ask "<ข้อความ>"        สั่งงานในนาม CEO และรอคำตอบจบ
  bagidea chat <agent> "<msg>"  ส่งงานให้ agent ระบุตัว (ไม่รอ)
  bagidea feed                  ดูเหตุการณ์สด (Ctrl+C ออก)
  bagidea note "<ข้อความ>"       แปะโน้ตบนกระดานกลาง

ทีมและงาน
  bagidea agents                รายชื่อพนักงาน + เสียง + เครื่องมือ
  bagidea projects              รายชื่อโปรเจค + ใครทำงาน
  bagidea open "<โปรเจค>"        เปิดหน้าต่างโปรเจค (= ▶)
  bagidea memory <agent>        อ่านสมุดความจำของ agent
  bagidea office                อ่าน OFFICE.md (ข้อมูลกลาง)

AI features (ใช้ main API keys)
  bagidea say "<ข้อความ>" [preset]  ให้เสียง TTS พูด (default sunny)
  bagidea image "<prompt>"          สร้างภาพ AI → ได้ path
  bagidea keys                      ดู key ที่ตั้งไว้ (ไม่โชว์ค่า)
  bagidea channels                  สถานะ Telegram / Discord / LINE

ซ่อมบำรุง
  bagidea fixmic                รีเซ็ตแผงไมค์ Windows ที่ค้าง
  bagidea help                  หน้านี้
```

## ตัวอย่างการใช้จริง

```powershell
# เปิดเครื่องมา สั่งเปิดออฟฟิศจากเทอร์มินัลเลย
bagidea start

# ถามอะไรก็ได้ — คำสั่งค้างรอจนคำตอบจบ (เหมาะกับใช้ในสคริปต์)
bagidea ask "สรุปงานที่ทีมทำไปเมื่อคืนให้หน่อย"

# สั่งงานยาวๆ แบบไม่รอ แล้วเปิดจอดูเหตุการณ์
bagidea chat pixel "รีแฟกเตอร์ CSS ของโปรเจค Calculator ทั้งหมด"
bagidea feed

# เช็คว่าใครทำอะไรอยู่
bagidea status
```

## ใช้ร่วมกับสคริปต์/automation

- `ask` คืนข้อความล้วนทาง stdout — pipe ต่อได้เลย:
  ```powershell
  bagidea ask "เขียน commit message จาก git diff นี้: $(git diff --stat)" | clip
  ```
- ทุกคำสั่งคุยกับ daemon ที่ `http://127.0.0.1:8787` — endpoint เดียวกับที่
  UI ใช้ (ดูตาราง HTTP API ใน README) เขียน integration ของคุณเองได้ตรงๆ
- `feed` อ่านจาก `daemon/journal.jsonl` — log ถาวรของทั้งออฟฟิศ
