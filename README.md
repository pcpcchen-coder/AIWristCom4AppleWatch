# AIWristCom4AppleWatch

把 Apple Watch 變成個人 AI Agent 的「手腕語音終端」。

目標不是單純把 ChatGPT/Claude 搬到手錶上，而是建立一個可擴充的 AI 入口：

```text
Apple Watch
  ↓ Double Tap / 語音輸入
Speech-to-Text
  ↓ WatchConnectivity
Paired iPhone Companion
  ↓ LLM Router
Provider
  ↓
文字回答
  ↓ WatchConnectivity
Apple Watch 顯示 + TTS

v0.1 Provider:
iPhone → Codex Gateway Host → ChatGPT OAuth

Future:
iPhone local model / OpenAI API / Claude / Gemini / OpenClaw / Hermes / FamilyRecorder / Calendar / ToDo
```

---

## 1. 專案目標

第一階段只做一件事，而且一定要做穩：

> 在 Apple Watch 上按一下，說中文，AI 收到後回覆，並可在 Watch 上顯示及朗讀答案。

### MVP 必備功能

- Apple Watch 原生 App
- SwiftUI UI
- 按鈕開始 / 停止錄音
- 中文語音轉文字
- 將文字送到後端 AI Gateway
- 接收 JSON 回覆
- Watch 顯示 AI 答案
- Watch 朗讀 AI 答案
- 錯誤狀態與重新嘗試
- API endpoint 可設定，不把秘密直接硬寫在 App

### MVP 暫時不做

- 多輪聊天紀錄
- 複雜 Agent workflow
- Calendar 寫入
- FamilyRecorder 整合
- Home Assistant
- Watch complication
- Siri / App Intent
- 串流語音
- 離線模型

先把 Voice → AI → Voice 打通，再擴充。

---

## Double Tap 操作（v0.1）

watchOS 11+ 使用官方 `handGestureShortcut(.primaryAction)`：

```text
App 在前景 / idle
→ Double Tap
→ 開始聆聽
→ 說話
→ 再次 Double Tap
→ 停止 + STT + Gateway + AI
→ 顯示並朗讀回答
```

重要限制：Double Tap 不是第三方 App 的全域 hotkey；AIWristCom 必須已在前景，而且 primary-action Button 必須在螢幕上。從 Watch Face 快速進入的下一階段會以 complication / Smart Stack 作入口。

完整設計與驗收： [docs/DOUBLE_TAP_DESIGN.md](docs/DOUBLE_TAP_DESIGN.md)

---

## 2. 使用者體驗

### 主畫面

```text
╭────────────────────╮
│                    │
│       小克         │
│                    │
│        🎙          │
│                    │
│    按一下說話      │
│                    │
╰────────────────────╯
```

### 聆聽中

```text
╭────────────────────╮
│       小克         │
│                    │
│      ～～～～      │
│                    │
│      聆聽中        │
│                    │
╰────────────────────╯
```

### 處理中

```text
╭────────────────────╮
│       小克         │
│                    │
│        ◌           │
│                    │
│    AI 思考中…      │
│                    │
╰────────────────────╯
```

### 回覆

```text
╭────────────────────╮
│ 小克：             │
│                    │
│ 你今天下午 3:30    │
│ 有一場 BMS review  │
│                    │
│   🔊 再播放        │
╰────────────────────╯
```

---

## 3. 建議架構

> **v0.1 架構修正：Apple Watch 的唯一近端 Hub 是配對的 iPhone companion app。**
>
> Watch 透過 WatchConnectivity 把文字送給 iPhone；iPhone 再決定使用哪個 LLM provider。
>
> 目前若要維持「ChatGPT OAuth / 不走 API billing」，iPhone 會再連到可執行 Codex App Server 的 provider host。
>
> 詳見 [docs/IPHONE_COMPANION_ARCHITECTURE.md](docs/IPHONE_COMPANION_ARCHITECTURE.md) 與 [docs/CHATGPT_OAUTH_BACKEND.md](docs/CHATGPT_OAUTH_BACKEND.md)。

```text
┌──────────────────────────────┐
│         Apple Watch          │
│ Double Tap / STT / UI / TTS  │
└──────────────┬───────────────┘
               │ WatchConnectivity
               ▼
┌──────────────────────────────┐
│     iPhone Companion App     │
│ WatchSessionManager          │
│ CompanionLLMRouter           │
│ provider settings            │
└──────────────┬───────────────┘
               │
        replaceable provider
               │
     ┌─────────┴─────────┐
     ▼                   ▼
Remote Codex Host     Future local/API
     │
     ▼
Codex App Server
     │ ChatGPT OAuth
     ▼
ChatGPT/Codex entitlement
```

