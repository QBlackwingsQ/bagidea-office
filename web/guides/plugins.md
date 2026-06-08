# Plugins — ส่วนขยายของออฟฟิศ

ระบบ plugin ให้คุณ (และคนอื่นในอนาคต) เพิ่มความสามารถใหม่ให้โปรแกรมได้จริง —
ทั้ง **แผง UI**, **HTTP routes ฝั่ง server**, และ **คำสั่งที่ agents สั่งได้**

เปิดดู/จัดการที่ปุ่ม 🧩 บน header

## โครงสร้าง plugin

วางโฟลเดอร์ไว้ใน `plugins/<id>/`

```
plugins/myplugin/
├── plugin.json     ← manifest (จำเป็น)
├── index.js        ← โค้ดฝั่ง server (ไม่บังคับ)
├── panel.html      ← แผง UI (ไม่บังคับ)
└── data/           ← ที่เก็บข้อมูลของ plugin (สร้างให้อัตโนมัติ)
```

### plugin.json

```json
{
  "id": "myplugin",
  "name": "🧰 My Plugin",
  "version": "1.0.0",
  "description": "อธิบายสั้นๆ",
  "panel": "panel.html",
  "commands": [
    { "name": "do", "args": "<x>", "desc": "ทำอะไรสักอย่าง" }
  ],
  "needsKeys": []
}
```

### index.js (ฝั่ง server)

```js
module.exports = (ctx) => {
  // ctx = { broadcast, reg, workspace, dataDir, pluginDir, manifest, log }
  return {
    // agents/UI เรียก POST /plugin/myplugin/cmd {cmd, args}
    onCommand(cmd, args, reply) {
      if (cmd === "do") return reply({ ok: true, msg: "ทำแล้ว: " + args });
      return reply({ ok: false, msg: "ไม่รู้จักคำสั่ง" });
    },
    // custom routes: GET/POST /plugin/myplugin/<key>
    routes: {
      hello(req, res) { res.writeHead(200); res.end("hi"); },
    },
  };
};
```

- `reply(obj)` ตอบกลับ (เรียก async ก็ได้ หรือ return ค่า/Promise)
- `ctx.broadcast(evt, false)` ส่ง event ไปทุก client (Godot + overlay) — `false` = ไม่ journal
- `ctx.dataDir` โฟลเดอร์เก็บ state ถาวรของ plugin

### panel.html (แผง UI)

หน้า HTML ธรรมดา เปิดใน iframe เมื่อกด ▶ — เรียก API ของตัวเองได้
(`/plugin/<id>/...`) และ subscribe `ws://127.0.0.1:8787/ws` เพื่ออัปเดตสด
(กรอง `e.type === "plugin.event" && e.plugin === "<id>"`)

## agents ใช้ plugin ได้เอง

ทุก plugin ที่มี `commands` จะถูกบอกให้ agents รู้อัตโนมัติ (ใน prompt) —
สั่งในแชทได้เลย เช่น *"เปิดเพลงให้หน่อย"* แล้วน้องจะ:

```
curl -s -X POST http://127.0.0.1:8787/plugin/music/cmd \
  -H "content-type: application/json" -d '{"cmd":"play","args":""}'
```

## plugin ที่ติดมาให้

### 🎵 Music Player (`plugins/music`)
เครื่องเล่นเพลงในออฟฟิศ — วางไฟล์ `.mp3` ไว้ใน `plugins/music/tracks/` แล้วเปิดแผง 🧩
เล่น/หยุด/ถัดไป/วนเพลย์ลิสต์/ปรับเสียงได้ และ **agents สั่งได้** ("เปิดเพลง",
"เปลี่ยนเพลง", "วน playlist ไว้") — เล่นเบื้องหลังระหว่างทำงานได้สบายๆ

## ติดตั้ง plugin (ง่ายสุด)

ในหน้า 🧩 มีช่อง **📦 ติดตั้ง plugin จากลิงก์ GitHub** — วางลิงก์ repo ของ plugin
(เช่น `https://github.com/you/my-plugin`) แล้วกด **⬇ ติดตั้ง** — ระบบ `git clone`
ลงโฟลเดอร์ `plugins/` ให้อัตโนมัติแล้วโหลดทันที (ต้องมี `plugin.json` ใน repo)

ถอนการติดตั้งได้ด้วยปุ่ม 🗑 ข้าง plugin (plugin หลักลบไม่ได้)

## เพิ่มเอง / โหลดใหม่

วางโฟลเดอร์ plugin เองใน `plugins/` แล้วกด 🔄 ในหน้า 🧩 (หรือ `POST /plugins/reload`)
— ไม่ต้องรีสตาร์ทโปรแกรม

## เขียน plugin แยก repo

ทำได้ — เขียนเป็น repo แยกแล้วให้ผู้ใช้ clone ลงโฟลเดอร์ `plugins/` ของเขา
(โครงสร้างเหมือนข้างบน) ในอนาคตจะมี plugin marketplace สำหรับเรียกดู/ติดตั้งจาก
registry กลาง (ดู REQUIREMENT.md ข้อ 11)
