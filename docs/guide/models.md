# Models & Providers — สมองถอดเปลี่ยนได้ (เลือกโมเดลต่อ agent)

ออฟฟิศรันด้วย **Claude Code CLI** เป็น engine เสมอ (tools, การแก้ไฟล์, skills,
session loop) — แต่ **"สมอง" (โมเดล) ที่อยู่เบื้องหลังเปลี่ยนได้ต่อ agent** ตั้งที่
⚙ → AGENTS → แก้ไข agent → ช่อง **🧠 สมอง (โมเดล/ผู้ให้บริการ)**

> `claude` เป็นแค่ตัวส่งคำขอ — ชี้ `ANTHROPIC_BASE_URL` ไปเจ้าอื่น มันก็คุยกับเจ้านั้นแทน
> โดย tools/loop ยังเป็นของ Claude Code (ฟรี ในเครื่อง) เปลี่ยนแค่โมเดล

## ทำไมถึงคุ้ม

- **ประหยัด** — โมเดลอย่าง DeepSeek/GLM/Qwen/MiniMax ถูกกว่า Claude หลายเท่าต่อ token
- **ไม่ต้องมี Claude plan ก็ได้** — ถ้าทุก agent ใช้ provider อื่น ก็ **ไม่แตะ credit Claude เลย**
  (ตั้ง provider อื่น + วาง key ของเจ้านั้น แล้วใช้งานได้ — Claude เป็นแค่ค่าเริ่มต้น)
- **fail-open** — agent ที่เป็น Claude หรือยังไม่ตั้ง key จะทำงานเหมือนเดิมทุกประการ

## ตั้งค่ายังไง

1. ⚙ → AGENTS → กดแก้ไข agent ที่ต้องการ
2. ช่อง **🧠 สมอง** → เลือกผู้ให้บริการ (ดีฟอลต์ = Claude)
3. (ถ้าไม่ใช่ Claude) วาง **API key** ของเจ้านั้นในช่องที่โผล่มา — เว้นว่างถ้าเคยตั้งไว้แล้ว
4. ช่อง **โมเดล** เว้นว่างได้ (จะใช้ดีฟอลต์ของเจ้านั้น) หรือระบุเอง เช่น `deepseek-v4-pro`
5. 💾 บันทึก — มีผลกับ session ใหม่ของ agent นั้น (session ที่ resume อยู่จะคงโมเดลเดิมจนเริ่มเธรดใหม่)

> 🧠 ghost (sub-agent) ใช้ provider เดียวกับ agent แม่อัตโนมัติ

## ผู้ให้บริการที่รองรับ

ต่อ Claude Code ได้ **ตรงๆ** (พูด "ภาษา Anthropic"):

| Provider | โมเดลแนะนำ | endpoint (สากล) | ขอ key |
|---|---|---|---|
| **Claude** (ดีฟอลต์) | opus / sonnet / haiku | — (ใช้ login/แผนของคุณ) | claude.ai หรือ ANTHROPIC_API_KEY |
| **GLM** (Z.AI) | `glm-4.6` | `https://api.z.ai/api/anthropic` | z.ai (มี coding plan แบบ key) |
| **DeepSeek** | `deepseek-v4-pro` / `-flash` | `https://api.deepseek.com/anthropic` | platform.deepseek.com |
| **Qwen** (Alibaba) | `qwen3-coder-plus` | `https://dashscope-intl.aliyuncs.com/apps/anthropic` | Alibaba Model Studio |
| **MiniMax** | `MiniMax-M3` | `https://api.minimax.io/anthropic` | platform.minimax.io |

ต้องผ่าน **proxy แปลร่าง (LiteLLM)** เพราะพูด "ภาษา OpenAI":

| Provider | โมเดล | วิธี |
|---|---|---|
| **OpenAI** | `gpt-4o` | proxy แปลร่างในตัว (ดูด้านล่าง) |
| **Gemini** | `gemini-2.5-flash` | proxy แปลร่างในตัว (ดูด้านล่าง) |

> **endpoint จีน** ต่างจากสากล — ถ้าอยู่จีนแผ่นดินใหญ่ตั้ง baseUrl เองได้ (registry `providerConfig.<p>.baseUrl`):
> Qwen `https://dashscope.aliyuncs.com/apps/anthropic` · MiniMax `https://api.minimaxi.com/anthropic` (มี "i" เพิ่ม)

## คำแนะนำการจัดทีม (tiered)

ความแม่นของ tool-use สำคัญต่อ "เงินที่เสียไปกับงานพัง/ทำซ้ำ" — เลือกตามงาน:

| บทบาท | แนะนำ | เหตุผล |
|---|---|---|
| **Director / main** (วางแผน, มอบงาน) | **Claude** | leverage สูง ผิดแล้วกระทบทั้งทีม — เก็บสมองดีไว้ |
| **น้อง build โปรเจค** | **DeepSeek V4 Pro** / GLM | ใกล้ Claude, ถูกกว่า ~10 เท่า, ต่อตรง |
| **น้อง assistant / social** | Qwen / MiniMax | งานเบา ไม่ต้องแม่น, ถูกสุด |

> โมเดลถูกเหมาะกับงาน assistant/chat (มีคนดู แก้ได้ทันที) มากกว่างาน autonomous loop ยาวๆ

## OpenAI / Gemini

OpenAI กับ Gemini พูด "ภาษา OpenAI" ไม่ใช่ Anthropic จึงต้องมีตัวแปลร่าง — **ออฟฟิศมี proxy แปลร่างในตัว** (zero-dep) ให้แล้ว ไม่ต้องลงอะไรเพิ่ม:

**วิธีง่าย (แนะนำ) — proxy ในตัว:**
1. ตั้ง **OPENAI_API_KEY** หรือ **GEMINI_API_KEY** ที่ ⚙ → 🔗 CONNECT (key เดียวกับที่ใช้เสียง/รูป)
2. แก้ไข agent → 🧠 สมอง → เลือก OpenAI หรือ Gemini → ใส่ชื่อโมเดลในช่องโมเดล (เช่น `gpt-4o`, `gemini-2.5-flash`)
3. 💾 → `bagidea restart` → ใช้ได้เลย

> daemon รับ request จาก claude (ภาษา Anthropic) → แปลเป็น OpenAI → ยิงไป OpenAI/Gemini ด้วย key ใน CONNECT
> (key จริงไม่เข้า sandbox) · รองรับ streaming + tool-use · ถ้าไม่มี key → fall back เป็น Claude (ไม่ค้าง)

**วิธี advanced — LiteLLM ของคุณเอง:**
ถ้าอยากใช้ LiteLLM (รองรับ provider/โมเดลมากกว่า) ตั้ง `providerConfig.litellm.baseUrl` (+ token) ใน registry →
ออฟฟิศจะใช้ LiteLLM แทน proxy ในตัว (เลี่ยงเวอร์ชัน 1.82.7/1.82.8 ที่เคยติด malware)

## หมายเหตุเรื่อง credit / นโยบาย

- เลือก provider อื่น = **จ่ายเจ้านั้น ไม่แตะ credit Claude** — `claude` แค่ส่งคำขอไปปลายทางที่ตั้ง
- การเลือกโมเดล/ผู้ให้บริการ **ไม่ผิดนโยบาย** — เป็นฟีเจอร์มาตรฐาน
- token เก็บใน `registry.json` ในเครื่องเท่านั้น (ที่เดียวกับ API keys อื่น) ไม่ถูกส่งไป Anthropic