---

## 4. Repository 規劃

```text
AIWristCom4AppleWatch/
│
├─ README.md
├─ docs/
│  ├─ ARCHITECTURE.md
│  ├─ CHATGPT_OAUTH_BACKEND.md
│  ├─ WEEKEND_BUILD_PLAN.md
│  └─ AGENT_BUILD_PROMPT.md
│
├─ WatchApp/
│  ├─ AIWristComApp.swift
│  ├─ ContentView.swift
│  ├─ Models/
│  │  └─ AppState.swift
│  ├─ Services/
│  │  ├─ SpeechRecognizer.swift
│  │  ├─ PhoneBridge.swift
│  │  ├─ VoiceInteractionController.swift
│  │  └─ SpeechOutput.swift
│  └─ Views/
│     ├─ IdleView.swift
│     ├─ ListeningView.swift
│     ├─ ThinkingView.swift
│     ├─ ResponseView.swift
│     └─ ErrorView.swift
│
├─ iPhoneApp/
│  ├─ AIWristCompanionApp.swift
│  ├─ Models/
│  ├─ Services/
│  │  ├─ WatchSessionManager.swift
│  │  ├─ CompanionSettings.swift
│  │  └─ LLMProvider.swift
│  └─ Views/
│     └─ CompanionHomeView.swift
│
├─ Server/
│  ├─ README.md
│  ├─ main.py
│  ├─ codex_client.py
│  ├─ models.py
│  └─ requirements.txt
│
└─ tests/
   ├─ api_smoke_test.py
   └─ sample_requests.json
```

---

## 5. Watch App State Machine

不要讓 UI 自己亂長狀態，直接定義有限狀態機：

```text
idle
 ↓ tap microphone
listening
 ↓ stop / silence
transcribing
 ↓ text ready
sending
 ↓ response received
speaking
 ↓ finish
idle
```

任何狀態發生例外：

```text
any state → error → retry / back to idle
```

建議 enum：

```swift
enum AppState {
    case idle
    case listening
    case transcribing
    case sending
    case speaking
    case error(String)
}
```

---

## 6. Watch → Server API Contract

### Request

```http
POST /api/v1/query
Content-Type: application/json
Authorization: Bearer <device-token>
```

```json
{
  "text": "幫我整理一下今天下午的工作重點",
  "device": "apple_watch",
  "locale": "zh-TW",
  "session_id": "optional-session-id"
}
```

### Response

```json
{
  "ok": true,
  "request_id": "req_123",
  "reply": "你今天下午可以先處理三件事……",
  "intent": "general_chat",
  "speak": true
}
```

### Error

```json
{
  "ok": false,
  "request_id": "req_123",
  "error": {
    "code": "MODEL_TIMEOUT",
    "message": "AI 暫時沒有回應"
  }
}
```

---

## 7. Agent Router 設計

MVP 先全部走 general_chat。

未來才加入：

```text
general_chat      → LLM
note              → FamilyRecorder / Notes
calendar          → Google Calendar
todo              → ToDo
research          → Web / Research Agent
home              → Home Assistant
local_agent       → OpenClaw / Hermes
```

建議 Router 介面：

```python
def route(text: str) -> str:
    # MVP
    return "general_chat"
```

未來再升級成 rule + LLM intent classifier。

---

## 8. 安全設計

### 不要做

- 不要把 OpenAI / Anthropic API Key 寫死在 Watch App。
- 不要讓 Watch 直接呼叫所有第三方服務。
- 不要把 server admin token 放進 repo。
- 不要把敏感設定 commit 到 Git。

### 建議做法

Watch 只知道：

```text
AI Gateway URL
Device token
```

真正的模型 API Key 放在 Server：

```text
Watch
  ↓
Your Gateway
  ↓
OpenAI / Anthropic / Local Model
```

---

## 9. MVP 驗收標準

### A. Watch UI

- [ ] App 可在真實 Apple Watch 開啟
- [ ] 主畫面有單一清楚的語音按鈕
- [ ] 點擊後顯示 Listening 狀態
- [ ] 狀態切換正確，不會卡死

### B. 語音輸入

- [ ] 可辨識繁體中文
- [ ] 10 秒語音可正常轉文字
- [ ] 轉錄結果可在送出前至少 debug 顯示

### C. API

