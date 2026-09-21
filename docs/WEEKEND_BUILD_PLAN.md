> **2026-09-21 工程狀態更新：** Xcode companion 專案與 mock 往返驗收入口已加入；本地繁中 STT、實機十次往返與完整語音驗收尚未完成。使用者選擇保留兩次 Double Tap，不改系統聽寫。實際進度及操作以 [v0.1 驗收指南](V0_1_ACCEPTANCE.md) 為準。

# Weekend Build Plan

目標：一個週末做出 v0.1 可操作 MVP。

## Day 1 — Watch + iPhone Connectivity

### Step 1 — 建立正確 Xcode project

建立：

```text
AIWristCom iOS App
└─ Apple Watch companion target
```

不是 Watch-only project。

驗收：

- iPhone app 可跑到實體 iPhone
- Watch app 可跑到配對的實體 Apple Watch

### Step 2 — 啟動 WCSession

iPhone 與 Watch 都建立、設定 delegate 並 activate `WCSession.default`。

驗收：

- iPhone 顯示 paired=true
- watch app installed=true
- activationState=activated

### Step 3 — Double Tap + UI state

驗收：

- idle / listening / transcribing / sending / speaking / error 正常
- Double Tap #1 → listening
- Double Tap #2 → finish/send
- busy 狀態不重複觸發

### Step 4 — 語音輸入

驗收：

- 繁中 10 秒語音可轉文字
- 拒絕 microphone/speech permission 時不 crash

### Step 5 — 先只打通 Watch ↔ iPhone

Watch：

```text
sendMessage({
  type: query,
  request_id,
  text,
  locale
})
```

iPhone 暫時固定回：

```text
iPhone 已收到：<text>
```

驗收：

```text
Watch → iPhone → Watch
```

連續 10 次都成功。

> 這一步沒過以前，不准開始接 LLM。

## Day 2 — iPhone LLM Provider + End-to-End

### Step 6 — iPhone Companion Router

iPhone 實作：

```text
WatchSessionManager
→ CompanionLLMRouter
→ LLMProvider
```

Provider 設定只存在 iPhone。

### Step 7 — ChatGPT OAuth provider

目前 no-extra-API-billing 路徑：

```text
Watch
→ iPhone
→ Codex Gateway Host
→ codex app-server
→ ChatGPT OAuth
```

開發期可先用 Mac 作 Codex host。

驗收：

- Codex host `auth/status` authenticated=true
- 不設定 `OPENAI_API_KEY`
- iPhone 可取得 ChatGPT/Codex reply
- Watch 不知道 Gateway URL/OAuth token
- reply 可從 iPhone 回 Watch

### Step 8 — Watch TTS

驗收：

- Watch 顯示 reply
- Watch 以 zh-TW TTS 播放 reply

### Step 9 — Failure tests

至少測：

1. iPhone 不在附近
2. iPhone companion 未安裝
3. iPhone 有連線、Codex host 關閉
4. provider timeout
5. ChatGPT OAuth 過期
6. 空白 STT
7. WatchConnectivity error

### Step 10 — 完整 10-cycle test

```text
Double Tap
→ Speak
→ Double Tap
→ STT
→ WatchConnectivity
→ iPhone
→ LLM
→ iPhone reply
→ Watch display/TTS
→ idle
```

連續 10 次成功才算 v0.1 Pass。

## 第一個週末不要做

- Calendar
- FamilyRecorder
- Home Assistant
- Siri
- Complication
- streaming
- 多 Agent
- fancy animation

先把 Watch ↔ iPhone ↔ LLM 的主路徑做穩。
