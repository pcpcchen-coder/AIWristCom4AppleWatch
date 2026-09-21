# Architecture

## 1. System Boundary

Apple Watch 僅負責四件事：

1. Capture voice
2. Speech-to-text
3. Send request
4. Present / speak response

其他能力全部放在後端 Gateway。

## 2. Components

### WatchApp

#### ContentView
依 AppState 決定畫面。

#### AudioRecorder
處理 microphone permission、start、stop。

#### SpeechRecognizer
將語音轉成文字。

#### AgentClient
負責 HTTPS request、timeout、JSON decode。

#### SpeechOutput
把 reply 朗讀出來。

### Server

#### main.py
FastAPI HTTP entry point。Apple Watch 只與此服務溝通。

#### codex_client.py
啟動官方 `codex app-server` child process，使用預設 stdio JSONL transport，並實作：

- initialize / initialized
- account/read
- account/login/start（ChatGPT device code）
- account/rateLimits/read
- model/list
- thread/start
- turn/start
- item/agentMessage/delta
- turn/completed

### v0.1 LLM Provider

```text
FastAPI
  ↓
codex app-server
  ↓
ChatGPT managed OAuth
  ↓
ChatGPT/Codex subscription entitlement
```

v0.1 不使用 OpenAI API key，也不直接呼叫 OpenAI Responses API。

模型名稱不 hard-code；啟動 query 時使用 `model/list` 取得目前帳號可用模型並優先選 `isDefault=true`。

## 3. API Versioning

API 一開始就使用：

```
/api/v1/query
```

未來 breaking change 才能開 /api/v2。

## 4. Timeouts

建議：

- Watch HTTP timeout: 30 s
- Gateway provider timeout: 25 s
- STT max utterance for MVP: 30 s

## 5. Logging

Server 每次 request 至少記：

```
timestamp
request_id
device
intent
provider
latency_ms
success
error_code
```

不要記 API key。

若要記完整 user query，請做成可關閉設定。

## 6. Future Streaming

MVP 不做 streaming。

之後可考慮：

```
Watch
  ↕ WebSocket
Gateway
  ↕ streaming provider API
```

但 watchOS 背景生命週期與網路中斷處理會複雜很多，所以不放在 v0.1。


## 7. Authentication boundary

OAuth token 僅由 Codex 管理。

```text
Apple Watch ──X── ChatGPT OAuth token
FastAPI     ──X── raw token parsing

codex app-server
  └─ owns OAuth login
  └─ persists credentials
  └─ refreshes credentials
```

第一次登入可用：

```
codex login
```

或 Gateway 的 device-code flow：

```
POST /api/v1/auth/device/start
```

## 8. Transport decision

v0.1：

```text
FastAPI parent process
  └─ codex app-server
      └─ stdio JSONL
```

不使用 remote WebSocket transport。

Watch 只存取 FastAPI HTTPS endpoint。

## 9. Subscription limits

ChatGPT OAuth 不代表無限制使用。

Gateway 暴露：

```
GET /api/v1/limits
```

讀取 ChatGPT/Codex rate-limit window，日後可在 Watch 顯示使用狀態。
