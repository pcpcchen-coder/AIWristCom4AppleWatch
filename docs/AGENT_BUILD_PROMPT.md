# Agent Build Prompt

以下命令可以直接交給 Claude Code / Codex 類 coding agent。

---

你正在開發 GitHub repository：

```
pcpcchen-coder/AIWristCom4AppleWatch
```

請先完整閱讀：

```
README.md
docs/ARCHITECTURE.md
docs/IPHONE_COMPANION_ARCHITECTURE.md
docs/CHATGPT_OAUTH_BACKEND.md
docs/DOUBLE_TAP_DESIGN.md
docs/WEEKEND_BUILD_PLAN.md
```

## 專案目標

建立一個原生 Apple Watch AI 語音終端。

第一版 MVP 流程：

```
Double Tap
→ speak Traditional Chinese
→ speech-to-text on Watch
→ WatchConnectivity
→ paired iPhone Companion
→ iPhone LLMProvider
→ reply through WatchConnectivity
→ Watch displays reply
→ Watch speaks reply
```

## 技術限制

Watch：
- Swift
- SwiftUI
- WatchConnectivity
- Apple 原生 API 優先
- 不使用第三方 UI framework
- 不把 Gateway URL、device token、OAuth token 或 LLM API key 寫入 Watch App
- **Watch 不得直接 HTTP 呼叫 LLM/Gateway**

iPhone Companion：
- SwiftUI
- WatchConnectivity / WCSession
- Watch request 必須先進 iPhone
- iPhone 擁有 provider settings 與 LLM Router
- 即時互動使用 sendMessage/replyHandler

Server（僅目前 ChatGPT OAuth provider host）：
- Python
- FastAPI
- 官方 Codex App Server
- ChatGPT managed OAuth / device-code login
- App Server 使用本機 stdio JSONL transport
- **不得要求 OPENAI_API_KEY**
- **不得呼叫未公開 ChatGPT web endpoint**
- **不得自行解析或複製 OAuth token**
- API contract 必須符合 README

## 必須建立的檔案

```
WatchApp/
  AIWristComApp.swift
  ContentView.swift
  Models/AppState.swift
  Services/SpeechRecognizer.swift
  Services/PhoneBridge.swift
  Services/VoiceInteractionController.swift
  Services/SpeechOutput.swift

iPhoneApp/
  AIWristCompanionApp.swift
  Models/GatewayModels.swift
  Services/WatchSessionManager.swift
  Services/CompanionSettings.swift
  Services/LLMProvider.swift
  Views/CompanionHomeView.swift

Server/
  README.md
  main.py
  codex_client.py
  models.py
  requirements.txt

tests/
  api_smoke_test.py
  sample_requests.json
```

## 開發原則

1. 先讓最短閉環工作。
2. 不提前做 roadmap 功能。
3. 每一階段都必須可測。
4. 錯誤不能直接 crash。
5. 所有 network response 必須 decode 成強型別 model。
6. timeout 必須明確設定。
7. secret 不可 commit。
8. logging 不得輸出 key / token。
9. UI 必須適合 Apple Watch 小螢幕。
10. 程式碼需保留清楚註解，但避免過度抽象。

## AppState

至少：

```
idle
listening
transcribing
sending
speaking
error
```

狀態切換集中管理，不要散落在各個 View。

## Double Tap interaction — 不得改壞

watchOS deployment target 為 11+。

語音主畫面必須只有一個 primary action，並以：

```swift
.handGestureShortcut(.primaryAction, isEnabled: ...)
```

綁定到與實體 Button 相同的 `controller.handlePrimaryAction()`。

狀態規則：

```text
idle       + Double Tap → start listening
listening  + Double Tap → stop + send
transcribing/sending/speaking/error → primary action disabled
```

不要自行使用 accelerometer / Core Motion 模擬 Double Tap，也不要聲稱可以在 Watch Face 全域攔截 Double Tap 喚醒 App。

## Watch ↔ iPhone protocol

Watch 使用 `WCSession.sendMessage`。

Request：

```text
type=query
request_id=<uuid>
text=<recognized text>
locale=zh-TW
```

Reply：

```text
request_id=<same uuid>
reply=<assistant text>
```

Error：

```text
request_id=<same uuid>
error=<message>
```

Watch 不得直接呼叫 `/api/v1/query`。

## v0.1 LLM backend 固定設計

```text
Watch
→ paired iPhone Companion
→ FastAPI/Codex Host
→ codex app-server
→ ChatGPT OAuth
→ subscription entitlement
```

必須實作／保留：

```
GET  /api/v1/auth/status
POST /api/v1/auth/device/start
GET  /api/v1/limits
POST /api/v1/query
```

Codex protocol 至少使用：

```
initialize
initialized
account/read
account/login/start
account/rateLimits/read
model/list
thread/start
turn/start
turn/completed
```

模型不可 hard-code；由 `model/list` 選目前帳號的 default model。

## 完成條件

不要以「程式碼已寫完」作為完成。

必須完成以下驗收：

- Watch project 可 compile
- Server 可啟動
- ChatGPT OAuth / device-code login 可完成
- auth/status 顯示 authenticated=true
- 不設定 OPENAI_API_KEY
- /api/v1/query smoke test pass
- Watch → iPhone sendMessage 可連續成功 10 次
- iPhone 可被 Watch live message 喚醒處理
- Watch 不直接 HTTP 呼叫 Gateway
- iPhone 可取得 provider reply 並回傳 Watch
- error response 不 crash
- 中文 STT flow 已接好
- TTS flow 已接好

最後請輸出：

1. 已完成項目
2. 未完成項目
3. 建置步驟
4. 執行步驟
5. 測試結果
6. 已知限制
7. 下一個最小工作項目

不要自行加入 Calendar、FamilyRecorder、Siri、Complication、多 Agent 或 streaming，除非 MVP 已全部通過。
