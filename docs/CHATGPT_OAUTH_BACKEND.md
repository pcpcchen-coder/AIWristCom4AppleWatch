# ChatGPT OAuth Backend Design

## 決策

AIWristCom v0.1 的 LLM backend 使用：

```text
FastAPI
  ↓
Official Codex App Server
  ↓
ChatGPT managed OAuth
  ↓
ChatGPT/Codex subscription entitlement
```

不使用：

```text
OPENAI_API_KEY
OpenAI Responses API billing
browser cookie scraping
private ChatGPT web endpoints
手動複製 OAuth access token
```

## 為什麼

OpenAI 官方 Codex 支援「使用 ChatGPT 登入」與「使用 API key」兩種模式。

本專案選 ChatGPT managed authentication，原因：

1. v0.1 是個人使用。
2. 已有 ChatGPT 訂閱。
3. 希望先避免額外 API usage billing。
4. Codex App Server 官方提供 app integration、OAuth、thread、turn、model list 與 rate-limit API。

## OAuth lifecycle

推薦由 Codex 管理 OAuth：

```text
account/login/start
  type=chatgptDeviceCode
        ↓
verificationUrl + userCode
        ↓
使用者在瀏覽器完成 ChatGPT 登入
        ↓
account/login/completed
        ↓
account/updated
  authMode=chatgpt
        ↓
Codex 自行保存並 refresh token
```

本專案不讀、不解析、不複製 ChatGPT token。

## Query lifecycle

```text
POST /api/v1/query
        ↓
account/read
        ↓
model/list
        ↓
thread/start
  approvalPolicy=never
  sandbox=readOnly
        ↓
turn/start
        ↓
item/agentMessage/delta
        ↓
turn/completed
        ↓
FastAPI 組合 final reply
        ↓
Watch
```

## 模型選擇

v0.1 不 hard-code 模型名稱。

流程：

1. 呼叫 `model/list`
2. 優先選 `isDefault=true`
3. 若沒有 default，使用第一個 picker-visible model
4. Response 回傳實際 model id，方便 debug

原因：ChatGPT/Codex 可用模型會隨方案與 OpenAI 更新而變化。

## 重要限制

### 1. 不是一般 ChatGPT API

這個架構使用 Codex App Server，不等於「ChatGPT 網頁版 API」。

所以不要假設以下能力自動存在：

- ChatGPT Memory
- ChatGPT 網頁版歷史對話
- 一般 ChatGPT UI tools
- Web browsing
- 所有 ChatGPT model picker 選項

### 2. 使用的是訂閱額度，不是無限免費

不需要額外 API key billing，但仍受 ChatGPT/Codex rate limits 約束。

Gateway 提供：

```
GET /api/v1/limits
```

用來讀取目前 rate-limit window。

### 3. v0.1 用 stdio，不直接開 App Server WebSocket

官方文件把 App Server WebSocket transport 標為 experimental / unsupported for production。

因此：

```text
FastAPI process
  └─ child process: codex app-server
        └─ stdio JSONL
```

Watch 永遠只接 FastAPI HTTPS。

### 4. Personal MVP first

這個方案適合 George 自己的 Watch MVP。

若未來要把 App 公開給其他使用者，認證、每人 ChatGPT entitlement、服務條款、帳號隔離與產品化方式都要重新設計，不能直接共用一個人的 OAuth session。

## 回退方案

若未來 Codex subscription limits 不適合日常語音助理：

```text
Provider A: Codex + ChatGPT OAuth   ← v0.1
Provider B: Local LLM               ← 最省成本 fallback
Provider C: OpenAI API              ← 需要時計費
Provider D: Anthropic API           ← 需要時計費
```

Watch API contract 不變，只替換 Gateway provider。