- [ ] Watch 可透過 HTTPS 呼叫 Server
- [ ] Server 正常解析 request JSON
- [ ] Server 可回傳標準 response JSON
- [ ] 網路斷線時 App 不 crash

### D. AI

- [ ] 一個 provider 可以正常工作
- [ ] 30 秒內無回覆時要 timeout
- [ ] provider error 要轉成統一錯誤格式

### E. 語音輸出

- [ ] Watch 能把 reply 用中文朗讀
- [ ] 可手動重新播放一次

### MVP 完成定義

以下完整流程連續成功 10 次，即視為 MVP Pass：

```text
Open App
→ Tap
→ Speak
→ STT
→ POST API
→ LLM
→ JSON response
→ Display
→ TTS
→ Back to idle
```

---

## 10. 開發順序

不要同時開發全部功能。

### Phase 0 — Environment

1. Mac 安裝最新版 Xcode
2. Apple Watch 與 iPhone 正常配對
3. Xcode 登入 Apple ID
4. 建立 watchOS App project
5. Hello World 跑到實體 Apple Watch

### Phase 1 — Fake AI

先完全不接 AI。

按按鈕後直接顯示：

```text
你好，我是小克。
```

確認 UI 與 Watch deployment 沒問題。

### Phase 2 — Speech Input

只做：

```text
Speak → Text
```

畫面印出辨識結果。

### Phase 3 — API

先不要接真模型。

Server 固定回：

```json
{
  "ok": true,
  "reply": "Server 已收到你的訊息",
  "intent": "general_chat",
  "speak": true
}
```

確認 Watch ↔ Server。

### Phase 4 — 真實 AI（ChatGPT OAuth）

v0.1 固定使用：

```text
FastAPI → codex app-server → ChatGPT OAuth
```

先執行 `codex login`，或呼叫 `POST /api/v1/auth/device/start` 完成 device-code login。

驗收：

- `GET /api/v1/auth/status` 顯示 authenticated=true
- 不設定 `OPENAI_API_KEY`
- `POST /api/v1/query` 能回傳 AI 回答
- `GET /api/v1/limits` 可讀取 ChatGPT/Codex rate limits

### Phase 5 — TTS

AI reply → Watch 語音播放。

### Phase 6 — Error Handling

測：

- Wi-Fi / LTE 斷線
- Server 關閉
- 401
- 500
- timeout
- 空白語音
- STT 失敗

### Phase 7 — Polish

- 觸覺回饋
- loading animation
- 大字體
- Digital Crown scrolling
- 自動回 idle

---

## 11. 未來 Roadmap

### v0.1

Voice → AI → Voice

### v0.2

- Conversation context
- reply history
- retry
- provider switch

### v0.3

- Siri / App Intent
- Smart Stack
- Complication
- Raise-to-use workflow

### v0.4

Agent Router：

- Calendar
- ToDo
- Notes
- FamilyRecorder

### v0.5

- OpenClaw
- Hermes
- Local LLM
- Home Assistant

### v1.0

Apple Watch 成為完整個人 AI Agent Terminal：

```text
Voice
→ Understand intent
→ Pick agent
→ Execute
→ Summarize
→ Speak result
```

---

## 12. 核心設計原則

### 原則 1：Watch 是 Terminal，不是 AI Server

模型不要跑在 Watch 上。

### 原則 2：先完成最短閉環

```text
Voice → Text → API → AI → Text → Voice
```

### 原則 3：所有外部能力走 Gateway

不要讓 Watch 直接整合十個服務。

### 原則 4：API Contract 先固定

Watch 與 Agent backend 才能獨立演進。

### 原則 5：Agent 逐步加入

先做聊天，再做 Action。

---

## 13. 成功畫面

這個專案真正的目標不是做一個「ChatGPT Watch App」。

而是做到：

> 抬手、按一下、說一句話，AI Agent 幫你理解、處理、執行，再從手腕告訴你結果。

這才是 AIWristCom4AppleWatch 的核心。


## v0.1 實作指南

- Watch Double Tap： [docs/DOUBLE_TAP_DESIGN.md](docs/DOUBLE_TAP_DESIGN.md)
- ChatGPT OAuth backend： [docs/CHATGPT_OAUTH_BACKEND.md](docs/CHATGPT_OAUTH_BACKEND.md)
- macOS 後端自動常駐： [docs/MACOS_ALWAYS_ON_GATEWAY.md](docs/MACOS_ALWAYS_ON_GATEWAY.md)
- Watch Xcode setup： [WatchApp/README.md](WatchApp/README.md)
